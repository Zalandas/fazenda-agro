-- =====================================================================
--  CONFERÊNCIA — a consulta de Contratos, para rodar direto no MySQL.
--
--  Mesma ideia do 03: é a consulta da TELA, não uma reescrita. Uma versão
--  "equivalente" escrita à mão para conferir é a armadilha clássica —
--  quando as duas discordam, ninguém sabe qual das duas errou. Aqui, se
--  o resultado bate com a tabela do 04-dados-contratos.sql, a tela está
--  certa; se não bate, o defeito é do código, não do conferidor.
--
--      mysql -udemo -pdemo erp_demo < banco/05-conferencia-contratos.sql
-- =====================================================================

SELECT
    TRIM(COALESCE(c.contratoContrato, c.contrato))                  AS CONTRATO,
    UPPER(prod.nomeProduto)                                         AS CULTURA,
    UPPER(pes.nomePessoa)                                           AS CLIENTE,
    UPPER(COALESCE(m.nomeMoeda, 'REAL'))                            AS MOEDA,
    ROUND(COALESCE(c.qtdContrato, 0.0) / 60.0, 2)                   AS QNT_SC,

    -- Em moeda alternativa o preço em reais vem da MÉDIA DAS FIXAÇÕES;
    -- precoContrato só entra quando não há fixação (o COALESCE cobre isso).
    ROUND(CASE WHEN m.codMoeda IS NOT NULL AND UPPER(m.nomeMoeda) <> 'REAL'
               THEN (COALESCE(f.totalValor / NULLIF(f.totalQuantidade, 0), c.precoContrato, 0.0) * 60.0)
               ELSE (COALESCE(c.precoContrato, 0.0) * 60.0) END, 2) AS PRECO_RS,
    ROUND(CASE WHEN m.codMoeda IS NOT NULL AND UPPER(m.nomeMoeda) <> 'REAL'
               THEN (COALESCE(c.qtdContrato, 0.0) * COALESCE(f.totalValor / NULLIF(f.totalQuantidade, 0), c.precoContrato, 0.0))
               ELSE (COALESCE(c.qtdContrato, 0.0) * COALESCE(c.precoContrato, 0.0)) END, 2) AS TOTAL_RS,

    -- Qual peso vale é decisão do CONTRATO, não do romaneio.
    ROUND((CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%'
                THEN COALESCE(r.saidaDestino, 0.0) ELSE COALESCE(r.saidaOrigem, 0.0) END) / 60.0, 2)   AS SAIDA_SC,
    ROUND((CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%'
                THEN COALESCE(r.entradaDestino, 0.0) ELSE COALESCE(r.entradaOrigem, 0.0) END) / 60.0, 2) AS ENTRADA_SC,

    -- saldo = contratado − saídas + devoluções
    ROUND(((COALESCE(c.qtdContrato, 0.0)
        - CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%' THEN COALESCE(r.saidaDestino, 0.0)   ELSE COALESCE(r.saidaOrigem, 0.0)   END
        + CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%' THEN COALESCE(r.entradaDestino, 0.0) ELSE COALESCE(r.entradaOrigem, 0.0) END
        ) / 60.0), 2)                                               AS SALDO_SC,

    CASE WHEN UPPER(TRIM(COALESCE(c.status, ''))) = 'FINALIZADO' THEN 'FINALIZADO'
         WHEN (COALESCE(c.qtdContrato, 0.0)
             - CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%' THEN COALESCE(r.saidaDestino, 0.0)   ELSE COALESCE(r.saidaOrigem, 0.0)   END
             + CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%' THEN COALESCE(r.entradaDestino, 0.0) ELSE COALESCE(r.entradaOrigem, 0.0) END
             ) <= 0 THEN 'FINALIZADO'
         ELSE 'PENDENTE' END                                        AS STATUS,

    DATE(r.maxDataEntrega)                                          AS DATA_ENTREGA,
    DATE(p.primeiraDataParcela)                                     AS DATA_PGTO
FROM contrato c
    LEFT JOIN safra        s    ON c.codSafra          = s.codSafra
    LEFT JOIN tipocontrato tc   ON c.codTipoContrato   = tc.codTipoContrato
    LEFT JOIN pessoa       pes  ON c.codPessoaCliente  = pes.codPessoa
    LEFT JOIN produto      prod ON c.codProdutoCultura = prod.codProduto
    LEFT JOIN moeda        m    ON c.codMoedaAlt       = m.codMoeda
    LEFT JOIN (SELECT codContrato, SUM(quantidade) AS totalQuantidade, SUM(valor) AS totalValor
                 FROM fixacoescontrato GROUP BY codContrato) f ON c.codContrato = f.codContrato
    LEFT JOIN (
        SELECT codContrato,
               MAX(dataLancRomaneio) AS maxDataEntrega,
               SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%SAIDA%'   THEN COALESCE(pesoLiqRomaneio, 0)        ELSE 0 END) AS saidaOrigem,
               SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%SAIDA%'   THEN COALESCE(pesoLiqDestinoRomaneio, 0) ELSE 0 END) AS saidaDestino,
               SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%ENTRADA%' THEN COALESCE(pesoLiqRomaneio, 0)        ELSE 0 END) AS entradaOrigem,
               SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%ENTRADA%' THEN COALESCE(pesoLiqDestinoRomaneio, 0) ELSE 0 END) AS entradaDestino
          FROM romaneio
         WHERE (canceladoRomaneio = 0 OR canceladoRomaneio IS NULL)
           AND UPPER(COALESCE(tipoEntSaiRomaneio, '')) NOT LIKE '%REMESSA%'
         GROUP BY codContrato
    ) r ON c.codContrato = r.codContrato
    LEFT JOIN (SELECT codContrato, MIN(vencimentoParcela) AS primeiraDataParcela
                 FROM parcelacontrato GROUP BY codContrato) p ON c.codContrato = p.codContrato
WHERE UPPER(COALESCE(c.status, '')) <> 'CANCELADO'
  AND UPPER(tc.nomeTipoContrato) LIKE '%VENDA%'
  AND s.dataInicial >= '2000-01-01'
ORDER BY CONTRATO;

-- ---------------------------------------------------------------------
--  Os KPIs do topo da tela. "Entregue" é LÍQUIDO — saídas menos
--  devoluções —, e é por isso que Contratado − Entregue fecha exatamente
--  com A Entregar. Se não fechar, a devolução entrou de um lado só.
--
--  Esperado:  15.000 · 12.240 · 2.760
-- ---------------------------------------------------------------------
SELECT
    ROUND(SUM(QNT_SC), 2)               AS CONTRATADO_SC,
    ROUND(SUM(SAIDA_SC - ENTRADA_SC),2) AS ENTREGUE_SC,
    ROUND(SUM(SALDO_SC), 2)             AS A_ENTREGAR_SC
FROM (
    SELECT
        COALESCE(c.qtdContrato, 0.0) / 60.0 AS QNT_SC,
        (CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%'
              THEN COALESCE(r.saidaDestino, 0.0) ELSE COALESCE(r.saidaOrigem, 0.0) END) / 60.0 AS SAIDA_SC,
        (CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%'
              THEN COALESCE(r.entradaDestino, 0.0) ELSE COALESCE(r.entradaOrigem, 0.0) END) / 60.0 AS ENTRADA_SC,
        ((COALESCE(c.qtdContrato, 0.0)
          - CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%' THEN COALESCE(r.saidaDestino, 0.0)   ELSE COALESCE(r.saidaOrigem, 0.0)   END
          + CASE WHEN UPPER(TRIM(COALESCE(c.controlePeso, ''))) LIKE '%DESTINO%' THEN COALESCE(r.entradaDestino, 0.0) ELSE COALESCE(r.entradaOrigem, 0.0) END
         ) / 60.0) AS SALDO_SC
    FROM contrato c
        LEFT JOIN safra s ON c.codSafra = s.codSafra
        LEFT JOIN tipocontrato tc ON c.codTipoContrato = tc.codTipoContrato
        LEFT JOIN (
            SELECT codContrato,
                   SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%SAIDA%'   THEN COALESCE(pesoLiqRomaneio, 0)        ELSE 0 END) AS saidaOrigem,
                   SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%SAIDA%'   THEN COALESCE(pesoLiqDestinoRomaneio, 0) ELSE 0 END) AS saidaDestino,
                   SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%ENTRADA%' THEN COALESCE(pesoLiqRomaneio, 0)        ELSE 0 END) AS entradaOrigem,
                   SUM(CASE WHEN UPPER(COALESCE(tipoRomaneio,'')) LIKE '%ENTRADA%' THEN COALESCE(pesoLiqDestinoRomaneio, 0) ELSE 0 END) AS entradaDestino
              FROM romaneio
             WHERE (canceladoRomaneio = 0 OR canceladoRomaneio IS NULL)
               AND UPPER(COALESCE(tipoEntSaiRomaneio, '')) NOT LIKE '%REMESSA%'
             GROUP BY codContrato
        ) r ON c.codContrato = r.codContrato
    WHERE UPPER(COALESCE(c.status, '')) <> 'CANCELADO'
      AND UPPER(tc.nomeTipoContrato) LIKE '%VENDA%'
      AND s.dataInicial >= '2000-01-01'
) k;
