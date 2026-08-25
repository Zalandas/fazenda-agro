# Fluxo de produção agrícola — demonstração

Tela de BI de produção agrícola rodando contra um banco de dados **fictício**, com a mesma
consulta e as mesmas regras de cálculo do sistema em produção.

```
docker compose up -d          # MySQL com o esquema e a fazenda de exemplo
dotnet run --project CeoDemoAgro
```

Depois, abra <http://localhost:5290>.

---

## O problema que este código resolve

Calcular produtividade agrícola parece uma divisão: sacas colhidas sobre hectares plantados. O
que torna difícil é que **nenhuma das duas pontas vem pronta**.

A colheita chega em romaneios — cargas de caminhão pesadas na balança, em quilos. Cada um traz
safra, fazenda, talhão, cultura, cultivar e ciclo. A área plantada vem de outra tabela, com a
mesma chave de seis campos. Juntar as duas é onde mora o trabalho:

**A chave precisa fechar por inteiro, inclusive a cultura.** Um mesmo talhão pode ter soja na
primeira safra e milho na segunda. Sem amarrar a cultura, o milho soma na soja e a produtividade
quase dobra — sem erro, sem aviso, num número que parece plausível.

**O grão da consulta é o cultivar, não o talhão.** Um talhão com dois cultivares devolve duas
linhas. Qualquer visão "por talhão" precisa reagregar, e reagregar significa somar sacas, somar
área e dividir uma pela outra — nunca tirar a média das produtividades das linhas.

**Nem toda colheita casa com o plantio.** Acontece de o romaneio vir com um cultivar que não
está registrado no plantio daquele talhão. Descartar é perder colheita real; atribuir a esmo é
inventar. A consulta resgata esses órfãos por uma chave mais curta, e só quando há exatamente
um destino possível.

---

## Por que os números deste demo importam

O banco de exemplo não é enfeite. Cada linha existe para exercitar uma dessas regras, e os
valores foram escolhidos para que **o erro e o acerto deem resultados diferentes**:

| Talhão | Cultura | Área | Sacas | sc/ha | O que exercita |
|---|---|---|---|---|---|
| T-01 | Soja | 100 ha | 6.000 | 60,00 | duas culturas no mesmo talhão |
| T-01 | Milho | 100 ha | 11.000 | 110,00 | a segunda safra que não pode vazar |
| T-02 | Soja | 150 ha | 9.450 | 63,00 | dois cultivares, exige reagregar |
| T-03 | Soja | 80 ha | 4.800 | 60,00 | só um romaneio órfão, resgatado |

Filtrando por soja, a tela mostra **61,36 sc/ha** — que é `20.250 ÷ 330`.

A média das produtividades por linha daria 61,25. A média por talhão daria 61,00. Os três
números existem e são diferentes de propósito: se a tela mostrar um dos outros dois, a soma
ponderada virou média de razões em algum ponto do caminho.

E se a soja do T-01 aparecer perto de 170 sc/ha, a consulta deixou de amarrar a cultura e está
somando o milho junto.

O arquivo [`banco/02-dados.sql`](banco/02-dados.sql) traz a tabela de valores esperados no
rodapé, e [`banco/03-conferencia.sql`](banco/03-conferencia.sql) roda a consulta da tela direto
no MySQL, para conferir sem subir a aplicação.

---

## O que este projeto NÃO é

**Não é o sistema.** É uma tela dele, com dados inventados. O sistema real sincroniza vários
clientes, resolve escopo por grupo e empresa, controla acesso e mantém um portal com quatro
telas. Nada disso está aqui.

**Não é um dashboard de exemplo.** A consulta e o pós-processamento são cópia literal do que
roda em produção, sem simplificação. Uma versão enxuta seria mais fácil de ler e não provaria
nada — o interesse está justamente no que a versão enxuta cortaria.

**Não é um template.** O esquema do banco é o recorte mínimo de um ERP de terceiro, com os
nomes de tabela e coluna que ele usa. Serve para rodar esta tela, e só.

**Os dados não têm relação com cliente nenhum.** Nomes de fazenda, talhão, cultivar e todos os
números são inventados. Plano de talhões e padrão de cultivar são informação do cliente, e não
aparecem aqui nem disfarçados.

---

## Como está montado

```
banco/
  01-esquema.sql        7 tabelas — o recorte do ERP que esta tela lê
  02-dados.sql          a fazenda fictícia, com os valores esperados
  03-conferencia.sql    a consulta da tela, para rodar direto no MySQL
CeoDemoAgro/
  Controllers/          a action, cópia da que está em produção
  Views/Publico/        a tela, cópia
  Views/Shared/         o layout do portal, cópia
docker-compose.yml      MySQL 8 na porta 3307, seed na primeira subida
```

A **única** diferença em relação ao sistema real é de onde vem a string de conexão. Em produção
o token está numa tabela e leva a um identificador de grupo, que nomeia a string
`ClienteConnection_{id}`. Aqui o token e o grupo estão no `appsettings.json`, e o resto do
caminho é o mesmo — inclusive o nome da string. O corpo da action não tem uma linha alterada.

### Sem Docker

Se já houver um MySQL na máquina, dá para dispensar o compose:

```sql
CREATE DATABASE erp_demo CHARACTER SET utf8mb4;
CREATE USER 'demo'@'localhost' IDENTIFIED BY 'demo';
GRANT ALL ON erp_demo.* TO 'demo'@'localhost';
```

```bash
mysql -udemo -pdemo erp_demo < banco/01-esquema.sql
mysql -udemo -pdemo erp_demo < banco/02-dados.sql
```

Ajuste a porta em `CeoDemoAgro/appsettings.json` se não for a 3306.

---

## Documentação relacionada

As notas de campo da integração com a API do Conta Azul — a outra metade deste sistema, do lado
financeiro — estão em documento separado: dois servidores de OAuth, refresh token que rotaciona
a cada uso, categorias agrupadoras que a API não devolve, e o `data_alteracao` que não muda
quando só a categoria é trocada.

---

## Licença

MIT. Os dados de exemplo são fictícios e podem ser usados livremente.
