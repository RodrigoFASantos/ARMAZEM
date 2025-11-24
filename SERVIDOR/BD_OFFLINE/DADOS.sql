-- Dados iniciais (SEED) para ARMAZEM
-- Estes dados são carregados na primeira instalação

-- Utilizadores
INSERT INTO UTILIZADOR (ID_utilizador, Nome, Email, Username, Password, Ativo) VALUES 
(1, 'Rodrigo Santos', 'rodrigo@armazem.pt', 'rodrigo', '1234', 1),
(3, 'Luis Silva', 'luis@armazem.pt', 'luis', 'luis123', 1),
(2, 'Admin Sistema', 'admin@armazem.pt', 'admin', 'admin123', 1),
(4, 'Maria Costa', 'maria@armazem.pt', 'maria', 'maria123', 1),
(5, 'Utilizador Teste', 'teste@armazem.pt', 'teste', 'teste', 0);

-- Armazém padrão
INSERT INTO ARMAZEM (ID_armazem, Descricao, Localizacao) VALUES 
(1, 'Armazém Mangualde', 'Mangualde');

-- Estados padrão
INSERT INTO ESTADO (ID_Estado, Designacao) VALUES 
(1, 'Operacional'),
(2, 'Em Manutenção'),
(3, 'Avariado');

-- Tipos padrão
INSERT INTO TIPO (ID_tipo, Designacao) VALUES 
(1, 'Matéria Prima'),
(2, 'Produto Final');

-- Famílias padrão
INSERT INTO FAMILIA (ID_familia, Designacao) VALUES 
(1, 'Ferramentas Manuais'),
(2, 'Ferramentas Elétricas'),
(3, 'Proteção'),
(4, 'Consumíveis'),
(5, 'Máquinas');
