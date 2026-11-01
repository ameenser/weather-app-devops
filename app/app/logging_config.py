import json
import logging
import os
import sys
from datetime import datetime, timezone


LOG_FIELDS = (
    "request_id",
    "method",
    "route",
    "status_code",
    "duration_ms",
    "error_type",
)


class JsonFormatter(logging.Formatter):
    """Convert application log records into structured JSON."""

    def format(self, record):
        timestamp = datetime.fromtimestamp(
            record.created,
            tz=timezone.utc,
        ).isoformat(timespec="milliseconds").replace("+00:00", "Z")

        payload = {
            "timestamp": timestamp,
            "level": record.levelname,
            "service": os.getenv("SERVICE_NAME", "weather-app"),
            "environment": os.getenv("APP_ENV", "unknown"),
            "event": getattr(record, "event", "application_log"),
            "message": record.getMessage(),
        }

        for field in LOG_FIELDS:
            value = getattr(record, field, None)
            if value is not None:
                payload[field] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(
            payload,
            ensure_ascii=False,
            default=str,
        )


def configure_logging():
    """Create the application logger that writes JSON to stdout."""

    logger = logging.getLogger("weather-app")
    logger.setLevel(os.getenv("LOG_LEVEL", "INFO").upper())
    logger.handlers.clear()
    logger.propagate = False

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())

    logger.addHandler(handler)

    return logger
