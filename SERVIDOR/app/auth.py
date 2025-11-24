from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from .db import get_connection

router = APIRouter()


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    success: bool
    message: Optional[str] = None
    utilizador: Optional[dict] = None


@router.post("/auth/login", response_model=LoginResponse)
def login(request: LoginRequest):
    """
    Endpoint de autenticação.
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        # Busca utilizador
        query = """
            SELECT ID_utilizador, Nome, Email, Username, Password, Ativo
            FROM Utilizadores
            WHERE Username = ? AND Ativo = 1
        """
        
        cur.execute(query, (request.username,))
        row = cur.fetchone()
        
        if not row:
            cur.close()
            conn.close()
            return LoginResponse(
                success=False,
                message="Utilizador não encontrado ou inativo"
            )
        
        # Verifica password
        if row[4] != request.password:
            cur.close()
            conn.close()
            return LoginResponse(
                success=False,
                message="Password incorreta"
            )
        
        # Login OK
        utilizador = {
            "ID_utilizador": row[0],
            "Nome": row[1],
            "Email": row[2],
            "Username": row[3],
            "Ativo": row[5]
        }
        
        cur.close()
        conn.close()
        
        return LoginResponse(
            success=True,
            message="Login bem-sucedido",
            utilizador=utilizador
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro: {str(e)}")