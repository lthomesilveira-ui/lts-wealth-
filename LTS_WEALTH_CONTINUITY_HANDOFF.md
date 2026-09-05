# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-09-05 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before every repository write.

## Conduct
- Preserve every open financial, documentary, classification, reconciliation and product dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, recurrence, reconciliation, valuation, tax or economic-effect rules.
- Ask the user only when a real financial/classification/documentary decision is required; otherwise advance autonomously.
- Test before user homologation; do not delegate basic QA.
- Never claim authenticated visual/data E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Never force branch divergence; use normal fast-forward/merge only after fresh compare.
- Preserve historical evidence back to 2013 where supported.

## Fixed links / access
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Supabase project: `tadhkamnwtsbdozwkyut`.
- Public fallback remains WIP35-v136; protected `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized/not done.

## Current release — v160 real-data bridge / truthful fallback
- v154 established the accepted official-reference visual direction.
- v155 corrected false-zero/navigation defects but later showed runtime slowness.
- v156 removed permanent runtime churn and established the liquidity-first Dashboard, but real iPhone homologation showed no financial data and inoperable routes.
- v157 targeted WebKit and passed deterministic gates, but real-iPhone evidence rejected it.
- v158 removed the shadow financial Dashboard and recovered truthful native/auth fallback through the existing nested core.
- v159 improved prototype/mobile presentation and six-route fit, but real-iPhone evidence still showed all five liquidity-first KPIs as `—`.
- v160 corrects the release-readiness defect exposed by v159: a Dashboard is not considered ready unless material financial cockpit data exists.
- Source branch: `v160-real-data-bridge`.
- Candidate: `wip35-v160-candidate.html`.
- Final staged candidate head: `9f49c8637796d0e56b012896bedb55f5e29259c1`.
- Controlled exposure commit: `cbc4bc9d7e4798a9e97b80feb7510af535ac6d43`.
- `homologacao-current.json` points to v160 and `promotion_status:not_promoted`.
- Branch v160 Chromium/WebKit run `33991299085`: SUCCESS.
- Exact-main v160 run `33992238668`: SUCCESS.
- Exact GitHub Pages run `33992238643`: SUCCESS.
- Immutable checkpoint: `backups/WIP35_V160_REAL_DATA_BRIDGE_HOMOLOGATION_CHECKPOINT_2026-09-05.md`.
- Authenticated physical-iPhone financial/data E2E remains pending/not claimed.

## v160 runtime contract
- Keep the liquidity-first/official-reference Dashboard baseline rather than inventing a new product architecture.
- Recursively traverse the bounded same-origin frame chain to find the existing application state and RPC-capable layer.
- Reuse existing read-only RPC `lts_browser_dashboard_cockpit_v1` when financial cockpit data is not already present.
- Prototype Dashboard can become visible only after material financial data exists.
- If material cockpit data is unavailable, the native/login/core state must surface; a prototype Dashboard containing only `—` is forbidden as a successful state.
- v160 owns the six candidate route controls exclusively to prevent nested navigation-handler races.
- Six routes remain: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- Mobile navigation remains one fixed six-item row without clipping/overflow.
- `synthetic_financial_values_added:false`; v160 does not fabricate user-facing financial values.
- No financial/backend writer is introduced.
- No `document.write`, permanent `setInterval` or `MutationObserver` is introduced.
- Public `index.html` is unchanged.

## Deterministic evidence / limits
- Branch run `33991299085` validates Chromium desktop and WebKit iPhone-equivalent controlled bridge behavior, all five KPI slots, six physical route controls, Dashboard return, candidate route ownership, no clipping and no horizontal overflow.
- No-fixture branch gate verifies truthful fallback: absent material cockpit data, the empty prototype Dashboard cannot remain exposed and the native/core state remains visible.
- Exact-main run `33992238668` passed on exposure head `cbc4bc9d7e4798a9e97b80feb7510af535ac6d43`.
- Exact GitHub Pages deployment `33992238643` passed on the same exposure head.
- CI is unauthenticated and cannot prove the user's actual authenticated financial session. Do not reinterpret these results as authenticated physical-device E2E.

## Official visual / Dashboard target
- Original Dashboard source: 1312×1199; SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`.
- Product target remains dark desktop rail, light dense executive canvas, compact spacing and persistent usable mobile navigation.
- Liquidity-first hierarchy remains: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`; pending actions secondary.
- Visual reference defines hierarchy/density/language, not financial values.

## Current financial/product invariants
### Dashboard / Planning / FGTS
- Primary liquidity is available realizable through D+3; bank cash, D0 and vested RSU D+3 remain separated.
- `Contas + curto prazo` arithmetic may use only evidenced components: `bank_cash + d0` when both exist, otherwise `through_d3 - vested` only when both exist; missing evidence stays unavailable.
- FGTS exact documentary balance: R$22.432,31 at 21/08/2026; restricted/approximately D+30; never D+3.
- No future FGTS deposits/accrual are projected.
- Historical R$17.509,05 + R$3.700/month and dependent R$32.309,05 request-date / old worst-case figures are historical evidence only.
- Revalidate first-negative and management/action dates under the conservative rule and display them separately when different.
- Future RSUs remain excluded until vest/settlement.

### Despesas
- Invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Nature and context/person/cost center are distinct dimensions.
- Periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- Context→nature and nature→context drilldowns are read-only and show detail only where evidence exists.
- Evidence hierarchy: explicit user rule → exact/consistent LTS history → public merchant research → manual review.
- Marketplaces/intermediaries stay manual where purchase purpose is unproven.
- Density/ranking/decision-useful insights and evidence-only reduction of `A classificar` remain open.

### Atualizações / search / documents
- Atualizações remains a compact action center/checklist; no large blank whitespace or buried actions.
- `Lançamento por texto` routes to existing `Entradas` preview; no automatic posting; explicit approval required.
- Server-side transaction search through `lts_browser_transactions_v1` remains in progress: incremental typing, supported history from 10/10/2013 + future existing launches, total, read-only results, Excel-compatible CSV export.
- Backend evidence for `Mastercard`: 239 rows from 01/11/2013 to 12/04/2028.
- Filename never infers account/card/competence/date/value and upload alone never posts financial facts.
- Real authenticated PDF/image interpret→review remains pending.

### Fluxo Diário / liquidity input
- Mandatory Itaú, Bradesco, C6 and Consolidado; history from 2013 where supported.
- `Saldo anterior | Entradas | Saídas | Saldo final`; facts > projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed their own forecast.
- Bank↔liquidity-asset transfer consolidated economic effect zero.
- Natural input parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`; never guess account/asset; preview before explicit confirmation.
- Authenticated save→refresh→visible and append-only reversal semantics remain open.

### Cards / RSU / CIPÓ / Volvo
- Cards certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- Mastercard/Visa incomplete historical months remain documentary-recovery work; never pattern-fill.
- RSU vested 459.483 units / R$32.772,30 / D+3; 283-unit sale net R$19.095,04; R$578,68 remains unexplained/unitemized.
- CIPÓ unresolved: consortium R$303,60 delta; different-date arithmetic R$6.654,50 = R$6.502,70 + R$151,80; condominium source absent; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70. Never fabricate post-2029 TR or automatically treat market-minus-cost as taxable/net gain.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031 exactly once economically; exact trim/km remains open before valuation refinement.

### Open Finance / QA
- Provider-neutral private architecture QA 14/14; no real consent/token/provider.
- Need written pricing/support/SLA/product×bank for Itaú/Bradesco/C6; no provider commitment without explicit user decision.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites + supplemental v143 16/16.
- v146 navigation regression 140 physical Playwright clicks remains historical evidence; v160 adds evidence-driven financial readiness, exclusive route ownership and truthful fallback gates.

## Current material state
- v160 is technically delivered to the fixed homologation URL with branch, exact-main and exact-Pages deterministic gates green.
- The invalid success condition seen on v159 — visible Dashboard with five `—` KPIs — is no longer accepted by the release layer.
- Authenticated physical-iPhone financial/data E2E remains an explicit evidence gap and must not be claimed as completed.
- Public promotion is separate and requires explicit user authorization.

## Open backlog that must always remain visible
- Authenticated physical-iPhone financial/data E2E when material real-device evidence is needed.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation→review.
- Natural liquidity authenticated save→refresh→visible.
- Append-only cancellation/reversal semantics.
- Server-side transaction search + total + Excel-compatible CSV.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary recovery.
- Planning/FGTS recalculation under no-future-accrual rule, separating first-negative and management/action dates.
- CIPÓ consortium R$303,60 delta; different-date arithmetic R$6.654,50 = R$6.502,70 + R$151,80; condominium source; raw R$1.780.358 / dedup R$1.312.268 gaps; duplicate excess R$3.531,70; no fabricated post-2029 TR; no automatic taxable/net-gain conclusion.
- Volvo exact trim/km.
- Open Finance pricing/SLA/product×bank; no provider/consent/spend decision without explicit user authorization.
- Public promotion only after explicit user approval.
- Performance only after correctness/parity.
- Audit of all project dependencies/improvements since 07/07/2026 so none disappear across chats.
- Preserve official-reference visual language, compact Atualizações, no large whitespace regressions, mobile/desktop usability, fixed links, backup and traceability.
