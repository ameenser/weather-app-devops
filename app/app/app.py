#### review by Adi ####
from flask import Flask, render_template, request, redirect, url_for, Response, g
import os
import boto3
import weather_service
from exceptions import (InvalidCoordinatesError,
                        WeatherAPIError,EmptyLocationError,LocationNotFoundError)

from datetime import datetime, timezone
from decimal import Decimal
import json
import time
from uuid import uuid4
from logging_config import configure_logging
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

app = Flask(__name__)
logger = configure_logging()
@app.context_processor
def inject_background_flag():
    return {
        "change_background_color": os.getenv(
            "CHANGE_BACKGROUND_COLOR", "false"
        ).lower() == "true"
    }

dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
weather_table = dynamodb.Table("WeatherData")


HTTP_REQUESTS_TOTAL = Counter(
    "weather_app_http_requests_total",
    "Total number of HTTP requests handled by the weather application.",
    ["method", "route", "status"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "weather_app_http_request_duration_seconds",
    "Time spent processing HTTP requests.",
    ["method", "route"],
)

CITY_LOOKUPS_TOTAL = Counter(
    "weather_app_city_lookups_total",
    "Total number of successful weather lookups for each city.",
    ["city"],
)

@app.before_request
def start_request_timer():
    """Create a request ID and record the request start time."""
    g.request_id = str(uuid4())

    if request.path != "/metrics":
        g.request_start_time = time.perf_counter()



@app.after_request
def record_request_metrics(response):
    """Record metrics and write a structured request log."""
    if request.path == "/metrics":
        return response

    route = request.url_rule.rule if request.url_rule else "unmatched"
    start_time = getattr(g, "request_start_time", None)

    duration_seconds = None
    if start_time is not None:
        duration_seconds = time.perf_counter() - start_time

    HTTP_REQUESTS_TOTAL.labels(
        method=request.method,
        route=route,
        status=str(response.status_code),
    ).inc()

    if duration_seconds is not None:
        HTTP_REQUEST_DURATION_SECONDS.labels(
            method=request.method,
            route=route,
        ).observe(duration_seconds)

    logger.info(
        "HTTP request completed",
        extra={
            "event": "http_request_completed",
            "request_id": g.request_id,
            "method": request.method,
            "route": route,
            "status_code": response.status_code,
            "duration_ms": (
                round(duration_seconds * 1000, 2)
                if duration_seconds is not None
                else None
            ),
        },
    )

    response.headers["X-Request-ID"] = g.request_id

    return response



@app.route("/metrics")
def metrics():
    """Expose application metrics in Prometheus format."""
    return Response(generate_latest(), content_type=CONTENT_TYPE_LATEST)


@app.route("/")
def home():
    """ Render the home page with the location search form. """
    return render_template("home.html")

@app.route("/locations")
def locations():
    """Handle location search requests and route the user accordingly.

    This endpoint retrieves the 'location' query parameter from the request,
    parses it into city and optional country, and fetches matching locations
    using the weather service.

    Behavior:
    - If only a city is provided → renders 'locations.html' with a list of matches.
    - If both city and country are provided → redirects directly to the forecast page
      using the first matching location.
    - If an error occurs (empty input, no results, API failure) → renders 'home.html'
      with an appropriate error message.

    Exceptions handled:
    - EmptyLocationError → when the input is empty
    - LocationNotFoundError → when no matching locations are found
    - WeatherAPIError → when external API fails
    - Generic Exception → fallback for unexpected errors
    """
    try:
        location = request.args.get("location")
        city, country = weather_service.parse_location(location)

        locations_list = weather_service.search_locations(location)

        if country:
            selected_place = locations_list[0]
            return redirect(url_for(
                "forecast",
                lat=selected_place["latitude"],
                lon=selected_place["longitude"],
                name=selected_place["name"],
                country=selected_place["country"]
            ))

        return render_template("locations.html",locations=locations_list,search_value=location)
    except EmptyLocationError as error:
        logger.warning(
            "Location search rejected because location is empty",
            extra={
                "event": "empty_location",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/locations",
                "error_type": type(error).__name__,
            },
        )
        return render_template("home.html", error=str(error))

    except LocationNotFoundError as error:
        logger.warning(
            "Location search returned no matches",
            extra={
                "event": "location_not_found",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/locations",
                "error_type": type(error).__name__,
            },
        )
        return render_template("home.html", error=str(error))

    except WeatherAPIError as error:
        logger.error(
            "External weather API failed during location search",
            extra={
                "event": "weather_api_error",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/locations",
                "error_type": type(error).__name__,
            },
            exc_info=True,
        )
        return render_template("home.html", error=str(error))

    except Exception as error:
        logger.exception(
            "Unexpected error during location search",
            extra={
                "event": "unexpected_location_error",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/locations",
                "error_type": type(error).__name__,
            },
        )
        return render_template(
            "home.html",
            error="Something went wrong",
        )


@app.route("/forecast")
def forecast():
    """Render the weather forecast page for a selected location.

    This endpoint reads query parameters (lat, lon, name, country) from the URL,
    retrieves weather data using the weather service, and displays it on the
    'forecast.html' page.

    Behavior:
    - Expects valid latitude and longitude values in the request.
    - Calls get_weather_by_coordinates to fetch weather data.
    - Renders 'forecast.html' with the returned data.

    Error Handling:
    - InvalidCoordinatesError → returned when lat/lon are missing or invalid,
      redirects user back to home page with an error message.
    - WeatherAPIError → returned when the external weather API fails.
    - Generic Exception → fallback for unexpected errors.

    Returns:
        HTML page with weather forecast data or error message.
    """

    try:
        lat = request.args.get("lat")
        lon = request.args.get("lon")
        name = request.args.get("name")
        country = request.args.get("country")

        data = weather_service.get_weather_by_coordinates(lat, lon, name, country)
        city_label = name.strip().lower()
        CITY_LOOKUPS_TOTAL.labels(city=city_label).inc()
        tips = []

        for i in range(len(data["daily"]["time"])):
            code = data["daily"]["weathercode"][i]
            max_temp = data["daily"]["temperature_2m_max"][i]

            tips.append(
                weather_service.get_weather_tip(code, max_temp)
            )

        data["tips"] = tips

        return render_template("forecast.html", data=data)


    except InvalidCoordinatesError as error:
        logger.warning(
            "Forecast request rejected because coordinates are invalid",
            extra={
                "event": "invalid_coordinates",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/forecast",
                "error_type": type(error).__name__,
            },
        )
        return render_template("home.html", error=str(error))


    except WeatherAPIError as error:
        logger.error(
            "External weather API failed while retrieving forecast",
            extra={
                "event": "weather_api_error",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/forecast",
                "error_type": type(error).__name__,
            },
            exc_info=True,
        )
        return render_template("home.html", error=str(error))

    except Exception as error:
        logger.exception(
            "Unexpected error while retrieving forecast",
            extra={
                "event": "unexpected_forecast_error",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/forecast",
                "error_type": type(error).__name__,
            },
        )
        return render_template("home.html", error="Something went wrong")

@app.route("/save-weather", methods=["POST"])
def save_weather():
    try:
        city = request.form.get("city")
        country = request.form.get("country")
        lat = request.form.get("lat")
        lon = request.form.get("lon")

        if not city or not lat or not lon:
            logger.warning(
                "Save weather request rejected because data is missing",
                extra={
                    "event": "missing_weather_data",
                    "request_id": getattr(g, "request_id", "unknown"),
                    "route": "/save-weather",
                },
            )
            return render_template(
                "home.html",
                error="Missing weather data",
            )

        data = weather_service.get_weather_by_coordinates(lat, lon, city, country)

        item = {
            "city": city,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "country": country,
            "latitude": Decimal(str(lat)),
            "longitude": Decimal(str(lon)),
            "weather_data": json.loads(json.dumps(data), parse_float=Decimal)
        }

        weather_table.put_item(Item=item)

        tips = []
        for i in range(len(data["daily"]["time"])):
            code = data["daily"]["weathercode"][i]
            max_temp = data["daily"]["temperature_2m_max"][i]
            tips.append(weather_service.get_weather_tip(code, max_temp))

        data["tips"] = tips

        return render_template(
            "forecast.html",
            data=data,
            success="Weather data saved to DynamoDB"
        )

    except Exception as error:
        logger.exception(
            "Failed to save weather data",
            extra={
                "event": "save_weather_failed",
                "request_id": getattr(g, "request_id", "unknown"),
                "route": "/save-weather",
                "error_type": type(error).__name__,
            },
        )
        return render_template(
            "home.html",
            error="Failed to save weather data",
        )

@app.route('/download-sky')
def download_sky():

    s3 = boto3.client('s3', region_name='us-east-1')

    url = s3.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': 'weather-app-bucket-ameenser',
            'Key': 'images/sky.jpg',
            'ResponseContentDisposition': 'attachment; filename="sky.jpg"'
        },
        ExpiresIn=300
    )

    return redirect(url)

if __name__ == "__main__":
    app.run(debug=True)
