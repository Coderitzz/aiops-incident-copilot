import os
import time

import redis
from fastapi import HTTPException
from pydantic import BaseModel, Field

from common.factory import create_app

app, log = create_app("inventory-service")
r = redis.Redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379/0"), decode_responses=True)

SEED = {"laptop": 50, "phone": 100, "headphones": 200}


@app.on_event("startup")
def seed_stock():
    for _ in range(30):
        try:
            for item, qty in SEED.items():
                r.setnx(f"stock:{item}", qty)
            return
        except redis.ConnectionError:
            time.sleep(1)
    raise RuntimeError("redis not reachable")


class StockChange(BaseModel):
    item_id: str
    quantity: int = Field(gt=0)


@app.get("/stock/{item_id}")
def get_stock(item_id: str):
    val = r.get(f"stock:{item_id}")
    if val is None:
        raise HTTPException(404, "unknown item")
    return {"item_id": item_id, "stock": int(val)}


@app.post("/reserve")
def reserve(req: StockChange):
    key = f"stock:{req.item_id}"
    if not r.exists(key):
        raise HTTPException(404, "unknown item")
    remaining = r.decrby(key, req.quantity)
    if remaining < 0:
        r.incrby(key, req.quantity)
        raise HTTPException(409, "insufficient stock")
    return {"item_id": req.item_id, "reserved": req.quantity, "remaining": remaining}


@app.post("/release")
def release(req: StockChange):
    remaining = r.incrby(f"stock:{req.item_id}", req.quantity)
    return {"item_id": req.item_id, "remaining": remaining}
