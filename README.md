# BI agrícola — demonstração

Duas telas de BI agrícola — **Produção** e **Contratos de venda** — rodando contra um banco de
dados **fictício**, com as mesmas consultas e as mesmas regras de cálculo do sistema em produção.

```
docker compose up -d          # MySQL com o esquema e a fazenda de exemplo
dotnet run --project CeoDemoAgro
```

Depois, abra <http://localhost:5290>.

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

---

## O que este projeto NÃO é

**Não é o sistema.** São duas telas dele, com dados inventados. O sistema real sincroniza vários
clientes, resolve escopo por grupo e empresa, controla acesso, e o portal tem quatro telas mais
todo um lado financeiro. Nada disso está aqui.

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
  01-esquema.sql               13 tabelas — o recorte do ERP que estas telas leem
  02-dados.sql                 a fazenda fictícia, com os valores esperados
  03-conferencia.sql           a consulta de Produção, para rodar direto no MySQL
  04-dados-contratos.sql       a carteira fictícia, com os valores esperados
  05-conferencia-contratos.sql a consulta de Contratos
CeoDemoAgro/
  Controllers/          as actions, cópia das que estão em produção
  Views/Publico/        as telas, cópia
  Views/Shared/         o layout do portal, cópia
docker-compose.yml      MySQL 8 na porta 3307, seed na primeira subida
```

O esquema é **um arquivo só** porque as telas compartilham tabelas: `safra`, `produto` e
`romaneio` servem às duas. O `romaneio`, aliás, é a mesma linha lida de dois jeitos — na
Produção é colheita, nos Contratos é entrega —, e separar o esquema por tela obrigaria a
decidir de quem ele é.

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
