import pyodbc
from .config import settings

def _build_server() -> str:
    """
    String de servidor adequada para a conexão: 
    Se o servidor tiver uma instância nomeada (ex: localhost\SQLEXP_RSANTOS) e não houver uma porta TCP definida, é preciso usar Named Pipes senão usar TCP/IP.
    """
    port = (settings.db_port or "").strip()
    srv = settings.db_server
    
    if "\\" in srv and not port:
        inst = srv.split("\\", 1)[1]
        # Formato name pipes
        return fr"np:\\.\pipe\MSSQL${inst}\sql\query"
    
    return f"{srv},{port}" if port else srv

def get_connection() -> pyodbc.Connection:
    """
    Cria uma conexão ao SQL Server usando SQL Server Native Client 11.0.
    
    Returns:
        pyodbc.Connection: Objeto de conexão ativa
        
    Raises:
        pyodbc.Error: Se houver erro na conexão
    """
    server = _build_server()
    
    # Usa SQL Server Native Client 11.0
    conn_str = (
        "DRIVER={SQL Server Native Client 11.0};"
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
    """
    Testa a conexão à base de dados executando um SELECT 1.
    Retorna TRUE se a conexão for bem-sucedida
    Retorna Exception: Se houver erro na conexão ou execução da query
    """
    with get_connection() as conn:
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.fetchone()
    return True

