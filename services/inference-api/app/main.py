import os
from fastapi import FastAPI
from pydantic import BaseModel
import socket

app = FastAPI(title="Rx Fraud/Waste Scoring API", version="1.0.0")

class ScoreRequest(BaseModel):
    npi_list: list[str]

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/version")
def version():
    return {
        "version": os.getenv("APP_VERSION", "unknown"),
        "pod": socket.gethostname(),
        "commit": os.getenv("GIT_COMMIT", "unknown"),
    }
