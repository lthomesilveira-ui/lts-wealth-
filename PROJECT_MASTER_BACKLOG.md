# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and checkpoints. Never remove an open financial, documentary, classification or product dependency during compaction.

## P0 — v145 Dashboard stability — 31/08/2026
- [x] User material homologation of v144 identified a real Dashboard flicker: titles alternated as if there were a bad contact.
- [x] Root cause proven: inherited v142 Dashboard cockpit could poll every 180 ms and re-render; v143 feedback polish reapplied final copy every 220 ms.
- [x] v145 preserves historical candidates and stabilizes ownership without changing financial rules, values, classifications or backend writers.
- [x] Final renderer copy: `Sua vida financeira, em uma tela.` / `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`.
- [x] Legacy repeated Dashboard polling is locked after a valid cockpit exists; explicit one-shot read-only refresh remains available.
- [x] v144 Atualizações classification/action center remains inherited and preserved.
- [x] Product commit `8ccd9fc6eca1f7da833f80b9788fefd98c601f18`; initial branch gate `33421305585` SUCCESS.
- [x] Hardened candidate SHA `9d4a52df566d74bdc77f92b0d227906fc46bddce`; branch gate `33423228532` SUCCESS.
- [x] Integrated into `main` by fast-forward with `force=false`; no divergent work overwritten.
- [x] Integrated-main v145 stability `33423462471` SUCCESS; artifact `9769869448`.
- [x] Integrated-main Pages `33423461388` SUCCESS.
- [x] Controlled exposure SHA `a99483543f3d1408be5b297dc66ec5f491be68dd` switches fixed homologation to v145 with `promotion_status: not_promoted`.
- [x] Exposure exact-SHA v145 stability `33424045510` SUCCESS.
- [x] Exposure exact-SHA v144 Updates/full-browser smoke `33424045367` SUCCESS.
- [x] Exposure exact-SHA candidate-smoke `33424045318` SUCCESS.
- [x] Exposure exact-SHA Pages `33424044022` SUCCESS.
- [x] Manifest resolves `v145` → `wip35-v145-candidate.html`, candidate head `9d4a52df...`.
- [x] Protected public `index.html` remains exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- [~] Material user visual re-homologation of v145 is now the current release gate.
- [ ] Public `index.html` promotion only after explicit user approval.
- [ ] Real authenticated visual E2E remains pending/unclaimed.

## P0 — v144 Atualizações corrective package — retained facts
- [x] Restored classification first with `Sugestão + pesquisa + % de confiança, item por item`.
- [x] Evidence hierarchy: explicit user rule → exact/consistent LTS history → public merchant research → manual confirmation.
- [x] `GULA GULA MORUMBI` remains taxonomy review: `Restaurantes` suggestion shown with evidence/confidence but no auto-confirmation.
- [x] Marketplaces/intermediators remain review where purchase purpose is unproven.
- [x] v144 exposure SHA `e8c522728a9c5740be89f1bcf08c8301ceecee78`; post-switch Updates `33417045276`, candidate `33417045163`, Pages `33417043749` all SUCCESS.
- [x] v145 post-switch smoke confirms this Atualizações/classification surface remains present.

## 0. Release / homologation guardrails
- [x] Public root: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- [x] Fixed homologation currently targets v145; public fallback remains WIP35-v136.
- [x] Public protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- [ ] Never force branch history to resolve divergence.
- [ ] Never promote `index.html` without explicit user authorization.
- [ ] Never claim authenticated visual E2E unless actually performed.

## 1. Dashboard / executive UX
- [x] Header `Sua vida financeira, em uma tela.`.
- [x] Hero `Disponível realizável até D+3`.
- [x] Bank cash / D0-Cofrinho / vested RSU / restricted FGTS D+30 separated.
- [x] FGTS second reading remains clearly restricted, not cash today.
- [x] Faturas vencidas/a confirmar; faturas abertas; pendências; próxima ação de cartão.
- [x] Human future-liquidity warning and request-by timing.
- [x] v145 temporal smoke desktop/mobile proves stable title/subtitle with `renderDelta=0`, `rpcDelta=0`, zero overflow/errors under synthetic browser data.
- [~] Material user visual approval pending.

## 2. Fluxo Diário / FIX86
- [x] Daily flow mandatory by bank + consolidated; historical coverage preserved back to available 2013 history.
- [x] Hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`; balances retain subtle visual emphasis.
- [x] Engine `daily-flow-fix86-v13-bank-asset-liquidity-parity`.
- [x] Historical parity 2,030 days / 147 months exact through 2025; facts beat projections; scenarios never become facts.
- [x] Bank↔liquidity-asset movements excluded from spend/revenue; economic effect zero.
- [x] Card cannot feed its own forecast.
- [ ] Never infer a historical bank where evidence is absent.
- [ ] Real authenticated visual E2E remains open.

## 3. Planejamento / Liquidez detalhada
- [x] First management point **08/01/2027**.
- [x] FGTS request-by **09/12/2026**.
- [x] Documentary FGTS 18/08/2026 **R$17.509,05**.
- [x] Existing accrual model **R$3.700/mês**; do not change by assumption.
- [x] Projected request-date FGTS **R$32.309,05**.
- [x] Worst before contingency **-R$21.046,80**; worst after **+R$11.262,25**.
- [x] No uncovered gap through 28/02/2027 under the existing modeled contingency.
- [x] Jan/2027 is a liquidity-management point, not proven patrimonial insufficiency.
- [x] Future vestings remain conditional until vest/settle.
- [ ] Any new money-changing assumption/scenario requires explicit user decision.

## 4. Atualizações / classification / recurrence / documents
- [x] Clear action center: classifications, documents, balance refreshes, missing recurrence.
- [x] Suggestion + public research/evidence + confidence visible without auto-confirming ambiguity.
- [x] Marketplaces/intermediators/ambiguous names stay review.
- [x] `GULA GULA MORUMBI`: 2 Aeternum Sep/2026 rows, R$725,46, current detail `A classificar`; public evidence supports restaurant suggestion; remains `taxonomy_review`.
- [x] Taxonomy inventory 48 groups / 53 lines / 62 options; earlier safe auto-suggestions 0; 26 effective August rows required human review.
- [x] Generic recurrence compares history vs next 12 months; missing future is investigation, not automatic projection.
- [x] Historical median is evidence only, never a future amount.
- [x] Document backend QA 5/5; bank/card docs need identity+competence; financing needs commitment+as-of; filename similarity insufficient.
- [~] Guided document-association UI remains open.
- [~] Improve PDF/image interpretation while preserving manual review.
- [~] Authenticated resolved-item disappearance/save-refresh/self-heal/`O que mudou` path pending.

## 5. Natural input / resgate / aplicação
- [x] Parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] Never guess account/asset.
- [x] Preview shows both legs, before→after and economic effect R$0; explicit confirmation before write.
- [x] Apply refreshes Flow/Planning/Dashboard/Patrimônio/future cache through the same engine.
- [x] Transactional QA writes roll back; no QA financial row persists.
- [~] Real authenticated save→refresh→visible-result check pending.
- [ ] Cancellation/reversal UI not implemented; design append-only auditable reversal semantics before destructive behavior.

## 6. Despesas
- [x] Economic invariant **R$8.623.752,53** preserved.
- [x] Analytical cache **3.860/3.860**, zero missing/extra/mismatch.
- [x] Primary concepts category/group/macrogroup/center of cost/context; merchant secondary.
- [x] Mixed historical model: certified detail where evidence exists, aggregate otherwise; never fabricate items.
- [~] Density/insight refinement after visual feedback.
- [~] Reduce `A classificar` only with evidence.

## 7. Cartões / historical recovery
- [x] Open invoice = observed now and may grow; future installments = contracted floor, not prediction.
- [x] Certified allocation **38 cycles / 650 rows / R$885.855,19**.
- [x] Aggregate fallback **314 rows / R$2.650.846,36** remains aggregate-only.
- [x] C6 Aug/2024 category R$4.087,42; detail R$4.020,72; explicit Taxi/Uber gap **R$66,70**.
- [x] Visa 2017 **R$126.681,76 aggregate-only**; Visa Infinite Itaú 2024 **R$112.253,01 aggregate-only**; Visa Infinite Itaú 2025 12/12 certified.
- [x] Mastercard 2022 certified Apr R$11.910,91; Jun R$10.185,54; Jul R$13.486,29; Oct R$28.374,06.
- [~] Mastercard 2022 remaining months require documentary recovery.
- [~] Mastercard 2023: 12 ledger-only payments totaling **R$496.689,05**; independent category matrix absent.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; other months incomplete.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [~] Continue recovery by evidence/impact only; never pattern-backfill.

## 8. Patrimônio / RSU / CIPÓ / Volvo
- [x] RSU vested **459.483 units / R$32.772,30 / D+3**; future awards excluded until vest/settle.
- [x] Historical RSU sale 283 units settled 05/08/2026; theoretical gross R$19.673,72; net R$19.095,04; **R$578,68** difference unitemized.
- [x] `Simular antecipação` is read-only.
- [x] CIPÓ drill-down exposes purchase/reforms/debt/market estimate/equity/schedule.
- [ ] CIPÓ Itaú consortium delta **R$303,60** unresolved.
- [ ] CIPÓ `R$6.654,50 = R$6.502,70 + R$151,80` is arithmetic overlap evidence only; dates differ, do not suppress rows.
- [ ] CIPÓ condominium formula/cut lacks source.
- [ ] CIPÓ raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70.
- [ ] Never fabricate post-2029 TR.
- [ ] Market-minus-cost is not automatically taxable profit/net gain without validated rules.
- [x] Volvo Bradesco financing: 60 × **R$2.886,43**, 08/09/2026 through 08/08/2031; no duplicate economic effect.
- [~] Volvo exact trim/km required before valuation refinement.

## 9. FGTS historical temporal distinction
- [x] Historical Excel R$25.585,03; 07/05/2026 `FGTS` +R$25.585,03 and `investimentos itaú` -R$25.000,00 evidence historical realization.
- [x] Current employer FGTS R$17.509,05 is a later temporal position; never compare as the same static balance.

## 10. Performance / refresh / backup
- [x] Despesas cache reduced old ~29s path to ~0.1s range while preserving parity.
- [x] Operational truth is Flow v13 / refresh v4; liquidity targeted refresh v2 updates dependent surfaces.
- [~] Further performance only after correctness/exact parity.
- [x] Canonical export/safe restore and private daily backup preserved; pg_cron 06:15 UTC / 03:15 BRT idempotent.

## 11. Open Finance
- [x] Provider-neutral private architecture QA 14/14; no real consent/token/provider commitment.
- [~] Need written pricing, support/SLA and explicit product×bank coverage for Itaú/Bradesco/C6.
- [ ] No provider consent, spend, credential or commercial commitment without explicit user decision.

## 12. QA truth
- [x] Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948` unchanged.
- [x] v14 293/293 across 24 suites; v15 67/67 across 5; v16 19/19 across 2; v17 32/32 across 4.
- [x] Staged total 411 checks / 35 suites PASS; supplemental v143 QA 16/16 PASS.
- [x] v145 exact exposure gates all green: `33424045510`, `33424045367`, `33424045318`, `33424044022`.
- [ ] Real authenticated visual E2E pending/unclaimed.

## 13. Remaining user-dependent decisions
- [ ] Human classification where evidence remains insufficient.
- [ ] Any new money-changing financial assumption/scenario.
- [ ] Volvo refinement when exact trim/km evidence is available.
- [ ] Open Finance provider/consent/spend.
- [~] Material v145 visual homologation now available at fixed homologation URL.
- [ ] Public promotion only after explicit user approval.

Until one of these is the genuine blocker, continue autonomous technical/documentary work. Do not ask the user to perform basic QA.
