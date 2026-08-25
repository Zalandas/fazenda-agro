-- =====================================================================
--  CONFERÊNCIA — a tela de Insumos.
--
--  Esta é diferente das outras três, e vale dizer por quê: em Insumos o
--  SQL entrega apenas o dado BRUTO — valor aplicado, área plantada e
--  sacas colhidas por (talhão, cultura, categoria). O cálculo que dá
--  sentido à tela (custo em sacas pelo preço da própria cultura, relação
--  de troca sobre a produtividade colhida) acontece em C#, isolado em
--  InsumosService.Calcular, porque é lá que ele pode ser testado sem
--  banco.
--
--  Então este arquivo confere a PRIMEIRA metade — a coluna R$/HA e as
--  áreas — e a segunda fica com a tabela de valores esperados no rodapé
--  do 06-dados-quadro.sql, que traz também sc/ha e troca.
--
--      mysql -udemo -pdemo erp_demo < banco/08-conferencia-insumos.sql
-- =====================================================================

-- ---------------------------------------------------------------------
--  (A) A MATRIZ: categoria de insumo x talhão
--
--  A categoria sai de um CASE sobre tipo e subtipo do produto, e a ORDEM
--  das cláusulas importa: '%DEFENSIVO%' no tipo é testado antes de
--  herbicida e inseticida. É por isso que no seed eles têm tipo próprio.
-- ---------------------------------------------------------------------
SELECT
    UPPER(TRIM(t.nomeTalhao))                                  AS TALHAO,
    CASE
        WHEN tp.nomeTipoProd LIKE '%SEMENTE%'     OR stp.nomeSubtipoProd LIKE '%SEMENTE%'   THEN 'SEMENTES'
        WHEN tp.nomeTipoProd LIKE '%FERTILIZANTE%' OR stp.nomeSubtipoProd LIKE '%CORRETIVO%' THEN 'FERTILIZANTES E CORRETIVOS'
        WHEN tp.nomeTipoProd LIKE '%DEFENSIVO%'   OR stp.nomeSubtipoProd LIKE '%FUNGICIDA%' THEN 'FUNGICIDAS'
        WHEN stp.nomeSubtipoProd LIKE '%HERBICIDA%'                                          THEN 'HERBICIDAS'
        WHEN stp.nomeSubtipoProd LIKE '%INSETICIDA%'                                         THEN 'INSETICIDAS'
        ELSE UPPER(COALESCE(tp.nomeTipoProd, 'OUTROS'))
    END                                                        AS CATEGORIA,
    ROUND(SUM(COALESCE(itap.valorItAplicTalhao, 0.0)), 2)      AS VALOR
FROM itensaplictalhao itap
    JOIN      aplictalhao   ap  ON itap.codAplicTalhao = ap.codAplicTalhao
    LEFT JOIN produto       pi_ ON itap.codProduto     = pi_.codProduto
    LEFT JOIN tipoproduto   tp  ON pi_.codTipoProd     = tp.codTipoProd
    LEFT JOIN subtipoproduto stp ON pi_.codSubTipoProdutoTP = stp.codSubtipoProd
    LEFT JOIN talhao        t   ON ap.codTalhao        = t.codTalhao
GROUP BY TALHAO, CATEGORIA
ORDER BY TALHAO, CATEGORIA;

-- ---------------------------------------------------------------------
--  (B) O TOTAL POR TALHÃO e o R$/HA
--
--  A área é a PLANTADA, somada por cultura — não a física do talhão.
--  O T-01 é o caso que decide: 100 ha de soja mais 100 de milho dão
--  200 ha, e a área física dele é 100. Com a física, o R$/ha do T-01
--  daria 5.700,00 em vez de 2.850,00.
--
--  Esperado:
--    T-01 SEDE      570.000,00 ÷ 200,0 ha = 2.850,00
--    T-02 BAIXADA   420.000,00 ÷ 150,0 ha = 2.800,00
--    T-03 DIVISA    250.000,00 ÷  80,0 ha = 3.125,00
--    T-04 PASTO      60.000,00 ÷  50,0 ha = 1.200,00
--    TOTAL        1.300.000,00 ÷ 480,0 ha = 2.708,33
-- ---------------------------------------------------------------------
SELECT
    UPPER(TRIM(t.nomeTalhao))                        AS TALHAO,
    ROUND(SUM(x.VALOR), 2)                           AS VALOR_APLICADO,
    ROUND(SUM(x.AREA_PLANTADA), 1)                   AS AREA_PLANTADA,
    ROUND(MAX(t.areaTalhao), 1)                      AS AREA_FISICA,
    ROUND(SUM(x.VALOR) / NULLIF(SUM(x.AREA_PLANTADA), 0), 2) AS RS_POR_HA
FROM (
    SELECT
        ap.codTalhao,
        SUM(COALESCE(itap.valorItAplicTalhao, 0.0)) AS VALOR,
        COALESCE((SELECT SUM(COALESCE(cs.areaPrevistaConfigSafra, 0.0))
                    FROM configsafra cs
                   WHERE cs.codSafra          = ap.codSafra
                     AND cs.codTalhao         = ap.codTalhao
                     AND cs.codProdutoCultura = ap.codProdutoCultura), 0.0) AS AREA_PLANTADA
    FROM itensaplictalhao itap
        JOIN aplictalhao ap ON itap.codAplicTalhao = ap.codAplicTalhao
    GROUP BY ap.codAplicTalhao, ap.codTalhao, ap.codSafra, ap.codProdutoCultura
) x
    JOIN talhao t ON x.codTalhao = t.codTalhao
GROUP BY t.nomeTalhao
ORDER BY TALHAO;

-- ---------------------------------------------------------------------
--  (C) O QUE ALIMENTA A RELAÇÃO DE TROCA
--
--  Produtividade COLHIDA por (talhão, cultura): Σ sacas ÷ Σ área. Nunca
--  média de produtividades — e é sobre ela que a troca é calculada.
--
--  Esperado: T-01 soja 60,00 · T-01 milho 110,00 · T-02 63,00 ·
--            T-03 60,00 · T-04 sem colheita
-- ---------------------------------------------------------------------
SELECT
    UPPER(TRIM(t.nomeTalhao))                                     AS TALHAO,
    UPPER(TRIM(p.nomeProduto))                                    AS CULTURA,
    ROUND(SUM(COALESCE(cs.areaPrevistaConfigSafra, 0.0)), 2)      AS AREA,
    ROUND(COALESCE((SELECT SUM(COALESCE(r.pesoLiqRomaneio, 0.0)) / 60.0
                      FROM romaneio r
                     WHERE r.codSafra          = cs.codSafra
                       AND r.codTalhao         = cs.codTalhao
                       AND r.codProdutoCultura = cs.codProdutoCultura
                       AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                       AND r.tipoRomaneio       LIKE 'ENTRADA%'
                       AND COALESCE(r.canceladoRomaneio, 0) = 0), 0.0), 2) AS SACAS,
    ROUND(COALESCE((SELECT SUM(COALESCE(r.pesoLiqRomaneio, 0.0)) / 60.0
                      FROM romaneio r
                     WHERE r.codSafra          = cs.codSafra
                       AND r.codTalhao         = cs.codTalhao
                       AND r.codProdutoCultura = cs.codProdutoCultura
                       AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                       AND r.tipoRomaneio       LIKE 'ENTRADA%'
                       AND COALESCE(r.canceladoRomaneio, 0) = 0), 0.0)
          / NULLIF(SUM(COALESCE(cs.areaPrevistaConfigSafra, 0.0)), 0), 2)  AS SC_POR_HA
FROM configsafra cs
    JOIN talhao  t ON cs.codTalhao         = t.codTalhao
    JOIN produto p ON cs.codProdutoCultura = p.codProduto
GROUP BY t.nomeTalhao, p.nomeProduto, cs.codSafra, cs.codTalhao, cs.codProdutoCultura
ORDER BY TALHAO, CULTURA;
