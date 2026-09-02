# LTS Wealth — Auditoria Planejamento Excel → motor atual — 2026-08-30

Status: **ENCERRADA para o bloqueio P0 atual / ponte econômica explicada e regressão permanente criada.** A lacuna histórica das células calculadas vazias do Excel permanece registrada, mas não bloqueia a leitura atual porque o ponto material de janeiro foi explicado por dados e regras já existentes, sem inventar premissas.

## Conclusão executiva

O `08/01/2027` não deve ser apresentado como “falta real de dinheiro”. Ele é o **primeiro ponto de gestão** em que caixa + Cofrinho + RSU vested + vestings programados cruzam zero antes de acionar a contingência FGTS.

A causa técnica do falso diagnóstico mais alarmista foi identificada: o motor já projetava corretamente os créditos mensais de FGTS em `lts_flow_dynamic_layers_v1`, porém a antiga escada de liquidez somava uma âncora estática de **R$17.509,05** em vez do saldo de FGTS projetado por data.

Aplicando a regra já confirmada pelo usuário — FGTS acessível em necessidade com aproximadamente **D+30** — a leitura conservadora usa apenas o saldo que já estará projetado na **data-limite de solicitação**, sem contar contribuições posteriores:

- Primeiro ponto de gestão: **08/01/2027**.
- Solicitar FGTS até: **09/12/2026**.
- FGTS documentado em 18/08/2026: **R$17.509,05**.
- Acréscimo mensal já existente no motor: **R$3.700,00**.
- FGTS projetado em 09/12/2026: **R$32.309,05**.
- FGTS projetado em 08/01/2027: **R$36.009,05**.
- Pior saldo antes da contingência: **R$-21.046,80**.
- Pior saldo após usar somente o saldo conservador disponível na data do pedido: **R$+11.262,25**.
- Primeiro gap não coberto após a contingência no horizonte até 28/02/2027: **nenhum**.

Portanto a classificação correta, no horizonte auditado, é **ponto de gestão de liquidez coberto por FGTS D+30 se solicitado no prazo**, e não insuficiência patrimonial.

## O que o Excel antigo efetivamente mostrava

A aba `Fluxo Negativo` do `Controle_Financeiro_Fase1_Compactado.xlsx` preserva a série `Saldo Ex RSUs` de 2026. Ela já terminava dezembro negativa em **R$-78.668,59**. Logo o Excel antigo também dependia de RSUs/FGTS para a leitura final de liquidez; comparar o cenário atual com “Saldo Ex RSUs” nunca seria uma comparação econômica equivalente.

O workbook preserva os rótulos `Saldo Ex FGTS`, `Saldo Total` e `Saldo Futuro`, mas o cache recuperado não contém os valores calculados dessas células. Esses números **não foram reconstruídos por hipótese**. Essa lacuna permanece registrada como limitação histórica não bloqueante.

## Ponte RSU fechada

A diferença entre uma posição antiga de RSU vested em torno de R$51,4 mil e a posição atual em torno de R$32,8 mil não é dinheiro desaparecido.

Evidência documental recuperada:

- A trilha histórica de `liq_rsu_vested` registra **459,483 unidades disponíveis** após uma **baixa de 283 unidades por venda liquidada em 05/08/2026**.
- O caixa líquido documentado dessa venda é **R$19.095,04**.
- O evento de 05/08/2026 registra `Realização de investimento — venda de ações` por **R$19.095,04**.
- No mesmo circuito há transferência C6 → Bradesco do mesmo valor, preservando a trilha bancária.
- A posição atual `Organon Long Share Holdings`, de 18/08/2026, mantém **459,483 unidades** e valor de **R$32.772,30**, D+3.
- A posição anterior implícita era aproximadamente **742,483 unidades** antes da baixa de 283.

O bruto teórico documentável pela combinação 283 × preço × FX é maior que o caixa líquido em cerca de **R$578,68**; a origem exata dessa diferença não foi inferida porque impostos/taxas não estão itemizados de forma suficiente.

Conclusão: **a redução de RSU vested é explicada materialmente por venda documentada e mudança de preço/FX**, não por perda de rastreabilidade.

## Ponte FGTS fechada

Também foi localizada a referência histórica de **R$25.585,03** do Excel:

- 07/05/2026: entrada `FGTS` de **R$25.585,03** no Itaú.
- 07/05/2026: saída `investimentos itaú` de **R$25.000,00** no mesmo dia.

Isso prova que o valor histórico do Excel corresponde a um **saque de FGTS que virou caixa e em seguida investimento**, enquanto a posição atual de **R$17.509,05** é outro estado temporal, posterior, do FGTS Organon. Os dois valores não devem ser tratados como um único saldo estático.

O motor dinâmico já possuía o crescimento mensal do FGTS:

| Data | FGTS projetado |
|---|---:|
| 30/08/2026 | R$21.209,05 |
| 30/09/2026 | R$24.909,05 |
| 31/10/2026 | R$28.609,05 |
| 30/11/2026 | R$32.309,05 |
| 31/12/2026 | R$36.009,05 |
| 08/01/2027 | R$36.009,05 |
| 31/01/2027 | R$39.709,05 |
| 28/02/2027 | R$43.409,05 |

O defeito estava na **ligação da escada de Planejamento à posição estática**, não na ausência da projeção mensal.

## Delta de fluxo Excel → atual

A ponte de eventos entre setembro/2026 e janeiro/2027 já havia mostrado deterioração líquida acumulada de aproximadamente **R$6,55 mil** contra a projeção antiga, fortemente concentrada em setembro. Principais drivers documentados daquele mês:

- Visa Aeternum: ~R$5,44 mil pior.
- Mastercard/Personnalité: ~R$1,13 mil pior.
- Benjamin Educação: R$4,925 mil pior.
- Fisioterapia Larissa + reembolso: ~R$585 pior.
- Financiamento CIPÓ: ~R$158 pior.
- Volvo, C6 e salário/Coopharma compensam parte da deterioração.

Esse delta continua válido, mas **não explicava sozinho** o diagnóstico de janeiro. A ponte de posição RSU/FGTS era o componente faltante.

## Coopharma e RSUs futuras

Duas hipóteses foram descartadas durante a auditoria:

- **Coopharma não está duplicado.** O motor incorpora o desconto econômico ao salário líquido e remove o segundo débito bancário, preservando a regra FIX86.
- **RSUs futuras de novembro não pioraram o cenário.** O schedule atual documentado é até ligeiramente superior à referência antiga recuperada; portanto não é a causa do gap.

## Correção implementada em paralelo

Foi criada uma nova ponte de Planejamento sem alterar as regras canônicas anteriores nem promover o fallback público:

- `lts_dashboard_cash_ladder_from_flow_v2`.
- `lts_planning_liquidity_ladder_from_flow_v2` — versão `planning-liquidity-ladder-v5-fgts-d30-projected-conservative`.
- `lts_planning_bridge_executive_v1`.
- `lts_browser_planning_bridge_executive_v1` autenticado; anon bloqueado.

Semântica nova da leitura:

1. Caixa.
2. Cofrinho / D+0-D+1.
3. RSU vested / realizável.
4. Vestings futuros somente após elegibilidade + settlement.
5. FGTS restrito D+30, acionado apenas quando o prazo permite.

A cobertura FGTS é propositalmente conservadora: **usa o saldo projetado existente na data-limite do pedido, não o saldo maior que existirá no dia do gap**.

## Gates

Foi criado `lts_planning_excel_bridge_qa_v1` com **19/19 checks PASS**, cobrindo:

- ponto de gestão em 08/01/2027;
- ausência de gap não coberto após FGTS planejado;
- solicitação até 09/12/2026;
- FGTS atual e projetado;
- pior saldo antes/depois;
- saque FGTS histórico de R$25.585,03;
- aplicação Itaú no mesmo dia de R$25.000;
- venda RSU de R$19.095,04;
- posição atual de 459,483 unidades;
- ACL do RPC browser.

O heavy gate foi elevado para `lts_candidate_homologation_gate_v14`: **293/293 PASS em 24 suítes**.

PASS de backend continua separado de smoke de navegador, E2E visual autenticado e homologação do usuário.

## UX correta de Planejamento

A candidata v142 passa a comunicar:

- **“Sua liquidez cobre o horizonte. Janeiro é um ponto de gestão.”**
- data de solicitação do FGTS;
- valor conservador disponível no pedido;
- pior saldo antes e depois da contingência;
- escada visual de recursos;
- ponte documental de RSU e FGTS em detalhe recolhido.

Ela não deve chamar janeiro de “primeiro aperto real” nem “falta patrimonial”.

## Lacunas históricas que permanecem abertas, mas não bloqueiam esta correção

- Valores calculados vazios nas células antigas `Saldo Ex FGTS`, `Saldo Total` e `Saldo Futuro` não podem ser reconstruídos exatamente sem um cache de cálculo válido.
- A diferença de ~R$578,68 entre bruto teórico e caixa líquido da venda de 283 RSUs não foi decomposta em imposto/taxa por falta de documento específico.
- Uma referência antiga manual de FGTS sem evidência temporal suficiente não é usada como âncora.

Nenhuma dessas lacunas altera a conclusão atual de cobertura D+30, que é sustentada por posições e projeções existentes no próprio motor.

## Guardrails permanentes

- Fato vence projeção correspondente.
- Cenário não vira fato.
- RSU futura só entra após elegibilidade + settlement.
- FGTS é contingência ~D+30, nunca caixa automático.
- Para provar cobertura, FGTS usa no máximo o saldo já projetado na data-limite de solicitação.
- Venda de RSU é realização patrimonial, não renda operacional recorrente.
- Coopharma permanece efeito econômico único.
- Não inventar imposto, taxa, FX, merchant, classificação ou reconciliação.
- Não reinterpretar entrada/saída apenas para eliminar um gap.
- Não inferir os valores vazios do Excel.
- Nenhuma promoção para `index.html` por causa desta auditoria isoladamente; a candidata precisa continuar passando seus próprios gates de navegador e homologação.
