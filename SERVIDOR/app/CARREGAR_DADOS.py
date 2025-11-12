from fastapi import APIRouter, HTTPException
from typing import List, Dict, Any
import pyodbc
from .db import get_connection

router = APIRouter()


def _fetch_table_data(table: str, columns: str = "*") -> List[Dict[str, Any]]:
    """
    Busca dados de uma tabela e retorna como lista de dicionários.
    """
    conn = get_connection()
    cur = conn.cursor()
    
    try:
        cur.execute(f"SELECT {columns} FROM {table}")
        rows = cur.fetchall()
        
        # Converte pyodbc.Row para dicionário
        columns = [desc[0] for desc in cur.description]
        result = []
        
        for row in rows:
            row_dict = {}
            for i, col in enumerate(columns):
                value = row[i]
                # Converte datetime para string ISO
                if hasattr(value, 'isoformat'):
                    value = value.isoformat()
                row_dict[col] = value
            result.append(row_dict)
        
        return result
        
    finally:
        cur.close()
        conn.close()


@router.get("/sync")
def sync_all_data():
    """
    Endpoint principal de sincronização.
    Retorna todos os dados necessários para a app mobile.
    """
    try:
        data = {
            "estados": _fetch_table_data("ESTADO"),
            "tipos": _fetch_table_data("TIPO"),
            "familias": _fetch_table_data("FAMILIA"),
            "armazens": _fetch_table_data("ARMAZEM"),
            "artigos": _fetch_table_data("ARTIGO"),
            "equipamentos": _fetch_table_data("EQUIPAMENTO"),
            "movimentos": _fetch_table_data("MOVIMENTOS"),
            "timestamp": __import__("datetime").datetime.now().isoformat(),
        }
        
        # Estatísticas
        total_registos = sum(len(v) for k, v in data.items() if isinstance(v, list))
        
        return {
            "success": True,
            "data": data,
            "stats": {
                "total_registos": total_registos,
                "estados": len(data["estados"]),
                "tipos": len(data["tipos"]),
                "familias": len(data["familias"]),
                "armazens": len(data["armazens"]),
                "artigos": len(data["artigos"]),
                "equipamentos": len(data["equipamentos"]),
                "movimentos": len(data["movimentos"]),
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro na sincronização: {str(e)}")


@router.get("/sync/light")
def sync_light():
    """
    Sincronização leve - apenas dados essenciais (sem movimentos).
    Útil para sincronizações rápidas.
    """
    try:
        data = {
            "estados": _fetch_table_data("ESTADO"),
            "tipos": _fetch_table_data("TIPO"),
            "familias": _fetch_table_data("FAMILIA"),
            "armazens": _fetch_table_data("ARMAZEM"),
            "artigos": _fetch_table_data("ARTIGO"),
            "equipamentos": _fetch_table_data("EQUIPAMENTO"),
            "timestamp": __import__("datetime").datetime.now().isoformat(),
        }
        
        return {"success": True, "data": data}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro na sincronização: {str(e)}")


@router.get("/sync/stats")
def sync_stats():
    """
    Retorna estatísticas dos dados sem transferir tudo.
    Útil para verificar se há novos dados.
    """
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        stats = {}
        tables = ["ESTADO", "TIPO", "FAMILIA", "ARMAZEM", "ARTIGO", "EQUIPAMENTO", "MOVIMENTOS"]
        
        for table in tables:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            count = cur.fetchone()[0]
            stats[table.lower()] = count
        
        cur.close()
        conn.close()
        
        return {
            "success": True,
            "stats": stats,
            "timestamp": __import__("datetime").datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao obter estatísticas: {str(e)}")


@router.get("/sync/artigos")
def sync_artigos_only():
    """
    Sincroniza apenas artigos (para atualizações rápidas).
    """
    try:
        artigos = _fetch_table_data("ARTIGO")
        
        return {
            "success": True,
            "data": artigos,
            "count": len(artigos),
            "timestamp": __import__("datetime").datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao sincronizar artigos: {str(e)}")