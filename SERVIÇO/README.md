# ESTRUTURA

requirements.txt: 
    lista das dependências do projeto. Serve para instalar tudo de uma só vez com pip install -r requirements.txt. Mantém versões fixas para garantir reprodutibilidade.

.env: 
    ficheiro de variáveis de ambiente. Contém as credenciais e parâmetros de execução (servidor SQL, base de dados, utilizador, password, encriptação, host e porta da API). Tem de estar em UTF-8 sem BOM; se o Pydantic acusar chaves com “\ufeff…”, é BOM no início do ficheiro.

.gitignore: 
    lista o que o Git deve ignorar. Exclui o ambiente virtual, ficheiros compilados Python, a pasta .vscode e o próprio .env.

.vscode/settings.json: 
    configurações do VS Code para o projeto. Aponta o interpretador Python para .venv\Scripts\python.exe, ativa o format on save e o linter Ruff, ativa pytest e silencia o falso positivo do Pylance sobre chamadas de BaseSettings.

.vscode/launch.json: 
configuração de debug. Arranca o Uvicorn com a app app.main:app, usa o .env para as variáveis e abre a consola integrada. Permite carregar a API em modo debug diretamente com F5.

app/config.py: 
carrega as variáveis do .env e expõe um objeto settings para o resto da aplicação. Usa python-dotenv para ler o .env e um modelo Pydantic simples para tipar os valores. Campos: db_server, db_database, db_username, db_password, db_trust_cert, db_encrypt, db_port, app_env, app_host, app_port. Se DB_PORT vier vazio, o código trata como None, o que ativa a lógica de instância/Named Pipes no módulo de base de dados.

app/db.py: 
    cria a ligação ao SQL Server com pyodbc. A função _build_server() escolhe o alvo do servidor: se DB_SERVER tiver instância (ex.: localhost\RODRIGO) e não houver porta, usa Named Pipes via np:\\.\pipe\MSSQL$INSTANCIA\sql\query para evitar problemas de TCP. Se tiveres DB_PORT, usa TCP no formato server,port. A função get_connection() constrói a connection string com o “ODBC Driver 18 for SQL Server”, encriptação e “TrustServerCertificate” conforme o .env. A função ping_db() valida a ligação com um SELECT 1.

app/main.py: 
    ponto de entrada da API FastAPI. Cria a aplicação, expõe GET /health para status da API e GET /db/ping para testar a ligação à base de dados. Em caso de falha de ligação, devolve 500 com a mensagem detalhada, útil para diagnóstico.

app/schemas.py: 
    modelos Pydantic para respostas/entradas da API. ArtigoOut descreve o objeto que o cliente recebe (id, nome, referência, tipo, família, stock_total, localizações, rfid, nfc, qr_code). ScanResult representa o resultado básico da leitura de um código (tipo e valor). Estes modelos garantem respostas consistentes e documentação automática em /docs.

app/repositories/artigos_repo.py: 
    camada de acesso a dados para “Artigo”. get_artigo_by_id(artigo_id) consulta a base para detalhe do artigo, soma de stock e localizações com movimento, devolve um ArtigoOut. get_artigo_by_code(code_value) procura o artigo por QR/NFC/RFID ou referência e reaproveita get_artigo_by_id para montar a resposta final. Aqui ajustas os nomes de tabelas/colunas ao teu esquema real.

app/services/vision.py: 
    serviço de visão para leitura simples de QR a partir de imagem. Usa OpenCV (QRCodeDetector) para obter o conteúdo do QR e devolve ScanResult com o valor lido. Isto serve de base para integrares leitura por câmara e, mais tarde, o modelo TensorFlow Lite.

tests/test_health.py: 
    teste rápido com pytest para o endpoint /health. Garante que a API arranca e responde status: ok. Serve de exemplo para acrescentar mais testes unitários/integração.

# COMANDOS
Ativar venv: .\.venv\Scripts\Activate.ps1
Instalar dependências: pip install -r requirements.txt
Arrancar a API: python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
Abrir docs: http://127.0.0.1:8000/docs
Testar saúde: http://127.0.0.1:8000/health
Testar BD: http://127.0.0.1:8000/db/ping
Ver se o .env não tem BOM: Get-Content .env -Encoding Byte -TotalCount 3 | % { "{0:X2}" -f $_ }