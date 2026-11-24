import os

import httpx
from fastapi import HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from common.factory import create_app

app, log = create_app("frontend")
ORDER_URL = os.getenv("ORDER_URL", "http://localhost:8001")
http = httpx.Client(timeout=15.0)

PAGE = """<!doctype html><html><body style="font-family:sans-serif;max-width:480px;margin:3rem auto">
<h2>Demo shop</h2>
<select id="item"><option>laptop</option><option>phone</option><option>headphones</option></select>
<button onclick="buy()">Place order</button>
<pre id="out"></pre>
<script>
async function buy(){
  const r = await fetch('/api/checkout',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({item_id:document.getElementById('item').value,quantity:1,amount:99.0})});
  document.getElementById('out').textContent = r.status + ' ' + await r.text();
}
</script></body></html>"""


class Checkout(BaseModel):
    item_id: str
    quantity: int = Field(1, gt=0)
    amount: float = Field(gt=0)


@app.get("/", response_class=HTMLResponse)
def index():
    return PAGE


@app.post("/api/checkout")
def checkout(req: Checkout):
    try:
        resp = http.post(f"{ORDER_URL}/orders", json=req.model_dump())
    except httpx.HTTPError:
        raise HTTPException(503, "order-service unreachable")
    if resp.status_code >= 400:
        raise HTTPException(resp.status_code, resp.json().get("detail", "order failed"))
    return resp.json()
