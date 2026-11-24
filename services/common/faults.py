"""Fault injection: lets you break a service on demand during demos."""
import asyncio
import random

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field


class FaultConfig(BaseModel):
    latency_ms: int = Field(0, ge=0, le=30000)
    error_rate: float = Field(0.0, ge=0.0, le=1.0)


class LeakRequest(BaseModel):
    mb: int = Field(10, ge=1, le=512)


class FaultState:
    def __init__(self) -> None:
        self.config = FaultConfig()
        self.leak: list[bytearray] = []
        self.leaked_mb = 0

    async def maybe_fail(self):
        """Apply latency, then maybe return a 500 response."""
        if self.config.latency_ms:
            await asyncio.sleep(self.config.latency_ms / 1000)
        if self.config.error_rate and random.random() < self.config.error_rate:
            return JSONResponse({"detail": "injected fault"}, status_code=500)
        return None


state = FaultState()
router = APIRouter(prefix="/faults", tags=["faults"])


@router.get("")
def get_faults():
    return {"config": state.config, "leaked_mb": state.leaked_mb}


@router.post("")
def set_faults(cfg: FaultConfig):
    state.config = cfg
    return {"config": state.config}


@router.post("/leak")
def leak_memory(req: LeakRequest):
    # b"x" * n forces real allocation, so RSS actually grows
    state.leak.append(bytearray(b"x") * (req.mb * 1024 * 1024))
    state.leaked_mb += req.mb
    return {"leaked_mb": state.leaked_mb}


@router.delete("")
def reset_faults():
    state.config = FaultConfig()
    state.leak.clear()
    state.leaked_mb = 0
    return {"status": "reset"}
