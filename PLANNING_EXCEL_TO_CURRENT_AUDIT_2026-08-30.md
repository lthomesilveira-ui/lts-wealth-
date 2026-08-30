# LTS Wealth — Auditoria Planejamento Excel → motor atual — 2026-08-30

Status: **ABERTA / P0, ponte material avançada**. Nenhuma conclusão financeira nova deve ser promovida a regra de negócio até esta ponte fechar.

## Por que esta auditoria existe

Na homologação real de 30/08/2026, o usuário voltou a apontar uma inconsistência material: na leitura que fazia no Excel, o horizonte após considerar RSUs e FGTS não mostrava falta real de recursos, enquanto o motor atual sinaliza um cruzamento negativo em janeiro/2027. O fato de os gates internos passarem prova consistência do motor atual com suas próprias entradas; **não prova paridade econômica com o Excel nem prova que as premissas carregadas são as mesmas**.

Portanto, `08/01/2027` e `R$ -21.046,80` permanecem resultados do motor atual sob a camada de RSUs programadas. **Não devem ser chamados de “falta real de dinheiro” na UX enquanto esta auditoria estiver aberta.**

## Evidência atual do motor

Consulta direta a `lts_dashboard_cash_ladder_v2` para 30/08/2026–28/02/2027, por mínimo mensal:

| Mês | Caixa | +D0/D1 | +RSU vested | +RSUs programadas | +FGTS estático* |
|---|---:|---:|---:|---:|---:|
| 2026-08 | 4.766,99 | 47.609,58 | 80.381,88 | 80.381,88 | 97.890,93 |
| 2026-09 | -37.469,94 | 5.372,65 | 38.144,95 | 38.144,95 | 55.654,00 |
| 2026-10 | -67.810,86 | -24.968,27 | 7.804,03 | 7.804,03 | 25.313,08 |
| 2026-11 | -88.560,10 | -45.717,51 | -12.945,21 | 8.364,53 | 25.873,58 |
| 2026-12 | -113.228,58 | -70.385,99 | -37.613,69 | 1.443,24 | 18.952,29 |
| 2027-01 | -135.718,62 | -92.876,03 | -60.103,73 | **-21.046,80** | **-3.537,75** |
| 2027-02 | -105.797,48 | -62.954,89 | -30.182,59 | 8.874,34 | 26.383,39 |

\* `balance_with_fgts` é uma camada contrafactual que soma o saldo de FGTS. Ela **não significa caixa automaticamente disponível antes do prazo de saque**. FGTS permanece contingência ~D+30.

## Âncoras atuais

- Cofrinho Itaú: **R$42.842,59**, posição 27/08/2026, D+0.
- RSU vested / Organon Long Share Holdings: **R$32.772,30**, posição 18/08/2026, D+3.
- FGTS Organon: **R$17.509,05**, posição 18/08/2026, restrito / contingência ~D+30.
- Caixa bancário: derivado das âncoras bancárias atuais + fatos/projeções efetivos.

## O Excel antigo efetivamente mostrava sem RSUs

A aba `Fluxo Negativo` do `Controle_Financeiro_Fase1_Compactado.xlsx` recuperou a série mensal `Saldo Ex RSUs` de 2026:

| Mês | Saldo Ex RSUs no Excel |
|---|---:|
| Jan | R$34.632,90 |
| Fev | R$8.295,33 |
| Mar | R$-1.794,36 |
| Abr | R$82.943,24 |
| Mai | R$82.556,02 |
| Jun | R$95.126,22 |
| Jul | R$55.813,48 |
| Ago | R$26.600,57 |
| Set | R$1.714,42 |
| Out | R$-31.194,26 |
| Nov | R$-51.881,67 |
| Dez | **R$-78.668,59** |

Conclusão parcial segura: **o Excel já ficava negativo sem RSUs**. Portanto a lembrança do usuário é compatível com a evidência e deve ser testada no cenário que adicionava RSUs/FGTS — não contra o cenário `Saldo Ex RSUs`.

O workbook também preserva os blocos `Saldo Ex FGTS`, `Saldo Total` e `Saldo Futuro`, mas os valores calculados dessas linhas estão vazios no cache recuperável do arquivo. Os rótulos são evidência; os números não serão reconstruídos por hipótese.

## Ponte operacional: Excel importado x motor atual

Foi comparado o `evento_base` legado com `lts_corrected_cashflow_operational_v1` para set/2026–jan/2027. A comparação é de fluxo operacional do período e não substitui a ponte de saldos/ativos.

| Mês | Líquido legado | Líquido atual | Delta atual − legado |
|---|---:|---:|---:|
| Set/2026 | R$-30.735,13 | R$-42.226,83 | **R$-11.491,70** |
| Out/2026 | — | — | **R$+2.592,03** |
| Nov/2026 | — | — | **R$-96,21** |
| Dez/2026 | — | — | **R$+2.127,06** |
| Jan/2027 | — | — | **R$+314,13** |

Delta acumulado set→jan: aproximadamente **R$-6.554,69**. A piora operacional relativa ao plano legado está fortemente concentrada em setembro; outubro, dezembro e janeiro são favoráveis ao motor atual e novembro é praticamente neutro.

### Ponte detalhada de setembro/2026

Principais diferenças documentadas, após neutralizar simples renomes:

- Visa Aeternum: legado ~R$-12.523,13 → atual R$-17.967,48: **~R$-5.444,35** pior.
- Mastercard/Personnalité: legado ~R$-8.457,38 → atual R$-9.589,03: **~R$-1.131,65** pior.
- Benjamin Educação: legado R$-5.912,00 → atual R$-10.837,00: **R$-4.925,00** pior.
- Fisioterapia Larissa + reembolso: efeito líquido atual ~R$-585,00 versus ausência/efeito diferente na projeção antiga: **~R$-585,00** pior.
- Financiamento CIPÓ: diferença pequena, ~**R$-157,52** pior.
- Volvo: parcela + seguro atuais têm efeito ~**R$464,62 favorável** versus a antiga linha de compra/carro na comparação do período.
- C6: ~**R$214,08 favorável**.
- Salário + Coopharma: ~**R$73,12 favorável**.

A soma explica materialmente o delta mensal sem exigir uma hipótese de “nova regra” genérica.

## Coopharma: hipótese de duplo débito descartada

A auditoria verificou o tratamento atual e a referência FIX86:

- O legado tinha `Salário` +R$10.300 e `Pagamento Novo Coopharma` -R$4.451,02.
- O motor atual possui uma linha econômica `economic_withholding`/Folha e, na visão operacional, **a incorpora ao salário líquido e remove a linha separada**.
- A regra FIX86 original certifica `Coopharma econômico sem segundo débito bancário`.

Portanto **Coopharma não explica a deterioração como novo débito duplicado**. A semântica atual preserva um único efeito econômico.

## RSUs futuras: também não explicam a piora

Evidência antiga recuperada para novembro/2026:

- RSU 05/11/2026: ~R$21.060,49.
- RSU 07/11/2026: ~R$16.765,26.
- Total antigo aproximado: **R$37.825,75**.

Schedule atual ativo:

- RSU 05/11/2026 + D+3: **R$21.745,98**, `gross_only`.
- RSU 07/11/2026 + D+3: **R$17.310,95**, `gross_only`.
- Total atual: **R$39.056,93**.

O total atual é ~**R$1.231,18 maior** que o recuperado do plano antigo. Logo os vestings futuros de novembro, isoladamente, não explicam por que o cenário atual piorou.

## Pontos que agora concentram a investigação

### 1. RSU já vested / realizável

Há evidência antiga em julho/2026 em torno de **R$51.437,69** para RSU vested, contra **R$32.772,30** na posição atual de 18/08/2026 — diferença aproximada de **R$18.665,39**.

Isso é material, mas **não autoriza concluir bug**: o valor pode ter sido vendido, consumido, reprecificado ou substituído por uma posição posterior. A ponte precisa explicar a movimentação documentalmente antes de usar a diferença como causa.

### 2. FGTS

O motor atual usa posição documentada **R$17.509,05** e prazo ~D+30. O Excel contém referência histórica de FGTS e os blocos `Saldo Ex FGTS` / `Saldo Total`, mas o cache calculado dessas fórmulas não foi recuperado de forma suficiente. A semântica e a data-base do valor antigo ainda precisam fechar.

### 3. Saldo inicial / data-base

A comparação mensal de eventos explica apenas cerca de R$6,55 mil de piora acumulada set→jan. Ela **não é suficiente para explicar sozinha** a diferença entre a lembrança do Excel pós-RSU/FGTS e o cruzamento atual. A ponte de posição inicial, RSU vested e FGTS continua sendo o bloco mais relevante.

### 4. Janeiro/2027 é intramês

O motor atual cruza zero antes de entradas relevantes do fim do mês e volta a ficar positivo em fevereiro. Portanto o diagnóstico precisa distinguir:

- falta estrutural de patrimônio;
- necessidade temporária de liquidez / funding intramês;
- gap ainda não conciliado entre planilha e motor.

Até o fechamento desta auditoria, a UX deve usar **“ponto do motor em auditoria”**, não “primeiro aperto real” ou “falta real”.

## Liquidez futura posterior

Cash Award 18/02/2027 + D+3: bruto **R$198.145,97** / líquido estimado **R$138.702,18**. Por ocorrer depois do ponto de janeiro, não pode ser antecipado para eliminá-lo.

## Próxima ponte obrigatória

1. Explicar RSU vested de ~R$51,4 mil antiga → R$32,8 mil atual por eventos/posição documental.
2. Fechar a semântica/data-base do FGTS antigo versus R$17,5 mil atual.
3. Produzir uma ponte de posição: `posição antiga + deltas de fluxo + deltas de ativos = posição atual`.
4. Classificar cada diferença como `fato posterior`, `mudança documental`, `timing`, `projeção substituída`, `duplicidade`, `bug` ou `não resolvido`.
5. Recalcular o horizonte apenas depois disso.
6. Se a ponte fechar, explicar por que o ponto mudou. Se não fechar, corrigir o modelo antes de homologar Planejamento.
7. Criar gate regressivo permanente Excel→motor para a janela reconciliada.

## UX de Planejamento durante a auditoria

A referência de informação é a visão executiva antiga já recuperada no projeto:

- `Planejamento de liquidez — não falta patrimonial` quando aplicável;
- recursos disponíveis hoje;
- Cofrinho D+0;
- RSUs vested D+3;
- RSUs futuras somente depois de vesting + liquidação;
- FGTS separado/restrito;
- `Primeiro ponto de gestão`, não linguagem alarmista;
- cenário com e sem recursos futuros lado a lado;
- poucas ações concretas.

A tela não deve expor nomes de funções, QA ou texto técnico como mensagem principal.

## Guardrails

- Fato vence projeção correspondente.
- Cenário não vira fato.
- RSU futura só entra após elegibilidade + settlement.
- FGTS é contingência ~D+30, nunca caixa automático.
- Coopharma permanece efeito econômico único, sem segundo débito bancário.
- Não inventar valor líquido de RSU, imposto, FX, merchant, classificação ou reconciliação.
- Não reinterpretar entrada/saída apenas para eliminar um gap.
- Não inferir os valores vazios de `Saldo Ex FGTS`, `Saldo Total` ou `Saldo Futuro`.
- Nenhuma promoção para `index.html` enquanto a candidata visual e esta frente P0 não estiverem em estado homologável.
