using CeoManager.Models;
using Dapper;
using MySqlConnector;

namespace CeoManager.Services
{
    /// <summary>
    /// Monta o BI de Insumos. Fonte ÚNICA das telas interna (InsumosController) e
    /// pública (PublicoController) — antes eram dois métodos copiados de ~280 linhas,
    /// e toda correção precisava ser feita duas vezes. Foi assim que a relação de
    /// troca da tela pública zerou uma vez, quando um alias de SQL mudou só num lado.
    ///
    /// Regras de cálculo que não podem regredir (ver CLAUDE.md §9):
    ///  - custo em sacas convertido pelo preço da PRÓPRIA cultura da aplicação;
    ///  - R$/ha divide pela área PLANTADA da cultura, não pela área física do talhão;
    ///  - produtividade da relação de troca é a COLHIDA (Σsacas ÷ Σárea colhida),
    ///    nunca média de produtividades.
    /// </summary>
    public class InsumosService
    {
        /// <summary>Último recurso quando o ERP não fornece preço médio de nenhuma cultura da safra.</summary>
        private const decimal PRECO_SACA_BASE = 113.06m;

        public class Resultado
        {
            public InsumosBiViewModel Model { get; set; } = new();
            public List<string> SafrasDisponiveis { get; set; } = new();
            public List<string> FazendasDisponiveis { get; set; } = new();
            public List<string> CulturasDisponiveis { get; set; } = new();
            public string ErroBanco { get; set; }
        }

        /// <param name="dataInicialMinima">
        /// Corte de safras da consulta. As duas telas divergem de propósito hoje: a interna
        /// usa 2023-06-01 e a pública 2000-01-01, então a pública mostra safras que a interna
        /// não mostra (São Rafael 2022/2023, 1.534 aplicações). Parametrizado para a extração
        /// deste serviço não mudar o que cada tela exibe — unificar é decisão de produto.
        /// </param>
        /// <param name="safrasDaTabelaSafra">
        /// true: lista de safras vem da tabela `safra` do ERP (todas, como faz a tela interna).
        /// false: deriva das próprias aplicações (só safras com insumo, como faz a pública).
        /// </param>
        public static async Task<Resultado> GerarAsync(
            string connString,
            string safraFiltro,
            string fazendaFiltro,
            string culturaFiltro,
            string dataInicialMinima,
            bool safrasDaTabelaSafra)
        {
            var resultado = new Resultado();
            var model = resultado.Model;
            model.MatrizPivot = new Dictionary<string, Dictionary<string, CelulaMatrizInsumo>>();
            model.TotaisPorTalhao = new Dictionary<string, CelulaMatrizInsumo>();
            model.AreasTalhoes = new Dictionary<string, decimal>();
            model.ColunasTalhoes = new List<string>();
            model.ChartLabelsTalhoes = new List<string>();
            model.ChartCustoSacas = new List<decimal>();
            model.ChartRelacaoTroca = new List<decimal>();

            var baseDados = new List<InsumoDadoBruto>();

            // Área COLHIDA por (talhão, cultura), na mesma régua da tela de Produção:
            // faixa de cultivar conta se tem romaneio próprio OU está fechada no ERP.
            // É a base da produtividade usada na relação de troca (colhida, não geral).
            var areasColhidas = new Dictionary<(string Talhao, string Cultura), decimal>();

            try
            {
                if (!string.IsNullOrEmpty(connString))
                {
                    string sql = $@"
                    SELECT
                        UPPER(TRIM(up.nomeUnidPessoa)) AS FAZENDA,
                        UPPER(TRIM(t.nomeTalhao)) AS TALHAO,
                        UPPER(TRIM(COALESCE(pc.nomeProduto, ''))) AS CULTURA,
                        UPPER(TRIM(s.nomeSafra)) AS SAFRA,

                        CASE
                            WHEN tp.nomeTipoProd LIKE '%SEMENTE%' OR stp.nomeSubtipoProd LIKE '%SEMENTE%' THEN 'SEMENTES'
                            WHEN tp.nomeTipoProd LIKE '%FERTILIZANTE%' OR stp.nomeSubtipoProd LIKE '%CORRETIVO%' THEN 'FERTILIZANTES E CORRETIVOS'
                            WHEN tp.nomeTipoProd LIKE '%DEFENSIVO%' OR stp.nomeSubtipoProd LIKE '%FUNGICIDA%' THEN 'FUNGICIDAS'
                            WHEN stp.nomeSubtipoProd LIKE '%HERBICIDA%' THEN 'HERBICIDAS'
                            WHEN stp.nomeSubtipoProd LIKE '%INSETICIDA%' THEN 'INSETICIDAS'
                            WHEN stp.nomeSubtipoProd LIKE '%ADJUVANTE%' THEN 'ADJUVANTES'
                            WHEN stp.nomeSubtipoProd LIKE '%BIOLOGICO%' THEN 'BIOLOGICOS'
                            ELSE UPPER(COALESCE(tp.nomeTipoProd, 'OUTROS'))
                        END AS TIPO_INSUMO,

                        -- Área PLANTADA da cultura no talhão (não a área física do talhão):
                        -- o custo do insumo é da lavoura, então o R$/ha tem que dividir pelo
                        -- que foi plantado daquela cultura. Com a área física, talhão com
                        -- safra + safrinha contava a área uma vez só e o custo das duas,
                        -- dobrando o R$/ha na visão de todas as culturas.
                        -- Fallback na área física quando não há configsafra para a aplicação.
                        COALESCE(
                            NULLIF((SELECT SUM(COALESCE(cs.areaPrevistaConfigSafra, 0.0))
                                    FROM configsafra cs
                                    WHERE cs.codSafra = ap.codSafra
                                      AND cs.codTalhao = ap.codTalhao
                                      AND cs.codProdutoCultura = ap.codProdutoCultura), 0),
                            MAX(COALESCE(t.areaTalhao, 0.0)), 0.0) AS HA,
                        SUM(COALESCE(itap.valorItAplicTalhao, 0.0)) AS VALOR_APLIC,

                        COALESCE((
                            SELECT SUM(COALESCE(r.pesoLiqRomaneio, 0.0)) / 60.0
                            FROM romaneio r
                            WHERE r.codSafra = ap.codSafra
                              AND r.codTalhao = ap.codTalhao
                              AND r.codProdutoCultura = ap.codProdutoCultura
                              AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                              AND r.tipoRomaneio LIKE 'ENTRADA%'
                              AND COALESCE(r.canceladoRomaneio, 0) = 0
                        ), 0.0) AS SACAS_COLHIDAS

                    FROM itensaplictalhao itap
                    JOIN aplictalhao ap ON itap.codAplicTalhao = ap.codAplicTalhao
                    LEFT JOIN produto pc ON ap.codProdutoCultura = pc.codProduto
                    LEFT JOIN produto pItem ON itap.codProduto = pItem.codProduto
                    LEFT JOIN tipoproduto tp ON pItem.codTipoProd = tp.codTipoProd
                    LEFT JOIN subtipoproduto stp ON pItem.codSubTipoProdutoTP = stp.codSubtipoProd
                    LEFT JOIN safra s ON ap.codSafra = s.codSafra
                    LEFT JOIN talhao t ON ap.codTalhao = t.codTalhao
                    LEFT JOIN unidadepessoa up ON t.codUnidPessoaFaz = up.codUnidPessoa

                    WHERE s.dataInicial >= '{dataInicialMinima}'
                      AND t.nomeTalhao IS NOT NULL AND TRIM(t.nomeTalhao) <> ''
                    GROUP BY s.nomeSafra, up.nomeUnidPessoa, t.nomeTalhao, pc.nomeProduto,
                             CASE
                                WHEN tp.nomeTipoProd LIKE '%SEMENTE%' OR stp.nomeSubtipoProd LIKE '%SEMENTE%' THEN 'SEMENTES'
                                WHEN tp.nomeTipoProd LIKE '%FERTILIZANTE%' OR stp.nomeSubtipoProd LIKE '%CORRETIVO%' THEN 'FERTILIZANTES E CORRETIVOS'
                                WHEN tp.nomeTipoProd LIKE '%DEFENSIVO%' OR stp.nomeSubtipoProd LIKE '%FUNGICIDA%' THEN 'FUNGICIDAS'
                                WHEN stp.nomeSubtipoProd LIKE '%HERBICIDA%' THEN 'HERBICIDAS'
                                WHEN stp.nomeSubtipoProd LIKE '%INSETICIDA%' THEN 'INSETICIDAS'
                                WHEN stp.nomeSubtipoProd LIKE '%ADJUVANTE%' THEN 'ADJUVANTES'
                                WHEN stp.nomeSubtipoProd LIKE '%BIOLOGICO%' THEN 'BIOLOGICOS'
                                ELSE UPPER(COALESCE(tp.nomeTipoProd, 'OUTROS'))
                             END, ap.codSafra, ap.codTalhao, ap.codProdutoCultura";

                    string sqlAreaColhida = @"
                    SELECT
                        UPPER(TRIM(t.nomeTalhao)) AS TALHAO,
                        UPPER(TRIM(p.nomeProduto)) AS CULTURA,
                        SUM(CASE WHEN COALESCE(cs.fechaColheitaConfigSafra, 0) = 1
                                   OR EXISTS (
                                       SELECT 1 FROM romaneio r
                                       WHERE COALESCE(r.canceladoRomaneio, 0) = 0
                                         AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                                         AND r.tipoRomaneio LIKE 'ENTRADA%'
                                         AND r.codSafra = cs.codSafra
                                         AND r.codUnidadePessoaFaz = cs.codUnidPessoaFaz
                                         AND r.codTalhao = cs.codTalhao
                                         AND r.codProdutoCultura = cs.codProdutoCultura
                                         AND r.codCiclo = cs.codCiclo
                                         AND r.codProdutoCultivar = cs.codProdutoCultivar
                                   )
                                 THEN COALESCE(cs.areaPrevistaConfigSafra, 0.0)
                                 ELSE 0.0 END) AS AREA_COLHIDA
                    FROM configsafra cs
                    LEFT JOIN safra s ON cs.codSafra = s.codSafra
                    LEFT JOIN talhao t ON cs.codTalhao = t.codTalhao
                    LEFT JOIN produto p ON cs.codProdutoCultura = p.codProduto
                    WHERE UPPER(TRIM(s.nomeSafra)) = @safra
                      AND t.nomeTalhao IS NOT NULL AND TRIM(t.nomeTalhao) <> ''
                      AND p.nomeProduto IS NOT NULL
                    GROUP BY t.nomeTalhao, p.nomeProduto";

                    using var connection = new MySqlConnection(connString);
                    baseDados = (await connection.QueryAsync<InsumoDadoBruto>(sql)).ToList();

                    var linhasAreaColhida = await connection.QueryAsync(sqlAreaColhida, new { safra = safraFiltro });
                    foreach (var l in linhasAreaColhida)
                        areasColhidas[((string)l.TALHAO, (string)l.CULTURA)] = Convert.ToDecimal(l.AREA_COLHIDA);
                }
            }
            catch (MySqlException ex)
            {
                resultado.ErroBanco = (ex.Number == 1129 || ex.Message.Contains("flush-hosts"))
                    ? "O servidor de banco de dados bloqueou o nosso acesso temporariamente por medida de segurança (excesso de falhas de conexão). Acione o suporte técnico."
                    : "Não foi possível conectar ao banco de dados do cliente no momento. Verifique as configurações de conexão.";
            }
            catch (Exception)
            {
                resultado.ErroBanco = "Ocorreu um erro inesperado ao tentar buscar os dados. Tente novamente mais tarde.";
            }

            var query = baseDados.AsQueryable();

            if (!string.IsNullOrEmpty(safraFiltro))
                query = query.Where(x => x.SAFRA == safraFiltro);

            if (safrasDaTabelaSafra)
            {
                // Consulta protegida: com o banco do cliente fora, abrir uma segunda conexão
                // sem try derrubava a tela com erro 500 em vez de mostrar o banner.
                try
                {
                    if (!string.IsNullOrEmpty(connString))
                    {
                        using var connSafras = new MySqlConnection(connString);
                        resultado.SafrasDisponiveis = (await connSafras.QueryAsync<string>(@"
                            SELECT UPPER(TRIM(nomeSafra))
                            FROM safra
                            WHERE dataInicial >= '2000-01-01'
                            ORDER BY dataInicial DESC")).ToList();
                    }
                }
                catch (Exception)
                {
                    resultado.ErroBanco ??= "Não foi possível conectar ao banco de dados do cliente no momento. Verifique as configurações de conexão.";
                }
            }
            else
            {
                resultado.SafrasDisponiveis = baseDados.Select(x => x.SAFRA).Distinct().OrderByDescending(x => x).ToList();
            }

            resultado.FazendasDisponiveis = query.Select(x => x.FAZENDA).Where(x => !string.IsNullOrEmpty(x)).Distinct().OrderBy(x => x).ToList();
            if (!string.IsNullOrEmpty(fazendaFiltro))
                query = query.Where(x => x.FAZENDA == fazendaFiltro);

            resultado.CulturasDisponiveis = query.Select(x => x.CULTURA).Where(x => !string.IsNullOrEmpty(x)).Distinct().OrderBy(x => x).ToList();
            if (!string.IsNullOrEmpty(culturaFiltro))
                query = query.Where(x => x.CULTURA == culturaFiltro);

            var listaFiltrada = query.ToList();

            // A ÚNICA linha do original que NÃO veio junto ficava aqui: um filtro temporário
            // que escondia a categoria "INSUMOS CORRETIVO" de todo o BI, posto para uma
            // apresentação específica e marcado para sair depois.
            //
            // Não copiei porque ele é o contrário do que este demo se propõe. Ele suprime dado
            // em silêncio: o custo por hectare aparece MENOR do que é, e nada na tela diz
            // isso. Num sistema em produção, com quem o pôs por perto, é uma decisão
            // reversível; num repositório público seria uma regra escondida que ninguém
            // consegue explicar — e o leitor não teria como saber que o número está
            // incompleto.
            //
            // O resto do método é cópia literal.

            // Daqui em diante é só cálculo, sem banco — a parte testável está em Calcular().

            // Preço médio realizado POR CULTURA (fórmula única em PrecoMedioService): o custo
            // em sacas e a relação de troca do milho usam o preço do milho, os da soja o da
            // soja. Fallback em cascata: preço geral da safra → constante de último recurso.
            var precosPorCultura = new Dictionary<string, decimal>();
            decimal precoGeralSafra = 0m;
            try
            {
                if (!string.IsNullOrEmpty(connString))
                {
                    var precos = await PrecoMedioService.ObterPorCulturaAsync(connString, safraFiltro);
                    foreach (var p in precos.Where(p => p.PrecoMedio > 0))
                        precosPorCultura[p.Cultura] = p.PrecoMedio;

                    decimal sacasVendidas = precos.Sum(p => p.SacasTotal);
                    precoGeralSafra = sacasVendidas > 0 ? precos.Sum(p => p.ValorRecebidoTotal) / sacasVendidas : 0m;
                }
            }
            catch (Exception ex)
            {
                // sem preço do ERP, a tela segue com a constante de último recurso —
                // mas registra, senão o custo em sacas sai errado e ninguém descobre por quê.
                //
                // No original esta linha é um Serilog.Log.Warning. O demo não carrega Serilog
                // (seria uma dependência inteira por uma linha), então escreve no stderr, que
                // aparece no terminal de quem rodou. O que importa é o aviso EXISTIR: engolir
                // esta exceção faria a tela mostrar um custo em sacas errado, calculado sobre
                // a constante, sem nada na tela dizendo isso.
                Console.Error.WriteLine(
                    $"[AVISO] Insumos: falha ao obter preço médio da safra {safraFiltro} — " +
                    $"o custo em sacas usará o preço de último recurso. {ex.Message}");
            }

            // O cálculo em si não toca o banco: fica isolado em Calcular() para poder
            // ser testado com dados sintéticos (ver CeoManager.Tests).
            Calcular(resultado.Model, listaFiltrada, areasColhidas, precosPorCultura, precoGeralSafra);

            return resultado;
        }

        /// <summary>
        /// Núcleo de cálculo do BI de Insumos — puro, sem banco e sem I/O.
        /// Recebe as aplicações já filtradas, as áreas colhidas e os preços por cultura,
        /// e preenche o modelo. Separado de <see cref="GerarAsync"/> justamente para ser
        /// testável: são estas regras que quebraram em produção mais de uma vez.
        /// </summary>
        public static void Calcular(
            InsumosBiViewModel model,
            List<InsumoDadoBruto> listaFiltrada,
            Dictionary<(string Talhao, string Cultura), decimal> areasColhidas,
            Dictionary<string, decimal> precosPorCultura,
            decimal precoGeralSafra)
        {
            decimal PrecoDaCultura(string cultura) =>
                precosPorCultura.TryGetValue((cultura ?? "").Trim().ToUpper(), out var preco)
                    ? preco
                    : (precoGeralSafra > 0 ? precoGeralSafra : PRECO_SACA_BASE);

            // Passo 1: sacas e área por (talhão, cultura) — evita duplicar o SACAS_COLHIDAS repetido por insumo
            var porTalhaoCultura = listaFiltrada
                .GroupBy(x => new { x.TALHAO, x.CULTURA })
                .Select(g => new
                {
                    Talhao = g.Key.TALHAO,
                    Cultura = g.Key.CULTURA,
                    Sacas = g.Max(x => x.SACAS_COLHIDAS),   // distinto por cultura no talhão
                    Area = g.Max(x => x.HA),                // área plantada da cultura (repetida por linha de insumo)
                    AreaColhida = areasColhidas.TryGetValue((g.Key.TALHAO, g.Key.CULTURA), out var ac) ? ac : 0m
                })
                .ToList();

            // Passo 2: consolida por talhão — sacas e área plantada somam entre culturas
            var talhoesDistintos = porTalhaoCultura
                .GroupBy(x => x.Talhao)
                .Select(g =>
                {
                    decimal sacasTalhao = g.Sum(x => x.Sacas);           // soma soja + milho
                    decimal areaTalhao = g.Sum(x => x.Area);             // hectares plantados no ano (safra + safrinha)
                    decimal areaColhidaTalhao = g.Sum(x => x.AreaColhida);
                    // Produtividade COLHIDA (sacas ÷ área efetivamente colhida). Cai para a
                    // área plantada só se a área colhida não veio do ERP.
                    decimal areaBase = areaColhidaTalhao > 0 ? areaColhidaTalhao : areaTalhao;
                    return new
                    {
                        Talhao = g.Key,
                        Area = areaTalhao,
                        AreaColhida = areaColhidaTalhao,
                        SacasColhidas = sacasTalhao,
                        Produtividade = areaBase > 0 ? sacasTalhao / areaBase : 0m
                    };
                })
                .ToList();

            model.ColunasTalhoes = talhoesDistintos.Select(x => x.Talhao).ToList();

            foreach (var t in talhoesDistintos)
            {
                model.AreasTalhoes[t.Talhao] = t.Area;
                model.TotaisPorTalhao[t.Talhao] = new CelulaMatrizInsumo();
            }

            var tiposInsumos = listaFiltrada.Select(x => x.TIPO_INSUMO).Distinct().OrderBy(x => x).ToList();

            foreach (var tipo in tiposInsumos)
            {
                model.MatrizPivot[tipo] = new Dictionary<string, CelulaMatrizInsumo>();
                foreach (var talhao in model.ColunasTalhoes)
                {
                    var aplicacoes = listaFiltrada.Where(x => x.TIPO_INSUMO == tipo && x.TALHAO == talhao).ToList();
                    decimal valorTotalAplic = aplicacoes.Sum(x => x.VALOR_APLIC);
                    decimal areaTalhao = model.AreasTalhoes.ContainsKey(talhao) ? model.AreasTalhoes[talhao] : 0m;
                    decimal produtividade = talhoesDistintos.FirstOrDefault(x => x.Talhao == talhao)?.Produtividade ?? 0m;

                    var celula = new CelulaMatrizInsumo();
                    if (areaTalhao > 0)
                    {
                        celula.CustoReaisHa = valorTotalAplic / areaTalhao;
                        // Convertido linha a linha pelo preço da PRÓPRIA cultura da aplicação
                        celula.CustoSacasHa = aplicacoes.Sum(x => x.VALOR_APLIC / PrecoDaCultura(x.CULTURA)) / areaTalhao;
                        celula.RelacaoTroca = produtividade > 0 ? (celula.CustoSacasHa / produtividade) * 100m : 0m;
                    }

                    model.MatrizPivot[tipo][talhao] = celula;
                    model.TotaisPorTalhao[talhao].CustoReaisHa += celula.CustoReaisHa;
                    model.TotaisPorTalhao[talhao].CustoSacasHa += celula.CustoSacasHa;
                }
            }

            // Total por talhão: troca a partir do custo acumulado e da produtividade do talhão
            foreach (var talhao in model.ColunasTalhoes)
            {
                decimal produtividade = talhoesDistintos.FirstOrDefault(x => x.Talhao == talhao)?.Produtividade ?? 0m;
                var total = model.TotaisPorTalhao[talhao];
                total.RelacaoTroca = produtividade > 0 ? (total.CustoSacasHa / produtividade) * 100m : 0m;
            }

            model.ValorTotalAplicacoes = listaFiltrada.Sum(x => x.VALOR_APLIC);
            decimal areaTotalGlobal = model.AreasTalhoes.Values.Sum();

            // Produção total reagregada (Σ sacas dos talhões), no método da tela de Produção
            decimal sacasTotalGlobal = talhoesDistintos.Sum(t => t.SacasColhidas);

            if (areaTotalGlobal > 0)
            {
                model.CustoMedioReaisHa = model.ValorTotalAplicacoes / areaTotalGlobal;
                model.CustoMedioSacasHa = listaFiltrada.Sum(x => x.VALOR_APLIC / PrecoDaCultura(x.CULTURA)) / areaTotalGlobal;

                // Produtividade média COLHIDA = Σsacas ÷ Σárea colhida (NÃO média de
                // produtividades). Fallback para a área plantada se o ERP não trouxe área
                // colhida. A distinção não é acadêmica: numa safra em que parte da área não
                // foi colhida, dividir pela plantada afunda a produtividade e a relação de
                // troca aparece vários pontos pior do que foi.
                decimal areaColhidaGlobal = talhoesDistintos.Sum(t => t.AreaColhida);
                decimal produtividadeMediaGlobal = areaColhidaGlobal > 0
                    ? sacasTotalGlobal / areaColhidaGlobal
                    : sacasTotalGlobal / areaTotalGlobal;

                // Troca média = custo médio em sacas ÷ produtividade média (NÃO média ponderada de trocas)
                model.RelacaoTrocaMedia = produtividadeMediaGlobal > 0
                    ? (model.CustoMedioSacasHa / produtividadeMediaGlobal) * 100m
                    : 0m;
            }

            model.ChartLabelsTalhoes = model.ColunasTalhoes;
            model.ChartCustoSacas = model.ColunasTalhoes.Select(t => model.TotaisPorTalhao[t].CustoSacasHa).ToList();
            model.ChartRelacaoTroca = model.ColunasTalhoes.Select(t => model.TotaisPorTalhao[t].RelacaoTroca).ToList();
        }
    }
}
