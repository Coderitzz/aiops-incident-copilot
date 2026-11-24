import random
import uuid

from fastapi import HTTPException
from pydantic import BaseModel, Field

from common.factory import create_app

app, log = create_app("payment-service")


class ChargeRequest(BaseModel):
    amount: float = Field(gt=0)


@app.post("/charge")
def charge(req: ChargeRequest):
    if req.amount > 10000:
        raise HTTPException(status_code=402, detail="amount exceeds limit")
    return {
        "transaction_id": str(uuid.uuid4()),
        "status": "approved",
        "processing_ms": random.randint(5, 40),
    }
