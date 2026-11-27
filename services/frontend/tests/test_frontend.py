from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json()["service"] == "frontend"


def test_index_page_renders():
    r = client.get("/")
    assert r.status_code == 200
    assert "Demo shop" in r.text


def test_checkout_returns_503_when_order_service_is_down():
    r = client.post("/api/checkout", json={"item_id": "laptop", "quantity": 1, "amount": 10})
    assert r.status_code == 503
