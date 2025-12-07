# SERVIDOR/app/imagens.py
from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from fastapi.responses import FileResponse
from typing import Optional
import base64
import os
from pathlib import Path
import uuid
from .db import get_connection

router = APIRouter()

# Diretório para guardar imagens
IMAGES_DIR = Path("assets/images/artigos")
IMAGES_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/artigos/{id_artigo}/imagem")
async def upload_imagem_artigo(
    id_artigo: int,
    file: UploadFile = File(...)
):
    """
    Upload de imagem para um artigo.
    Guarda a imagem no disco e atualiza o campo Imagem na BD.
    """
    try:
        # Validar tipo de ficheiro
        if not file.content_type.startswith('image/'):
            raise HTTPException(
                status_code=400, 
                detail="Ficheiro deve ser uma imagem"
            )
        
        # Gerar nome único para o ficheiro
        file_extension = file.filename.split('.')[-1]
        unique_filename = f"{id_artigo}_{uuid.uuid4().hex[:8]}.{file_extension}"
        file_path = IMAGES_DIR / unique_filename
        
        # Guardar ficheiro
        content = await file.read()
        with open(file_path, 'wb') as f:
            f.write(content)
        
        print(f"✅ Imagem guardada: {file_path}")
        
        # Atualizar BD com caminho da imagem
        conn = get_connection()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE Artigo 
            SET Imagem = ? 
            WHERE ID_artigo = ?
        """, (str(file_path), id_artigo))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return {
            "success": True,
            "message": "Imagem carregada com sucesso",
            "image_path": str(file_path),
            "id_artigo": id_artigo
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500, 
            detail=f"Erro ao carregar imagem: {str(e)}"
        )


@router.get("/artigos/{id_artigo}/imagem")
def get_imagem_artigo(id_artigo: int):
    """
    Retorna a imagem de um artigo.
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        cur.execute("""
            SELECT Imagem 
            FROM Artigo 
            WHERE ID_artigo = ?
        """, (id_artigo,))
        
        result = cur.fetchone()
        cur.close()
        conn.close()
        
        if not result or not result[0]:
            raise HTTPException(
                status_code=404,
                detail="Artigo não tem imagem"
            )
        
        image_path = Path(result[0])
        
        if not image_path.exists():
            raise HTTPException(
                status_code=404,
                detail="Ficheiro de imagem não encontrado"
            )
        
        return FileResponse(image_path)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao obter imagem: {str(e)}"
        )


@router.get("/artigos/{id_artigo}/imagem/base64")
def get_imagem_base64(id_artigo: int):
    """
    Retorna a imagem em base64 (útil para sincronização mobile).
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        cur.execute("""
            SELECT Imagem 
            FROM Artigo 
            WHERE ID_artigo = ?
        """, (id_artigo,))
        
        result = cur.fetchone()
        cur.close()
        conn.close()
        
        if not result or not result[0]:
            return {
                "success": False,
                "message": "Artigo não tem imagem"
            }
        
        image_path = Path(result[0])
        
        if not image_path.exists():
            return {
                "success": False,
                "message": "Ficheiro não encontrado"
            }
        
        # Ler e converter para base64
        with open(image_path, 'rb') as f:
            image_data = f.read()
            image_base64 = base64.b64encode(image_data).decode('utf-8')
        
        return {
            "success": True,
            "id_artigo": id_artigo,
            "image_base64": image_base64,
            "mime_type": f"image/{image_path.suffix[1:]}"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao processar imagem: {str(e)}"
        )


@router.delete("/artigos/{id_artigo}/imagem")
def delete_imagem_artigo(id_artigo: int):
    """
    Remove a imagem de um artigo.
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        # Buscar caminho da imagem
        cur.execute("""
            SELECT Imagem 
            FROM Artigo 
            WHERE ID_artigo = ?
        """, (id_artigo,))
        
        result = cur.fetchone()
        
        if result and result[0]:
            image_path = Path(result[0])
            
            # Remover ficheiro se existir
            if image_path.exists():
                os.remove(image_path)
                print(f"🗑️ Imagem removida: {image_path}")
        
        # Atualizar BD
        cur.execute("""
            UPDATE Artigo 
            SET Imagem = NULL 
            WHERE ID_artigo = ?
        """, (id_artigo,))
        
        conn.commit()
        cur.close()
        conn.close()
        
        return {
            "success": True,
            "message": "Imagem removida com sucesso"
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao remover imagem: {str(e)}"
        )


@router.get("/artigos/imagens/stats")
def get_imagens_stats():
    """
    Estatísticas sobre imagens dos artigos.
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        # Total de artigos
        cur.execute("SELECT COUNT(*) FROM Artigo")
        total_artigos = cur.fetchone()[0]
        
        # Artigos com imagem
        cur.execute("SELECT COUNT(*) FROM Artigo WHERE Imagem IS NOT NULL")
        artigos_com_imagem = cur.fetchone()[0]
        
        # Artigos sem imagem
        artigos_sem_imagem = total_artigos - artigos_com_imagem
        
        cur.close()
        conn.close()
        
        return {
            "total_artigos": total_artigos,
            "artigos_com_imagem": artigos_com_imagem,
            "artigos_sem_imagem": artigos_sem_imagem,
            "percentagem_com_imagem": round(
                (artigos_com_imagem / total_artigos * 100) if total_artigos > 0 else 0, 
                2
            )
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao obter estatísticas: {str(e)}"
        )