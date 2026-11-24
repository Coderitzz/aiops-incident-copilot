import os
import time

import httpx
import psycopg
from fastapi import HTTPException
from pydantic import BaseModel, Field

from common.factory import create_app

app, log = create_app("order-service")

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://app:app@localhost:5432/orders")
INVENTORY_URL = os.getenv("INVENTORY_URL", "http://localhost:8003")
PAYMENT_URL = os.getenv("PAYMENT_URL", "http://localhost:8002")
http = httpx.Client(timeout=10.0)


@app.on_event("startup")
def init_db():
    for _ in range(30):
        try:
            with psycopg.connect(DATABASE_URL) as conn:
                conn.execute(
                    """CREATE TABLE IF NOT EXISTS orders (
                         id SERIAL PRIMARY KEY,
                         item_id TEXT NOT NULL,
                         quantity INT NOT NULL,
                         amount NUMERIC(10,2) NOT NULL,
                         transaction_id TEXT,
                         status TEXT NOT NULL,
                         created_at TIMESTAMPTZ DEFAULT now()
                       )"""
                )
            return
        except psycopg.OperationalError:
            time.sleep(1)
    raise RuntimeError("postgres not reachable")


class OrderRequest(BaseModel):
    item_id: str
    quantity: int = Field(1, gt=0)
    amount: float = Field(gt=0)


@app.post("/orders", status_code=201)
def create_order(req: OrderRequest):
    inv = http.post(f"{INVENTORY_URL}/reserve", json={"item_id": req.item_id, "quantity": req.quantity})
    if inv.status_code != 200:
        raise HTTPException(inv.status_code, f"inventory: {inv.json().get('detail')}")

    try:
        pay = http.post(f"{PAYMENT_URL}/charge", json={"amount": req.amount})
        pay.raise_for_status()
    except httpx.HTTPError as exc:
        http.post(f"{INVENTORY_URL}/release", json={"item_id": req.item_id, "quantity": req.quantity})
        log.error("payment failed, stock released", extra={"extra_fields": {"error": str(exc)}})
        raise HTTPException(502, "payment failed")

    txn = pay.json()["transaction_id"]
    with psycopg.connect(DATABASE_URL) as conn:
        row = conn.execute(
            "INSERT INTO orders (item_id, quantity, amount, transaction_id, status) "
            "VALUES (%s,%s,%s,%s,'confirmed') RETURNING id",
            (req.item_id, req.quantity, req.amount, txn),
        ).fetchone()
    return {"order_id": row[0], "status": "confirmed", "transaction_id": txn}


@app.get("/orders/{order_id}")
def get_order(order_id: int):
    with psycopg.connect(DATABASE_URL) as conn:
        row = conn.execute(
            "SELECT id, item_id, quantity, amount, status FROM orders WHERE id=%s", (order_id,)
        ).fetchone()
    if not row:
        raise HTTPException(404, "order not found")
    return {"order_id": row[0], "item_id": row[1], "quantity": row[2], "amount": float(row[3]), "status": row[4]}
