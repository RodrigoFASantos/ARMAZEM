# SERVIDOR/app/sync.py
from fastapi import APIRouter, HTTPException
from .db import get_connection

router = APIRouter()

@router.get("/sync/tipos")
def sync_tipos():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT ID_tipo, Designacao FROM Tipo")
        rows = cur.fetchall()
        result = [{"ID_tipo": row[0], "Designacao": row[1]} for row in rows]
        cur.close()
        conn.close()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/sync/familias")
def sync_familias():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT ID_familia, Designacao FROM Familia")
        rows = cur.fetchall()
        result = [{"ID_familia": row[0], "Designacao": row[1]} for row in rows]
        cur.close()
        conn.close()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/sync/estados")
def sync_estados():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT ID_Estado, Designacao FROM Estado")
        rows = cur.fetchall()
        result = [{"ID_Estado": row[0], "Designacao": row[1]} for row in rows]
        cur.close()
        conn.close()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/sync/armazens")
def sync_armazens():
    """Retorna todos os armazéns COM NOVOS CAMPOS de localização"""
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        cur.execute("""
            SELECT 
                ID_armazem, Descricao, Localizacao
            FROM Armazem
        """)
        rows = cur.fetchall()
        
        result = [
            {
                "ID_armazem": row[0],
                "Descricao": row[1],
                "Localizacao": row[2]                
            }
            for row in rows
        ]
        
        cur.close()
        conn.close()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/sync/artigos")
def sync_artigos():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT ID_artigo, ID_tipo, ID_familia, Referencia, Designacao, 
                   Imagem, Cod_bar, Cod_NFC, Cod_RFID
            FROM Artigo
        """)
        rows = cur.fetchall()
        result = [
            {
                "ID_artigo": row[0], "ID_tipo": row[1], "ID_familia": row[2],
                "Referencia": row[3], "Designacao": row[4], "Imagem": row[5],
                "Cod_bar": row[6], "Cod_NFC": row[7], "Cod_RFID": row[8]
            }
            for row in rows
        ]
        cur.close()
        conn.close()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/sync/equipamentos")
def sync_equipamentos():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT ID_equipamento, ID_artigo, ID_Estado, N_serie, Marca, 
                   Modelo, Data_aquisicao, Requer_inspecao, Ciclo_inspecao_dias
            FROM Equipamento
        """)
        rows = cur.fetchall()
        
        result = []
        for row in rows:
            equipamento = {
                "ID_equipamento": row[0], "ID_artigo": row[1], "ID_Estado": row[2],
                "N_serie": row[3], "Marca": row[4], "Modelo": row[5],
                "Data_aquisicao": None,
                "Requer_inspecao": row[7] if row[7] is not None else 0,
                "Ciclo_inspecao_dias": row[8]
            }
            if row[6]:
                try:
                    equipamento["Data_aquisicao"] = row[6].isoformat()
                except:
                    equipamento["Data_aquisicao"] = str(row[6])
            result.append(equipamento)
        
        cur.close()
        conn.close()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro: {str(e)}")








@router.get("/sync/movimentos")
def sync_movimentos():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT ID_movimento, ID_artigo, ID_armazem, Data_mov, 
                   Qtd_entrada, Qtd_saida, 
                   Rack, NPrateleira, DPrateleira, 
                   NCorredor, DCorredor, Zona
            FROM Movimentos
        """)
        rows = cur.fetchall()

        result = [
            {
                "ID_movimento": row[0],
                "ID_artigo": row[1],
                "ID_armazem": row[2],
                "Data_mov": row[3].isoformat() if row[3] else None,
                "Qtd_entrada": float(row[4]) if row[4] else 0.0,
                "Qtd_saida": float(row[5]) if row[5] else 0.0,

                "Rack": row[6],
                "NPrateleira": row[7],
                "DPrateleira": row[8],
                "NCorredor": row[9],
                "DCorredor": row[10],
                "Zona": row[11]
            }
            for row in rows
        ]

        cur.close()
        conn.close()
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))




@router.get("/sync/utilizadores")
def sync_utilizadores():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT ID_utilizador, Nome, Email, Username, Password, Ativo
            FROM Utilizadores
        """)
        rows = cur.fetchall()
        result = [
            {
                "ID_utilizador": row[0], "Nome": row[1], "Email": row[2],
                "Username": row[3], "Password": row[4], "Ativo": row[5]
            }
            for row in rows
        ]
        cur.close()
        conn.close()
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))