-- Dados iniciais (SEED) para ARMAZEM
-- Estes dados são carregados na primeira instalação

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
