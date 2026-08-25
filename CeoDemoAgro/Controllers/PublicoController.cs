using CeoManager.Models;
using Dapper;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;

namespace CeoDemoAgro.Controllers
{
    /// <summary>
    /// A tela pública de Produção, servida com dados fictícios.
    ///
    /// O corpo desta action é CÓPIA LITERAL de PublicoController.Producao do CeoManager —
    /// a consulta, a regra da área colhida, a reagregação por talhão e os gráficos. Nada foi
    /// simplificado: um demo que calcula diferente do sistema não demonstra o sistema.
    ///
    /// A ÚNICA diferença é de onde vem a string de conexão. No sistema real o token está numa
    /// tabela do SQL Server e leva a um GrupoId, que por sua vez nomeia a string
    /// "ClienteConnection_{GrupoId}". Aqui não há SQL Server nem cadastro: o token e o grupo
    /// vivem no appsettings, e o resto do caminho é o mesmo — inclusive o nome da string.
    /// </summary>
    public class PublicoController : Controller
    {
        private readonly IConfiguration _configuration;

        public PublicoController(IConfiguration configuration) => _configuration = configuration;

        /// <summary>
        /// Faz o papel de PublicoController.ResolverTokenAsync: valida o token e devolve a
        /// string de conexão do ERP. Sem banco, sem contagem de acesso, sem link revogável —
        /// o que sobra é a forma.
        /// </summary>
        private (bool ok, string? conexao, string cliente) ResolverToken(string token)
        {
            var esperado = _configuration["Demo:Token"];
            if (string.IsNullOrEmpty(esperado) || token != esperado)
                return (false, null, "");

            int grupoId = _configuration.GetValue("Demo:GrupoId", 999);
            var conexao = _configuration.GetConnectionString($"ClienteConnection_{grupoId}");
            return (true, conexao, _configuration["Demo:NomeCliente"] ?? "Cliente");
        }

        [HttpGet("p/producao/{token}")]
        public async Task<IActionResult> Producao(string token, string safra = "2024/2025",
            string ciclo = "", string fazenda = "", string cultura = "", string cultivar = "")
        {
            var (ok, connStringERP, nomeCliente) = ResolverToken(token);
            if (!ok)
                return Content("Este link é inválido ou foi desativado pelo administrador.");

            ViewBag.NomeCliente = nomeCliente;
            ViewBag.Token = token;

            var baseDados = new List<ProducaoPublicaViewModel>();

            if (!string.IsNullOrEmpty(connStringERP))
            {
                string sqlMysql = @"
            SELECT 
                UPPER(TRIM(u.nomeUnidPessoa)) AS Fazenda,
                UPPER(TRIM(t.nomeTalhao)) AS Talhao,
                UPPER(TRIM(p.nomeProduto)) AS Cultura,
                UPPER(TRIM(s.nomeSafra)) AS Safra,
                UPPER(TRIM(c.nomeCiclo)) AS Ciclo,
                COALESCE(UPPER(TRIM(pc.nomeProduto)), '') AS Cultivar,
                SUM(COALESCE(cs.areaPrevistaConfigSafra, 0.0)) AS AreaPlantada,
                MAX(COALESCE(cs.fechaColheitaConfigSafra, 0)) AS ColheitaFechada,
                (COALESCE(MAX(rom.total_colhido_kg), 0.0) + COALESCE(MAX(orf.total_colhido_kg), 0.0)) / 60.0 AS TotalProduzidoSacas
            FROM configsafra cs
            LEFT JOIN safra s ON cs.codSafra = s.codSafra
            LEFT JOIN talhao t ON cs.codTalhao = t.codTalhao
            LEFT JOIN unidadepessoa u ON cs.codUnidPessoaFaz = u.codUnidPessoa
            LEFT JOIN ciclo c ON cs.codCiclo = c.codCiclo
            LEFT JOIN produto p ON cs.codProdutoCultura = p.codProduto
            LEFT JOIN produto pc ON cs.codProdutoCultivar = pc.codProduto
            LEFT JOIN (
                SELECT 
                    r.codSafra, r.codUnidadePessoaFaz, r.codTalhao, r.codProdutoCultura, r.codProdutoCultivar, r.codCiclo,
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
            -- Resgate de romaneio ÓRFÃO (espelho do ProducaoController.SqlProducao — toda
            -- correção lá deve ser replicada aqui): colheita lançada com cultivar que não
            -- existe no configsafra é atribuída pela chave sem cultivar à única linha sem par.
            LEFT JOIN (
                SELECT
                    r.codSafra, r.codUnidadePessoaFaz, r.codTalhao, r.codProdutoCultura, r.codCiclo,
                    SUM(COALESCE(r.pesoLiqRomaneio, 0.0)) AS total_colhido_kg
                FROM romaneio r
                WHERE COALESCE(r.canceladoRomaneio, 0) = 0
                  AND r.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                  AND r.tipoRomaneio LIKE 'ENTRADA%'
                  AND NOT EXISTS (
                      SELECT 1 FROM configsafra cs2
                      WHERE cs2.codSafra = r.codSafra
                        AND cs2.codUnidPessoaFaz = r.codUnidadePessoaFaz
                        AND cs2.codTalhao = r.codTalhao
                        AND cs2.codProdutoCultura = r.codProdutoCultura
                        AND cs2.codCiclo = r.codCiclo
                        AND cs2.codProdutoCultivar = r.codProdutoCultivar
                  )
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
                     WHERE cs3.codSafra = cs.codSafra
                       AND cs3.codUnidPessoaFaz = cs.codUnidPessoaFaz
                       AND cs3.codTalhao = cs.codTalhao
                       AND cs3.codProdutoCultura = cs.codProdutoCultura
                       AND cs3.codCiclo = cs.codCiclo
                       AND NOT EXISTS (
                           SELECT 1 FROM romaneio r2
                           WHERE COALESCE(r2.canceladoRomaneio, 0) = 0
                             AND r2.tipoEntSaiRomaneio LIKE 'COLHEITA%'
                             AND r2.tipoRomaneio LIKE 'ENTRADA%'
                             AND r2.codSafra = cs3.codSafra
                             AND r2.codUnidadePessoaFaz = cs3.codUnidPessoaFaz
                             AND r2.codTalhao = cs3.codTalhao
                             AND r2.codProdutoCultura = cs3.codProdutoCultura
                             AND r2.codCiclo = cs3.codCiclo
                             AND r2.codProdutoCultivar = cs3.codProdutoCultivar
                       )
                 )
            WHERE s.dataInicial >= '2000-01-01'
              AND t.nomeTalhao IS NOT NULL AND TRIM(t.nomeTalhao) <> ''
              AND p.nomeProduto IS NOT NULL AND TRIM(p.nomeProduto) <> ''
            GROUP BY s.nomeSafra, u.nomeUnidPessoa, t.nomeTalhao, p.nomeProduto, c.nomeCiclo, pc.nomeProduto";

                try
                {
                    using (var mySqlConn = new MySqlConnection(connStringERP))
                    {
                        baseDados = (await mySqlConn.QueryAsync<ProducaoPublicaViewModel>(sqlMysql)).ToList();
                    }
                }
                catch (MySqlException)
                {
                    ViewBag.ErroBanco = "Não foi possível carregar os dados de produção no momento. Tente novamente em instantes.";
                }
                catch (Exception)
                {
                    ViewBag.ErroBanco = "Ocorreu um erro inesperado ao buscar os dados.";
                }
            }

            // Mesmo critério da tela interna (ProducaoController): a FAIXA de cultivar conta
            // como colhida se tem romaneio próprio OU está fechada no ERP. A flag é o que
            // faz o % Colhido fechar em quem encerra sem romaneio — braquiária (pastagem) e
            // faixas pesadas junto da vizinha ('TESTE DE VARIEDADES', 'A DEFINIR'). Faixa sem
            // romaneio e sem flag é colheita parcial e fica fora.
            foreach (var item in baseDados)
            {
                item.AreaColhida = item.ColheitaFechada || item.TotalProduzidoSacas > 0
                    ? item.AreaPlantada
                    : 0m;
                item.Produtividade = item.AreaPlantada > 0
                    ? item.TotalProduzidoSacas / item.AreaPlantada
                    : 0m;
            }

            var query = baseDados.AsQueryable();

            if (!string.IsNullOrEmpty(safra))
                query = query.Where(x => x.Safra == safra);

            ViewBag.SafrasDisponiveis = baseDados.Select(x => x.Safra).Where(x => !string.IsNullOrEmpty(x)).Distinct().OrderByDescending(x => x).ToList();

            ViewBag.CiclosDisponiveis = query.Select(x => x.Ciclo).Where(x => !string.IsNullOrEmpty(x)).Distinct().OrderBy(x => x).ToList();
            if (!string.IsNullOrEmpty(ciclo))
                query = query.Where(x => x.Ciclo == ciclo);

            ViewBag.FazendasDisponiveis = query.Select(x => x.Fazenda).Where(x => !string.IsNullOrEmpty(x)).Distinct().OrderBy(x => x).ToList();
            if (!string.IsNullOrEmpty(fazenda))
                query = query.Where(x => x.Fazenda == fazenda);

            ViewBag.CulturasDisponiveis = query.Select(x => x.Cultura).Where(x => !string.IsNullOrEmpty(x)).Distinct().OrderBy(x => x).ToList();
            if (!string.IsNullOrEmpty(cultura))
                query = query.Where(x => x.Cultura == cultura);

            // Cultivar — dependente da cultura
            ViewBag.CultivaresDisponiveis = query.Select(x => x.Cultivar).Where(x => !string.IsNullOrEmpty(x)).Distinct().OrderBy(x => x).ToList();
            if (!string.IsNullOrEmpty(cultivar))
                query = query.Where(x => x.Cultivar == cultivar);

            var listaFiltrada = query.OrderBy(x => x.Fazenda).ThenBy(x => x.Talhao).ToList();

            ViewBag.SafraAtual = safra;
            ViewBag.SafraSelecionada = safra;
            ViewBag.CicloSelecionado = ciclo;
            ViewBag.FazendaSelecionada = fazenda;
            ViewBag.CulturaSelecionada = cultura;
            ViewBag.CultivarSelecionada = cultivar;

            // ===== Cards e gráficos: talhões colhidos =====
            // AreaColhida por linha já carrega a regra por talhão (loop acima) — linha com
            // AreaColhida > 0 pertence a talhão colhido, mesmo sem romaneio próprio.
            var colhidos = listaFiltrada.Where(x => x.AreaColhida > 0).ToList();

            decimal areaPlantadaTotal = listaFiltrada.Sum(x => x.AreaPlantada);
            decimal areaColhida = colhidos.Sum(x => x.AreaPlantada);
            decimal producaoTotalSc = listaFiltrada.Sum(x => x.TotalProduzidoSacas);
            decimal producaoColhidaSc = colhidos.Sum(x => x.TotalProduzidoSacas);

            ViewBag.AreaTotal = areaPlantadaTotal;
            ViewBag.AreaColhida = areaColhida;
            ViewBag.ProducaoTotalSc = producaoTotalSc;
            ViewBag.ProducaoColhidaSc = producaoColhidaSc;

            ViewBag.PercentualColhido = areaPlantadaTotal > 0
                ? (areaColhida / areaPlantadaTotal) * 100m : 0m;

            ViewBag.ProdutividadeGeral = areaPlantadaTotal > 0
                ? producaoTotalSc / areaPlantadaTotal : 0m;

            ViewBag.ProdutividadeColhida = areaColhida > 0
                ? producaoColhidaSc / areaColhida : 0m;

            // Gráficos usam o mesmo conjunto
            var dadosGrafico = colhidos;

            // Por Talhão: consolida cultivares do mesmo talhão. Σprodução ÷ Σárea.
            var dadosPorTalhao = dadosGrafico
                .GroupBy(x => new { x.Talhao, x.Cultura })
                .Select(g => new
                {
                    Talhao = g.Key.Talhao,
                    Cultura = g.Key.Cultura,
                    Produtividade = g.Sum(x => x.AreaPlantada) > 0
                        ? g.Sum(x => x.TotalProduzidoSacas) / g.Sum(x => x.AreaPlantada)
                        : 0m
                })
                .OrderBy(x => x.Talhao)
                .ToList();

            ViewBag.ChartTalhoes = dadosPorTalhao.Select(x => $"{x.Talhao} ({x.Cultura})").ToList();
            ViewBag.ChartProdutividades = dadosPorTalhao.Select(x => x.Produtividade).ToList();

            // Por Cultivar: mesma regra Σprodução ÷ Σárea. Faixas sem romaneio próprio ficam
            // de fora — o grão delas foi pesado na cultivar vizinha (barra zerada só distorce).
            var dadosPorCultivar = dadosGrafico
                .Where(x => x.TotalProduzidoSacas > 0)
                .GroupBy(x => string.IsNullOrEmpty(x.Cultivar) ? "(SEM CULTIVAR)" : x.Cultivar)
                .Select(g => new
                {
                    Cultivar = g.Key,
                    Produtividade = g.Sum(x => x.AreaPlantada) > 0
                        ? g.Sum(x => x.TotalProduzidoSacas) / g.Sum(x => x.AreaPlantada)
                        : 0m
                })
                .OrderByDescending(x => x.Produtividade)
                .ToList();

            ViewBag.ChartCultivares = dadosPorCultivar.Select(x => x.Cultivar).ToList();
            ViewBag.ChartCultivarProdutividades = dadosPorCultivar.Select(x => x.Produtividade).ToList();

            return View(listaFiltrada);
        }
    }
}
