-- =====================================================================
--  CONFERÊNCIA — o Quadro de Safras, para rodar direto no MySQL.
--
--  Duas consultas, porque o quadro tem duas metades:
--    (A) o PREÇO MÉDIO realizado, que é a conta difícil;
--    (B) a linha do quadro — área, produção, custo — e a margem que sai
--        do cruzamento das duas.
--
--  As duas são as consultas da TELA, não reescritas. Se o resultado bate
--  com a tabela do 06-dados-quadro.sql, a tela está certa.
--
--      mysql -udemo -pdemo erp_demo < banco/07-conferencia-quadro.sql
-- =====================================================================

-- ---------------------------------------------------------------------
--  (A) PREÇO MÉDIO REALIZADO   — esperado: SOJA 119,7840 · MILHO 70,8000
--
--  Dois termos que não podem se sobrepor:
--    (1) notas emitidas contra o contrato, EXCETO adiantamento, com
--        devolução invertendo o sinal e acréscimo/desconto vindos da baixa;
--    (2) saldo do contrato ainda NÃO faturado — descontando TODO documento
--        já emitido, inclusive o adiantamento, com piso em zero.
--
--  O ERP não abate o saldo ao faturar: é o termo (2) que faz isso. Sem ele
--  o mesmo grão conta duas vezes.
-- ---------------------------------------------------------------------
SELECT
    UPPER(TRIM(prodSafra.nomeSafra))                              AS Safra,
    UPPER(TRIM(prod.nomeProduto))                                 AS Cultura,
    ROUND(SUM(sub.VALOR_TOTAL_REAL), 2)                           AS ValorTotal,
    ROUND(SUM(sub.QTD_CONTRATO_SC), 2)                            AS Sacas,
    ROUND(SUM(sub.VALOR_TOTAL_REAL) / SUM(sub.QTD_CONTRATO_SC),4) AS PrecoMedio
FROM (
    SELECT
        c.codContrato, c.codSafra, c.codProdutoCultura,
        (COALESCE(c.qtdContrato, 0.0) / 60.0) AS QTD_CONTRATO_SC,

        -- (1) NOTAS
        COALESCE((
            SELECT SUM(
                CASE WHEN UPPER(COALESCE(op.nomeTipoOper, '')) LIKE '%DEVOLUCAO%VENDA%PRODUCAO%'
                       OR UPPER(COALESCE(op.nomeTipoOper, '')) LIKE '%DEVOLU%VEND%'
                     THEN -1 ELSE 1 END *
                (IFNULL(d.valorDoc, 0) + IFNULL(ipd.TOTAL_ACRESCIMO, 0) - IFNULL(ipd.TOTAL_DESCONTO, 0)))
            FROM parcelacontrato pcx
            INNER JOIN (SELECT DISTINCT codDocumento, codParcelaC, codParcelaCAdt FROM parceladocumento) pdx
                    ON pdx.codParcelaCAdt = pcx.codParcela OR pdx.codParcelaC = pcx.codParcela
            INNER JOIN documento d ON d.codDoc = pdx.codDocumento
            LEFT  JOIN tipooperacao op ON d.codTipoOper = op.codTipoOper
            LEFT  JOIN (
                SELECT pd2.codDocumento,
                       SUM(IFNULL(ib.acrescimoPrincItBaixa, 0)) AS TOTAL_ACRESCIMO,
                       SUM(IFNULL(ib.descontoPrincItBaixa, 0))  AS TOTAL_DESCONTO
                  FROM parceladocumento pd2
                  INNER JOIN itensbaixa ib ON ib.codParcelaDocumento = pd2.codParcela
                  INNER JOIN baixa b ON b.codBaixa = ib.codBaixa
                 WHERE b.canceladaBaixa = 0
                   AND (ib.retencao = 0 OR ib.retencao IS NULL)
                 GROUP BY pd2.codDocumento
            ) ipd ON ipd.codDocumento = d.codDoc
            WHERE pcx.codContrato = c.codContrato
              AND UPPER(COALESCE(d.historicoDoc, '')) NOT LIKE '%ADIANTAMENTO%'
        ), 0.0)

        -- (2) SALDO NÃO FATURADO
        + COALESCE((
            SELECT SUM(GREATEST(
                (CASE WHEN pc.codMoedaAltParcela = 2
                      THEN COALESCE(pc.saldoAltParcela, 0.0) *
                           (SELECT cm.valor FROM cotacaomoeda cm
                             WHERE cm.codMoeda = 2 AND cm.dataCotMoeda <= CURDATE()
                             ORDER BY cm.dataCotMoeda DESC LIMIT 1)
                      ELSE COALESCE(pc.saldoAltParcela, 0.0) END)
                - COALESCE((SELECT SUM(COALESCE(pd0.valorPrincParcela, 0.0))
                              FROM parceladocumento pd0
                             WHERE pd0.codParcelaC = pc.codParcela
                                OR pd0.codParcelaCAdt = pc.codParcela), 0.0)
            , 0.0))
            FROM parcelacontrato pc
            WHERE pc.codContrato = c.codContrato
              AND COALESCE(pc.saldoAltParcela, 0.0) > 0
        ), 0.0) AS VALOR_TOTAL_REAL
    FROM contrato c
    INNER JOIN safra sf        ON c.codSafra        = sf.codSafra
    INNER JOIN tipocontrato tc ON c.codTipoContrato = tc.codTipoContrato
    WHERE UPPER(TRIM(sf.nomeSafra)) = '2024/2025'
      AND UPPER(tc.nomeTipoContrato) LIKE '%VENDA%'
      AND UPPER(COALESCE(c.status, '')) <> 'CANCELADO'
) sub
INNER JOIN safra   prodSafra ON sub.codSafra          = prodSafra.codSafra
INNER JOIN produto prod      ON sub.codProdutoCultura = prod.codProduto
GROUP BY prodSafra.nomeSafra, prod.nomeProduto;

-- ---------------------------------------------------------------------
--  (B) A LINHA DO QUADRO, por cultura
--
--  Esperado (2024/2025):
--    SOJA        330,00 ha plantados · 330,00 colhidos · 20.250 sc · custo 990.000,00
--    MILHO       100,00 ha plantados · 100,00 colhidos · 11.000 sc · custo 250.000,00
--    BRAQUIARIA   50,00 ha plantados ·   0,00 colhidos ·      0 sc · custo  60.000,00
--
--  A área COLHIDA não é a plantada: uma faixa de cultivar só entra se
--  tiver romaneio de colheita PRÓPRIO (safra, fazenda, talhão, cultura,
--  ciclo E cultivar) ou estiver fechada no ERP. É por isso que a
--  braquiária tem área plantada e zero colhida.
-- ---------------------------------------------------------------------
SELECT
    s.nomeSafra                                                  AS Safra,
    UPPER(TRIM(p.nomeProduto))                                   AS Cultura,
    ROUND(SUM(COALESCE(cs.areaPrevistaConfigSafra, 0.0)), 2)     AS AreaPlantada,
    ROUND(SUM(CASE WHEN COALESCE(cs.fechaColheitaConfigSafra, 0) = 1
                     OR EXISTS (SELECT 1 FROM romaneio rc
                                 WHERE rc.codSafra            = cs.codSafra
                                   AND rc.codUnidadePessoaFaz = cs.codUnidPessoaFaz
                                   AND rc.codTalhao           = cs.codTalhao
                                   AND rc.codProdutoCultura   = cs.codProdutoCultura
                                   AND rc.codCiclo            = cs.codCiclo
                                   AND rc.codProdutoCultivar  = cs.codProdutoCultivar
                                   AND rc.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                                   AND rc.tipoRomaneio       LIKE 'ENTRADA%'
                                   AND COALESCE(rc.canceladoRomaneio, 0) = 0)
                   THEN COALESCE(cs.areaPrevistaConfigSafra, 0.0) ELSE 0.0 END), 2) AS AreaColhida,
    ROUND(COALESCE((SELECT SUM(COALESCE(itap.valorItAplicTalhao, 0.0))
                      FROM itensaplictalhao itap
                      JOIN aplictalhao ap ON itap.codAplicTalhao = ap.codAplicTalhao
                     WHERE ap.codSafra = cs.codSafra
                       AND ap.codProdutoCultura = cs.codProdutoCultura), 0.0), 2)   AS CustoTotal,
    ROUND(COALESCE((SELECT SUM(COALESCE(r.pesoLiqRomaneio, 0.0)) / 60.0
                      FROM romaneio r
                     WHERE r.codSafra = cs.codSafra
                       AND r.codProdutoCultura = cs.codProdutoCultura
                       AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                       AND r.tipoRomaneio       LIKE 'ENTRADA%'
                       AND COALESCE(r.canceladoRomaneio, 0) = 0), 0.0), 2)          AS ProducaoSacas
FROM configsafra cs
    LEFT JOIN safra   s ON cs.codSafra          = s.codSafra
    LEFT JOIN produto p ON cs.codProdutoCultura = p.codProduto
WHERE s.dataInicial >= '2000-01-01' AND p.nomeProduto IS NOT NULL
GROUP BY s.nomeSafra, p.nomeProduto, cs.codSafra, cs.codProdutoCultura;
