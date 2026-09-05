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
- Public fallback remains WIP35-v136; protected `index.html` blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized/not done.

## Current release — v157 fixed homologation
- v154 established the accepted official-reference visual direction.
- v155 corrected false-zero and deterministic navigation defects but introduced runtime churn/slowness.
- v156 removed the permanent churn and established the liquidity-first Dashboard, but real iPhone homologation rejected it because financial data did not load and navigation remained inoperable.
- v157 is the dedicated iOS/WebKit recovery; architecture was not restarted.
- Source branch: `v157-ios-webkit-nav-recovery`.
- Candidate: `wip35-v157-candidate.html`.
- Product candidate commit: `c88955095a9e07de72b11921cdc45a7edce7f6a0`.
- WebKit workflow commit: `89c5be2915936e8838c7322a045a0636c46012dd`.
- Integrated/exposed main SHA: `cb0b4420c030c6336db59249e11bf1307e9ce500`.
- `homologacao-current.json` points to v157 and `promotion_status:not_promoted`.
- Branch WebKit runs `33970332769` and `33970468539`: SUCCESS.
- Exact-main v157 WebKit run `33970591125`: SUCCESS.
- Exact-main Pages run `33970589882`: SUCCESS.
- Immutable checkpoint: `backups/WIP35_V157_IOS_WEBKIT_HOMOLOGATION_CHECKPOINT_2026-09-05.md`.
- Authenticated real-device/data E2E remains pending/not claimed.

## v157 iOS/WebKit contract
- Static official-reference shell; no runtime fetch/string reconstruction of `wip35-v154-candidate.html`.
- No `document.write`, permanent `setInterval` or `MutationObserver`.
- Existing same-origin core is loaded through `wip35-v151-candidate.html?v157-parent`.
- Boot, financial-model read and route retries are bounded; steady state has no permanent polling loop.
- Mobile navigation remains persistent across Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações.
- Null-safe numeric parsing remains mandatory: missing evidence stays missing/`—`; never fabricate R$0,00.
- `Contas + curto prazo` may use only evidenced arithmetic: `bank_cash + d0` when both exist, otherwise `through_d3 - vested` only when both exist.
- No financial/backend writer was added by v157.

## Deterministic evidence / limits
- WebKit iPhone-equivalent 390×844 touch gate physically navigated Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard.
- WebKit fixture-backed Dashboard loaded all five liquidity-first KPIs.
- WebKit steady state remained responsive for 20 seconds with no repeated Dashboard patching, material DOM churn or page-level horizontal overflow.
- WebKit no-fixture smoke booted the existing core, remained responsive for 12 seconds and physically opened Fluxo Diário.
- Chromium desktop 1312×1199 parity smoke passed.
- CI is unauthenticated and cannot reproduce the user's authenticated session or exact physical iPhone runtime. Do not reinterpret deterministic WebKit evidence as authenticated financial correctness.

## Official visual / Dashboard contract
- Original Dashboard source: 1312×1199; SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`.
- Preserve dark desktop rail, light executive canvas, five-KPI first row, dense multi-row executive cockpit, compact cards and persistent mobile navigation.
- Visual reference defines hierarchy/density/language, not financial values.
- Current top KPIs: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`.
- Pending actions are secondary/compact rather than a primary KPI.
- `Evolução da Liquidez` keeps an explicit R$ scale; patrimônio líquido/distribution remain secondary strategic context.

## Current financial/product invariants
### Dashboard / Planning / FGTS
- Primary liquidity is available realizable through D+3; bank cash, D0 and vested RSU D+3 remain separated.
- FGTS exact documentary balance: R$22.432,31 at 21/08/2026; restricted/approximately D+30; never D+3.
- No future FGTS deposits/accrual are projected.
- Historical R$17.509,05 + R$3.700/month and dependent R$32.309,05 request-date / old worst-case figures are historical model evidence only, not current validated forecast.
- Revalidate first-negative and management/action dates under the current conservative rule and display them separately when different.
- Future RSUs remain excluded until vest/settlement.

### Despesas
- Invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Nature and context/person/cost center are distinct dimensions.
- Periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- Context→nature and nature→context drilldowns are read-only and show detail only where evidence exists.
- Evidence hierarchy: explicit user rule → exact/consistent LTS history → public merchant research → manual review.
- Marketplaces/intermediaries stay manual where purchase purpose is unproven.
- Density/ranking/decision-useful insights and evidence-only reduction of `A classificar` remain open refinement work.

### Atualizações / search / documents
- Atualizações remains a compact action center/checklist; avoid large blank whitespace and buried actions.
- `Lançamento por texto` routes to existing `Entradas` preview; no automatic posting; explicit approval remains required.
- Server-side transaction search through `lts_browser_transactions_v1` remains in progress: incremental typing, supported history from 10/10/2013 + future existing launches, total, read-only results, Excel-compatible CSV export.
- Backend evidence for `Mastercard`: 239 rows from 01/11/2013 to 12/04/2028.
- Explicit document association and review contracts remain; filename never infers account/card/competence/date/value and upload alone never posts financial facts.
- Real authenticated PDF/image interpret→review remains pending.

### Fluxo Diário / liquidity input
- Mandatory Itaú, Bradesco, C6 and Consolidado; preserve history from 2013 where supported.
- `Saldo anterior | Entradas | Saídas | Saldo final`; facts > projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed own forecast.
- Bank↔liquidity-asset transfer consolidated economic effect zero.
- Natural input parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`; never guess account/asset; preview before explicit confirmation.
- Authenticated save→refresh→visible and append-only reversal semantics remain open.

### Cards / RSU / CIPÓ / Volvo
- Cards certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- Mastercard/Visa incomplete historical months remain documentary-recovery work; never pattern-fill.
- RSU vested 459.483 units / R$32.772,30 / D+3; 283-unit sale net R$19.095,04; R$578,68 difference remains unexplained/unitemized.
- CIPÓ unresolved: consortium R$303,60 delta; different-date arithmetic R$6.654,50 = R$6.502,70 + R$151,80; condominium source absent; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70. Never fabricate post-2029 TR or automatically treat market-minus-cost as taxable/net gain.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031 exactly once economically; exact trim/km remains open before valuation refinement.

### Open Finance / QA
- Provider-neutral private architecture QA 14/14; no real consent/token/provider.
- Need written pricing/support/SLA/product×bank for Itaú/Bradesco/C6; no provider commitment without explicit user decision.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites + supplemental v143 16/16.
- v146 navigation regression remains 140 physical Playwright clicks.
- v157 adds WebKit iPhone-equivalent route/steady-state/no-fixture boot evidence on top of the existing deterministic QA baseline.

## Current material gate
- Real authenticated iPhone homologation of v157 is required because v156 failed specifically on the user's physical device/session despite deterministic browser evidence.
- The user check is intentionally narrow: real financial data must load, page must remain responsive, and Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard must work.
- Public promotion remains separate and requires explicit user authorization.

## Open backlog that must always remain visible
- Material authenticated real-iPhone homologation of current v157 fixed candidate.
- Real authenticated visual/data E2E.
- Public promotion only after explicit user approval.
- Real authenticated PDF/image interpretation→review.
- Real authenticated classification lifecycle.
- Natural liquidity authenticated save→refresh→visible.
- Append-only cancellation/reversal semantics.
- Server-side transaction search + total + Excel-compatible CSV.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary recovery.
- All CIPÓ blockers listed above.
- Volvo exact trim/km.
- Open Finance pricing/SLA/product×bank.
- Planning/FGTS recalculation under no-future-accrual rule.
- Performance only after correctness/parity.
- Audit of all project dependencies/improvements since 07/07/2026 so none disappear across chats.
- Preserve official-reference visual language, compact Atualizações, no large whitespace regressions, mobile/desktop usability, fixed links, backup and traceability.