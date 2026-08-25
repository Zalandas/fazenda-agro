namespace CeoManager.Models
{
    public class InsumoDadoBruto
    {
        public string FAZENDA { get; set; }
        public string TALHAO { get; set; }
        public string CULTURA { get; set; }
        public string SAFRA { get; set; }
        public string TIPO_INSUMO { get; set; }
        public decimal HA { get; set; }
        public decimal VALOR_APLIC { get; set; } // Custo Total R$
        public decimal SACAS_COLHIDAS { get; set; } // Produtividade SC/HA vinda da Produção
    }

    public class CelulaMatrizInsumo
    {
        public decimal CustoReaisHa { get; set; } // R$/HA
        public decimal CustoSacasHa { get; set; } // SC/HA (Considerando R$ 60/Saca ou Preço Base)
        public decimal RelacaoTroca { get; set; } // % (CustoSacasHa / SACAS_COLHIDAS)
    }

    public class InsumosBiViewModel
    {
        public decimal ValorTotalAplicacoes { get; set; }
        public decimal CustoMedioReaisHa { get; set; }
        public decimal CustoMedioSacasHa { get; set; }
        public decimal RelacaoTrocaMedia { get; set; }

        public List<string> ColunasTalhoes { get; set; } = new List<string>();
        public Dictionary<string, decimal> AreasTalhoes { get; set; } = new Dictionary<string, decimal>();

        public Dictionary<string, Dictionary<string, CelulaMatrizInsumo>> MatrizPivot { get; set; }
            = new Dictionary<string, Dictionary<string, CelulaMatrizInsumo>>();

        public Dictionary<string, CelulaMatrizInsumo> TotaisPorTalhao { get; set; }
            = new Dictionary<string, CelulaMatrizInsumo>();

        public List<string> ChartLabelsTalhoes { get; set; } = new List<string>();
        public List<decimal> ChartCustoSacas { get; set; } = new List<decimal>();
        public List<decimal> ChartRelacaoTroca { get; set; } = new List<decimal>();
    }
}