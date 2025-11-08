from fastapi import FastAPI, HTTPException
from .config import settings
from .db import ping_db

app = FastAPI(title="AR-ERP API", version="0.1.0")

@app.get("/health")
def health():
    return {"status": "ok", "env": settings.app_env}

@app.get("/db/ping")
def db_ping():
    try:
        ping_db()
        return {"db": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB ping falhou: {e}")
