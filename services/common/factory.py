"""Shared app factory: JSON logs, Prometheus metrics, health check, faults."""
import json
import logging
import sys
import time

from fastapi import FastAPI, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

from common import faults

EXEMPT_PATHS = ("/health", "/metrics", "/faults")

REQUESTS = Counter(
    "http_requests_total", "Total HTTP requests",
    ["service", "method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds", "HTTP request latency",
    ["service", "method", "path"],
)


class JsonFormatter(logging.Formatter):
    def __init__(self, service: str) -> None:
        super().__init__()
        self.service = service

    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "service": self.service,
            "message": record.getMessage(),
        }
        entry.update(getattr(record, "extra_fields", {}))
        if record.exc_info:
            entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(entry)


def setup_logging(service: str) -> logging.Logger:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter(service))
    logger = logging.getLogger(service)
    logger.handlers = [handler]
    logger.setLevel(logging.INFO)
    logger.propagate = False
    return logger


def create_app(service: str, **kwargs) -> tuple[FastAPI, logging.Logger]:
    log = setup_logging(service)
    app = FastAPI(title=service, **kwargs)
    app.include_router(faults.router)

    @app.get("/metrics", include_in_schema=False)
    def metrics():
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

    @app.get("/health", tags=["ops"])
    def health():
        return {"status": "ok", "service": service}

    @app.middleware("http")
    async def instrument(request: Request, call_next):
        start = time.perf_counter()
        exempt = request.url.path.startswith(EXEMPT_PATHS)
        response = None
        if not exempt:
            response = await faults.state.maybe_fail()
        if response is None:
            response = await call_next(request)
        elapsed = time.perf_counter() - start

        if not exempt:
            route = request.scope.get("route")
            path = route.path if route else "unmatched"
            REQUESTS.labels(service, request.method, path, response.status_code).inc()
            LATENCY.labels(service, request.method, path).observe(elapsed)
            log.info(
                "request",
                extra={"extra_fields": {
                    "method": request.method, "path": request.url.path,
                    "status": response.status_code,
                    "duration_ms": round(elapsed * 1000, 1),
                }},
            )
        return response

    return app, log
