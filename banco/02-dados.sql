-- =====================================================================
--  Fazenda FICTÍCIA. Nenhum nome, talhão, cultivar ou número aqui
--  reproduz cliente real — plano de talhões e padrão de cultivar são
--  informação deles.
--
--  Os valores foram escolhidos para serem CONFERÍVEIS À MÃO. A tabela
--  de resultados esperados está no fim deste arquivo; se a tela mostrar
--  outra coisa, é defeito, não arredondamento.
-- =====================================================================

SET NAMES utf8mb4;

INSERT INTO safra (codSafra, nomeSafra, dataInicial) VALUES
  (1, '2024/2025', '2024-09-01');

INSERT INTO unidadepessoa (codUnidPessoa, nomeUnidPessoa) VALUES
  (1, 'Fazenda Crissiumal');

INSERT INTO talhao (codTalhao, nomeTalhao, areaTalhao, codUnidPessoaFaz) VALUES
  (1, 'T-01 Sede',    100.0000, 1),
  (2, 'T-02 Baixada', 150.0000, 1),
  (3, 'T-03 Divisa',   80.0000, 1);

INSERT INTO ciclo (codCiclo, nomeCiclo) VALUES
  (1, '1a Safra'),
  (2, '2a Safra');

-- Cultura e cultivar saem da mesma tabela.
INSERT INTO produto (codProduto, nomeProduto) VALUES
  (10, 'SOJA'),
  (11, 'MILHO'),
  (20, 'TMG 7062'),
  (21, 'BRS 1010'),
  (22, 'AG 8088');

-- ---------------------------------------------------------------------
-- PLANTIO
--
-- O T-01 tem DUAS culturas na mesma safra: soja na primeira, milho na
-- segunda. É o caso que produziu o bug dos 144 sc/ha na base real — se a
-- subquery de colheita não amarrar a CULTURA, o milho soma na soja e a
-- produtividade da soja quase dobra. O demo existe para mostrar que aqui
-- ela não soma.
--
-- O T-02 tem dois CULTIVARES da mesma cultura: o grão da consulta é por
-- cultivar, então "por talhão" exige reagregar.
--
-- O T-03 tem um cultivar no plantio e outro no romaneio — o caso do
-- romaneio órfão, que o SQL resgata.
-- ---------------------------------------------------------------------
INSERT INTO configsafra
  (codSafra, codUnidPessoaFaz, codTalhao, codProdutoCultura, codProdutoCultivar, codCiclo, areaPrevistaConfigSafra, fechaColheitaConfigSafra)
VALUES
  (1, 1, 1, 10, 20, 1, 100.0000, 1),   -- T-01 soja  TMG 7062  100 ha
  (1, 1, 1, 11, 22, 2, 100.0000, 1),   -- T-01 milho AG 8088   100 ha (2a safra)
  (1, 1, 2, 10, 20, 1,  90.0000, 1),   -- T-02 soja  TMG 7062   90 ha
  (1, 1, 2, 10, 21, 1,  60.0000, 1),   -- T-02 soja  BRS 1010   60 ha
  (1, 1, 3, 10, 20, 1,  80.0000, 1);   -- T-03 soja  TMG 7062   80 ha

-- ---------------------------------------------------------------------
-- MOTORISTAS E VEÍCULOS — para a LISTA de romaneios.
--
-- Códigos a partir de 200 para não colidirem com os clientes do
-- 04-dados-contratos.sql, que usa 100..102 na mesma tabela `pessoa`.
--
-- Nem toda carga usa o cadastro: frete avulso é digitado à mão no próprio
-- romaneio. A consulta prefere o texto manual quando ele não está vazio, e
-- os dois caminhos aparecem abaixo de propósito.
-- ---------------------------------------------------------------------
INSERT INTO pessoa (codPessoa, nomePessoa) VALUES
  (200, 'Joao Batista Ferreira'),
  (201, 'Marcos Antonio Silva');

INSERT INTO veiculo (codVeiculo, placaVeiculo) VALUES
  (1, 'QAB-1234'),
  (2, 'QAC-5678');

-- ---------------------------------------------------------------------
-- COLHEITA — peso em QUILOS; a tela divide por 60 para virar saca.
--
-- Colheita é o PAR 'Colheita' + 'Entrada'. As duas últimas linhas existem
-- para provar que o filtro funciona: uma cancelada e uma de saída, que
-- NÃO podem entrar na conta.
--
-- BRUTO − TARA = LÍQUIDO em toda linha. A tara é o peso do caminhão vazio,
-- e mantê-la coerente importa: a lista mostra as três colunas lado a lado,
-- e uma soma que não fecha na tela salta aos olhos de quem conhece balança.
-- ---------------------------------------------------------------------
INSERT INTO romaneio
  (codRomaneio, codSafra, codUnidadePessoaFaz, codTalhao, codProdutoCultura, codProdutoCultivar, codCiclo,
   pesoLiqRomaneio, tipoEntSaiRomaneio, tipoRomaneio, canceladoRomaneio,
   numeroRomaneio, numeroNF, dataPesag1Romaneio, pesoBrutoRomaneio, pesoTaraRomaneio,
   codPessoaMotorista, motoristaManual, codVeiculo, placaManual)
VALUES
  -- T-01 soja: 3 cargas de 120.000 kg = 360.000 kg = 6.000 sc
  -- As duas primeiras usam motorista e veículo do CADASTRO.
  (1, 1, 1, 1, 10, 20, 1, 120000.000, 'Colheita', 'Entrada', 0,
   1001, '000101', '2025-02-18 08:14:00', 135000.000, 15000.000,  200, NULL, 1, NULL),
  (2, 1, 1, 1, 10, 20, 1, 120000.000, 'Colheita', 'Entrada', 0,
   1002, '000102', '2025-02-18 11:02:00', 135000.000, 15000.000,  201, NULL, 2, NULL),
  -- Esta é FRETE AVULSO: motorista e placa digitados à mão, sem cadastro.
  -- Se a consulta lesse só pm.nomePessoa/v.placaVeiculo, esta linha viria
  -- com as duas colunas em branco.
  (3, 1, 1, 1, 10, 20, 1, 120000.000, 'Colheita', 'Entrada', 0,
   1003, NULL,     '2025-02-19 07:45:00', 135000.000, 15000.000, NULL, 'Sebastiao Alves Pinto', NULL, 'QAD-9012'),

  -- T-01 milho: 660.000 kg = 11.000 sc
  (4, 1, 1, 1, 11, 22, 2, 330000.000, 'Colheita', 'Entrada', 0,
   1004, '000210', '2025-07-08 09:30:00', 360000.000, 30000.000,  200, NULL, 1, NULL),
  (5, 1, 1, 1, 11, 22, 2, 330000.000, 'Colheita', 'Entrada', 0,
   1005, '000211', '2025-07-09 14:20:00', 360000.000, 30000.000,  201, NULL, 2, NULL),

  -- T-02 soja TMG: 351.000 kg = 5.850 sc
  -- Cadastro E manual preenchidos: o MANUAL vence. É o caso que separa
  -- "prefere o manual" de "usa o manual só quando falta cadastro".
  (6, 1, 1, 2, 10, 20, 1, 351000.000, 'Colheita', 'Entrada', 0,
   1006, '000103', '2025-02-21 16:05:00', 386000.000, 35000.000,  200, 'Antonio Carlos Moreira', 1, 'QAE-3456'),
  -- T-02 soja BRS: 216.000 kg = 3.600 sc
  -- Manual com só ESPAÇOS: o TRIM faz cair no cadastro, não em branco.
  (7, 1, 1, 2, 10, 21, 1, 216000.000, 'Colheita', 'Entrada', 0,
   1007, '000104', '2025-02-22 10:40:00', 240000.000, 24000.000,  201, '   ', 2, '   '),

  -- T-03: ÓRFÃO. O plantio registrou TMG 7062; o romaneio veio com BRS 1010,
  -- que não tem linha de configsafra nesse talhão. O SQL atribui pela chave
  -- sem cultivar, porque há exatamente uma linha sem par. 288.000 kg = 4.800 sc
  (8, 1, 1, 3, 10, 21, 1, 288000.000, 'Colheita', 'Entrada', 0,
   1008, '000105', '2025-02-25 13:12:00', 318000.000, 30000.000,  200, NULL, 1, NULL),

  -- NÃO ENTRAM:
  (9,  1, 1, 1, 10, 20, 1, 100000.000, 'Colheita', 'Entrada', 1,
   1009, '000106', '2025-02-26 08:00:00', 112000.000, 12000.000,  200, NULL, 1, NULL),  -- cancelada
  (10, 1, 1, 1, 10, 20, 1,  50000.000, 'Colheita', 'Saida',   0,
   1010, '000107', '2025-02-27 08:00:00',  56000.000,  6000.000,  200, NULL, 1, NULL);  -- saída, não colheita

-- =====================================================================
--  RESULTADO ESPERADO — confira contra a tela
--
--  POR TALHÃO E CULTURA
--    T-01  SOJA    100 ha   6.000 sc    60,00 sc/ha
--    T-01  MILHO   100 ha  11.000 sc   110,00 sc/ha
--    T-02  SOJA    150 ha   9.450 sc    63,00 sc/ha   (5.850 + 3.600)
--    T-03  SOJA     80 ha   4.800 sc    60,00 sc/ha   (só o órfão)
--
--  POR CULTURA
--    SOJA    330 ha  20.250 sc   61,3636 sc/ha
--    MILHO   100 ha  11.000 sc  110,0000 sc/ha
--
--  O 06-dados-quadro.sql acrescenta um sexto plantio — BRAQUIÁRIA, 50 ha no
--  T-04, sem colheita — de que o Quadro de Safras precisa. Com ele carregado
--  esta tela passa a mostrar 480 ha PLANTADOS contra 430 COLHIDOS (89,6%), e
--  as duas produtividades deixam de coincidir: 65,10 sc/ha geral (sobre a
--  área plantada) e 72,67 sc/ha colhida (sobre a colhida). A produção não
--  muda, e nenhum número da soja muda.
--
--  A SOJA é o teste que importa. A média das três produtividades por
--  talhão — (60 + 63 + 60) / 3 — dá 61,00, e está ERRADA. A conta certa
--  é Σsacas ÷ Σárea = 20.250 / 330 = 61,3636. Se a tela mostrar 61,00,
--  alguém trocou a soma ponderada por média de razões.
--
--  E se a SOJA do T-01 aparecer perto de 170 sc/ha, a subquery deixou de
--  amarrar a cultura e está somando o milho junto.
-- =====================================================================
