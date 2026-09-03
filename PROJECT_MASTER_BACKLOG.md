# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Never remove an open financial, documentary, classification or product dependency during compaction. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and release checkpoints.

## P0 — v151 Dashboard / Atualizações / busca de lançamentos — 03/09/2026
- [~] Active branch `v151-dashboard-updates-cockpit`; base is current v150 fixed homologation.
- [x] v151 executive Dashboard recomposition and evidence-clarity layer implemented without changing financial writers.
- [x] User material feedback captured: current `Consultar o Fluxo` timed out on a broad query (`canceling statement due to statement timeout`) and is not acceptable as the transaction-finding experience.
- [~] Replace the broad Flow fetch with **server-side transaction search** using `lts_browser_transactions_v1`.
- [~] Desired behavior: type-as-you-go search; e.g. typing `Mastercard` immediately returns matching launches without requiring a separate top-level tab.
- [~] Search scope must cover supported history from **10/10/2013 onward plus future launches already present in LTS**.
- [~] Result list must expose a total and remain read-only.
- [~] Add **Excel-compatible CSV export** of all matches, preserving date, description, account, direction, amount, category, counterparty, cost center and source/reference where available.
- [x] Direct backend evidence check for `Mastercard` found 239 matching rows spanning 01/11/2013 to 12/04/2028; this is evidence that the server-side search can cover historical + future records without fetching the whole Flow first.
- [ ] v151 branch gate must be fully green before integration/exposure.
- [ ] Integrate v151 into `main` only after fresh compare and green gates.
- [ ] Expose v151 only on fixed homologation after integrated-main gates are green; public `index.html` remains protected.
- [ ] Real authenticated visual E2E remains pending/unclaimed.

## P0 — FGTS documentary refresh / conservative rule — 03/09/2026
- [x] New CAIXA FGTS statement received, issued 03/09/2026 17:48.
- [x] Statement chronology confirms prior 21/04/2026 balance R$25.585,03, full 07/05/2026 withdrawal to R$0, and later rebuilding through deposits/credits.
- [x] Latest exact documentary balance in the statement is **R$22.432,31 as of 21/08/2026** (R$22.358,79 after Jul/2026 deposit on 19/08 + R$73,52 JAM on 21/08).
- [x] Append-only asset-position evidence recorded for FGTS Organon at 21/08/2026 / R$22.432,31; previous snapshots remain preserved.
- [x] Product/wealth/dashboard read caches refreshed so current FGTS read model uses R$22.432,31 as the restricted position.
- [x] User rule: **FGTS must be conservative; do not estimate future FGTS deposits/accrual because the amount depends on percentage and other variables.**
- [~] Reconcile Planning/FGTS bridge with the new documentary position and the new no-future-estimate rule before relying on any request-date FGTS coverage amount.
- [ ] Historical planning values based on the older R$17.509,05 + R$3.700/month accrual (including R$32.309,05 projected request-date FGTS and downstream worst-after-contingency) are retained only as historical model evidence until the planning bridge is recalculated under the new rule; they are **not** to be presented as current validated forecast.
- [x] FGTS remains restricted / approximately D+30 contingency when accessible, never immediate D+3 cash.
- [x] `Valor para fins rescisórios` shown by CAIXA is not treated as current withdrawable cash balance.

## P0 — v150 release baseline
- [x] v150 exact green product SHA `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- [x] v150 integrated and exposed on fixed homologation; `homologacao-current.json` remains v150 until v151 is green/exposed.
- [x] Protected public `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- [x] Public fallback remains WIP35-v136; public promotion is NOT authorized.
- [x] v150 reviewed text input routes to existing `Entradas` preview with `preview_only:true`, adds no writer and requires explicit approval.
- [x] v150 Despesas context×nature and read-only drilldowns are preserved.

## 0. Release / homologation guardrails
- [x] Public root: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- [ ] Never force branch history or overwrite parallel work.
- [ ] Before every repository write, re-fetch `main`, active branch, this backlog, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and latest immutable checkpoint.
- [ ] Never promote `index.html` without explicit user authorization.
- [ ] Never claim authenticated visual E2E unless actually performed.
- [ ] Keep fixed link, mobile/desktop usability, backup and traceability working through every release.

## 1. Dashboard / planejamento incorporado
- [x] Product framing: `Sua vida financeira, em uma tela.`.
- [x] Primary liquidity: available realizable through D+3; bank cash, D0 and vested RSU D+3 remain separated.
- [x] FGTS separate/restricted; never current D+3 cash.
- [x] Redundant top-level `Planejamento` removed; planning remains inside Dashboard/liquidity view.
- [~] Previous management-point model (08/01/2027; request-by 09/12/2026) must be revalidated after the new FGTS conservative/no-accrual rule before current presentation of FGTS-funded coverage conclusions.
- [x] Future RSUs remain excluded before vest/settlement.
- [ ] Any new money-changing assumption/scenario requires explicit user decision unless already explicitly stated by the user.

## 2. Despesas — natureza × contexto/pessoa
- [x] Economic invariant R$8.623.752,53 preserved.
- [x] Analytical cache 3.860/3.860, zero mismatch.
- [x] Nature of spend and context/person/cost center remain distinct dimensions.
- [x] Periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- [x] Context examples: Benjamin, Lucas, Larissa, Rafiki, Casa, Não atribuído.
- [x] Context→nature and nature→context read-only drilldown only where detail exists.
- [x] `Não atribuído` split between documentary detail not recovered, system investigation and classification/context pending.
- [~] Improve density, ranking and decision-useful insights.
- [~] Reduce `A classificar` only by evidence, never by invention.

## 3. Classification evidence hierarchy
1. explicit user-confirmed rule;
2. exact/consistent LTS history;
3. public merchant research;
4. manual review if ambiguity remains.

- [x] Merchant research never invents purchase purpose.
- [x] Marketplaces/intermediaries remain manual where actual purchase purpose is unproven.
- [x] Existing writer `lts_browser_semantic_feedback_v1`; reader `lts_browser_product_v1`.
- [x] Synthetic v148 lifecycle covers save→refresh→resolved disappearance/read-only retry/`O que mudou`.
- [ ] Real authenticated lifecycle remains pending.

## 4. Atualizações / Input / documents
- [x] Atualizações remains a compact action center/checklist; avoid large blank whitespace and buried actions.
- [x] `Lançamento por texto` continues to existing `Entradas` preview; no automatic posting.
- [x] Date/value/account-or-card mandatory before approval; liquidity/RSU movements are not revenue/expense.
- [~] `Encontrar lançamentos` replaces the timeout-prone broad `Consultar o Fluxo` experience in v151.
- [~] Search is read-only, server-side, incremental and exportable to Excel-compatible CSV.
- [x] v147 guided association preserved: bank statement → explicit account/institution + competence; card statement → card + competence; financing → commitment + exact as-of; other docs → manual review.
- [x] Filename never determines account/card/competence/date/value; upload alone never posts financial data.
- [x] v149 separates `Vínculo informado por você` from `Leitura do arquivo · revisar`; extraction remains evidence only.
- [ ] Real authenticated PDF/image interpret→review remains pending/unclaimed.

## 5. Fluxo Diário / FIX86
- [x] Mandatory Itaú, Bradesco, C6 and Consolidado; history from 2013 where evidence exists.
- [x] Visual hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`; balances visually differentiated.
- [x] Facts beat projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed own forecast.
- [x] Bank↔liquidity-asset transfer economic consolidated effect zero.
- [ ] Never infer historical bank without evidence.
- [ ] Real authenticated visual E2E remains open.

## 6. Natural liquidity input
- [x] Parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] Never guess account/asset; preview both legs/before-after/economic effect R$0; explicit confirmation before write.
- [ ] Authenticated save→refresh→visible remains pending.
- [ ] Cancellation/reversal semantics must be append-only and auditable; do not invent behavior.

## 7. Cartões / historical recovery
- [x] Certified allocation 38 cycles / 650 rows / R$885.855,19.
- [x] Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- [x] C6 Aug/2024 category R$4.087,42 vs detail R$4.020,72; explicit R$66,70 Taxi/Uber gap.
- [x] Mastercard 2022 certified Apr/Jun/Jul/Oct; remaining months need evidence.
- [~] Mastercard 2023 12 ledger-only payments / R$496.689,05; independent category matrix absent.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; others incomplete.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [x] Visa 2017 R$126.681,76 aggregate-only; Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite Itaú 2025 12/12 certified.
- [~] Continue Mastercard/Visa recovery only from documentary evidence; never pattern-fill purchases.

## 8. Patrimônio / RSU / CIPÓ / Volvo
### RSU
- [x] Vested 459.483 units / R$32.772,30 / D+3; future awards excluded.
- [x] Sale 283 units settled 05/08/2026: theoretical gross R$19.673,72; net R$19.095,04.
- [ ] R$578,68 historical sale difference remains unexplained/unitemized.

### FGTS temporal distinction
- [x] 21/04/2026 R$25.585,03 and 07/05/2026 full withdrawal are historical positions.
- [x] 21/07/2026 R$17.509,05 is an intermediate later balance in the newly supplied statement.
- [x] 21/08/2026 R$22.432,31 is the latest documentary balance currently evidenced.
- [x] Keep temporal positions distinct; do not sum snapshots.
- [x] No future FGTS accrual estimation under the current user rule.

### CIPÓ 396
- [x] Drilldown exposes purchase/history/reforms/debt/market estimate/equity/schedule.
- [ ] Itaú consortium delta R$303,60 unresolved.
- [ ] R$6.654,50 = R$6.502,70 + R$151,80 is arithmetic evidence only; dates differ.
- [ ] Condominium formula/cutoff lacks source.
- [ ] Raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70 unresolved.
- [ ] Never fabricate post-2029 TR; market-minus-cost is not automatically taxable/net gain.

### Volvo
- [x] Bradesco financing 60 × R$2.886,43, first 08/09/2026, last 08/08/2031, exactly once economically.
- [ ] Exact trim/version and km required before valuation refinement.

## 9. Open Finance
- [x] Provider-neutral private architecture QA 14/14; no real consent/token/provider.
- [~] Need written pricing, support, SLA and product×bank coverage for Itaú/Bradesco/C6.
- [ ] No provider consent/spend/credential/commercial commitment without explicit user decision.

## 10. Backend QA / stability / performance
- [x] Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`.
- [x] v14 293/293; v15 67/67; v16 19/19; v17 32/32; staged 411 checks / 35 suites + supplemental v143 16/16.
- [x] v146 repeated navigation regression: 10 × 7 destinations × desktop/mobile = 140 physical clicks.
- [x] v151 must continue rerunning inherited parser/navigation/v147/v148/v149/v150 gates.
- [~] Performance work only after correctness/parity; current transaction-search timeout is being solved by server-side filtering rather than a larger broad Flow fetch.

## 11. Historical continuity / backups / product quality
- [~] Continue audit back to project start 07/07/2026 so no pending item disappears.
- [x] Preserve historical evidence from 2013 where supported.
- [x] Preserve fixed public/homologation links and canonical backup/restore traceability.
- [~] Preserve balance visual emphasis, compact Atualizações, no large whitespace regressions, mobile/desktop usability.

## 12. Current user-dependent decisions / blockers
- [ ] Human classification only where evidence remains insufficient.
- [ ] New money-changing assumptions not already explicitly supplied by the user.
- [ ] Append-only reversal semantics before cancellation/reversal UI.
- [ ] Volvo refinement when exact trim/km evidence is available.
- [ ] Open Finance provider/consent/spend decisions.
- [ ] Public promotion only after explicit user approval.

Until one of these is the genuine blocker, continue autonomous technical/documentary work and test before asking the user to inspect anything.
