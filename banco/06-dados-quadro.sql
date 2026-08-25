-- =====================================================================
--  QUADRO DE SAFRAS — custo, faturamento e a simulação projetada.
--
--  Tudo fictício. O que esta carga acrescenta é a metade FINANCEIRA da
--  safra: quanto custou produzir e por quanto o grão foi vendido. Com
--  isso o quadro fecha margem por cultura.
--
--  Como nos outros arquivos, os números foram escolhidos para que uma
--  regra quebrada mude o resultado de forma visível. A tabela do fim
--  diz o que esperar e o que cada desvio denuncia.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  BRAQUIÁRIA — o motivo do checkbox
--
--  É PASTAGEM, não lavoura: ocupa área, consome custo e não produz saca
--  nenhuma. Deixá-la no quadro derruba a produtividade média e a margem
--  de tudo, então ela fica fora por padrão.
--
--  Sem uma linha destas o checkbox "Incluir Braquiária" seria um
--  controle que não faz nada — pior que não existir.
-- ---------------------------------------------------------------------
INSERT INTO produto (codProduto, nomeProduto) VALUES
  (30, 'BRAQUIARIA');

INSERT INTO talhao (codTalhao, nomeTalhao, areaTalhao, codUnidPessoaFaz) VALUES
  (4, 'T-04 Pasto', 50.0000, 1);

-- Sem cultivar e com fechaColheita = 0: não há colheita de grão, então a
-- área COLHIDA dela é zero e a plantada não.
INSERT INTO configsafra
  (codSafra, codUnidPessoaFaz, codTalhao, codProdutoCultura, codProdutoCultivar, codCiclo, areaPrevistaConfigSafra, fechaColheitaConfigSafra)
VALUES
  (1, 1, 4, 30, NULL, 1, 50.0000, 0);

-- ---------------------------------------------------------------------
--  CUSTO DE PRODUÇÃO — as aplicações por talhão
--
--  Estas linhas servem a DUAS telas, em graus diferentes:
--    Quadro de Safras — só o total por (safra, cultura), para o custo/ha;
--    Insumos          — item a item, por talhão e por tipo de insumo.
--
--  Por isso a aplicação é por TALHÃO, e não uma por cultura: o Quadro
--  soma tudo de qualquer forma, mas Insumos precisa saber onde foi
--  gasto. Os totais por cultura ficam iguais aos de antes — 990.000 na
--  soja, 250.000 no milho, 60.000 na braquiária —, então o Quadro não
--  muda.
--
--  Os talhões têm custo/ha DIFERENTE de propósito: comparar talhão é
--  justamente o que a tela de Insumos existe para fazer, e três valores
--  iguais não mostrariam nada.
-- ---------------------------------------------------------------------

-- Os INSUMOS. O tipo do herbicida e do inseticida NÃO é 'DEFENSIVO', e
-- isso não é descuido: o CASE do BI testa '%DEFENSIVO%' ANTES de olhar
-- herbicida e inseticida, então defensivo com subtipo herbicida cairia em
-- FUNGICIDAS. Na base real eles têm tipo próprio.
INSERT INTO tipoproduto (codTipoProd, nomeTipoProd) VALUES
  (1, 'SEMENTES'),
  (2, 'FERTILIZANTES'),
  (3, 'AGROQUIMICOS');

INSERT INTO subtipoproduto (codSubtipoProd, nomeSubtipoProd) VALUES
  (1, 'SEMENTE TRATADA'),
  (2, 'MACRONUTRIENTE'),
  (3, 'FUNGICIDA'),
  (4, 'HERBICIDA'),
  (5, 'INSETICIDA');

INSERT INTO produto (codProduto, nomeProduto, codTipoProd, codSubTipoProdutoTP) VALUES
  (40, 'Semente Soja Tratada',   1, 1),
  (41, 'Semente Milho Tratada',  1, 1),
  (42, 'Semente Braquiaria',     1, 1),
  (43, 'Adubo Formulado NPK',    2, 2),
  (44, 'Calcario Dolomitico',    2, 2),
  (45, 'Fungicida Triazol',      3, 3),
  (46, 'Herbicida Glifosato',    3, 4),
  (47, 'Inseticida Piretroide',  3, 5);

INSERT INTO aplictalhao (codAplicTalhao, codSafra, codTalhao, codProdutoCultura) VALUES
  (1, 1, 1, 10),   -- T-01 soja       100 ha
  (2, 1, 2, 10),   -- T-02 soja       150 ha
  (3, 1, 3, 10),   -- T-03 soja        80 ha
  (4, 1, 1, 11),   -- T-01 milho      100 ha (2a safra, mesmo talhão)
  (5, 1, 4, 30);   -- T-04 braquiária  50 ha

INSERT INTO itensaplictalhao (codItAplicTalhao, codAplicTalhao, codProduto, valorItAplicTalhao) VALUES
  -- T-01 SOJA — 320.000,00 em 100 ha = 3.200,00/ha (o mais caro)
  ( 1, 1, 40,  60000.00),
  ( 2, 1, 43, 100000.00),
  ( 3, 1, 44,  40000.00),
  ( 4, 1, 46,  45000.00),
  ( 5, 1, 45,  55000.00),
  ( 6, 1, 47,  20000.00),
  -- T-02 SOJA — 420.000,00 em 150 ha = 2.800,00/ha (o mais barato)
  ( 7, 2, 40,  85000.00),
  ( 8, 2, 43, 140000.00),
  ( 9, 2, 44,  40000.00),
  (10, 2, 46,  60000.00),
  (11, 2, 45,  70000.00),
  (12, 2, 47,  25000.00),
  -- T-03 SOJA — 250.000,00 em 80 ha = 3.125,00/ha
  (13, 3, 40,  48000.00),
  (14, 3, 43,  90000.00),
  (15, 3, 44,  20000.00),
  (16, 3, 46,  36000.00),
  (17, 3, 45,  42000.00),
  (18, 3, 47,  14000.00),
  -- T-01 MILHO — 250.000,00 em 100 ha = 2.500,00/ha
  (19, 4, 41,  70000.00),
  (20, 4, 43, 120000.00),
  (21, 4, 46,  30000.00),
  (22, 4, 45,  20000.00),
  (23, 4, 47,  10000.00),
  -- T-04 BRAQUIÁRIA — 60.000,00 em 50 ha = 1.200,00/ha, e nenhuma receita
  (24, 5, 42,  25000.00),
  (25, 5, 43,  35000.00);

-- ---------------------------------------------------------------------
--  FATURAMENTO — de onde sai o PREÇO MÉDIO realizado
--
--  A conta tem DOIS termos que não podem se sobrepor:
--    (1) as NOTAS já emitidas contra o contrato, exceto adiantamento;
--    (2) o SALDO do contrato ainda NÃO faturado.
--
--  O que torna isso difícil é que o ERP **não abate o saldo ao faturar**:
--  a parcela paga continua com o saldo cheio. Sem descontar o que já
--  virou documento, o contrato conta duas vezes.
-- ---------------------------------------------------------------------
INSERT INTO tipooperacao (codTipoOper, nomeTipoOper) VALUES
  (1, 'VENDA DE PRODUCAO'),
  (2, 'DEVOLUCAO DE VENDA DE PRODUCAO');

INSERT INTO documento (codDoc, valorDoc, codTipoOper, historicoDoc) VALUES
  -- CT-001: faturou 3.000 das 5.000 sc
  (1, 360000.00, 1, 'Faturamento parcial do contrato'),
  -- CT-002: faturou as 2.940 sc entregues (2.940 x 126,00)
  (2, 370440.00, 1, 'Faturamento da entrega'),
  -- CT-002: ADIANTAMENTO. Fica FORA do termo (1) — é o mesmo dinheiro que a
  -- nota quita por encontro de contas, e contá-lo dobraria o contrato.
  (3, 100000.00, 1, 'ADIANTAMENTO sobre contrato de venda'),
  -- CT-004: venda e a DEVOLUÇÃO dela, que entra com sinal invertido
  (4, 246000.00, 1, 'Faturamento do contrato'),
  (5,  24600.00, 2, 'Devolucao parcial da venda'),
  -- CT-003: contrato em dólar, faturado por inteiro
  (6, 288000.00, 1, 'Faturamento do contrato'),
  -- CT-005: faturou 500 das 1.000 sc
  (7,  27000.00, 1, 'Faturamento parcial do contrato');

-- A ponte nota <-> contrato. O adiantamento entra por codParcelaCAdt, os
-- demais por codParcelaC — a consulta aceita as duas.
INSERT INTO parceladocumento
  (codParcela, codDocumento, codParcelaC, codParcelaCAdt, valorPrincParcela)
VALUES
  (1, 1, 2,    NULL, 360000.00),
  (2, 2, 3,    NULL, 370440.00),
  (3, 3, NULL, 3,    100000.00),   -- adiantamento
  (4, 4, 6,    NULL, 246000.00),
  (5, 5, 6,    NULL,  24600.00),   -- devolução
  (6, 6, 4,    NULL, 288000.00),
  (7, 7, 7,    NULL,  27000.00);

-- Acréscimo e desconto do faturamento vêm da BAIXA, não da nota — a nota
-- guarda o valor de face. Só o CT-001 tem, para o efeito ficar isolado.
INSERT INTO baixa (codBaixa, canceladaBaixa) VALUES
  (1, 0),
  (2, 1);   -- CANCELADA: os itens dela não podem entrar

INSERT INTO itensbaixa
  (codItBaixa, codBaixa, codParcelaDocumento, acrescimoPrincItBaixa, descontoPrincItBaixa, retencao)
VALUES
  (1, 1, 1, 12000.00,  6000.00, 0),   -- CT-001: +12.000 -6.000 = +6.000
  (2, 1, 1,     0.00,     0.00, 1),   -- RETENÇÃO: fica fora
  (3, 2, 1, 99000.00,     0.00, 0);   -- de baixa CANCELADA: fica fora

-- A cotação do dólar. A linha do ano 3905 é o retrato de um defeito real da
-- base de origem: pegar "a mais recente" sem teto de data traz ela, com valor
-- 1,00, e a conversão do saldo em dólar vira o valor nominal.
INSERT INTO cotacaomoeda (codCotacao, codMoeda, dataCotMoeda, valor) VALUES
  (1, 2, '2025-06-30', 5.000000),
  (2, 2, '2025-01-15', 4.800000),
  (3, 2, '3905-01-01', 1.000000);   -- LIXO: a consulta a barra com <= CURDATE()

-- ---------------------------------------------------------------------
--  A SIMULAÇÃO PROJETADA — o outro lado da comparação
--
--  `cliente` precisa casar com Demo:NomeCliente do appsettings: a consulta
--  filtra por LIKE '%cliente%'.
-- ---------------------------------------------------------------------
INSERT INTO simulacao_projetado
  (id, cliente, safra, cultura, areaPlantada, areaColhida, produtividade, precoMedio, custoProducaoHa)
VALUES
  (1, 'Fazenda Crissiumal', '2024/2025', 'SOJA',  330.0000, 330.0000,  58.0000, 115.0000, 2900.0000),
  (2, 'Fazenda Crissiumal', '2024/2025', 'MILHO', 100.0000, 100.0000, 105.0000,  68.0000, 2400.0000);

-- simulacao_realizado fica VAZIA de propósito.
--
-- Uma linha ali SOBRESCREVE área, produção, preço e custo que vieram do ERP —
-- é o recurso para o cliente que não tem banco de origem. Preenchê-la aqui
-- faria a tela mostrar números que não saem do dado que o demo carrega, e a
-- conferência à mão perderia o sentido. A tabela existe para o código ser
-- cópia literal; ela responder vazio é o caso normal de quem TEM ERP.

-- =====================================================================
--  RESULTADO ESPERADO — safra 2024/2025
--
--  PREÇO MÉDIO REALIZADO
--    SOJA    R$ 1.197.840,00 ÷ 10.000 sc  =  119,784 R$/sc
--            (CT-001 606.000 + CT-002 370.440 + CT-004 221.400)
--    MILHO   R$   354.000,00 ÷  5.000 sc  =   70,80  R$/sc
--            (CT-003 300.000 + CT-005 54.000)
--
--  QUADRO (sem braquiária, que é o padrão)
--                     SOJA            MILHO
--    Área plantada    330,00 ha       100,00 ha
--    Área colhida     330,00 ha       100,00 ha
--    Produção         20.250 sc       11.000 sc
--    Produtividade     61,36 sc/ha    110,00 sc/ha
--    Preço médio      119,784         70,80
--    Custo/ha          3.000,00        2.500,00
--    Receita bruta  2.425.626,00     778.800,00
--    Custo total      990.000,00     250.000,00
--    Receita líquida 1.435.626,00    528.800,00
--
--    TOTAIS   430 ha · bruta 3.204.426,00 · custo 1.240.000,00
--             líquida 1.964.426,00 · margem operacional 158,42%
--
--  COM braquiária, os totais viram 480 ha · custo 1.300.000,00 ·
--  líquida 1.904.426,00 · margem 146,49%. A receita não muda: é
--  exatamente por isso que ela fica fora.
--
--  ---------------------------------------------------------------------
--  O QUE CADA NÚMERO DENUNCIA SE VIER DIFERENTE
--
--  SOJA a 179,78 R$/sc     → o saldo do contrato não foi abatido pelo que
--                            já virou nota. O CT-001 contou 966.000 em vez
--                            de 606.000: o mesmo grão duas vezes.
--  SOJA a 129,784          → o ADIANTAMENTO do CT-002 entrou no termo (1).
--  SOJA a 120,540          → o adiantamento não foi subtraído no termo (2),
--                            deixando 7.560 de resíduo fantasma.
--  SOJA a 122,244          → a devolução do CT-004 entrou somando em vez de
--                            subtrair (+24.600 no lugar de -24.600).
--  SOJA a 119,184          → a baixa CANCELADA ou a linha de RETENÇÃO
--                            entraram nos acréscimos.
--  MILHO a 68,40 R$/sc     → a cotação do ano 3905 foi usada: o saldo em
--                            dólar do CT-003 converteu a 1,00.
--  Produtividade da soja
--    em 61,36 mas a área
--    colhida menor que 330 → a regra da faixa de cultivar mudou.
--  Braquiária aparecendo
--    sem marcar o checkbox → o filtro caiu; a margem cai 12 pontos.
--
--  =====================================================================
--  E O QUE A TELA DE INSUMOS FAZ COM ESTAS MESMAS APLICAÇÕES
--
--  A matriz é tipo de insumo x talhão. O T-01 é o talhão que importa: ele
--  tem SOJA e MILHO na mesma safra, e é onde as três regras aparecem.
--
--    TALHÃO   ÁREA      R$/HA       SC/HA    TROCA
--    T-01     200,0 ha  2.850,00    31,01    36,49%
--    T-02     150,0 ha  2.800,00    23,38    37,10%
--    T-03      80,0 ha  3.125,00    26,09    43,48%
--    T-04      50,0 ha  1.200,00    11,60     0,00%
--
--    KPIs   R$ 1.300.000,00 aplicados · R$ 2.708,33/ha · 25,78 sc/ha ·
--           troca média 35,48%
--
--  AS TRÊS REGRAS, E O QUE CADA UMA CUSTA SE CAIR
--
--  1) O custo em sacas converte pelo preço da PRÓPRIA cultura. No T-01 são
--     320.000 de soja a 119,784 mais 250.000 de milho a 70,80. Com um preço
--     único a coluna daria 23,79 sc/ha em vez de 31,01 — 23% a menos, e
--     justamente no talhão mais caro.
--
--  2) O R$/ha divide pela área PLANTADA (200 ha = 100 de soja + 100 de
--     milho), não pela área FÍSICA do talhão (100 ha). Com a física daria
--     5.700,00/ha: o DOBRO, porque a área contaria uma vez e o custo das
--     duas culturas.
--
--  3) A troca usa a produtividade COLHIDA. No T-01 são 17.000 sc em 200 ha
--     = 85 sc/ha, e 31,01 ÷ 85 = 36,49%.
--
--  A BRAQUIÁRIA exercita o fallback: não tem contrato, então não tem preço
--  próprio, e o custo em sacas cai no preço GERAL da safra —
--  (1.197.840 + 354.000) ÷ 15.000 = 103,456 R$/sc, que dá 11,60 sc/ha. A
--  troca dela é 0%: não há colheita para trocar.
-- =====================================================================
