#!/usr/bin/env python3
"""
Script de teste para verificar endpoints de sincronização
"""
import requests
import json

BASE_URL = "http://172.20.10.2:8000"

def test_endpoint(endpoint):
    """Testa um endpoint e mostra o resultado"""
    url = f"{BASE_URL}{endpoint}"
    print(f"\n{'='*60}")
    print(f"Testando: {endpoint}")
    print(f"{'='*60}")
    
    try:
        response = requests.get(url, timeout=5)
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            
            if isinstance(data, list):
                print(f"Registos: {len(data)}")
                if len(data) > 0:
                    print(f"\nPrimeiro registo:")
                    print(json.dumps(data[0], indent=2, ensure_ascii=False))
                else:
                    print("⚠️  LISTA VAZIA - Base de dados não tem dados!")
            else:
                print(f"Tipo de resposta: {type(data)}")
                print(json.dumps(data, indent=2, ensure_ascii=False))
        else:
            print(f"❌ Erro: {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Erro de conexão - Servidor não está a correr!")
    except Exception as e:
        print(f"❌ Erro: {e}")

def main():
    print("🔍 Teste de Endpoints de Sincronização")
    print("="*60)
    
    # Testa health primeiro
    print("\n1. Health Check")
    test_endpoint("/health")
    
    # Testa todos os endpoints de sync
    endpoints = [
        "/sync/tipos",
        "/sync/familias", 
        "/sync/estados",
        "/sync/armazens",
        "/sync/artigos",
        "/sync/equipamentos",
        "/sync/movimentos",
        "/sync/utilizadores"
    ]
    
    print("\n\n2. Endpoints de Sincronização")
    for endpoint in endpoints:
        test_endpoint(endpoint)
    
    print("\n" + "="*60)
    print("✅ Testes concluídos!")
    print("="*60)

if __name__ == "__main__":
    main()