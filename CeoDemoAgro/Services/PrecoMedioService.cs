using Dapper;
using Microsoft.Extensions.Caching.Memory;
using MySqlConnector;

namespace CeoManager.Services
{
    // Linha do preço médio realizado por (safra, cultura), vinda dos contratos de VENDA.
    public class PrecoMedioCultura
    {
        public string Safra { get; set; }
        public string Cultura { get; set; }
        public decimal ValorRecebidoTotal { get; set; }
        public decimal SacasTotal { get; set; }
        public decimal PrecoMedio => SacasTotal > 0 ? ValorRecebidoTotal / SacasTotal : 0m;
    }

    /// <summary>
    /// Fonte ÚNICA do preço médio realizado por cultura, usada pelo Quadro de Safras e pelo
    /// BI de Insumos (telas internas e públicas). A fórmula foi calibrada contra a planilha de
    /// um cliente real e fechou ao centavo; o nome dele e o número conferido ficaram no
    /// repositório privado, porque preço de venda é informação do cliente.
    ///
    /// Valor final do contrato em 2 termos SEM sobreposição, só contratos de VENDA não cancelados:
    ///   (1) NOTAS vinculadas ao contrato (exceto adiantamento): valor de face + acréscimos
    ///       − descontos, devolução de venda com sinal invertido. Nota em aberto conta pela
    ///       face — o saldo dela já está aqui dentro. Adiantamento fica de fora: é o mesmo
    ///       dinheiro que as notas quitam por encontro de contas (contá-lo dobra o contrato).
    ///   (2) SALDO DO CONTRATO ainda não faturado: o ERP NÃO abate saldoAltParcela ao faturar
    ///       (parcela 100% paga mantém saldo cheio), então desconta-se o que já virou documento
    ///       — TODOS os documentos, inclusive adiantamento, senão contratos com parte adiantada
    ///       deixam resíduo fantasma — com piso em zero.
    /// Preço médio = Σ(1+2) ÷ Σ sacas contratadas.
    /// A cotação do dólar exige dataCotMoeda <= CURDATE(): há linha lixo com ano 3905 e
    /// valor 1 que zerava a conversão se pegasse a "mais recente".
    /// </summary>
    public static class PrecoMedioService
    {
        private const string SqlPrecoMedio = @"
            SELECT
                UPPER(TRIM(prodSafra.nomeSafra)) AS Safra,
                UPPER(TRIM(prod.nomeProduto)) AS Cultura,
                SUM(sub.VALOR_TOTAL_REAL) AS ValorRecebidoTotal,
                SUM(sub.QTD_CONTRATO_SC) AS SacasTotal
            FROM (
                SELECT
                    c.codContrato,
                    c.codSafra,
                    c.codProdutoCultura,
                    (COALESCE(c.qtdContrato, 0.0) / 60.0) AS QTD_CONTRATO_SC,

                    -- (1) NOTAS (documentos) vinculadas ao contrato, exceto adiantamento
                    COALESCE((
                        SELECT SUM(
                            CASE
                                WHEN UPPER(COALESCE(op.nomeTipoOper, '')) LIKE '%DEVOLUCAO%VENDA%PRODUCAO%'
                                  OR UPPER(COALESCE(op.nomeTipoOper, '')) LIKE '%DEVOLU%VEND%'
                                THEN -1 ELSE 1
                            END *
                            (IFNULL(d.valorDoc, 0) + IFNULL(ipd.TOTAL_ACRESCIMO, 0) - IFNULL(ipd.TOTAL_DESCONTO, 0))
                        )
                        FROM parcelacontrato pcx
                        INNER JOIN (
                            SELECT DISTINCT codDocumento, codParcelaC, codParcelaCAdt
                            FROM parceladocumento
                        ) pdx ON pdx.codParcelaCAdt = pcx.codParcela OR pdx.codParcelaC = pcx.codParcela
                        INNER JOIN documento d ON d.codDoc = pdx.codDocumento
                        LEFT JOIN tipooperacao op ON d.codTipoOper = op.codTipoOper
                        LEFT JOIN (
                            SELECT
                                pd2.codDocumento,
                                SUM(IFNULL(ib.acrescimoPrincItBaixa, 0)) AS TOTAL_ACRESCIMO,
                                SUM(IFNULL(ib.descontoPrincItBaixa, 0)) AS TOTAL_DESCONTO
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

                    -- (2) SALDO DO CONTRATO ainda não faturado (piso zero por parcela)
                    + COALESCE((
                        SELECT SUM(GREATEST(
                            (CASE WHEN pc.codMoedaAltParcela = 2   -- dólar
                                  THEN COALESCE(pc.saldoAltParcela, 0.0) * (SELECT cm.valor FROM cotacaomoeda cm
                                                                            WHERE cm.codMoeda = 2 AND cm.dataCotMoeda <= CURDATE()
                                                                            ORDER BY cm.dataCotMoeda DESC LIMIT 1)
                                  ELSE COALESCE(pc.saldoAltParcela, 0.0) END)
                            - COALESCE((SELECT SUM(COALESCE(pd0.valorPrincParcela, 0.0))
                                        FROM parceladocumento pd0
                                        WHERE pd0.codParcelaC = pc.codParcela OR pd0.codParcelaCAdt = pc.codParcela), 0.0)
                        , 0.0))
                        FROM parcelacontrato pc
                        WHERE pc.codContrato = c.codContrato
                          AND COALESCE(pc.saldoAltParcela, 0.0) > 0
                    ), 0.0) AS VALOR_TOTAL_REAL

                FROM contrato c
                INNER JOIN safra sf ON c.codSafra = sf.codSafra
                INNER JOIN tipocontrato tc ON c.codTipoContrato = tc.codTipoContrato
                WHERE UPPER(TRIM(sf.nomeSafra)) = @safra
                  -- Mesma régua da tela de Contratos: só VENDA (exclui remessa, arrendamento
                  -- e compra — remessas têm sacas sem valor financeiro e diluíam o preço
                  -- médio) e sem cancelados.
                  AND UPPER(tc.nomeTipoContrato) LIKE '%VENDA%'
                  AND UPPER(COALESCE(c.status, '')) <> 'CANCELADO'
            ) sub
            INNER JOIN safra prodSafra ON sub.codSafra = prodSafra.codSafra
            INNER JOIN produto prod ON sub.codProdutoCultura = prod.codProduto
            GROUP BY prodSafra.nomeSafra, prod.nomeProduto";

        /// <summary>
        /// Cache curto do resultado. A consulta é pesada (subconsultas correlacionadas por
        /// contrato: ~2,5 s no São Rafael) e é chamada por 4 telas — Quadro de Safras e
        /// Insumos, interna e pública. Sem isso, cada abertura do portal do cliente refazia
        /// tudo contra o banco do próprio cliente. O preço médio deriva de contratos e notas,
        /// que mudam ao longo de dias, então minutos de defasagem não têm efeito prático.
        /// </summary>
        private static readonly MemoryCache _cache = new(new MemoryCacheOptions());
        private static readonly TimeSpan _validadeCache = TimeSpan.FromMinutes(5);

        public static async Task<List<PrecoMedioCultura>> ObterPorCulturaAsync(string connString, string safra)
        {
            // A connection string identifica o cliente; entra na chave por hash para não
            // deixar senha de banco em memória como texto de chave.
            string chave = $"precomedio|{connString?.GetHashCode()}|{safra}";

            if (_cache.TryGetValue(chave, out List<PrecoMedioCultura> emCache))
                return emCache;

            using var conn = new MySqlConnection(connString);
            var precos = (await conn.QueryAsync<PrecoMedioCultura>(SqlPrecoMedio, new { safra })).ToList();

            _cache.Set(chave, precos, _validadeCache);
            return precos;
        }

        /// <summary>Descarta o cache — útil se for preciso forçar releitura sem esperar os 5 min.</summary>
        public static void LimparCache() => _cache.Clear();
    }
}
