import pyodbc
from .config import settings

def _build_server() -> str:
    port = (settings.db_port or "").strip()
    srv = settings.db_server
    if "\\" in srv and not port:
        inst = srv.split("\\", 1)[1]
        return fr"np:\\.\pipe\MSSQL\sql\query"
    return f"{srv},{port}" if port else srv

def get_connection() -> pyodbc.Connection:
    server = _build_server()
    conn_str = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={server};"
        f"DATABASE={settings.db_database};"
        f"UID={settings.db_username};"
        f"PWD={settings.db_password};"
        f"Encrypt={settings.db_encrypt};"
        f"TrustServerCertificate={settings.db_trust_cert};"
        "Connection Timeout=5;"
    )
    return pyodbc.connect(conn_str)

def ping_db() -> bool:
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.fetchone()
    return True
