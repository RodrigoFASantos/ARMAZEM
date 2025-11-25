from fastapi import FastAPI, HTTPException
from .config import settings
from .db import ping_db
from .auth import router as auth_router
from .artigos import router as artigos_router
from .sync import router as sync_router

app = FastAPI(title="ARMAZÉM API", version="1.0.0")

# Registar routers
app.include_router(auth_router)
app.include_router(artigos_router)
app.include_router(sync_router)

@app.get("/health")
def health():
    """Verifica se a API está online."""
    return {"status": "ok", "env": settings.app_env}

@app.get("/db/ping")
def db_ping():
    """Testa a conexão à base de dados."""
    try:
        ping_db()
        return {"db": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB ping falhou: {e}")