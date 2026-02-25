import os
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Rx Fraud/Waste Scoring API", version="1.0.0")

class ScoreRequest(BaseModel):
    npi_list: list[str]

@app.get("/health")
def health():
    return {"status": "ok", "deploy_color": os.getenv("DEPLOY_COLOR", "unknown")}
