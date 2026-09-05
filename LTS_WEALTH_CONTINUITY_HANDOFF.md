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

## Current release — v158 native-core/auth/mobile recovery
- v154 established the accepted official-reference visual direction.
- v155 corrected false-zero/navigation defects but later showed runtime slowness.
- v156 removed permanent runtime churn and established the liquidity-first Dashboard, but real iPhone homologation showed no financial data and inoperable routes.
- v157 targeted WebKit and passed deterministic gates, but material real-iPhone evidence rejected it: top financial KPIs remained `—`, `Despesas (mês)` status text overlapped and bottom navigation was clipped with `Atualizações` not fully accessible.
- The v157 screenshot was captured inside an Instagram in-app browser context. Do not assume from that alone whether authentication was shared with Safari/another context.
- The definite v157 product defect was that its synthetic/shadow Dashboard could mask the native core authentication/data state behind an empty financial presentation.
- v158 removes that shadow financial Dashboard. The candidate layer owns no financial KPI values.
- Source branch: `v158-native-core-auth-mobile-recovery`.
- Candidate: `wip35-v158-candidate.html`.
- Branch staged head: `ecc7feb534921a93ac54064cd7e743d841a2486c`.
- Controlled exposure head: `aa5495f0cb230acc9d167f5577e1c5576641efc5`.
- `homologacao-current.json` points to v158 and `promotion_status:not_promoted`.
- Branch v158 native-core/WebKit run `33973465268`: SUCCESS.
- Exact-main/exposure v158 run `33973672077`: SUCCESS.
- Exact exposure GitHub Pages run `33973671958`: SUCCESS.
- Immutable checkpoint: `backups/WIP35_V158_NATIVE_CORE_AUTH_MOBILE_RECOVERY_CHECKPOINT_2026-09-05.md`.
- Authenticated real-device/data E2E remains pending/not claimed.

## v158 runtime contract
- Load exactly one full-screen same-origin native/proven core through `index.html?v158-native-core`.
- Native core owns authentication, financial data, state and route behavior.
- Unauthenticated browser context must expose native login rather than a synthetic Dashboard full of dashes.
- Authenticated context must expose native app/data; candidate must not synthesize financial values.
- Mobile adaptation is limited to one fixed row of six established routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- No `document.write`, permanent `setInterval` or `MutationObserver`; bounded retry burst only.
- Public `index.html` itself is not changed by v158.

## Deterministic evidence / limits
- v158 WebKit iPhone-equivalent gate validates exactly one native core frame, zero top-level synthetic KPI cards, truthful native authentication state, no top-level horizontal overflow and mobile single-row navigation policy.
- Chromium desktop native-core smoke passes.
- CI is unauthenticated and cannot prove the user's actual financial session. Do not reinterpret this as authenticated E2E.

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
- v146 navigation regression 140 physical Playwright clicks remains historical evidence; v158 adds native-core/auth-truth/WebKit mobile gates.

## Current material gate
- Real authenticated physical-iPhone homologation of v158 is the current release gate.
- Expected behavior is truthful: browser context without session shows native login; authenticated context shows native app/data.
- After authentication, Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard must work without clipping, dead controls or route traps.
- Public promotion is separate and requires explicit user authorization.

## Open backlog that must always remain visible
- Material authenticated physical-iPhone homologation of current v158 candidate.
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