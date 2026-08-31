# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and checkpoints. Never remove an open financial, documentary, classification or product dependency during compaction.

## P0 — v144 Atualizações corrective package — 31/08/2026
- [x] User v143 material homologation found a P0 regression in Atualizações: assisted classification had lost the earlier visible suggestion + research/evidence + certainty %, and the page had poor hierarchy/large blank space.
- [x] v144 restores classification FIRST with `Sugestão + pesquisa + % de confiança, item por item`, preserving existing classification helpers and save handlers instead of inventing a new financial writer.
- [x] Evidence hierarchy remains explicit user rule → exact/consistent LTS history → public merchant research → manual confirmation when ambiguity remains.
- [x] `GULA GULA MORUMBI` sample remains taxonomy review: `Restaurantes` suggestion is shown with evidence/confidence, but no auto-confirmation is authorized.
- [x] Marketplaces/intermediators remain review items; public research identifies the merchant but does not invent purchase purpose.
- [x] v144 deep-runtime/lexical-state bridge exposes the inherited runtime state only inside the same product realm; it does not alter financial logic.
- [x] Stable product host commit `01b15f5e382939851086c67515b5ecff38fbcef1`.
- [x] Branch gate run `33412827358` SUCCESS.
- [x] Freeze/pre-integration checkpoint committed; freeze run `33413763757` SUCCESS on head `b0d23e35be1d5d27400268a36bb3562395bb3513`.
- [x] Integrated into `main` by fast-forward with `force=false`; no divergent work overwritten.
- [x] Integrated-main same-SHA v144 smoke `33414249775` SUCCESS.
- [x] Integrated-main same-SHA legacy candidate-smoke `33414249873` SUCCESS.
- [x] Integrated-main same-SHA Pages `33414248379` SUCCESS.
- [x] Protected public `index.html` still exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9` before exposure switch.
- [~] Controlled fixed-homologation manifest switch from v143 to v144 is contained in the current exposure commit; post-switch exact-SHA gates are still required before user access.
- [ ] Post-switch exact-SHA v144 smoke + candidate-smoke + Pages must all pass; public `index.html` must remain unchanged.
- [ ] Material user visual homologation of v144 only after those gates are green.
- [ ] Public `index.html` promotion only after explicit user approval.
- [ ] Real authenticated visual E2E remains pending/unclaimed.

## P0 — v143 release facts retained
- [x] v143 integrated normally by PR #6; integrated baseline `0526033f33ef90086388a946470313bd5002180c`.
- [x] Integrated same-SHA candidate-smoke `33401135988` SUCCESS and Pages `33401135026` SUCCESS.
- [x] Exposure main SHA `a86b7cffe909098d65fcaad849800316c13dab3a`.
- [x] Post-switch exact-SHA Pages `33402028275` SUCCESS and candidate smoke `33402029074` SUCCESS.
- [x] Protected public `index.html` exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- [x] Dashboard, Planejamento, Despesas, Cartões and Patrimônio corrections remain inherited by v144.
- [x] Backend final fingerprint `85a1b60816a5b84dfe3b41341ed27948`; v14 293/24 + v15 67/5 + v16 19/2 + v17 32/4 = 411 checks / 35 suites PASS, staged not monolithic.
- [x] Supplemental v143 backend QA 16/16 PASS on same fingerprint.

## 0. Release / homologation guardrails
- [x] Public root fixed: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation entrypoint: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html` using no-store/timestamp manifest routing.
- [x] Public fallback remains WIP35-v136, protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- [~] Fixed homologation is being switched to v144 in the current exposure package; same-SHA post-switch gates remain mandatory before user access.
- [ ] Never force branch history to resolve divergence.
- [ ] Never promote `index.html` without explicit user authorization.
- [ ] Never claim authenticated visual E2E unless actually performed.

## 1. Dashboard / executive UX
- [x] Header `Sua vida financeira, em uma tela.`.
- [x] Hero `Disponível realizável até D+3`.
- [x] Bank cash / D0-Cofrinho / vested RSU / restricted FGTS D+30 separated.
- [x] Clear second reading including FGTS without presenting it as cash available today.
- [x] Faturas vencidas/a confirmar; faturas abertas; pendências; próxima ação de cartão.
- [x] Human future-liquidity warning and request-by timing.
- [x] Few executive numbers; light background/white cards/restrained semantic colors.
- [~] Material visual approval remains pending through the v144 homologation cycle.

## 2. Fluxo Diário / FIX86
- [x] Daily flow mandatory by bank + consolidated; historical coverage preserved back to available 2013 history.
- [x] Reading hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`.
- [x] Balance/sum cells retain subtle consistent emphasis.
- [x] Flow engine `daily-flow-fix86-v13-bank-asset-liquidity-parity`.
- [x] Historical parity 2,030 days / 147 months exact through 2025; facts beat projections; stale/superseded anchors never reanchor; scenarios never become facts.
- [x] Bank↔liquidity-asset movements excluded from spend/revenue; economic effect zero.
- [x] Card cannot feed its own forecast.
- [ ] Never infer a historical bank where evidence is absent.
- [ ] Real authenticated visual E2E remains open.

## 3. Planejamento / Liquidez detalhada
- [x] First management point **08/01/2027**.
- [x] FGTS request-by **09/12/2026**.
- [x] Documentary FGTS 18/08/2026 **R$17.509,05**.
- [x] Existing accrual model **R$3.700/mês**; do not change by assumption.
- [x] Projected FGTS on request date **R$32.309,05**.
- [x] Worst balance before contingency **-R$21.046,80**.
- [x] Worst balance after planned FGTS **+R$11.262,25**.
- [x] No uncovered gap through 28/02/2027 under the existing modeled contingency.
- [x] Interpretation: Jan/2027 is a liquidity-management point, not proven patrimonial insufficiency, if FGTS is initiated on time.
- [x] Future vestings remain conditional and outside already-available liquidity until vest/settle.
- [ ] Any new money-changing assumption/scenario requires explicit user decision.

## 4. Atualizações / classification / recurrence / documents
- [x] Clear action center: classifications, documents, balance refreshes, missing recurrence.
- [x] v144 restores prominent suggestion + public research/evidence + confidence percentages without auto-confirming ambiguity.
- [x] Classification evidence order: explicit user-confirmed semantic rule → exact/consistent LTS history → public merchant research → manual review.
- [x] Marketplaces/intermediators/ambiguous names stay review.
- [x] `GULA GULA MORUMBI`: 2 Aeternum Sep/2026 rows, R$725,46, current detail `A classificar`; public evidence supports restaurant suggestion; remains `taxonomy_review`.
- [x] Taxonomy inventory remains 48 groups / 53 lines / 62 options; earlier safe auto-suggestions 0; 26 effective August rows required human review.
- [x] Generic recurrence audit compares history vs next 12 months; missing future is investigation, not automatic projection.
- [x] Historical median is evidence only, never a future amount.
- [x] Document backend QA 5/5; bank/card docs require explicit identity+competence; financing requires explicit commitment+as-of; filename similarity is insufficient.
- [~] Guided document-association UI remains open.
- [~] Improve PDF/image interpretation while preserving manual review.
- [~] Real authenticated resolved-item disappearance/save-refresh/self-heal/`O que mudou` path pending.

## 5. Natural input / resgate / aplicação
- [x] Parser: `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] Never guess account/asset.
- [x] Preview shows bank leg, asset leg, before→after, economic effect R$0; explicit confirmation before write.
- [x] Apply refreshes Flow/Planning/Dashboard/Patrimônio/future cache through the same effective engine.
- [x] Transactional QA writes roll back; no QA financial row persists.
- [~] Real authenticated save→refresh→visible-result check pending.
- [ ] Cancellation/reversal UI not implemented; design append-only auditable reversal semantics before destructive behavior.

## 6. Despesas
- [x] Economic invariant **R$8.623.752,53** preserved.
- [x] Analytical cache **3.860/3.860**, zero missing/extra/mismatch.
- [x] Primary concepts category/group/macrogroup/center of cost/context; merchant secondary.
- [x] Evidence-backed drill contexts include Benjamin · Educação, Benjamin · Saúde, Rafiki, IPTU, financing/loans, Casa, Lucas, Larissa when supported.
- [x] Mixed historical model: certified detail where evidence exists, aggregate otherwise; never fabricate items.
- [~] Density/insight refinement after visual feedback.
- [~] Reduce `A classificar` only with evidence.

## 7. Cartões / historical recovery
- [x] Open invoice = observed now and may grow.
- [x] Future installments = known contracted floor, not predicted closing.
- [x] Certified allocation **38 cycles / 650 rows / R$885.855,19**.
- [x] Aggregate fallback **314 rows / R$2.650.846,36** remains aggregate-only.
- [x] C6 Aug/2024 category R$4.087,42; detail R$4.020,72; explicit Taxi/Uber gap **R$66,70**.
- [x] Visa 2017 **R$126.681,76 aggregate-only**.
- [x] Visa Infinite Itaú 2024 **R$112.253,01 aggregate-only**.
- [x] Visa Infinite Itaú 2025 12/12 certified.
- [x] Mastercard 2022 certified Apr R$11.910,91; Jun R$10.185,54; Jul R$13.486,29; Oct R$28.374,06.
- [~] Mastercard 2022 remaining months require documentary recovery.
- [~] Mastercard 2023: 12 ledger-only payments totaling **R$496.689,05**; independent category matrix absent.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; other months incomplete.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [~] Continue recovery by evidence/impact only; never pattern-backfill.

## 8. Patrimônio / RSU / CIPÓ / Volvo
- [x] RSU vested current **459.483 units / R$32.772,30 / D+3**.
- [x] Future awards excluded from acquired net worth until vest/settle.
- [x] Historical RSU sale 283 units, settled 05/08/2026; theoretical gross R$19.673,72; net R$19.095,04; difference **R$578,68** remains unitemized.
- [x] `Simular antecipação` is read-only.
- [x] CIPÓ drill-down exposes purchase/reforms/debt/market estimate/equity/schedule.
- [ ] CIPÓ Itaú consortium delta **R$303,60** unresolved.
- [ ] CIPÓ `R$6.654,50 = R$6.502,70 + R$151,80` is arithmetic overlap evidence only; dates differ, do not suppress rows.
- [ ] CIPÓ condominium formula/cut lacks source.
- [ ] CIPÓ best raw gap R$1.780.358; best dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70.
- [ ] Never fabricate post-2029 TR.
- [ ] Market-minus-cost is not automatically taxable profit/net gain without validated tax/cost rules.
- [x] Volvo financing Bradesco: 60 × **R$2.886,43**, first 08/09/2026, last 08/08/2031; no duplicate economic effect.
- [~] Volvo exact trim/km required before valuation refinement.

## 9. FGTS historical temporal distinction
- [x] Historical Excel R$25.585,03; 07/05/2026 `FGTS` +R$25.585,03 and `investimentos itaú` -R$25.000,00 evidence historical realization.
- [x] Current employer FGTS R$17.509,05 is a later temporal position; never compare as the same static balance.

## 10. Performance / refresh / backup
- [x] Despesas cache reduced old ~29s path to ~0.1s range while preserving parity.
- [x] Operational truth is current Flow v13 / refresh v4.
- [x] Liquidity targeted refresh v2 updates Flow/Planning/Dashboard/Patrimônio/future cache.
- [~] Further performance only after correctness/exact parity.
- [x] Canonical export/safe restore and private daily backup preserved.
- [x] `pg_cron` daily backup 06:15 UTC / 03:15 BRT remains idempotent one snapshot/user/date.

## 11. Open Finance
- [x] Provider-neutral private architecture QA 14/14; no real consent/token/provider commitment.
- [~] Need written pricing, support/SLA and explicit product×bank coverage for Itaú/Bradesco/C6.
- [ ] No real provider consent, spend, credential or commercial commitment without explicit user decision.

## 12. Gates / QA truth
- [x] Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948` unchanged.
- [x] v14 293/293 across 24 suites PASS.
- [x] v15 67/67 across 5 suites PASS.
- [x] v16 19/19 across 2 suites PASS.
- [x] v17 32/32 across 4 suites PASS.
- [x] Staged total 411 checks / 35 suites PASS; not monolithic.
- [x] Supplemental v143 backend QA 16/16 PASS.
- [x] v143 post-switch candidate-smoke `33402029074` + Pages `33402028275` green on exposure SHA `a86b7c...`.
- [x] v144 branch run `33412827358` green.
- [x] v144 freeze run `33413763757` green on `b0d23e35...`.
- [x] Integrated-main v144 smoke `33414249775` SUCCESS on `b0d23e35...`.
- [x] Integrated-main candidate-smoke `33414249873` SUCCESS on `b0d23e35...`.
- [x] Integrated-main Pages `33414248379` SUCCESS on `b0d23e35...`.
- [~] Post-manifest-switch same-SHA gates required before user access.
- [ ] Real authenticated visual E2E pending/unclaimed.

## 13. Remaining user-dependent decisions
- [ ] Human classification where evidence remains insufficient.
- [ ] Any new money-changing financial assumption/scenario.
- [ ] Volvo refinement when exact trim/km evidence is available.
- [ ] Open Finance provider/consent/spend.
- [ ] Material v144 visual homologation only after safe fixed-link exposure gates are green.
- [ ] Public promotion only after explicit user approval.

Until one of these is the genuine blocker, continue autonomous technical/documentary work. Do not ask the user to perform basic QA.
