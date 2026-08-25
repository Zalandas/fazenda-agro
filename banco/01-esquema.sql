-- =====================================================================
--  Esquema MINIMO do ERP agricola — só o que a tela de Produção lê.
--
--  Não é o schema do ERP do cliente: é o recorte das tabelas e colunas
--  que a consulta de Produção realmente toca, derivado do próprio SQL.
--  Sem FK, sem índice, sem o resto do ERP — o demo não precisa deles, e
--  cada coluna a mais seria uma que ninguém sabe explicar.
--
--  Nomes de tabela e coluna são os do ERP porque a consulta é copiada
--  como está. Renomeá-los obrigaria a bifurcar o SQL, que é justamente
--  o que este demo existe para não fazer.
-- =====================================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS romaneio, configsafra, talhao, unidadepessoa, ciclo, produto, safra;

-- Safra: "2024/2025". dataInicial é filtrada (>= 2000-01-01) para barrar
-- linha-lixo com ano absurdo, que a base real tem.
CREATE TABLE safra (
    codSafra     INT PRIMARY KEY,
    nomeSafra    VARCHAR(60)  NOT NULL,
    dataInicial  DATE         NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A FAZENDA do BI vem daqui, e não de um cadastro nosso: no sistema real
-- a unidade do agro é um NOME vindo do ERP, sem Id do nosso lado.
CREATE TABLE unidadepessoa (
    codUnidPessoa   INT PRIMARY KEY,
    nomeUnidPessoa  VARCHAR(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE talhao (
    codTalhao        INT PRIMARY KEY,
    nomeTalhao       VARCHAR(60)   NOT NULL,
    areaTalhao       DECIMAL(12,4) NULL,
    codUnidPessoaFaz INT           NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ciclo (
    codCiclo   INT PRIMARY KEY,
    nomeCiclo  VARCHAR(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cultura e cultivar saem da MESMA tabela; o que as separa é a coluna do
-- configsafra que aponta para cada uma.
CREATE TABLE produto (
    codProduto   INT PRIMARY KEY,
    nomeProduto  VARCHAR(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- O PLANTIO: uma linha por (safra, fazenda, talhão, cultura, cultivar, ciclo).
-- areaPrevistaConfigSafra é a área plantada — denominador da produtividade.
CREATE TABLE configsafra (
    codSafra                 INT           NOT NULL,
    codUnidPessoaFaz         INT           NOT NULL,
    codTalhao                INT           NOT NULL,
    codProdutoCultura        INT           NOT NULL,
    codProdutoCultivar       INT           NULL,
    codCiclo                 INT           NOT NULL,
    areaPrevistaConfigSafra  DECIMAL(12,4) NULL,
    fechaColheitaConfigSafra TINYINT       NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A COLHEITA. O par que a define é tipoEntSaiRomaneio='Colheita' MAIS
-- tipoRomaneio='Entrada'; só o primeiro deixaria entrar saída de produto.
-- pesoLiqRomaneio é em QUILOS — a tela divide por 60 para virar saca.
CREATE TABLE romaneio (
    codRomaneio          INT PRIMARY KEY,
    codSafra             INT           NOT NULL,
    codUnidadePessoaFaz  INT           NOT NULL,
    codTalhao            INT           NOT NULL,
    codProdutoCultura    INT           NOT NULL,
    codProdutoCultivar   INT           NULL,
    codCiclo             INT           NOT NULL,
    pesoLiqRomaneio      DECIMAL(14,3) NULL,
    tipoEntSaiRomaneio   VARCHAR(40)   NULL,
    tipoRomaneio         VARCHAR(40)   NULL,
    canceladoRomaneio    TINYINT       NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
