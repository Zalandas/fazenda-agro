-- =====================================================================
--  Esquema MINIMO do ERP agricola — só o que as telas deste demo leem.
--
--  Não é o schema do ERP do cliente: é o recorte das tabelas e colunas
--  que as consultas realmente tocam, derivado dos próprios SQLs.
--  Sem FK, sem índice, sem o resto do ERP — o demo não precisa deles, e
--  cada coluna a mais seria uma que ninguém sabe explicar.
--
--  Nomes de tabela e coluna são os do ERP porque a consulta é copiada
--  como está. Renomeá-los obrigaria a bifurcar o SQL, que é justamente
--  o que este demo existe para não fazer.
--
--  Duas telas hoje, e elas COMPARTILHAM tabelas: safra, produto e
--  romaneio servem às duas. É por isso que o esquema é um arquivo só —
--  separar por tela obrigaria a decidir de quem é o `romaneio`, que na
--  Produção é colheita e nos Contratos é entrega.
-- =====================================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS romaneio, configsafra, talhao, unidadepessoa, ciclo, produto, safra,
                     contrato, tipocontrato, pessoa, moeda, fixacoescontrato, parcelacontrato;

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

-- O ROMANEIO serve às DUAS telas, com leituras diferentes da mesma linha:
--
--   Produção  — colheita, definida pelo PAR tipoEntSaiRomaneio='Colheita'
--               MAIS tipoRomaneio='Entrada'. Só o primeiro deixaria entrar
--               saída de produto.
--   Contratos — entrega, classificada por tipoRomaneio LIKE '%SAIDA%' ou
--               '%ENTRADA%' (devolução), amarrada ao contrato por
--               codContrato, e com REMESSA excluída pelo tipoEntSai.
--
-- pesoLiqRomaneio é em QUILOS — as telas dividem por 60 para virar saca.
--
-- Os DOIS pesos existem porque a carga é pesada duas vezes, na origem e no
-- destino, e eles divergem (quebra de transporte). Qual vale é decisão do
-- CONTRATO, na coluna controlePeso — não do romaneio.
CREATE TABLE romaneio (
    codRomaneio             INT PRIMARY KEY,
    codSafra                INT           NOT NULL,
    codUnidadePessoaFaz     INT           NOT NULL,
    codTalhao               INT           NOT NULL,
    codProdutoCultura       INT           NOT NULL,
    codProdutoCultivar      INT           NULL,
    codCiclo                INT           NOT NULL,
    pesoLiqRomaneio         DECIMAL(14,3) NULL,   -- peso de ORIGEM
    pesoLiqDestinoRomaneio  DECIMAL(14,3) NULL,   -- peso de DESTINO
    tipoEntSaiRomaneio      VARCHAR(40)   NULL,
    tipoRomaneio            VARCHAR(40)   NULL,
    canceladoRomaneio       TINYINT       NULL DEFAULT 0,
    codContrato             INT           NULL,   -- nulo na colheita
    dataLancRomaneio        DATE          NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
--  TELA DE CONTRATOS
-- ---------------------------------------------------------------------

-- VENDA e COMPRA saem da mesma tabela; a tela filtra por nome LIKE '%VENDA%'.
CREATE TABLE tipocontrato (
    codTipoContrato   INT PRIMARY KEY,
    nomeTipoContrato  VARCHAR(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pessoa (
    codPessoa   INT PRIMARY KEY,
    nomePessoa  VARCHAR(120) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Moeda nula (ou 'REAL') significa contrato em reais: aí o preço sai de
-- precoContrato. Em moeda alternativa, quem manda são as FIXAÇÕES.
CREATE TABLE moeda (
    codMoeda   INT PRIMARY KEY,
    nomeMoeda  VARCHAR(40) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- qtdContrato em QUILOS, precoContrato em R$/kg — a tela multiplica por 60
-- para exibir R$/saca. As duas colunas de número (contratoContrato e
-- contrato) existem porque o ERP guarda o número em uma OU na outra; a
-- consulta resolve com COALESCE.
CREATE TABLE contrato (
    codContrato        INT PRIMARY KEY,
    contratoContrato   VARCHAR(40)   NULL,
    contrato           VARCHAR(40)   NULL,
    codSafra           INT           NULL,
    codTipoContrato    INT           NULL,
    codPessoaCliente   INT           NULL,
    codProdutoCultura  INT           NULL,
    codMoedaAlt        INT           NULL,
    qtdContrato        DECIMAL(14,3) NULL,
    precoContrato      DECIMAL(14,6) NULL,
    precoUnitAlt       DECIMAL(14,6) NULL,
    valorAlt           DECIMAL(16,2) NULL,
    dataLancContrato   DATETIME      NULL,
    tipoFrete          VARCHAR(10)   NULL,   -- '0' = CIF, '1' = FOB
    controlePeso       VARCHAR(40)   NULL,   -- contém 'DESTINO' ou não
    status             VARCHAR(40)   NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- FIXAÇÃO: em contrato de moeda alternativa, o preço em reais não é o do
-- contrato — é a média das fixações (Σvalor ÷ Σquantidade). Um contrato
-- pode ter várias, fixadas em datas e cotações diferentes.
CREATE TABLE fixacoescontrato (
    codFixacao   INT PRIMARY KEY,
    codContrato  INT           NOT NULL,
    quantidade   DECIMAL(14,3) NULL,
    valor        DECIMAL(16,2) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE parcelacontrato (
    codParcela         INT PRIMARY KEY,
    codContrato        INT  NOT NULL,
    vencimentoParcela  DATE NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
