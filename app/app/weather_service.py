#### review by Adi ####
import requests
from datetime import datetime

from exceptions import InvalidCoordinatesError, WeatherAPIError,EmptyLocationError,LocationNotFoundError


def search_locations(location):
    """Search locations via API, filter by country if provided, and return results.

    Raises:
        EmptyLocationError, WeatherAPIError, LocationNotFoundError
    """

    if not location or not location.strip():
        raise  EmptyLocationError("Empty location")

    city, country = parse_location(location)
    geo_url = "https://geocoding-api.open-meteo.com/v1/search"
    geo_params = {
        "name": city,
        "count": 10
    }

    try:

        response = requests.get(geo_url, params=geo_params)
        response.raise_for_status()
        geo_response = response.json()

    except requests.exceptions.Timeout:
        raise WeatherAPIError("request timed out")

    except requests.exceptions.ConnectionError:
        raise WeatherAPIError("failed to connect to weather service")

    except requests.exceptions.HTTPError:
        raise WeatherAPIError("API returned error")

    except Exception:
        raise Exception("Unexpected error occurred")

    results = geo_response.get("results", [])

    if not results:
        raise LocationNotFoundError("No locations found")

    if country:
        results = [
            place for place in results
            if place.get("country", "").strip().lower() == country.strip().lower()
        ]
        if not results:
            raise LocationNotFoundError("No matching locations found for country")

    return results


def get_weather_by_coordinates(lat, lon, name, country_name):
    """
    Fetch weather data by coordinates and return structured forecast.

    Validates coordinates, calls API, and formats response.

    Raises:
        InvalidCoordinatesError, WeatherAPIError
    """
    if lat is None or lon is None:
        raise InvalidCoordinatesError("Missing latitude or longitude")
    try:
        lat = float(lat)
        lon = float(lon)
    except (TypeError, ValueError):
        raise InvalidCoordinatesError("Latitude and longitude must be numbers")

    if not (-90 <= float(lat) <= 90 and -180 <= float(lon) <= 180):
        raise InvalidCoordinatesError("Invalid latitude or longitude range")


    weather_url = "https://api.open-meteo.com/v1/forecast"

    weather_params = {
        "latitude": lat,
        "longitude": lon,
        "daily": "temperature_2m_max,temperature_2m_min,weathercode",
        "hourly": "temperature_2m,relativehumidity_2m",
        "timezone": "auto"
    }
    try:
        response = requests.get(weather_url, params=weather_params, timeout=5)
        response.raise_for_status()
        weather_response = response.json()

    except requests.exceptions.Timeout:
        raise WeatherAPIError("Weather API timeout. Please try again.")

    except requests.exceptions.ConnectionError:
        raise WeatherAPIError("Cannot connect to Weather API.")

    except requests.exceptions.HTTPError:
        raise WeatherAPIError("Weather API returned an error.")

    try:
        codes = weather_response["daily"]["weathercode"]
        icons = [get_weather_icon(code) for code in codes]

        daily_times = weather_response["daily"]["time"]
        day_names = [get_day_name(d) for d in daily_times]

        humidity_daily = humidity_avg(weather_response)

        data = {
            "location": name,
            "country": country_name,
            "latitude": str(lat),
            "longitude": str(lon),
            "daily": weather_response["daily"],
            "hourly": weather_response["hourly"],
            "humidity_daily": humidity_daily,
            "icons": icons,
            "day_names": day_names
        }

        return data

    except KeyError:
        raise WeatherAPIError("Weather API response is missing required data.")


def parse_location(location):
    """Split a location string into city and optional country."""

    if not isinstance(location, str) or not location.strip():
        raise EmptyLocationError("Location must not be empty")

    parts = location.split(",")

    city = parts[0].strip()
    if not city:
        raise EmptyLocationError("City must not be empty")

    country = None
    if len(parts) > 1:
        country = parts[1].strip() or None

    return city, country


def humidity_avg(weather_response):
    """Calculate average daily humidity from hourly weather data."""
    try:
        hourly_times = weather_response["hourly"]["time"]
        hourly_humidity = weather_response["hourly"]["relativehumidity_2m"]
        daily_times = weather_response["daily"]["time"]
    except KeyError:
        raise Exception("Missing data in weather response")

    humidity_by_day = {}

    for time, humidity in zip(hourly_times, hourly_humidity):
        day = time.split("T")[0]

        if day not in humidity_by_day:
            humidity_by_day[day] = []

        humidity_by_day[day].append(humidity)

    humidity_daily = []

    for day in daily_times:
        day_values = humidity_by_day.get(day, [])

        if not day_values:
            raise Exception(f"Missing hourly humidity data for day {day}")

        avg_humidity = sum(day_values) / len(day_values)
        humidity_daily.append(round(avg_humidity))

    return humidity_daily

def get_weather_tip(code, max_temp):
    if code in range(51, 68):
        return "Take an umbrella ☔"

    if code in range(71, 78):
        return "Wear warm clothes ❄️"

    if max_temp >= 30:
        return "Drink water and avoid long sun exposure 🥵"

    if code in range(0, 4):
        return "Great day to go outside ☀️"

    return "Check the weather before going out 🌤️"



def get_weather_icon(code):
    """Return weather icon based on weather code."""
    if code == 0:
        return "☀️"
    elif 1 <= code <= 3:
        return "🌤️"
    elif 45 <= code <= 48:
        return "🌫️"
    elif 51 <= code <= 67:
        return "🌧️"
    elif 71 <= code <= 77:
        return "❄️"
    elif 80 <= code <= 82:
        return "🌦️"
    elif 95 <= code <= 99:
        return "⛈️"
    else:
        return "🌍"


def get_day_name(date_str):
    """Convert date string (YYYY-MM-DD) to weekday abbreviation."""
    date_obj = datetime.strptime(date_str, "%Y-%m-%d")
    return date_obj.strftime("%a")
