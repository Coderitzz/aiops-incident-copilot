import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_faults():
    client.delete("/faults")
    yield
    client.delete("/faults")


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["service"] == "payment-service"


def test_charge_is_approved():
    r = client.post("/charge", json={"amount": 99})
    assert r.status_code == 200
    assert r.json()["status"] == "approved"


def test_charge_over_limit_is_declined():
    assert client.post("/charge", json={"amount": 20000}).status_code == 402


def test_injected_errors_can_be_reset():
    client.post("/faults", json={"error_rate": 1.0})
    assert client.post("/charge", json={"amount": 10}).status_code == 500
    client.delete("/faults")
    assert client.post("/charge", json={"amount": 10}).status_code == 200


def test_metrics_are_exposed():
    client.post("/charge", json={"amount": 10})
    body = client.get("/metrics").text
    assert "http_requests_total" in body
    assert "http_request_duration_seconds" in body
