from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from .config import settings
from .db import ping_db
from .auth import router as auth_router
from .artigos import router as artigos_router
from .sync import router as sync_router
from .imagens import router as imagens_router  
from pathlib import Path

app = FastAPI(title="ARMAZÉM API", version="2.0.0")

# Criar diretório de imagens se não existir
IMAGES_DIR = Path("assets/images")
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

# Servir imagens estaticamente (opcional, para acesso direto via URL)
app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")

# Registar routers
app.include_router(auth_router)
app.include_router(artigos_router)
app.include_router(sync_router)
app.include_router(imagens_router)  

@app.get("/")
def root():
    """Informação sobre a API."""
    return {
        "name": "ARMAZÉM API",
        "version": "2.0.0",
        "features": [
            "Autenticação offline-first",
            "Gestão de artigos",
            "Sincronização de dados",
            "Upload e gestão de imagens",  
            "Scanners NFC/RFID/QR/AR"
        ],
        "endpoints": {
            "health": "/health",
            "auth": "/auth/login",
            "artigos": "/artigos",
            "sync": "/sync/*",
            "imagens": "/artigos/{id}/imagem"
        }
    }

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