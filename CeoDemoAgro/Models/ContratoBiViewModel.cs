namespace CeoManager.Models
{
    public class ContratoBiViewModel
    {
        public string SAFRA { get; set; }
        public string CULTURA { get; set; }
        public string CONTRATO { get; set; }
        public string TIPO { get; set; }
        public string CLIENTE { get; set; }
        public string MOEDA { get; set; }
        public decimal QNT_SC { get; set; }
        public decimal? PRECO_USD { get; set; }
        public decimal? TOTAL_USD { get; set; }
        public decimal PRECO_RS { get; set; }
        public decimal TOTAL_RS { get; set; }
        public DateTime? DATA_EMISSAO { get; set; }
        public DateTime? DATA_ENTREGA { get; set; }
        public DateTime? DATA_PGTO { get; set; }
        public string FRETE { get; set; }
        public decimal SAIDA_SC { get; set; }
        public decimal ENTRADA_SC { get; set; }
        public decimal SALDO_SC { get; set; }
        public string STATUS { get; set; }

        // Propriedades calculadas auxiliares para os cards do BI
        public decimal VolumePendente => STATUS == "PENDENTE" ? SALDO_SC : 0;
        public decimal ReceitaRealizada => MOEDA == "REAL" ? (SAIDA_SC * PRECO_RS) : (SAIDA_SC * (PRECO_USD ?? 0));
    }
}