-- Schema SQLite para ARMAZEM (Base de Dados Offline)
-- Criado automaticamente 

-- Tabela: Utilizador
CREATE TABLE IF NOT EXISTS UTILIZADOR (
    ID_utilizador INTEGER PRIMARY KEY AUTOINCREMENT,
    Nome TEXT NOT NULL,
    Email TEXT NOT NULL UNIQUE,
    Username TEXT NOT NULL UNIQUE,
    Password TEXT NOT NULL,
    Ativo INTEGER DEFAULT 1,
);

-- Índice para login rápido
CREATE INDEX IF NOT EXISTS idx_utilizador_email ON UTILIZADOR(Email);
CREATE INDEX IF NOT EXISTS idx_utilizador_username ON UTILIZADOR(Username);

-- Tabela: Tipo
CREATE TABLE IF NOT EXISTS TIPO (
    ID_tipo INTEGER PRIMARY KEY,
    Designacao TEXT NOT NULL
);

-- Tabela: Familia
CREATE TABLE IF NOT EXISTS FAMILIA (
    ID_familia INTEGER PRIMARY KEY,
    Designacao TEXT NOT NULL
);

-- Tabela: Estado
CREATE TABLE IF NOT EXISTS ESTADO (
    ID_Estado INTEGER PRIMARY KEY,
    Designacao TEXT NOT NULL
);

-- Tabela: Armazem
CREATE TABLE IF NOT EXISTS ARMAZEM (
    ID_armazem INTEGER PRIMARY KEY,
    Descricao TEXT NOT NULL,
    Localizacao TEXT
);

-- Tabela: Artigo
CREATE TABLE IF NOT EXISTS ARTIGO (
    ID_artigo INTEGER PRIMARY KEY,
    ID_tipo INTEGER,
    ID_familia INTEGER,
    Referencia TEXT,
    Designacao TEXT NOT NULL,
    Imagem TEXT,
    Cod_bar TEXT,
    Cod_NFC TEXT,
    Cod_RFID TEXT,
    FOREIGN KEY (ID_tipo) REFERENCES TIPO(ID_tipo),
    FOREIGN KEY (ID_familia) REFERENCES FAMILIA(ID_familia)
);

-- Índices para pesquisa rápida por código
CREATE INDEX IF NOT EXISTS idx_artigo_cod_bar ON ARTIGO(Cod_bar);
CREATE INDEX IF NOT EXISTS idx_artigo_cod_nfc ON ARTIGO(Cod_NFC);
CREATE INDEX IF NOT EXISTS idx_artigo_cod_rfid ON ARTIGO(Cod_RFID);
CREATE INDEX IF NOT EXISTS idx_artigo_referencia ON ARTIGO(Referencia);

-- Tabela: Equipamento
CREATE TABLE IF NOT EXISTS EQUIPAMENTO (
    ID_equipamento INTEGER PRIMARY KEY,
    ID_artigo INTEGER NOT NULL,
    ID_Estado INTEGER,
    N_serie TEXT,
    Marca TEXT,
    Modelo TEXT,
    Data_aquisicao TEXT,
    Requer_inspecao INTEGER DEFAULT 0,
    Ciclo_inpecao_dias INTEGER,
    FOREIGN KEY (ID_artigo) REFERENCES ARTIGO(ID_artigo),
    FOREIGN KEY (ID_Estado) REFERENCES ESTADO(ID_Estado)
);

-- Tabela: Movimentos
CREATE TABLE IF NOT EXISTS MOVIMENTOS (
    ID_movimento INTEGER PRIMARY KEY,
    ID_artigo INTEGER NOT NULL,
    ID_armazem INTEGER NOT NULL,
    Data_mov TEXT NOT NULL,
    Qtd_entrada REAL DEFAULT 0,
    Qtd_saida REAL DEFAULT 0,
    FOREIGN KEY (ID_artigo) REFERENCES ARTIGO(ID_artigo),
    FOREIGN KEY (ID_armazem) REFERENCES ARMAZEM(ID_armazem)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_movimentos_artigo ON MOVIMENTOS(ID_artigo);
CREATE INDEX IF NOT EXISTS idx_movimentos_armazem ON MOVIMENTOS(ID_armazem);
CREATE INDEX IF NOT EXISTS idx_movimentos_data ON MOVIMENTOS(Data_mov);

-- Tabela de controlo de sincronização
CREATE TABLE IF NOT EXISTS SYNC_LOG (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ultima_sync TEXT NOT NULL,
    total_registos INTEGER DEFAULT 0,
    sucesso INTEGER DEFAULT 1
);