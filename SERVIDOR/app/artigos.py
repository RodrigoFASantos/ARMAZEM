from fastapi import APIRouter, HTTPException
from typing import List, Optional
from .db import get_connection

router = APIRouter()


@router.get("/artigos")
def get_all_artigos():
    """
    Retorna todos os artigos com informações de tipo, família e stock.
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        query = """
            SELECT 
                a.ID_artigo,
                a.ID_tipo,
                a.ID_familia,
                a.Referencia,
                a.Designacao,
                a.Imagem,
                a.Cod_bar,
                a.Cod_NFC,
                a.Cod_RFID,
                t.Designacao AS tipo_designacao,
                f.Designacao AS familia_designacao
            FROM Artigo a
            LEFT JOIN Tipo t ON a.ID_tipo = t.ID_tipo
            LEFT JOIN Familia f ON a.ID_familia = f.ID_familia
            ORDER BY a.Designacao
        """
        
        cur.execute(query)
        rows = cur.fetchall()
        
        artigos = []
        for row in rows:
            artigo = {
                "ID_artigo": row[0],
                "ID_tipo": row[1],
                "ID_familia": row[2],
                "Referencia": row[3],
                "Designacao": row[4],
                "Imagem": row[5],
                "Cod_bar": row[6],
                "Cod_NFC": row[7],
                "Cod_RFID": row[8],
            }
            
            # Adiciona tipo se existir
            if row[1] and row[9]:
                artigo["tipo"] = {
                    "ID_tipo": row[1],
                    "Designacao": row[9]
                }
            
            # Adiciona família se existir
            if row[2] and row[10]:
                artigo["familia"] = {
                    "ID_familia": row[2],
                    "Designacao": row[10]
                }
            
            artigos.append(artigo)
        
        cur.close()
        conn.close()
        
        return artigos
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar artigos: {str(e)}")


@router.get("/artigos/{id_artigo}")
def get_artigo_by_id(id_artigo: int):
    """
    Retorna um artigo específico pelo ID.
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        query = """
            SELECT 
                a.ID_artigo,
                a.ID_tipo,
                a.ID_familia,
                a.Referencia,
                a.Designacao,
                a.Imagem,
                a.Cod_bar,
                a.Cod_NFC,
                a.Cod_RFID,
                t.Designacao AS tipo_designacao,
                f.Designacao AS familia_designacao
            FROM Artigo a
            LEFT JOIN Tipo t ON a.ID_tipo = t.ID_tipo
            LEFT JOIN Familia f ON a.ID_familia = f.ID_familia
            WHERE a.ID_artigo = ?
        """
        
        cur.execute(query, (id_artigo,))
        row = cur.fetchone()
        
        if not row:
            cur.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Artigo não encontrado")
        
        artigo = {
            "ID_artigo": row[0],
            "ID_tipo": row[1],
            "ID_familia": row[2],
            "Referencia": row[3],
            "Designacao": row[4],
            "Imagem": row[5],
            "Cod_bar": row[6],
            "Cod_NFC": row[7],
            "Cod_RFID": row[8],
        }
        
        # Adiciona tipo se existir
        if row[1] and row[9]:
            artigo["tipo"] = {
                "ID_tipo": row[1],
                "Designacao": row[9]
            }
        
        # Adiciona família se existir
        if row[2] and row[10]:
            artigo["familia"] = {
                "ID_familia": row[2],
                "Designacao": row[10]
            }
        
        cur.close()
        conn.close()
        
        return artigo
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar artigo: {str(e)}")


@router.get("/artigos/codigo/{codigo}")
def get_artigo_by_codigo(codigo: str):
    """
    Retorna um artigo pelo código (QR, NFC, RFID ou Código de Barras).
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        query = """
            SELECT 
                a.ID_artigo,
                a.ID_tipo,
                a.ID_familia,
                a.Referencia,
                a.Designacao,
                a.Imagem,
                a.Cod_bar,
                a.Cod_NFC,
                a.Cod_RFID,
                t.Designacao AS tipo_designacao,
                f.Designacao AS familia_designacao
            FROM Artigo a
            LEFT JOIN Tipo t ON a.ID_tipo = t.ID_tipo
            LEFT JOIN Familia f ON a.ID_familia = f.ID_familia
            WHERE a.Cod_bar = ? 
               OR a.Cod_NFC = ? 
               OR a.Cod_RFID = ?
               OR a.Referencia = ?
        """
        
        cur.execute(query, (codigo, codigo, codigo, codigo))
        row = cur.fetchone()
        
        if not row:
            cur.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Artigo não encontrado com este código")
        
        artigo = {
            "ID_artigo": row[0],
            "ID_tipo": row[1],
            "ID_familia": row[2],
            "Referencia": row[3],
            "Designacao": row[4],
            "Imagem": row[5],
            "Cod_bar": row[6],
            "Cod_NFC": row[7],
            "Cod_RFID": row[8],
        }
        
        # Adiciona tipo se existir
        if row[1] and row[9]:
            artigo["tipo"] = {
                "ID_tipo": row[1],
                "Designacao": row[9]
            }
        
        # Adiciona família se existir
        if row[2] and row[10]:
            artigo["familia"] = {
                "ID_familia": row[2],
                "Designacao": row[10]
            }
        
        cur.close()
        conn.close()
        
        return artigo
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar artigo por código: {str(e)}")