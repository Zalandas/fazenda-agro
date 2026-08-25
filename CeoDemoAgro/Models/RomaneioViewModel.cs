namespace CeoManager.Models
{
    public class RomaneioViewModel
    {
        public long CodRomaneio { get; set; }
        public int? NumeroRomaneio { get; set; }
        public string NumeroNF { get; set; }
        public DateTime? DataPesagem { get; set; }

        public string Fazenda { get; set; }
        public string Talhao { get; set; }
        public string Cultura { get; set; }
        public string Safra { get; set; }
        public string Ciclo { get; set; }

        public decimal PesoBruto { get; set; }
        public decimal PesoTara { get; set; }
        public decimal PesoLiquido { get; set; }

        public string Motorista { get; set; }
        public string Placa { get; set; }

        // Conversão para sacas (60 kg), para bater com o dashboard
        public decimal Sacas => PesoLiquido / 60m;
    }
}
