# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Never remove an open financial, documentary, classification, reconciliation or product dependency during compaction. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and release checkpoints.

## P0 — current canonical functional baseline — 06/09/2026
- [x] Strategic wrapper line v154→v160 is no longer the primary product architecture; it remains historical evidence only.
- [x] Single canonical frontend exists at `canonical-app.html`; no iframe/release-wrapper chain is part of the canonical product.
- [x] Canonical app owns Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações in one frontend.
- [x] Direct Supabase authentication/RPC layer is used by the canonical frontend; unauthenticated state exposes the real login rather than synthetic financial content.
- [x] Official-reference Dashboard language/density and later-approved liquidity-first hierarchy are preserved.
- [x] Canonical functional source commit `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`; file 79,339 bytes; SHA-256 `2ce0e6e92575c8ca11bc8178f54bc13a6b6c8bf05b0b75bc9b05046c1c1638f8`.
- [x] Deterministic functional gate `34003647351`: SUCCESS in Chromium desktop 1312×1199 and WebKit mobile 390×844.
- [x] Gate covers five KPIs, six physical routes, Fluxo account switching, Despesas nature×context + drilldown, Patrimônio, Cartões, Atualizações search/CSV/classification/documents, no iframe, no overflow/clipping, no page errors and truthful unauthenticated fallback.
- [x] Gate artifact `9980249754`; screenshots include Dashboard desktop/mobile and Atualizações.
- [x] Fixed homologation moved from v160 to `canonical-v1` / `canonical-app.html`; `promotion_status:not_promoted`.
- [x] Canonical exposure commit `e6f3ab7421d5b7cb1986df768835f9d826536d9d`; exact Pages deployment `34003976631`: SUCCESS.
- [x] Manifest traceability refresh `afdfc070528f17e2e906a53e54de74ff298d90aa` records the exact exposure SHA.
- [x] Immutable checkpoint: `backups/CANONICAL_APP_V1_FUNCTIONAL_HOMOLOGATION_CHECKPOINT_2026-09-06.md`.
- [x] Public `index.html` remains protected and unchanged; public promotion is NOT authorized.
- [ ] Authenticated physical-iPhone financial/data E2E of the canonical app remains pending and must not be claimed.

## Historical release evidence retained
- [x] v154 established accepted official-reference visual direction.
- [x] v155 corrected false-zero/navigation defects but later showed runtime slowness.
- [x] v156 established liquidity-first Dashboard but failed real iPhone data/navigation.
- [x] v157 WebKit recovery passed deterministic gates but failed real-device evidence.
- [x] v158 restored truthful native/auth fallback but regressed product presentation.
- [x] v159 restored presentation but real iPhone still showed all five KPI values unavailable.
- [x] v160 made readiness material-data driven and remains a historical technical fallback, not the primary product line.

## P0 — FGTS / planejamento under current conservative rule
- [x] Latest exact documentary FGTS balance: **R$22.432,31 as of 21/08/2026**.
- [x] FGTS remains restricted / approximately D+30 contingency when accessible, never D+3 cash.
- [x] No future FGTS deposit/accrual estimation under the current user rule.
- [x] Current audited planning contract separates action from first uncovered gap: FGTS request-by 30/11/2026; management/action point 30/12/2026; first uncovered gap 30/01/2027.
- [x] Current audit: bank cash R$15.794,43; D0 R$42.929,50; vested D+3 R$12.909,65; through D+3 R$71.633,58; worst before FGTS -R$25.782,39; worst after current documentary FGTS -R$3.350,08.
- [x] Migration `dashboard_planning_first_negative_alias` normalizes the first-negative field consumed by the frontend without changing financial arithmetic.
- [x] Historical values based on R$17.509,05 + R$3.700/month, including R$32.309,05 request-date FGTS and dependent worst-case figures, remain historical evidence only and must never be presented as current validated forecast.

## 0. Release / homologation guardrails
- [x] Public root: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- [ ] Never force branch history or overwrite parallel work.
- [ ] Before every repository write, re-fetch `main`, active branch, this backlog, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and latest immutable checkpoint.
- [ ] Never promote `index.html` without explicit user authorization.
- [ ] Never claim authenticated visual/data E2E unless actually performed.
- [ ] Preserve fixed links, mobile/desktop usability, backup and traceability through every release.

## 1. Dashboard / planejamento incorporado
- [x] Product framing: `Sua vida financeira, em uma tela.`.
- [x] Primary liquidity: available realizable through D+3; bank cash, D0 and vested RSU D+3 stay separated.
- [x] Liquidity-first hierarchy: Dinheiro em contas; Contas + curto prazo; RSUs vested; FGTS; Despesas (mês). Pending actions remain secondary.
- [x] `Contas + curto prazo` arithmetic is evidence-only: `bank_cash + d0` when both exist, otherwise `through_d3 - vested` only when both exist; missing evidence stays unavailable.
- [x] FGTS separate/restricted; never current D+3 cash.
- [x] Redundant top-level Planejamento removed; planning remains inside Dashboard/liquidity view.
- [x] Current planning displays/consumes distinct management/action and first-negative fields under the no-future-FGTS-accrual rule.
- [x] Future RSUs excluded before vest/settlement.
- [ ] Any new money-changing assumption/scenario requires explicit user decision unless already explicitly stated by the user.

## 2. Despesas — natureza × contexto/pessoa
- [x] Economic invariant R$8.623.752,53 preserved.
- [x] Analytical cache 3.860/3.860, zero mismatch.
- [x] Nature and context/person/cost center remain distinct analytical dimensions.
- [x] Canonical app directly consumes `lts_browser_expense_context_lens_v1`.
- [x] Periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- [x] Context→nature and nature→context read-only drilldown exists in the canonical route.
- [x] `Não atribuído` distinguishes documentary detail not recovered, system investigation, and classification/context pending.
- [~] Continue improving density, ranking and decision-useful insights from real evidence.
- [~] Reduce `A classificar` only by evidence, never invention.

## 3. Classification evidence hierarchy
1. explicit user-confirmed rule;
2. exact/consistent LTS history;
3. public merchant research;
4. manual review if ambiguity remains.

- [x] Merchant research never invents purchase purpose.
- [x] Marketplaces/intermediaries remain manual where actual purchase purpose is unproven.
- [x] Existing writer `lts_browser_semantic_feedback_v1`; reader `lts_browser_product_v1`.
- [x] Canonical lifecycle wiring performs save → product refresh/read verification and provides resolved/pending feedback; fixture keeps writer disabled by design.
- [ ] Real authenticated classification save→refresh→resolved disappearance/self-heal remains pending.

## 4. Atualizações / Input / documents / transaction search
- [x] Atualizações remains a compact checklist/action center; no large blank whitespace or buried actions.
- [x] `Lançamento por texto` continues to existing preview/review semantics; no automatic posting.
- [x] Date/value/account-or-card mandatory before approval; liquidity/RSU movements are not revenue/expense.
- [x] Canonical frontend implements server-side incremental transaction search through `lts_browser_transactions_v1`, replacing broad Flow lookup behavior.
- [x] Search scope contract: supported history from 10/10/2013 onward plus future launches already present in LTS.
- [x] Search remains read-only, exposes total, and can export Excel-compatible CSV preserving available date, description, account, direction, amount, category, counterparty, cost center and source/reference.
- [x] Backend evidence for `Mastercard`: 239 matching rows spanning 01/11/2013 to 12/04/2028.
- [ ] Real authenticated transaction-search E2E remains unclaimed; deterministic functional search/CSV gate is complete.
- [x] Explicit document association preserved: bank statement → account/institution + competence; card statement → card + competence; financing → commitment + exact as-of; other docs → manual review.
- [x] Filename never determines account/card/competence/date/value; upload alone never posts financial data.
- [x] Interpretation separates `Vínculo informado por você` from `Leitura do arquivo · revisar`; extraction remains evidence only.
- [x] Canonical Atualizações route consumes `lts_browser_document_lifecycle_v1` for lifecycle visibility.
- [ ] Real authenticated PDF/image interpret→review remains pending/unclaimed.

## 5. Fluxo Diário / FIX86
- [x] Mandatory Itaú, Bradesco, C6 and Consolidado; history from 2013 where evidence exists.
- [x] Canonical Fluxo route owns account switching without nested navigation wrappers.
- [x] Hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`; balances visually differentiated.
- [x] Facts beat projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed their own forecast.
- [x] Bank↔liquidity-asset transfer consolidated economic effect zero.
- [ ] Never infer historical bank without evidence.
- [ ] Real authenticated physical-device visual/data E2E remains open.

## 6. Natural liquidity input
- [x] Parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] Never guess account/asset; preview both legs/before-after/economic effect R$0; explicit confirmation before write.
- [ ] Authenticated save→refresh→visible remains pending.
- [ ] Cancellation/reversal semantics must be append-only and auditable; do not invent behavior.

## 7. Cartões / historical recovery
- [x] Canonical Cartões route directly consumes `lts_browser_card_history_coverage_v1`.
- [x] Certified allocation 38 cycles / 650 rows / R$885.855,19.
- [x] Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- [x] C6 Aug/2024 category R$4.087,42 vs detail R$4.020,72; explicit R$66,70 Taxi/Uber gap.
- [x] Mastercard 2022 certified Apr/Jun/Jul/Oct; remaining months need evidence.
- [~] Mastercard 2023: 12 ledger-only payments / R$496.689,05; independent category matrix absent.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; others incomplete.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [x] Visa 2017 R$126.681,76 aggregate-only; Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite Itaú 2025 12/12 certified.
- [~] Continue Mastercard/Visa recovery only from documentary evidence; never pattern-fill purchases.

## 8. Patrimônio / RSU / CIPÓ / Volvo
### RSU
- [x] Canonical Patrimônio route consumes `lts_browser_wealth_detail_v1`.
- [x] Vested 459.483 units / R$32.772,30 / D+3; future awards excluded.
- [x] Sale 283 units settled 05/08/2026: theoretical gross R$19.673,72; net R$19.095,04.
- [ ] R$578,68 historical sale difference remains unexplained/unitemized.

### FGTS temporal distinction
- [x] 21/04/2026 R$25.585,03 and 07/05/2026 full withdrawal are historical positions.
- [x] 21/07/2026 R$17.509,05 is an intermediate position.
- [x] 21/08/2026 R$22.432,31 is the latest documentary balance evidenced.
- [x] Keep temporal positions distinct; do not sum snapshots.
- [x] No future FGTS accrual estimation.

### CIPÓ 396
- [x] Drilldown exposes purchase/history/reforms/debt/market estimate/equity/schedule where evidence exists.
- [x] Ledger audit establishes separate actual consortium entries: R$6.654,50 on 12/05/2023 and R$151,80 on 15/05/2023; do not describe them as same-date documentary arithmetic.
- [ ] Itaú/consortium delta R$303,60 remains unresolved; recovered R$303,60 Visa Infinite rows are not valid consortium evidence.
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
- [x] Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948` retained as historical baseline evidence.
- [x] v14 293/293; v15 67/67; v16 19/19; v17 32/32; staged 411 checks / 35 suites + supplemental v143 16/16.
- [x] v146 navigation regression: 10 × 7 destinations × desktop/mobile = 140 physical clicks historical evidence.
- [x] Canonical gate `34003647351` covers single-frontend Chromium/WebKit functional behavior and truthful no-fixture auth fallback.
- [x] Exact Pages deployment for canonical homologation exposure `34003976631`: SUCCESS.
- [ ] Authenticated physical-device financial/data E2E remains open and explicitly unclaimed.
- [~] Continue performance work after correctness/parity; transaction search now uses server-side filtering rather than larger broad fetch.

## 11. Historical continuity / backups / product quality
- [~] Continue audit back to project start 07/07/2026 so no pending item disappears.
- [x] Preserve historical evidence from 2013 where supported.
- [x] Preserve fixed public/homologation links and canonical backup/restore traceability.
- [x] Canonical deterministic evidence preserves official-reference Dashboard language, compact Atualizações and mobile/desktop no-overflow behavior.
- [~] Continue real-data/product-quality refinement without reintroducing wrapper chains.

## 12. Current user-dependent decisions / blockers
- [ ] Authenticated physical-iPhone financial/data E2E of current canonical app when material real-device validation becomes the final gate.
- [ ] Human classification only where evidence remains insufficient.
- [ ] New money-changing assumptions not already explicitly supplied by the user.
- [ ] Append-only reversal semantics before cancellation/reversal UI if existing backend semantics do not already prove the required audit behavior.
- [ ] Volvo refinement when exact trim/km evidence is available.
- [ ] Open Finance provider/consent/spend decisions.
- [ ] Public promotion only after explicit user approval.

Until one of these is the genuine blocker, continue autonomous technical/documentary work and test before asking the user to inspect anything.
