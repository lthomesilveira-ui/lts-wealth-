# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Detailed completed evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and immutable checkpoints. Never remove an open financial, documentary, classification or product dependency during compaction.

## P0 — v143 real-life feedback package — 31/08/2026
- [x] `wip35-v143-candidate.html` preserves v142 as parent and leaves public `index.html` untouched.
- [x] Frozen implementation code head before documentation-only checkpoint: `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- [x] Branch candidate-smoke run `33399959217` SUCCESS on that exact code SHA.
- [x] Runtime/navigation smoke: desktop 1440×1000 PASS; mobile 390×844 PASS; zero root overflow; zero console/page errors.
- [x] Deterministic v143 ownership PASS for Dashboard, Planejamento, Despesas, Cartões, Patrimônio and nav; inherited v142 Dashboard/nav/Planning/Wealth pointers redirect to v143; all real nav click-through checks change `window.V` correctly.
- [x] Button census v3 covers v143 candidate/life-real/feedback/ownership: **197/197 identifiable and wired, 0 unresolved, 0 anonymous**. This is static wiring evidence, not authenticated visual E2E.
- [x] Dashboard restored to the binding executive concept **“Sua vida financeira, em uma tela.”** with D+3 liquidity hero, separate FGTS-inclusive reading, explicit restricted/D+30 semantics, high-priority human cross-zero warning and overdue/a-confirm card reading.
- [x] Dashboard keeps few decision numbers and does not regress into a QA/reconciliation screen.
- [x] Planejamento is visually **“Liquidez detalhada”**, not a duplicate Dashboard: cash → D0/Cofrinho → vested RSU → future vestings only when available → FGTS D+30 contingency; negative episodes, action deadline and conditional resources are separated.
- [x] Planejamento explicitly states that the audited Jan/2027 event is a liquidity-management point, not proven patrimonial insufficiency, when planned contingency remains positive.
- [x] Atualizações remains checklist/action-first; evidence-assisted classification is surfaced and `Atualizações` navigation ownership is stable.
- [x] Recurrence/future panel no longer hardcodes example series. It consumes the generic 12-month historical-vs-future audit and treats historical median only as evidence, never as an automatically projected amount.
- [x] Despesas v143 supports clickable ranking/drill-down with human category/group/macrogroup/center-cost context and underlying composition; technical merchant language is secondary evidence.
- [x] Cartões v143 restores card/invoice detail, consolidated LTS classification, raw evidence and **Cartão × mês**; open bill = observed amount that may grow, future installments = known contracted floor, not predicted closing.
- [x] Patrimônio v143 restores vested RSU, future vestings/availability, read-only `Simular antecipação`, CIPÓ drill-down and Volvo Bradesco financing visibility.
- [x] Backend final staged gates rerun on frozen fingerprint `85a1b60816a5b84dfe3b41341ed27948`: v14 293/24 PASS + v15 67/5 PASS + v16 19/2 PASS + v17 32/4 PASS = **411 checks / 35 suites PASS**. These are staged gates, not one monolithic gate.
- [x] Supplemental read-model QA `lts_v143_life_real_backend_qa_v2` = **16/16 PASS** on the same fingerprint, covering RSU scope/value, future awards, Volvo Bradesco schedule, evidence-backed expense contexts and browser ACLs.
- [~] v143 still must be integrated normally into `main`, then candidate-smoke + Pages must be green on the same integrated SHA before `homologacao-current.json` can move from v142 to v143.
- [ ] Real authenticated visual E2E remains pending/unclaimed.
- [ ] User material visual homologation of v143 only after the fixed homologation manifest is safely switched.
- [ ] Public `index.html` promotion only after explicit user approval.

## 0. Release / homologation guardrails
- [x] Public root fixed: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation entrypoint: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html` using no-store/timestamp manifest routing.
- [x] Public `index.html` fallback remains WIP35-v136, exact protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; effective prior approved visual reference remains v135.
- [x] `homologacao-current.json` remains on **v142** until v143 integration + same-SHA smoke/Pages complete.
- [x] v137 real homologation failure, v139 authenticated lexical-state failure and subsequent v140/v141/v142 recovery remain recorded in immutable incident/checkpoint files.
- [ ] Never force branch history to resolve divergence.
- [ ] Never promote `index.html` without explicit user authorization.

## 1. Dashboard / executive UX
Binding architecture remains:
- [x] Header “Sua vida financeira, em uma tela.”
- [x] Hero “Disponível realizável até D+3”.
- [x] Caixa bancário / D0-Cofrinho / RSU vested / FGTS restrito D+30 separated.
- [x] Clear second reading including FGTS without presenting it as cash available today.
- [x] Faturas vencidas/a confirmar; faturas abertas; pendências operacionais; próxima ação de cartão.
- [x] Human future-liquidity warning: without liquidity action, cash crosses zero on the audited management date.
- [x] If FGTS is the modeled contingency, request-by date and D+30 behavior are visible.
- [x] Horizons, prioritized actions, known future liquidity and shortcuts to Fluxo/Despesas/Cartões/Patrimônio.
- [x] Light background, white cards, fine borders, contained radius, restrained semantic color hierarchy.
- [~] Material user visual approval still pending after v143 exposure.

## 2. Fluxo Diário / FIX86
- [x] Daily flow remains mandatory by bank + consolidated, historical coverage preserved back to available 2013 history.
- [x] Reading hierarchy: **Saldo anterior | Entradas | Saídas | Saldo final**.
- [x] Balance/sum cells retain subtle consistent background emphasis; avoid excessive color.
- [x] Duplicate/confusing internal `Hoje` control removed while period navigation remains.
- [x] Flow v13 = `daily-flow-fix86-v13-bank-asset-liquidity-parity`; effective bank↔asset liquidity overlay does not change spend economics.
- [x] Historical effective parity: 2,030 days / 147 months exact through 2025; facts beat projections; stale/superseded anchors never reanchor; scenarios never become facts.
- [x] Bank↔liquidity-asset movements are excluded from spend/revenue and cannot create duplicate economic effect.
- [x] Card cannot feed its own forecast.
- [ ] Never infer a historical bank where evidence is absent.
- [ ] Final real authenticated visual E2E remains open.

## 3. Planejamento / Liquidez detalhada
- [x] Audited first management point: **08/01/2027**.
- [x] Conservative FGTS request-by: **09/12/2026**.
- [x] Documentary FGTS at 18/08/2026: **R$17.509,05**.
- [x] Existing accrual model: **R$3.700/mês**; do not change by assumption.
- [x] Conservative projected FGTS existing on request date: **R$32.309,05**.
- [x] Worst balance before contingency: **R$-21.046,80**.
- [x] Worst balance after planned FGTS D+30: **R$+11.262,25**.
- [x] No uncovered gap through 28/02/2027 under the already-modeled contingency.
- [x] Required interpretation: 08/01/2027 is a liquidity-management point; with FGTS initiated by 09/12/2026, real insufficiency is not proven in this audited horizon.
- [x] Future vestings stay conditional and outside already-available liquidity until actual vesting/settlement.
- [ ] Any new assumption/scenario that changes money requires explicit user decision.

## 4. Atualizações / classification / recurrence / documents
- [x] Action-first checklist: what needs action now; classification; documents; balance refreshes; missing recurrence; healthy/future items may collapse.
- [x] Classification evidence order: explicit user-confirmed semantic rule → exact consistent LTS history → public merchant research → manual review.
- [x] Public research may identify merchant and suggest a category, but cannot invent purchase purpose or auto-confirm ambiguous taxonomy.
- [x] Marketplaces/intermediators/ambiguous names remain review items.
- [x] Example preserved: `GULA GULA MORUMBI`, two Aeternum Sep/2026 rows, total **R$725,46**, detail `A classificar`; enrichment identifies Gula Gula / suggestion Restaurantes / confidence 0.99 / provider public_research / official evidence; status remains `taxonomy_review` because protected historical taxonomy does not authorize final choice.
- [x] Taxonomy inventory remains 48 groups / 53 lines / 62 options; earlier safe auto-suggestions were 0 and 26 effective August rows lacked sufficient evidence.
- [x] Generic recurrence audit compares past recurring history against the next 12 months. Missing future coverage opens investigation only; absence may mean termination, rename or missing projection.
- [x] Recurrence examples such as condominium, IPTU, Benjamin education, salary/advance are examples only, never hardcoded product rules.
- [x] Historical median is evidence only, not a future amount.
- [x] Document association backend QA 5/5; bank/card documents require explicit identity + competence; financing requires explicit commitment + as-of date; filename/similarity alone is insufficient.
- [~] Guided document-association UI remains open.
- [~] Improve PDF/image interpretation while preserving manual review when evidence is incomplete.
- [~] Real authenticated resolved-item disappearance/save-refresh/self-heal/`O que mudou` path pending.

## 5. Natural input / resgate / aplicação
- [x] Natural parser covered: `5 mil`, `R$ 5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] No account/asset preselection by guessing; only explicit name or unique safe case.
- [x] Preview shows bank leg, asset leg, before→after and economic effect R$0; nothing writes before explicit confirmation.
- [x] Apply refreshes Flow, Planning, Dashboard, Patrimônio and future cache through the effective engine.
- [x] Transactional QA writes are deliberately rolled back; no QA financial row persists.
- [~] Real authenticated save→refresh→visible-result check remains pending/unclaimed.
- [ ] Cancellation/reversal UI not implemented. Design append-only auditable reversal semantics before any destructive behavior; table `active|cancelled` alone does not authorize an improvised delete/edit.

## 6. Despesas
- [x] Economic invariant **R$8.623.752,53** preserved.
- [x] Analytical cache **3.860/3.860**, zero missing / zero extra / zero mismatch.
- [x] User-facing primary concepts remain category / group / macrogroup / center of cost and meaningful context; `merchant` is not the main visual model.
- [x] Drill-down can expose evidence-backed contexts such as Benjamin · Educação, Benjamin · Saúde, Rafiki, IPTU, financing/loans, Casa, Lucas, Larissa when data supports them.
- [x] Ranking is clickable and opens real composition.
- [x] Mixed historical model remains: certified detail where documents support it; aggregate where only aggregate is supported; never fabricate an item to close a bill.
- [~] Final density/insight refinement after user visual feedback; do not regress current auditability.
- [~] Reduce `A classificar` only with evidence.

## 7. Cartões / historical recovery
- [x] Open invoice = observed value so far and may grow.
- [x] Future installments = known contracted floor, not forecast closing amount.
- [x] Certified historical allocation: **38 cycles / 650 rows / R$885.855,19**.
- [x] Aggregate fallback: **314 rows / R$2.650.846,36**, non-promoting without composition evidence.
- [x] C6 Aug/2024: category total R$4.087,42; detail R$4.020,72; explicit Taxi/Uber gap **R$66,70**. Never invent a purchase to fill it.
- [x] Visa 2017 **R$126.681,76 aggregate-only**.
- [x] Visa Infinite Itaú 2024 **R$112.253,01 aggregate-only**.
- [x] Visa Infinite Itaú 2025 12/12 certified.
- [x] Mastercard 2022 certified: Apr R$11.910,91; Jun R$10.185,54; Jul R$13.486,29; Oct R$28.374,06.
- [~] Mastercard 2022 remaining months still require documentary recovery; partial/fragmented evidence is not certification.
- [~] Mastercard 2023: 12 ledger-only payments totaling **R$496.689,05**; independent category matrix missing.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; other months remain without full independent composition.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [~] File Library retrieval failures do not equal evidence absence; partial snippets do not authorize reconstructed composition.
- [~] Continue global historical recovery by evidence/impact only, never pattern backfill.

## 8. Patrimônio / RSU / CIPÓ / Volvo
- [x] RSU vested current certified position: **459.483 units / R$32.772,30 / D+3**.
- [x] Future awards/vestings remain outside current acquired net worth until vesting/settlement.
- [x] Historical RSU sale: 283 units, settled 05/08/2026; theoretical gross R$19.673,72; net received R$19.095,04; difference **R$578,68** remains unitemized — never invent tax/fee split.
- [x] `Simular antecipação` is read-only scenario only and never writes reality.
- [x] CIPÓ drill-down exposes evidence-backed purchase/reform outlays, documentary debt, central market estimate, equity and financing schedule.
- [ ] CIPÓ Itaú consortium delta **R$303,60** unresolved.
- [ ] CIPÓ arithmetic overlap evidence **R$6.654,50 = R$6.502,70 + R$151,80** has differing dates; do not suppress rows without proof.
- [ ] CIPÓ condominium formula/cut still lacks source; best raw gap R$1.780.358; best dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70. Proximity does not authorize ledger rewrite.
- [ ] Never fabricate post-2029 TR-dependent values.
- [ ] Difference between invested value and market estimate is not automatically taxable profit/net gain without validated tax/cost rules.
- [x] Volvo financing account confirmed **Bradesco**: 60 installments; first 08/09/2026; last 08/08/2031; **R$2.886,43** each; Flow Bradesco + Patrimônio parity QA passed without duplicate economic effect.
- [~] Volvo exact trim/km still required before valuation refinement.

## 9. FGTS historical temporal distinction
- [x] Historical Excel position R$25.585,03; 07/05/2026 `FGTS` +R$25.585,03 and same-day `investimentos itaú` -R$25.000,00 evidence a historical realization/withdrawal.
- [x] Current employer FGTS R$17.509,05 is a later position and must never be compared as if it were the same static balance.

## 10. Performance / refresh / backup
- [x] Despesas cache path reduced old ~29s behavior to ~0.1s range while preserving exact parity; Flow and semantic improvements remain guarded by exact output parity.
- [x] Operational rollover truth is current Flow v13 / operational refresh v4, not retired Flow v12/v3 wording.
- [x] Liquidity targeted refresh v2 updates effective Flow, Planning, Dashboard, Patrimônio and future cache; contract 11/11 and transactional 8/8 PASS.
- [~] Further performance work only after correctness and with exact parity.
- [x] Canonical export/safe restore and private daily backup snapshot remain protected; browser sees metadata only, not private payload.
- [x] `pg_cron` daily backup 06:15 UTC / 03:15 BRT remains idempotent one snapshot/user/date.

## 11. Open Finance
- [x] Provider-neutral private architecture QA 14/14; no real consent/token/provider commitment exists.
- [~] Production provider decision still requires written pricing, support/SLA and explicit product×bank coverage for Itaú/Bradesco/C6.
- [ ] No real provider consent, spend, external credential or commercial commitment without explicit user decision.

## 12. Gates / QA truth
- [x] Final v143 staged backend fingerprint before integration: `85a1b60816a5b84dfe3b41341ed27948` before and after gates.
- [x] v14 **293/293 across 24 suites PASS**.
- [x] v15 **67/67 across 5 suites PASS**.
- [x] v16 **19/19 across 2 suites PASS**.
- [x] v17 **32/32 across 4 suites PASS**.
- [x] Staged gate evidence = **411 checks / 35 suites PASS** on one unchanged fingerprint; still do not call this a monolithic gate because execution is deliberately staged.
- [x] Supplemental v143 backend QA v2 = **16/16 PASS** on same fingerprint.
- [x] v143 branch browser/runtime smoke + static census green on code SHA `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- [ ] Same-SHA integrated-main candidate-smoke + Pages still required.
- [ ] Real authenticated visual E2E remains pending/unclaimed.

## 13. Remaining user-dependent decisions
- [ ] Human classification where evidence remains insufficient.
- [ ] Any new money-changing financial assumption/scenario.
- [ ] Volvo refinement when exact trim/km evidence is available.
- [ ] Open Finance provider/consent/spend.
- [ ] Material v143 visual homologation only after safe manifest exposure.
- [ ] Public promotion only after explicit user approval.

Until one of these is the genuine blocker, continue autonomous technical/documentary work. Do not ask the user to perform basic QA.
