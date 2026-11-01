class WeatherAppError(Exception):
    pass

class EmptyLocationError(WeatherAppError):
    pass

class LocationNotFoundError(WeatherAppError):
    pass

class WeatherAPIError(WeatherAppError):
    pass

class InvalidCoordinatesError(WeatherAppError):
    pass
