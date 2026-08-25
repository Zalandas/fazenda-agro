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
--  As telas COMPARTILHAM tabelas, e é por isso que o esquema é um arquivo
--  só: separar por tela obrigaria a decidir de quem é cada uma. O
--  `romaneio` na Produção é colheita e nos Contratos é entrega; a
--  `aplictalhao` no Quadro é custo por cultura e em Insumos é item a item.
--  A mesma linha, lida de dois jeitos.
-- =====================================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS tipoproduto, subtipoproduto, romaneio, configsafra, talhao, unidadepessoa, ciclo, produto, safra,
                     contrato, tipocontrato, pessoa, moeda, fixacoescontrato, parcelacontrato,
                     aplictalhao, itensaplictalhao, documento, tipooperacao, parceladocumento,
                     baixa, itensbaixa, cotacaomoeda, veiculo,
                     simulacao_projetado, simulacao_realizado;

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

-- Cultura, cultivar e INSUMO saem todos da MESMA tabela; o que os separa é
-- quem aponta para eles. Cultura e cultivar vêm das colunas do configsafra;
-- insumo, do item da aplicação. Por isso cultura não tem tipo: as duas
-- colunas de tipo abaixo só valem para insumo.
CREATE TABLE produto (
    codProduto            INT PRIMARY KEY,
    nomeProduto           VARCHAR(120) NOT NULL,
    codTipoProd           INT          NULL,
    codSubTipoProdutoTP   INT          NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A CATEGORIA do insumo no BI sai de um CASE sobre estes dois nomes, e a
-- ORDEM das cláusulas importa: '%DEFENSIVO%' no tipo é testado ANTES de
-- herbicida e inseticida, então defensivo com subtipo herbicida cairia em
-- FUNGICIDAS. Na base real os herbicidas têm tipo próprio; o seed reproduz
-- isso, e é por isso que ele funciona.
CREATE TABLE tipoproduto (
    codTipoProd    INT PRIMARY KEY,
    nomeTipoProd   VARCHAR(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE subtipoproduto (
    codSubtipoProd    INT PRIMARY KEY,
    nomeSubtipoProd   VARCHAR(80) NOT NULL
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
    dataLancRomaneio        DATE          NULL,

    -- --- só a LISTA de romaneios lê daqui para baixo ---
    -- O dashboard de Produção soma peso; a lista mostra a carga uma a uma, e
    -- por isso precisa do documento, da pesagem e de quem levou.
    numeroRomaneio          INT           NULL,
    numeroNF                VARCHAR(30)   NULL,
    dataPesag1Romaneio      DATETIME      NULL,
    pesoBrutoRomaneio       DECIMAL(14,3) NULL,
    pesoTaraRomaneio        DECIMAL(14,3) NULL,

    -- Motorista e veículo entram de DOIS jeitos: escolhidos no cadastro
    -- (codPessoaMotorista / codVeiculo) ou digitados à mão no romaneio. A
    -- consulta prefere o manual quando ele não está vazio — ler só o cadastro
    -- deixaria em branco justamente as cargas de frete avulso.
    codPessoaMotorista      INT           NULL,
    motoristaManual         VARCHAR(120)  NULL,
    codVeiculo              INT           NULL,
    placaManual             VARCHAR(20)   NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE veiculo (
    codVeiculo   INT PRIMARY KEY,
    placaVeiculo VARCHAR(20) NOT NULL
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

-- saldoAltParcela é o saldo do contrato AINDA NÃO FATURADO — e o ERP **não o
-- abate** ao emitir a nota: parcela 100% paga mantém o saldo cheio. Quem
-- desconta é a consulta do preço médio, subtraindo o que já virou documento.
-- Sem isso, contrato faturado conta duas vezes.
CREATE TABLE parcelacontrato (
    codParcela           INT PRIMARY KEY,
    codContrato          INT           NOT NULL,
    vencimentoParcela    DATE          NULL,
    saldoAltParcela      DECIMAL(16,2) NULL,
    codMoedaAltParcela   INT           NULL   -- 2 = dólar; converte pela cotação
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
--  TELA DE QUADRO DE SAFRAS
--
--  Duas famílias de tabela entram aqui: o CUSTO aplicado por talhão, e o
--  faturamento (notas e baixas) de que sai o PREÇO MÉDIO realizado.
-- ---------------------------------------------------------------------

-- A APLICAÇÃO: o que foi aplicado num talhão, para uma cultura, numa safra.
-- Serve a DUAS telas, em graus diferentes — como o romaneio:
--   Quadro de Safras — só o total por (safra, cultura), para o custo/ha;
--   Insumos          — item a item, por talhão e por produto, para a matriz
--                      de tipo de insumo x talhão.
CREATE TABLE aplictalhao (
    codAplicTalhao     INT PRIMARY KEY,
    codSafra           INT NULL,
    codTalhao          INT NULL,
    codProdutoCultura  INT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- codProduto aponta para o INSUMO (não para a cultura): é dele que sai o
-- tipo/subtipo que o BI de Insumos agrupa.
CREATE TABLE itensaplictalhao (
    codItAplicTalhao    INT PRIMARY KEY,
    codAplicTalhao      INT           NOT NULL,
    codProduto          INT           NULL,
    valorItAplicTalhao  DECIMAL(16,2) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A NOTA. `historicoDoc` contendo 'ADIANTAMENTO' tira o documento do termo (1)
-- do preço médio: é o mesmo dinheiro que a nota quita por encontro de contas, e
-- contá-lo dobraria o contrato.
CREATE TABLE documento (
    codDoc         INT PRIMARY KEY,
    valorDoc       DECIMAL(16,2) NULL,
    codTipoOper    INT           NULL,
    historicoDoc   VARCHAR(200)  NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Devolução de venda entra no preço médio com o SINAL INVERTIDO; é o
-- nomeTipoOper que a identifica.
CREATE TABLE tipooperacao (
    codTipoOper   INT PRIMARY KEY,
    nomeTipoOper  VARCHAR(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A ponte entre nota e contrato. As DUAS colunas de parcela existem porque o
-- vínculo pode ser com a parcela normal (codParcelaC) ou com a de adiantamento
-- (codParcelaCAdt) — a consulta aceita qualquer uma.
CREATE TABLE parceladocumento (
    codParcela           INT PRIMARY KEY,
    codDocumento         INT           NOT NULL,
    codParcelaC          INT           NULL,
    codParcelaCAdt       INT           NULL,
    valorPrincParcela    DECIMAL(16,2) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Acréscimos e descontos do faturamento vêm da BAIXA, não da nota: a nota
-- guarda o valor de face.
CREATE TABLE baixa (
    codBaixa        INT PRIMARY KEY,
    canceladaBaixa  TINYINT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE itensbaixa (
    codItBaixa                INT PRIMARY KEY,
    codBaixa                  INT           NOT NULL,
    codParcelaDocumento       INT           NOT NULL,
    acrescimoPrincItBaixa     DECIMAL(16,2) NULL,
    descontoPrincItBaixa      DECIMAL(16,2) NULL,
    retencao                  TINYINT       NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A cotação tem LINHA-LIXO com ano absurdo na base real, e pegar "a mais
-- recente" sem teto zerava a conversão. Por isso a consulta exige
-- dataCotMoeda <= CURDATE().
CREATE TABLE cotacaomoeda (
    codCotacao     INT PRIMARY KEY,
    codMoeda       INT           NOT NULL,
    dataCotMoeda   DATE          NULL,
    valor          DECIMAL(16,6) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
--  AS SIMULAÇÕES — o "Projetado" contra o qual o realizado é comparado.
--
--  No sistema real estas duas tabelas vivem no SQL Server do CeoManager, e
--  não no ERP do cliente: são trabalho da consultoria, não dado do ERP.
--  Aqui elas estão no MESMO MySQL, para o demo não exigir dois bancos —
--  é a segunda (e última) diferença em relação ao original, e está
--  anotada também na action.
-- ---------------------------------------------------------------------
CREATE TABLE simulacao_projetado (
    id                INT PRIMARY KEY,
    cliente           VARCHAR(120)  NULL,
    safra             VARCHAR(60)   NULL,
    cultura           VARCHAR(80)   NULL,
    areaPlantada      DECIMAL(14,4) NULL,
    areaColhida       DECIMAL(14,4) NULL,
    produtividade     DECIMAL(14,4) NULL,
    precoMedio        DECIMAL(14,4) NULL,
    custoProducaoHa   DECIMAL(14,4) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Mesma forma. Fica VAZIA de propósito: uma linha aqui SOBRESCREVE os números
-- que vieram do ERP, e um demo cujo número não vem do dado que ele mostra
-- perde a graça. Ver o comentário no 06-dados-quadro.sql.
CREATE TABLE simulacao_realizado (
    id                INT PRIMARY KEY,
    cliente           VARCHAR(120)  NULL,
    safra             VARCHAR(60)   NULL,
    cultura           VARCHAR(80)   NULL,
    areaPlantada      DECIMAL(14,4) NULL,
    areaColhida       DECIMAL(14,4) NULL,
    produtividade     DECIMAL(14,4) NULL,
    precoMedio        DECIMAL(14,4) NULL,
    custoProducaoHa   DECIMAL(14,4) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
