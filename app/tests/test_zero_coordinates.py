from unittest.mock import Mock, patch

from app import weather_service


@patch("app.weather_service.requests.get")
def test_zero_coordinates_are_valid(mock_get):
    """Zero latitude and longitude are valid coordinates."""

    fake_response = Mock()
    fake_response.raise_for_status.return_value = None
    fake_response.json.return_value = {
        "daily": {
            "time": ["2026-08-03"],
            "temperature_2m_max": [25],
            "temperature_2m_min": [15],
            "weathercode": [0],
        },
        "hourly": {
            "time": [
                "2026-08-03T00:00",
                "2026-08-03T01:00",
            ],
            "temperature_2m": [20, 21],
            "relativehumidity_2m": [60, 80],
        },
    }

    mock_get.return_value = fake_response

    result = weather_service.get_weather_by_coordinates(
        0,
        0,
        "Null Island",
        "International Waters",
    )

    assert result["latitude"] == "0.0"
    assert result["longitude"] == "0.0"
    mock_get.assert_called_once()
