# BI agrícola — demonstração

As quatro telas de BI agrícola do portal — **Produção** (com a aba de **Romaneios**),
**Contratos de venda**, **Insumos** e **Quadro de Safras** — rodando contra um banco de dados
**fictício**, com as mesmas consultas e as mesmas regras de cálculo do sistema em produção.

```
docker compose up -d          # MySQL com o esquema e a fazenda de exemplo
dotnet run --project CeoDemoAgro
```

Depois, abra <http://localhost:5290> — a raiz redireciona para a tela de Produção já com o token
do `appsettings.json`, então não é preciso montar a URL à mão.

---

## O problema que este código resolve

### Produção — a divisão que não é uma divisão

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

### Contratos — quanto ainda se deve entregar

Aqui a conta parece ainda mais simples: contratado menos entregue. Três coisas atrapalham, e
nenhuma delas está no schema — são regras de negócio que só se descobrem lendo dado real.

**A carga é pesada duas vezes, e os dois números divergem.** Uma na origem, outra no destino;
a diferença é a quebra de transporte. Qual dos dois vale não é decisão do romaneio: está no
**contrato**, numa coluna de texto livre que às vezes diz "PESO DESTINO" e às vezes não diz
nada. Usar o peso errado não desloca só o total — pode zerar um saldo e fazer sumir da lista
de pendências um contrato que ainda deve grão.

**Nem toda saída é entrega.** Remessa para armazém sai da fazenda, tem romaneio, tem peso, e
não abate nada do contrato. Contá-la como entrega é dar por cumprido o que não foi.

**Devolução volta para o saldo.** O que retornou continua devendo, então a entrega é
*líquida*: saídas menos devoluções. Somar dos dois lados — ou de nenhum — desmonta a
identidade `contratado − entregue = a entregar`, e aí os três KPIs do topo param de fechar
entre si.

E o preço, quando o contrato é em moeda estrangeira, **não é o preço do contrato**: é a média
das fixações, feitas em datas e cotações diferentes ao longo da safra.

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
| T-04 | Braquiária | 50 ha | 0 | 0 | pastagem: área e custo sem colheita |

Filtrando por soja, a tela mostra **61,36 sc/ha** — que é `20.250 ÷ 330`.

A média das produtividades por linha daria 61,25. A média por talhão daria 61,00. Os três
números existem e são diferentes de propósito: se a tela mostrar um dos outros dois, a soma
ponderada virou média de razões em algum ponto do caminho.

E se a soja do T-01 aparecer perto de 170 sc/ha, a consulta deixou de amarrar a cultura e está
somando o milho junto.

O arquivo [`banco/02-dados.sql`](banco/02-dados.sql) traz a tabela de valores esperados no
rodapé, e [`banco/03-conferencia.sql`](banco/03-conferencia.sql) roda a consulta da tela direto
no MySQL, para conferir sem subir a aplicação.

### E na carteira de contratos

Cinco contratos aparecem na tela; três existem só para **não** aparecer (cancelado, contrato de
compra, e um preso a uma safra com data-lixo). Os cinco visíveis foram montados para que cada
regra, se quebrada, mude o resultado de um jeito visível:

| Contrato | O que exercita | Se a regra cair |
|---|---|---|
| CT-2025-001 | peso de **origem**, com destino divergente | saída vira 2.970 sc em vez de 3.000 |
| CT-2025-002 | peso de **destino** | saldo vira zero e o contrato some das pendências |
| CT-2025-003 | preço pela **média das fixações** | R$ 60,00/sc em vez de 72,00 — some R$ 48 mil |
| CT-2025-004 | devolução conta, **remessa não** | saldo negativo, e o contrato dá por cumprido |
| CT-2025-005 | **status explícito** ganha do saldo | vira PENDENTE com o contrato já encerrado |

Os KPIs fecham entre si: **15.000 contratados − 12.240 entregues = 2.760 a entregar**. Se os
três não fecharem, a devolução entrou de um lado só.

### E no quadro de safras

Aqui a conta é margem por cultura, e ela depende do preço médio — a parte mais escorregadia do
sistema. O valor de um contrato tem **dois termos que não podem se sobrepor**: as notas já
emitidas, e o saldo ainda não faturado. O que torna isso difícil é que **o ERP não abate o saldo
ao faturar**: a parcela paga continua com o saldo cheio, e somar os dois ingenuamente conta o
mesmo grão duas vezes.

| Se o preço da soja vier | O que quebrou |
|---|---|
| 179,78 | o saldo não foi abatido pelo que já virou nota — 50% de inflação |
| 129,78 | o adiantamento entrou como receita (é o mesmo dinheiro, por encontro de contas) |
| 120,54 | o adiantamento não foi descontado do saldo, deixando resíduo fantasma |
| 122,24 | a devolução somou em vez de subtrair |
| **119,784** | **certo** |

E o milho a 68,40 em vez de 70,80 denuncia outra coisa: a cotação do dólar foi buscada sem teto
de data, e veio a linha com **ano 3905** que a base real tem.

O quadro também mostra por que **braquiária fica fora por padrão**. É pastagem: ocupa 50 ha,
consome R$ 60 mil de custo e não produz saca nenhuma. Marcando o checkbox, a receita bruta não
muda em um centavo e a margem operacional cai de **158,4% para 146,5%**.

### E em insumos

A tela responde "quanto a lavoura pagou de insumo, em sacas". O talhão **T-01** existe para
exercitar as três regras de uma vez: ele tem soja e milho na mesma safra.

| A regra | Se cair, o T-01 mostra |
|---|---|
| converter pelo preço da **própria cultura** | 23,79 sc/ha em vez de **31,01** — 23% a menos, no talhão mais caro |
| dividir pela área **plantada** (200 ha), não a física (100) | R$ 5.700/ha em vez de **2.850,00** — o dobro |
| trocar sobre a produtividade **colhida** | a relação de troca deixa de ser 36,49% |

A braquiária exercita o resto do caminho: sem contrato, ela não tem preço próprio, e o custo em
sacas cai no preço **geral** da safra — `(1.197.840 + 354.000) ÷ 15.000 = 103,456 R$/sc`. A
relação de troca dela é 0%: não há colheita para trocar.

---

## O que este projeto NÃO é

**Não é o sistema.** É o portal dele, com dados inventados. O sistema real sincroniza vários
clientes, resolve escopo por grupo e empresa, controla acesso, gera e revoga os links, e tem
todo um lado financeiro — integração com a Conta Azul, fluxo de caixa, plano de contas. Nada
disso está aqui.

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
  01-esquema.sql               23 tabelas — o recorte do ERP que estas telas leem
  02-dados.sql                 a fazenda fictícia, com os valores esperados
  03-conferencia.sql           a consulta de Produção, para rodar direto no MySQL
  04-dados-contratos.sql       a carteira fictícia, com os valores esperados
  05-conferencia-contratos.sql a consulta de Contratos
  06-dados-quadro.sql          custo, faturamento e a simulação projetada
  07-conferencia-quadro.sql    as duas consultas do Quadro de Safras
  08-conferencia-insumos.sql   o dado bruto de Insumos (o cálculo é em C#)
CeoDemoAgro/
  Controllers/          as actions, cópia das que estão em produção
  Services/             preço médio e o BI de Insumos, cópia
  Views/Publico/        as telas, cópia
  Views/Shared/         o layout do portal, cópia
docker-compose.yml      MySQL 8 na porta 3307, seed na primeira subida
```

O esquema é **um arquivo só** porque as telas compartilham tabelas: `safra`, `produto` e
`romaneio` servem às duas. O `romaneio`, aliás, é a mesma linha lida de dois jeitos — na
Produção é colheita, nos Contratos é entrega —, e separar o esquema por tela obrigaria a
decidir de quem ele é.

São **três** as diferenças em relação ao sistema real, e vale enumerá-las porque a fidelidade é
o argumento deste repositório.

**1. De onde vem a string de conexão.** Em produção o token está numa tabela e leva a um
identificador de grupo, que nomeia a string `ClienteConnection_{id}`. Aqui o token e o grupo
estão no `appsettings.json`, e o resto do caminho é o mesmo — inclusive o nome da string.

**2. Onde moram as simulações** (só no Quadro de Safras). O "Projetado" vive, em produção, no
SQL Server do sistema, porque é trabalho da consultoria e não dado do ERP. Aqui está no mesmo
MySQL, para o demo não exigir dois bancos — muda o tipo da conexão e o `'%' + @cliente + '%'`
do SQL Server, que em MySQL é `CONCAT`.

**3. Um filtro que ficou de fora** (só em Insumos). O original esconde a categoria
`INSUMOS CORRETIVO` de todo o BI — um filtro temporário, posto para uma apresentação e marcado
para sair depois. Não veio junto, e a razão é o próprio propósito deste repositório: ele suprime
dado **em silêncio**, fazendo o custo por hectare aparecer menor do que é, sem nada na tela
dizendo isso. Em produção, com quem o pôs por perto, é uma decisão reversível; aqui seria uma
regra escondida que o leitor não teria como descobrir.

Há ainda uma troca sem efeito sobre número nenhum: uma chamada de log do Serilog virou escrita
no `stderr`, para o demo não carregar a dependência inteira por uma linha. O aviso continua
existindo — engoli-lo faria a tela mostrar custo em sacas calculado sobre o preço de último
recurso, sem dizer.

Fora isso, o corpo das actions não tem uma linha alterada.

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
