"""
Script de teste de conexão ao SQL Server
Testa a conexão diretamente sem depender da API FastAPI
"""

import pyodbc
from dotenv import load_dotenv
import os

# Carrega variáveis do .env
load_dotenv()

def build_server() -> str:
    """Constrói a string de servidor adequada"""
    db_server = os.getenv("DB_SERVER", "")
    db_port = (os.getenv("DB_PORT") or "").strip()
    
    if "\\" in db_server and not db_port:
        inst = db_server.split("\\", 1)[1]
        # Named Pipe para instância nomeada
        return fr"np:\\.\pipe\MSSQL${inst}\sql\query"
    
    # TCP/IP
    return f"{db_server},{db_port}" if db_port else db_server

def test_connection():
    """Testa a conexão à base de dados"""
    print("=" * 60)
    print("TESTE DE CONEXÃO AO SQL SERVER")
    print("=" * 60)
    
    # Mostra configurações
    db_server = os.getenv("DB_SERVER")
    db_database = os.getenv("DB_DATABASE")
    db_username = os.getenv("DB_USERNAME")
    db_encrypt = os.getenv("DB_ENCRYPT", "yes")
    db_trust_cert = os.getenv("DB_TRUST_CERT", "yes")
    
    print(f"\n📋 Configurações:")
    print(f"   Servidor: {db_server}")
    print(f"   Base de Dados: {db_database}")
    print(f"   Utilizador: {db_username}")
    print(f"   Encrypt: {db_encrypt}")
    print(f"   TrustServerCertificate: {db_trust_cert}")
    
    # Constrói servidor
    server = build_server()
    print(f"\n🔧 String do Servidor: {server}")
    
    # Tenta conectar
    print("\n🔄 A tentar conectar...")
    try:
        conn_str = (
            "DRIVER={ODBC Driver 21 for SQL Server};"
            f"SERVER={server};"
            f"DATABASE={db_database};"
            f"UID={db_username};"
            f"PWD={os.getenv('DB_PASSWORD')};"
            f"Encrypt={db_encrypt};"
            f"TrustServerCertificate={db_trust_cert};"
            "Connection Timeout=5;"
        )
        
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        # Testa query simples
        cursor.execute("SELECT 1 AS test")
        result = cursor.fetchone()
        
        # Informação do servidor
        cursor.execute("SELECT @@VERSION AS version")
        version = cursor.fetchone()
        
        cursor.execute("SELECT DB_NAME() AS current_db")
        current_db = cursor.fetchone()
        
        print("\n✅ CONEXÃO BEM-SUCEDIDA!")
        print(f"\n📊 Base de Dados Atual: {current_db[0]}")
        print(f"\n🖥️  Versão do SQL Server:")
        print(f"   {version[0][:80]}...")
        
        cursor.close()
        conn.close()
        
        return True
        
    except pyodbc.Error as e:
        print("\n❌ ERRO NA CONEXÃO!")
        print(f"\n⚠️  Detalhes do erro:")
        print(f"   {str(e)}")
        
        # Dicas de troubleshooting
        print("\n💡 Sugestões:")
        print("   1. Verifica se o SQL Server Express está a correr")
        print("   2. Confirma o nome da instância (SQL Server Configuration Manager)")
        print("   3. Verifica se Named Pipes está ativado")
        print("   4. Confirma as credenciais (utilizador/password)")
        print("   5. Verifica se a base de dados 'SIDM' existe")
        
        return False

if __name__ == "__main__":
    test_connection()
    print("\n" + "=" * 60)
