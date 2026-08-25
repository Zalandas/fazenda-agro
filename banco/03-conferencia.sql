-- =====================================================================
--  Confere o seed rodando a MESMA consulta da tela, sem subir a aplicação.
--
--  A CTE `grao` é cópia literal do SQL de PublicoController.Producao —
--  inclusive o resgate de romaneio órfão. Se ela divergir de lá, o demo
--  deixa de provar o que promete.
--
--  As duas leituras abaixo derivam DELA, e não de uma versão simplificada.
--  A primeira tentativa aqui reagregava por conta própria, sem o resgate,
--  e mostrava o T-03 zerado — acusando de defeito o que estava certo. Uma
--  conferência que não usa o mesmo caminho não confere nada.
--
--  Uso:
--    mysql -h 127.0.0.1 -udemo -pdemo erp_demo --table < banco/03-conferencia.sql
-- =====================================================================

WITH grao AS (
    SELECT
        UPPER(TRIM(u.nomeUnidPessoa)) AS Fazenda,
        UPPER(TRIM(t.nomeTalhao))     AS Talhao,
        UPPER(TRIM(p.nomeProduto))    AS Cultura,
        UPPER(TRIM(c.nomeCiclo))      AS Ciclo,
        COALESCE(UPPER(TRIM(pc.nomeProduto)), '') AS Cultivar,
        SUM(COALESCE(cs.areaPrevistaConfigSafra, 0.0)) AS Area,
        (COALESCE(MAX(rom.total_colhido_kg), 0.0) + COALESCE(MAX(orf.total_colhido_kg), 0.0)) / 60.0 AS Sacas
    FROM configsafra cs
    LEFT JOIN safra s ON cs.codSafra = s.codSafra
    LEFT JOIN talhao t ON cs.codTalhao = t.codTalhao
    LEFT JOIN unidadepessoa u ON cs.codUnidPessoaFaz = u.codUnidPessoa
    LEFT JOIN ciclo c ON cs.codCiclo = c.codCiclo
    LEFT JOIN produto p ON cs.codProdutoCultura = p.codProduto
    LEFT JOIN produto pc ON cs.codProdutoCultivar = pc.codProduto
    LEFT JOIN (
        SELECT r.codSafra, r.codUnidadePessoaFaz, r.codTalhao, r.codProdutoCultura, r.codProdutoCultivar, r.codCiclo,
               SUM(COALESCE(r.pesoLiqRomaneio, 0.0)) AS total_colhido_kg
        FROM romaneio r
        WHERE COALESCE(r.canceladoRomaneio, 0) = 0
          AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
          AND r.tipoRomaneio LIKE 'ENTRADA%'
        GROUP BY r.codSafra, r.codUnidadePessoaFaz, r.codTalhao, r.codProdutoCultura, r.codProdutoCultivar, r.codCiclo
    ) rom ON cs.codSafra = rom.codSafra
         AND cs.codUnidPessoaFaz = rom.codUnidadePessoaFaz
         AND cs.codTalhao = rom.codTalhao
         AND cs.codProdutoCultura = rom.codProdutoCultura
         AND cs.codProdutoCultivar = rom.codProdutoCultivar
         AND cs.codCiclo = rom.codCiclo
    LEFT JOIN (
        SELECT r.codSafra, r.codUnidadePessoaFaz, r.codTalhao, r.codProdutoCultura, r.codCiclo,
               SUM(COALESCE(r.pesoLiqRomaneio, 0.0)) AS total_colhido_kg
        FROM romaneio r
        WHERE COALESCE(r.canceladoRomaneio, 0) = 0
          AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
          AND r.tipoRomaneio LIKE 'ENTRADA%'
          AND NOT EXISTS (
              SELECT 1 FROM configsafra cs2
              WHERE cs2.codSafra = r.codSafra AND cs2.codUnidPessoaFaz = r.codUnidadePessoaFaz
                AND cs2.codTalhao = r.codTalhao AND cs2.codProdutoCultura = r.codProdutoCultura
                AND cs2.codCiclo = r.codCiclo AND cs2.codProdutoCultivar = r.codProdutoCultivar)
        GROUP BY r.codSafra, r.codUnidadePessoaFaz, r.codTalhao, r.codProdutoCultura, r.codCiclo
    ) orf ON cs.codSafra = orf.codSafra
         AND cs.codUnidPessoaFaz = orf.codUnidadePessoaFaz
         AND cs.codTalhao = orf.codTalhao
         AND cs.codProdutoCultura = orf.codProdutoCultura
         AND cs.codCiclo = orf.codCiclo
         AND rom.codSafra IS NULL
         AND 1 = (
             SELECT COUNT(DISTINCT COALESCE(cs3.codProdutoCultivar, -1))
             FROM configsafra cs3
             WHERE cs3.codSafra = cs.codSafra AND cs3.codUnidPessoaFaz = cs.codUnidPessoaFaz
               AND cs3.codTalhao = cs.codTalhao AND cs3.codProdutoCultura = cs.codProdutoCultura
               AND cs3.codCiclo = cs.codCiclo
               AND NOT EXISTS (
                   SELECT 1 FROM romaneio r2
                   WHERE COALESCE(r2.canceladoRomaneio, 0) = 0
                     AND r2.tipoEntSaiRomaneio LIKE 'COLHEITA%' AND r2.tipoRomaneio LIKE 'ENTRADA%'
                     AND r2.codSafra = cs3.codSafra AND r2.codUnidadePessoaFaz = cs3.codUnidPessoaFaz
                     AND r2.codTalhao = cs3.codTalhao AND r2.codProdutoCultura = cs3.codProdutoCultura
                     AND r2.codCiclo = cs3.codCiclo AND r2.codProdutoCultivar = cs3.codProdutoCultivar))
    WHERE s.dataInicial >= '2000-01-01'
      AND t.nomeTalhao IS NOT NULL AND TRIM(t.nomeTalhao) <> ''
      AND p.nomeProduto IS NOT NULL AND TRIM(p.nomeProduto) <> ''
    GROUP BY s.nomeSafra, u.nomeUnidPessoa, t.nomeTalhao, p.nomeProduto, c.nomeCiclo, pc.nomeProduto
)

-- 1) O grão da consulta: uma linha por CULTIVAR. É por isso que qualquer
--    visão "por talhão" precisa reagregar em vez de somar linha a linha.
SELECT Talhao, Cultura, Cultivar, Area, ROUND(Sacas,2) AS Sacas,
       ROUND(Sacas/NULLIF(Area,0), 2) AS ScPorHa
FROM grao ORDER BY Talhao, Cultura, Cultivar;
