import unittest
from unittest.mock import Mock, patch
from app import weather_service
from app.exceptions import EmptyLocationError, LocationNotFoundError, InvalidCoordinatesError
import requests
class TestWeatherService(unittest.TestCase):

    def test_parse_location_city_only(self):
        """Verify that parse_location returns city and None when only city is provided."""
        city, country = weather_service.parse_location("London")
        self.assertEqual(city, "London")
        self.assertIsNone(country)

    def test_parse_location_city_and_country(self):
        """Verify that parse_location correctly splits city and country when both are provided."""
        city, country = weather_service.parse_location("London, England")
        self.assertEqual(city, "London")
        self.assertEqual(country, "England")

    def test_parse_location_strip_spaces(self):
        """Verify that parse_location trims whitespace from city and country values."""
        city, country = weather_service.parse_location("  London  ,  England  ")
        self.assertEqual(city, "London")
        self.assertEqual(country, "England")

    def test_get_day_name_valid_date(self):
        """Verify that get_day_name returns correct weekday abbreviation for a valid date string."""
        result = weather_service.get_day_name("2026-04-27")
        self.assertEqual(result, "Mon")

    def test_humidity_avg(self):
        """Verify that humidity_avg calculates correct average humidity per day from hourly data."""
        weather_response = {
            "hourly": {
                "time": [
                    "2026-04-27T00:00",
                    "2026-04-27T01:00",
                    "2026-04-28T00:00",
                    "2026-04-28T01:00",
                ],
                "relativehumidity_2m": [50, 70, 80, 100]
            },
            "daily": {
                "time": ["2026-04-27", "2026-04-28"]
            }
        }

        result = weather_service.humidity_avg(weather_response)

        self.assertEqual(result, [60, 90])

    def test_search_locations_empty_location(self):
        """Verify that search_locations raises EmptyLocationError when input location is empty."""
        with self.assertRaises(EmptyLocationError):
            weather_service.search_locations("")

    def test_search_locations_location_not_found(self):
        """Verify that search_locations raises LocationNotFoundError when no locations are found."""
        with self.assertRaises(LocationNotFoundError):
            weather_service.search_locations("abcdefghigklmnopqrstuvwxyz")

    def test_search_locations_invalid_coordinates(self):
        """Verify that get_weather_by_coordinates raises InvalidCoordinatesError when lat/lon are missing."""
        with self.assertRaises(InvalidCoordinatesError):
            weather_service.get_weather_by_coordinates(None, None, "Tel Aviv", "Israel")

    def test_search_locations_invalid_lat_lon(self):
        """Verify that get_weather_by_coordinates raises InvalidCoordinatesError for out-of-range coordinates."""
        with self.assertRaises(InvalidCoordinatesError):
            weather_service.get_weather_by_coordinates(90, 181, "Tel Aviv", "Israel")

    @patch("app.weather_service.requests.get")
    def test_search_locations_success(self, mock_get):
        """Verify that search_locations returns valid results when API responds successfully."""
        fake_response = Mock()
        fake_response.raise_for_status.return_value = None
        fake_response.json.return_value = {
            "results": [
                {
                    "name": "London",
                    "country": "United Kingdom",
                    "latitude": 51.5,
                    "longitude": -0.1
                }
            ]
        }

        mock_get.return_value = fake_response

        result = weather_service.search_locations("London")

        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["name"], "London")
        self.assertEqual(result[0]["country"], "United Kingdom")

    @patch("app.weather_service.requests.get")
    def test_search_locations_not_found(self, mock_get):
        """Verify that search_locations raises LocationNotFoundError when API returns empty results."""
        fake_response = Mock()
        fake_response.raise_for_status.return_value = None
        fake_response.json.return_value = {
            "results": []
        }

        mock_get.return_value = fake_response

        with self.assertRaises(LocationNotFoundError):
            weather_service.search_locations("UnknownCity")


    @patch("app.weather_service.requests.get")
    def test_get_weather_by_coordinates_success(self, mock_get):
        """Verify that get_weather_by_coordinates returns correctly structured weather data on success."""
        fake_response = Mock()
        fake_response.raise_for_status.return_value = None
        fake_response.json.return_value = {
            "daily": {
                "time": ["2026-04-27"],
                "temperature_2m_max": [25],
                "temperature_2m_min": [15],
                "weathercode": [0]
            },
            "hourly": {
                "time": ["2026-04-27T00:00", "2026-04-27T01:00"],
                "temperature_2m": [20, 21],
                "relativehumidity_2m": [60, 80]
            }
        }

        mock_get.return_value = fake_response

        result = weather_service.get_weather_by_coordinates(
            32.1,
            34.8,
            "Tel Aviv",
            "Israel"
        )

        self.assertEqual(result["location"], "Tel Aviv")
        self.assertEqual(result["country"], "Israel")
        self.assertEqual(result["humidity_daily"], [70])
        self.assertIn("daily", result)
        self.assertIn("hourly", result)
        self.assertIn("icons", result)
        self.assertIn("day_names", result)

    def test_weather_app_reachable(self):
        """Verify that the Weather App is reachable."""
        response = requests.get(
            "http://weather-app-alb-390538117.us-east-1.elb.amazonaws.com",
            timeout=5
        )

        self.assertEqual(
            response.status_code,
            200
        )


if __name__ == "__main__":
    unittest.main()