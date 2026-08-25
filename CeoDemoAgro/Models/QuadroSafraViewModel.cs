namespace CeoManager.Models
{
    public class CulturaProjetada
    {
        public string Safra { get; set; }
        public string Cultura { get; set; }
        public decimal AreaPlantada { get; set; }
        public decimal AreaColhida { get; set; }
        public decimal Produtividade { get; set; }
        public decimal PrecoMedio { get; set; }
        public decimal CustoProducaoHa { get; set; }
    }

    public class CulturaRealizada
    {
        public string Safra { get; set; }
        public string NomeCultura { get; set; }
        public decimal AreaPlantada { get; set; }
        public decimal ProducaoSacas { get; set; }
        public decimal CustoTotal { get; set; }
        public decimal PrecoMedioVenda { get; set; }

        // Assume que a área colhida foi igual à plantada (ajuste se tiver tabela específica de perda)
        public decimal AreaColhida { get; set; }
        public decimal CustoProducaoHa => AreaPlantada > 0 ? CustoTotal / AreaPlantada : 0;

        // --- Fórmulas Calculadas ---
        public decimal Produtividade => AreaColhida > 0 ? ProducaoSacas / AreaColhida : 0;
        public decimal ReceitaBruta => ProducaoSacas * PrecoMedioVenda;
        public decimal ReceitaLiquida => ReceitaBruta - CustoTotal;
        public decimal MargemOperacional => CustoTotal > 0 ? (ReceitaLiquida / CustoTotal) : 0;
        public decimal MargemLucratividade => ReceitaBruta > 0 ? (ReceitaLiquida / ReceitaBruta) : 0;
    }

    public class QuadroSafraViewModel
    {
        public string SafraSelecionada { get; set; }
        public List<string> SafrasDisponiveis { get; set; } = new List<string>();

        public List<CulturaRealizada> CulturasRealizadas { get; set; } = new List<CulturaRealizada>();
        public List<CulturaProjetada> SimulacoesSalvas { get; set; } = new List<CulturaProjetada>();

        public decimal AreaTotalRealizada => CulturasRealizadas.Sum(c => c.AreaPlantada);
        public decimal ReceitaBrutaRealizada => CulturasRealizadas.Sum(c => c.ReceitaBruta);
        public decimal CustoTotalRealizado => CulturasRealizadas.Sum(c => c.CustoTotal);
        public decimal ReceitaLiquidaRealizada => CulturasRealizadas.Sum(c => c.ReceitaLiquida);
        public decimal MargemOperacionalRealizada => CustoTotalRealizado > 0 ? ReceitaLiquidaRealizada / CustoTotalRealizado : 0;
    }
}