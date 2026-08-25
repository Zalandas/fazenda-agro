using System.Globalization;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllersWithViews();

var app = builder.Build();

// pt-BR fixado, como no sistema real: data e decimal em formato brasileiro em
// toda a pilha. Sem isso a tela mostra 61.36 onde deveria mostrar 61,36.
var ptBr = new CultureInfo("pt-BR");
app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new Microsoft.AspNetCore.Localization.RequestCulture(ptBr),
    SupportedCultures = new List<CultureInfo> { ptBr },
    SupportedUICultures = new List<CultureInfo> { ptBr }
});

app.UseStaticFiles();
app.UseRouting();
app.MapControllers();

// A raiz leva direto ao demo: quem abre o endereço não deveria precisar saber
// o token de cor.
app.MapGet("/", (IConfiguration cfg) =>
    Results.Redirect($"/p/producao/{cfg["Demo:Token"]}"));

app.Run();
