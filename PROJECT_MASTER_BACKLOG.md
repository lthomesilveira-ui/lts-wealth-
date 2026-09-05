# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Never remove an open financial, documentary, classification, reconciliation or product dependency during compaction. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and release checkpoints.

## P0 — current release v158 — 05/09/2026
- [x] v154 established the accepted official-reference visual direction; v155 corrected false-zero/navigation defects; v156 removed permanent runtime churn and established the liquidity-first Dashboard.
- [x] v157 attempted a WebKit-specific recovery, but real iPhone evidence rejected it: financial KPIs remained unavailable, `Despesas (mês)` status text overlapped, and the bottom navigation was clipped with `Atualizações` not fully accessible.
- [x] The real-device screenshot was captured in an Instagram in-app browser context. This does not prove whether that context shared the user's authenticated session; however, it proved the v157 shadow Dashboard was masking the native auth/data state behind an unusable empty financial presentation.
- [x] v158 removes the shadow financial Dashboard. Candidate `wip35-v158-candidate.html` loads exactly one full-screen native/proven core through `index.html?v158-native-core`; the native core owns authentication, financial data and routes.
- [x] Unauthenticated browser context must expose native login rather than fake KPI dashes; authenticated context must expose the native app/data.
- [x] Mobile adaptation is limited to the six established routes in one fixed row: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações. No top-level financial values are synthesized.
- [x] No `document.write`, permanent `setInterval` or `MutationObserver`; bounded retry burst only.
- [x] Source branch `v158-native-core-auth-mobile-recovery`; branch staged head `ecc7feb534921a93ac54064cd7e743d841a2486c`.
- [x] Branch v158 native-core/WebKit gate `33973465268`: SUCCESS.
- [x] v158 integrated by normal fast-forward; no force. Controlled exposure commit `aa5495f0cb230acc9d167f5577e1c5576641efc5`.
- [x] Exact-main/exposure v158 gate `33973672077`: SUCCESS.
- [x] Exact exposure Pages `33973671958`: SUCCESS.
- [x] `homologacao-current.json` points to v158 / `wip35-v158-candidate.html` / `promotion_status:not_promoted`.
- [x] Immutable checkpoint: `backups/WIP35_V158_NATIVE_CORE_AUTH_MOBILE_RECOVERY_CHECKPOINT_2026-09-05.md`.
- [x] Public `index.html` remains protected and unchanged; public promotion is NOT authorized.
- [ ] Material authenticated physical-iPhone homologation of v158: native login if needed; after authentication real data must load and all six routes must work without clipping/traps.
- [ ] Real authenticated visual/data E2E remains pending and must not be claimed.

## P0 — FGTS documentary refresh / conservative rule
- [x] Latest exact documentary balance: **R$22.432,31 as of 21/08/2026**.
- [x] FGTS remains restricted / approximately D+30 contingency when accessible, never D+3 cash.
- [x] No future FGTS deposit/accrual estimation under the current user rule.
- [~] Reconcile Planning/FGTS bridge under the no-future-accrual rule before relying on request-date coverage conclusions.
- [ ] Historical values based on R$17.509,05 + R$3.700/month, including R$32.309,05 request-date FGTS and dependent worst-case figures, remain historical evidence only and must never be presented as current validated forecast.

## 0. Release / homologation guardrails
- [x] Public root: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- [ ] Never force branch history or overwrite parallel work.
- [ ] Before every repository write, re-fetch `main`, active branch, this backlog, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and latest immutable checkpoint.
- [ ] Never promote `index.html` without explicit user authorization.
- [ ] Never claim authenticated visual E2E unless actually performed.
- [ ] Preserve fixed links, mobile/desktop usability, backup and traceability through every release.

## 1. Dashboard / planejamento incorporado
- [x] Product framing: `Sua vida financeira, em uma tela.`.
- [x] Primary liquidity: available realizable through D+3; bank cash, D0 and vested RSU D+3 stay separated.
- [x] Liquidity-first hierarchy: dinheiro em contas; contas + curto prazo; vested RSUs; FGTS; despesas do mês. Pending actions remain secondary.
- [x] `Contas + curto prazo` arithmetic is evidence-only: `bank_cash + d0` when both exist, otherwise `through_d3 - vested` only when both exist; missing evidence stays unavailable.
- [x] FGTS separate/restricted; never current D+3 cash.
- [x] Redundant top-level Planejamento removed; planning remains inside Dashboard/liquidity view.
- [~] Revalidate first-negative date and management/action date under the current conservative FGTS rule; show both separately when they differ.
- [x] Future RSUs excluded before vest/settlement.
- [ ] Any new money-changing assumption/scenario requires explicit user decision unless already explicitly stated by the user.

## 2. Despesas — natureza × contexto/pessoa
- [x] Economic invariant R$8.623.752,53 preserved.
- [x] Analytical cache 3.860/3.860, zero mismatch.
- [x] Nature and context/person/cost center remain distinct analytical dimensions.
- [x] Periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- [x] Context→nature and nature→context read-only drilldown only where detail exists.
- [x] `Não atribuído` distinguishes documentary detail not recovered, system investigation, and classification/context pending.
- [~] Improve density, ranking and decision-useful insights.
- [~] Reduce `A classificar` only by evidence, never invention.

## 3. Classification evidence hierarchy
1. explicit user-confirmed rule;
2. exact/consistent LTS history;
3. public merchant research;
4. manual review if ambiguity remains.

- [x] Merchant research never invents purchase purpose.
- [x] Marketplaces/intermediaries remain manual where actual purchase purpose is unproven.
- [x] Existing writer `lts_browser_semantic_feedback_v1`; reader `lts_browser_product_v1`.
- [x] Synthetic lifecycle covers save→refresh→resolved disappearance/read-only retry/`O que mudou`.
- [ ] Real authenticated classification lifecycle remains pending.

## 4. Atualizações / Input / documents / transaction search
- [x] Atualizações remains a compact checklist/action center; no large blank whitespace or buried actions.
- [x] `Lançamento por texto` continues to existing `Entradas` preview; no automatic posting.
- [x] Date/value/account-or-card mandatory before approval; liquidity/RSU movements are not revenue/expense.
- [~] Replace timeout-prone broad Flow lookup with server-side incremental transaction search through `lts_browser_transactions_v1`.
- [~] Search scope: supported history from 10/10/2013 onward plus future launches already present in LTS.
- [~] Search must remain read-only, expose total, and export all matches to Excel-compatible CSV preserving available date, description, account, direction, amount, category, counterparty, cost center and source/reference.
- [x] Backend evidence for `Mastercard`: 239 matching rows spanning 01/11/2013 to 12/04/2028.
- [x] Explicit document association preserved: bank statement → account/institution + competence; card statement → card + competence; financing → commitment + exact as-of; other docs → manual review.
- [x] Filename never determines account/card/competence/date/value; upload alone never posts financial data.
- [x] Interpretation separates `Vínculo informado por você` from `Leitura do arquivo · revisar`; extraction remains evidence only.
- [ ] Real authenticated PDF/image interpret→review remains pending/unclaimed.

## 5. Fluxo Diário / FIX86
- [x] Mandatory Itaú, Bradesco, C6 and Consolidado; history from 2013 where evidence exists.
- [x] Hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`; balances visually differentiated.
- [x] Facts beat projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed their own forecast.
- [x] Bank↔liquidity-asset transfer consolidated economic effect zero.
- [ ] Never infer historical bank without evidence.
- [ ] Real authenticated visual/data E2E remains open.

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
- [~] Mastercard 2023: 12 ledger-only payments / R$496.689,05; independent category matrix absent.
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
- [x] 21/07/2026 R$17.509,05 is an intermediate position.
- [x] 21/08/2026 R$22.432,31 is the latest documentary balance evidenced.
- [x] Keep temporal positions distinct; do not sum snapshots.
- [x] No future FGTS accrual estimation.

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
- [x] v155 false-zero/navigation deterministic gate passed; v156 performance gate removed permanent runtime churn; v157 WebKit deterministic gate passed but was superseded by real-device failure evidence.
- [x] v158 gate validates native-core ownership, truthful auth state, no shadow financial Dashboard, one native frame, WebKit mobile no-overflow policy and Chromium desktop smoke.
- [~] Performance work only after correctness/parity; transaction search must solve timeout by server-side filtering rather than larger broad fetch.

## 11. Historical continuity / backups / product quality
- [~] Continue audit back to project start 07/07/2026 so no pending item disappears.
- [x] Preserve historical evidence from 2013 where supported.
- [x] Preserve fixed public/homologation links and canonical backup/restore traceability.
- [~] Preserve balance visual emphasis, compact Atualizações, official-reference Dashboard language, no large whitespace regressions, mobile/desktop usability.

## 12. Current user-dependent decisions / blockers
- [ ] Material authenticated physical-iPhone homologation of current v158 fixed candidate.
- [ ] Human classification only where evidence remains insufficient.
- [ ] New money-changing assumptions not already explicitly supplied by the user.
- [ ] Append-only reversal semantics before cancellation/reversal UI.
- [ ] Volvo refinement when exact trim/km evidence is available.
- [ ] Open Finance provider/consent/spend decisions.
- [ ] Public promotion only after explicit user approval.

Until one of these is the genuine blocker, continue autonomous technical/documentary work and test before asking the user to inspect anything.