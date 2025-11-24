from fastapi import FastAPI, HTTPException
from .config import settings
from .db import ping_db
from .CARREGAR_DADOS import router as sync_router
from .auth import router as auth_router

app = FastAPI(title="AR-ERP API", version="0.1.0")

app.include_router(sync_router)
app.include_router(auth_router)

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