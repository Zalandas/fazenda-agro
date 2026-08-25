namespace CeoManager.Models
{
    public class ProducaoPublicaViewModel
    {
        public string Fazenda { get; set; }
        public string Safra { get; set; }
        public string Ciclo { get; set; }
        public string Cultura { get; set; }
        public string Talhao { get; set; }
        public string Cultivar { get; set; } = "";
        public decimal AreaPlantada { get; set; }
        public decimal AreaColhida { get; set; }
        public bool ColheitaFechada { get; set; }
        public decimal TotalProduzidoSacas { get; set; }

        public decimal Produtividade { get; set; }
    }
}