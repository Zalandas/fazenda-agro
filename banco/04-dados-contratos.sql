-- =====================================================================
--  CONTRATOS DE VENDA — fictícios.
--
--  Nenhum cliente, número de contrato ou preço aqui reproduz negócio
--  real. Carteira de compradores e política de preço são informação do
--  cliente e não aparecem nem disfarçadas.
--
--  Como no arquivo da Produção, cada linha existe para exercitar uma
--  regra, e os números foram escolhidos para que o ERRO e o ACERTO deem
--  resultados DIFERENTES. Uma regra que, quebrada, ainda devolve o mesmo
--  total não está sendo testada — está sendo acompanhada.
--
--  A tabela de resultados esperados está no fim.
-- =====================================================================

SET NAMES utf8mb4;

-- Safra com data-lixo: o ERP real tem linhas com ano absurdo, e a consulta
-- se defende com `s.dataInicial >= '2000-01-01'`. Existe aqui para que a
-- defesa tenha o que barrar.
INSERT INTO safra (codSafra, nomeSafra, dataInicial) VALUES
  (99, '1899/1900', '1899-08-01');

INSERT INTO tipocontrato (codTipoContrato, nomeTipoContrato) VALUES
  (1, 'Venda de Graos'),
  (2, 'Compra de Insumos');

INSERT INTO pessoa (codPessoa, nomePessoa) VALUES
  (100, 'Cerealista Boa Safra'),
  (101, 'Exportadora Vale Verde'),
  (102, 'Armazens Rio Claro');

INSERT INTO moeda (codMoeda, nomeMoeda) VALUES
  (1, 'DOLAR');

-- ---------------------------------------------------------------------
--  OS CONTRATOS
--
--  qtdContrato em QUILOS, precoContrato em R$/kg. Contrato em reais tem
--  codMoedaAlt nulo; a consulta então mostra 'REAL' e usa precoContrato.
-- ---------------------------------------------------------------------
INSERT INTO contrato
  (codContrato, contratoContrato, contrato, codSafra, codTipoContrato, codPessoaCliente,
   codProdutoCultura, codMoedaAlt, qtdContrato, precoContrato, precoUnitAlt, valorAlt,
   dataLancContrato, tipoFrete, controlePeso, status)
VALUES
  -- 1) PESO DE ORIGEM. Origem e destino DIVERGEM de propósito (quebra de
  --    transporte). Como controlePeso não diz "destino", vale a origem.
  (1, 'CT-2025-001', NULL, 1, 1, 100, 10, NULL,
   300000.000, 2.000000, NULL, NULL, '2024-10-15 09:30:00', '0', 'ORIGEM', 'ABERTO'),

  -- 2) PESO DE DESTINO. Mesmo caso, decisão oposta — e aqui a escolha muda
  --    o STATUS, não só o número: pela origem o saldo daria ZERO e o
  --    contrato apareceria FINALIZADO.
  (2, 'CT-2025-002', NULL, 1, 1, 101, 10, NULL,
   180000.000, 2.100000, NULL, NULL, '2024-11-05 14:00:00', '1', 'PESO DESTINO', 'ABERTO'),

  -- 3) MOEDA ALTERNATIVA COM FIXAÇÃO. O preço em reais NÃO é o
  --    precoContrato (1,00) — é a média das fixações (1,20). Deixado com
  --    valores distantes para que usar o errado salte aos olhos.
  (3, 'CT-2025-003', NULL, 1, 1, 100, 11, 1,
   240000.000, 1.000000, 0.250000, 60000.00, '2025-01-20 10:00:00', '0', 'ORIGEM', 'ABERTO'),

  -- 4) DEVOLUÇÃO E REMESSA. A devolução VOLTA para o saldo; a remessa não
  --    é entrega e fica fora. Contá-la como saída viraria saldo negativo.
  (4, 'CT-2025-004', NULL, 1, 1, 102, 10, NULL,
   120000.000, 2.050000, NULL, NULL, '2024-12-01 08:15:00', '1', 'ORIGEM', 'ABERTO'),

  -- 5) STATUS EXPLÍCITO ganha do saldo: sobram 500 sc por entregar, mas o
  --    contrato foi encerrado. É a primeira condição do CASE.
  (5, 'CT-2025-005', NULL, 1, 1, 101, 11, NULL,
   60000.000, 0.900000, NULL, NULL, '2025-02-14 16:40:00', '0', 'ORIGEM', 'FINALIZADO'),

  -- ------- OS TRÊS ABAIXO NÃO PODEM APARECER NA TELA -------
  -- cancelado
  (900, 'CT-2025-900', NULL, 1, 1, 100, 10, NULL,
   600000.000, 2.000000, NULL, NULL, '2024-10-01 09:00:00', '0', 'ORIGEM', 'CANCELADO'),
  -- não é contrato de VENDA
  (901, 'CT-2025-901', NULL, 1, 2, 102, 10, NULL,
   300000.000, 1.500000, NULL, NULL, '2024-10-02 09:00:00', '0', 'ORIGEM', 'ABERTO'),
  -- safra com data-lixo
  (902, 'CT-1899-902', NULL, 99, 1, 100, 10, NULL,
   900000.000, 2.000000, NULL, NULL, '1899-09-01 09:00:00', '0', 'ORIGEM', 'ABERTO');

-- Média = 288.000,00 ÷ 240.000 kg = 1,20 R$/kg  →  72,00 R$/sc
INSERT INTO fixacoescontrato (codFixacao, codContrato, quantidade, valor) VALUES
  (1, 3, 144000.000, 172800.00),
  (2, 3,  96000.000, 115200.00);

-- DATA_PGTO é a MENOR parcela, não a primeira cadastrada: os contratos 1 e 3
-- têm duas, fora de ordem no INSERT de propósito.
INSERT INTO parcelacontrato (codParcela, codContrato, vencimentoParcela) VALUES
  (1, 1, '2025-04-10'),
  (2, 1, '2025-03-10'),
  (3, 2, '2025-05-15'),
  (4, 3, '2025-08-10'),
  (5, 3, '2025-07-10'),
  (6, 4, '2025-06-20'),
  (7, 5, '2025-09-05');

-- ---------------------------------------------------------------------
--  AS ENTREGAS
--
--  Mesma tabela da colheita, leitura diferente: aqui o que classifica é
--  tipoRomaneio ('Saida' / 'Entrada') e o vínculo é codContrato. Os dois
--  pesos vêm preenchidos para que a escolha do contrato tenha efeito.
--
--  Estes romaneios NÃO afetam a tela de Produção: nenhum deles é
--  'Colheita', e é o par Colheita+Entrada que ela exige.
-- ---------------------------------------------------------------------
INSERT INTO romaneio
  (codRomaneio, codSafra, codUnidadePessoaFaz, codTalhao, codProdutoCultura, codProdutoCultivar,
   codCiclo, pesoLiqRomaneio, pesoLiqDestinoRomaneio, tipoEntSaiRomaneio, tipoRomaneio,
   canceladoRomaneio, codContrato, dataLancRomaneio)
VALUES
  -- Contrato 1 — origem 180.000 (3.000 sc) x destino 178.200 (2.970 sc)
  (101, 1, 1, 1, 10, 20, 1,  90000.000,  89100.000, 'Venda', 'Saida', 0, 1, '2025-03-05'),
  (102, 1, 1, 1, 10, 20, 1,  90000.000,  89100.000, 'Venda', 'Saida', 0, 1, '2025-03-18'),

  -- Contrato 2 — origem 180.000 (3.000 sc) x destino 176.400 (2.940 sc)
  (103, 1, 1, 1, 10, 20, 1,  60000.000,  58800.000, 'Venda', 'Saida', 0, 2, '2025-04-02'),
  (104, 1, 1, 1, 10, 20, 1,  60000.000,  58800.000, 'Venda', 'Saida', 0, 2, '2025-04-11'),
  (105, 1, 1, 1, 10, 20, 1,  60000.000,  58800.000, 'Venda', 'Saida', 0, 2, '2025-04-25'),

  -- Contrato 3 — entrega o contrato inteiro: saldo zero
  (106, 1, 1, 1, 11, 22, 2, 120000.000, 119000.000, 'Venda', 'Saida', 0, 3, '2025-06-10'),
  (107, 1, 1, 1, 11, 22, 2, 120000.000, 119000.000, 'Venda', 'Saida', 0, 3, '2025-06-22'),

  -- Contrato 4 — saída, devolução, e duas que ficam de fora
  (108, 1, 1, 1, 10, 20, 1, 120000.000, 118800.000, 'Venda',              'Saida',   0, 4, '2025-05-08'),
  (109, 1, 1, 1, 10, 20, 1,  12000.000,  12000.000, 'Devolucao',          'Entrada', 0, 4, '2025-05-20'),
  (110, 1, 1, 1, 10, 20, 1,  60000.000,  59400.000, 'Remessa a Armazem',  'Saida',   0, 4, '2025-05-12'),
  (111, 1, 1, 1, 10, 20, 1,  30000.000,  29700.000, 'Venda',              'Saida',   1, 4, '2025-05-14'),

  -- Contrato 5 — entrega parcial, mas o contrato foi encerrado
  (112, 1, 1, 1, 11, 22, 2,  30000.000,  29700.000, 'Venda', 'Saida', 0, 5, '2025-07-15');

-- =====================================================================
--  RESULTADO ESPERADO — safra 2024/2025, sem filtro de cultura/cliente
--
--  CONTRATO      CULTURA  MOEDA  CONTRATADO   SAÍDA    ENTRADA   SALDO   STATUS
--  CT-2025-001   SOJA     REAL     5.000 sc  3.000 sc      —    2.000 sc PENDENTE
--  CT-2025-002   SOJA     REAL     3.000 sc  2.940 sc      —       60 sc PENDENTE
--  CT-2025-003   MILHO    DOLAR    4.000 sc  4.000 sc      —        0 sc FINALIZADO
--  CT-2025-004   SOJA     REAL     2.000 sc  2.000 sc   200 sc    200 sc PENDENTE
--  CT-2025-005   MILHO    REAL     1.000 sc    500 sc      —      500 sc FINALIZADO
--
--  PREÇOS (R$/sc)   001: 120,00   002: 126,00   003: 72,00   004: 123,00   005: 54,00
--  TOTAIS (R$)      SOJA 1.224.000,00   MILHO 342.000,00
--
--  KPIs   Contratado 15.000 sc · Entregue 12.240 sc · A entregar 2.760 sc
--         (entregue = saídas − devoluções; 15.000 − 12.240 = 2.760 fecha)
--
--  ---------------------------------------------------------------------
--  O QUE CADA NÚMERO DENUNCIA SE VIER DIFERENTE
--
--  001 com 2.970 sc de saída  → usou o peso de DESTINO onde o contrato
--                               manda usar a origem.
--  002 aparecendo FINALIZADO  → usou a ORIGEM: 180.000 − 180.000 = 0. É o
--                               engano mais caro, porque some da lista de
--                               pendências um contrato que ainda deve.
--  003 a 60,00 R$/sc          → ignorou as fixações e usou precoContrato.
--                               Some R$ 48.000,00 de receita.
--  004 FINALIZADO (saldo −800)→ contou a REMESSA como entrega.
--  004 com saldo 0            → ignorou a devolução.
--  005 PENDENTE               → perdeu a primeira condição do CASE, a do
--                               status explícito.
--  Qualquer linha CT-2025-900/901 ou CT-1899-902 na tela → um dos três
--                               filtros do WHERE caiu.
-- =====================================================================
