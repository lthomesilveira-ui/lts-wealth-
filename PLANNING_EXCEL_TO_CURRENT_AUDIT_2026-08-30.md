# LTS Wealth — Auditoria Planejamento Excel → motor atual — 2026-08-30

Status: **ABERTA / P0**. Nenhuma conclusão financeira nova deve ser promovida a regra de negócio até esta ponte fechar.

## Por que esta auditoria existe

Na homologação real de 30/08/2026, o usuário voltou a apontar uma inconsistência material: na leitura que fazia no Excel, o horizonte após considerar RSUs e FGTS não mostrava falta real de recursos, enquanto o motor atual sinaliza primeiro gap em janeiro/2027. O fato de os gates internos passarem prova consistência do motor atual com suas próprias entradas; **não prova paridade econômica com o Excel nem prova que as premissas carregadas são as mesmas**.

Portanto, `08/01/2027` e `R$ -21.046,80` permanecem resultados do motor atual, mas ficam sob auditoria de ponte antes de serem tratados como conclusão financeira definitiva na UX.

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

\* A coluna atual `balance_with_fgts` é uma camada contrafactual que soma o saldo de FGTS; ela **não deve ser lida como caixa automaticamente disponível antes do prazo de saque**. O planejamento separado registra FGTS como contingência ~D+30. Esta semântica precisa permanecer explícita.

## Âncoras atuais a reconciliar com o Excel

- Cofrinho Itaú: R$ 42.842,59, posição 27/08/2026, D+0.
- RSU vested / Organon Long Share Holdings: R$ 32.772,30, posição 18/08/2026, D+3.
- FGTS Organon: R$ 17.509,05, posição 18/08/2026, restrito / contingência ~D+30.
- Caixa bancário: derivado das contas correntes + fatos efetivos a partir das âncoras bancárias atuais.

## Liquidez futura atual relevante antes do gap

Tabela `lts_future_liquidity_schedule`, ativa:

- RSU 05/11/2026 + D+3: R$ 21.745,98, valor bruto, schedule legado certificado.
- RSU 07/11/2026 + D+3: R$ 17.310,95, valor bruto, schedule legado certificado.
- Cash Award 18/02/2027 + D+3: bruto R$ 198.145,97 / líquido estimado R$ 138.702,18. Por ocorrer depois de janeiro, não cobre o primeiro gap atual.

Ponto crítico: as duas RSUs de novembro estão como `gross_only`. A auditoria deve confirmar qual valor o Excel utilizava e se a comparação é bruto contra bruto, líquido contra líquido ou se havia outra premissa documentada. Não inferir imposto/FX/quantidade.

## Principais eventos do motor que pressionam a ponte até janeiro

A auditoria deve comparar, um a um, com o Excel projetado e classificar cada diferença como: `já existia no Excel`, `valor/data atualizados por fato`, `novo compromisso documentado`, `projeção substituída`, `possível duplicidade`, `ausente no Excel`, `inconclusivo`.

Itens materialmente relevantes hoje incluem:

- Financiamento CIPÓ 396: ~R$ 20,5–20,7 mil/mês.
- Cartões Visa/Mastercard/C6 com valores que mudam por competência.
- Benjamin Educação.
- Condomínio O Parque.
- Volvo: parcela R$ 2.886,43/mês + seguro.
- IPTU CIPÓ 396 até nov/2026 e IPVA/licenciamento em jan/2027.
- Fisioterapia Larissa + reembolsos correspondentes.
- Enel O Parque.
- Salário líquido + adiantamento quinzenal.
- Retention Bonus Organon de R$ 39.175,57 em 31/01/2027 no motor atual.

Nenhum desses itens deve ser removido ou alterado apenas para “fazer bater” com o Excel. A ponte deve explicar a diferença.

## Evidência recuperada do Excel

O arquivo histórico `Controle_Financeiro_v16.xlsm` / `Controle_Financeiro_Fase1_Compactado.xlsx`, aba `Fluxo Negativo`, contém pelo menos uma série mensal identificada como `Saldo Ex RSUs`, com 2026 visível nos artefatos recuperados. A série tem deterioração ao longo de 2026 e termina negativa no cenário sem RSUs. O arquivo também contém blocos rotulados `Saldo Ex FGTS`, `Saldo Total` e `Saldo Futuro`; os valores desses blocos ainda precisam ser extraídos de forma inequívoca antes da conclusão.

A observação do usuário — de que após RSUs + FGTS não via ruptura real — é a hipótese principal a testar contra esses blocos, não algo a descartar porque o motor atual passa QA.

## Plano de fechamento da ponte

1. Recuperar no Excel os valores mensais/diários de `Saldo Ex RSUs`, `Saldo Ex FGTS`, `Saldo Total` e `Saldo Futuro`, com datas e fórmulas/semântica.
2. Congelar uma tabela de âncoras comparáveis na mesma data-base.
3. Reconciliar entradas e saídas futuras por identidade, data e valor entre Excel e motor atual.
4. Separar diferenças provocadas por fatos ocorridos após a planilha daquelas provocadas por mudança de regra/modelo.
5. Reconciliar RSUs por vesting/settlement e verificar bruto x líquido sem inventar impostos, FX ou quantidade.
6. Reconciliar FGTS como contingência com prazo ~D+30, sem tratá-lo como caixa automático.
7. Produzir ponte acumulada até o primeiro gap: `saldo Excel + deltas documentados = saldo motor atual`.
8. Se fechar: explicar por que o gap mudou. Se não fechar: localizar bug/gap de modelo e corrigir antes de homologar Planejamento.
9. Criar gate regressivo permanente de paridade Excel→motor para a janela auditada.

## UX de Planejamento após a auditoria

A referência de informação é a antiga visão executiva já recuperada do projeto: leitura rápida de caixa/recursos, camadas de liquidez, cenário com/sem recursos futuros, diferença entre `ponto de gestão` e `falta real`, RSUs que mudam o caixa, necessidade por conta e poucas ações prioritárias. A tela não deve expor linguagem de implementação, nomes de funções, QA ou excesso de texto técnico.

## Guardrails

- Fato vence projeção correspondente.
- Cenário não vira fato.
- RSU futura só entra após elegibilidade + settlement.
- FGTS é contingência ~D+30, nunca caixa automático.
- Não inventar valor líquido de RSU, imposto, FX, merchant, classificação ou reconciliação.
- Não reinterpretar saída/entrada apenas para eliminar um gap.
- Nenhuma promoção para `index.html` enquanto a candidata visual e esta frente P0 não estiverem em estado homologável.
