# WIP35 v156 performance + liquidity homologation checkpoint — 05/09/2026

## Trigger / user evidence
- User approved the v154/v155 visual direction but rejected v155 as product-ready because the real page became slow and Chrome displayed `This page isn't responding`; the same family of slowness had also appeared on mobile.
- User requested a liquidity-first Dashboard: money in bank accounts; bank + short-term resources; vested RSUs; FGTS; monthly expenses retained as a useful consolidated KPI; pending actions demoted; cash/liquidity chart with R$ scale; patrimônio líquido/distribution moved lower; bank position retained; commitments/FGTS interpreted rather than merely listed.

## Root cause / performance correction
- v154 had a permanent source poll that repeatedly called `render()` and rebuilt the Dashboard.
- v155 added a `MutationObserver` plus a 500 ms `setInterval`, repeatedly traversing nested frames and patching the DOM.
- v156 removes the permanent runtime churn: no `setInterval`, no `MutationObserver`, source polling is bounded to at most 30 attempts and stops once the read model is available; route retries occur only after an explicit navigation action and are bounded.
- The visual language remains the official-reference dark-rail/light-executive-canvas design; architecture was not restarted.

## v156 Dashboard contract
- Top KPIs are now `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, and `Despesas (mês)`.
- Pending actions are a compact shortcut rather than a primary KPI.
- `Evolução da Liquidez` has an explicit R$ scale and separately labels current accounts, short-term liquidity, vested RSUs, and FGTS.
- `Distribuição do Patrimônio` and `Patrimônio Líquido` are moved below the liquidity cockpit and treated as secondary strategic context.
- Current liquidity composition explicitly separates bank cash, bank + short-term, vested RSU D+3, and restricted FGTS D+30.
- No financial/backend writer was added.

## Financial invariants
- FGTS latest documentary balance remains R$22.432,31 as of 21/08/2026.
- FGTS remains restricted / approximately D+30 and is never D+3.
- No future FGTS deposit/accrual projection is introduced.
- `Contas + curto prazo` is arithmetic only over already-evidenced components: `bank_cash + d0` when both exist; otherwise `through_d3 - vested` only when both exist. Missing evidence remains unavailable rather than being invented.
- Facts remain above projections; scenarios are never facts.

## Deterministic performance / browser evidence
- Branch: `v156-performance-liquidity-dashboard`.
- Product / branch exact head: `3b1c61e5a9a1b594aad27884ad92288da35067ed`.
- Branch full v156 run `33968053985`: SUCCESS after correcting a test-only hidden-selector issue from the preceding run; static, desktop/mobile performance gate, no-fixture responsiveness smoke and artifact upload all passed.
- Exact-main v156 run `33968206767`: SUCCESS.
- Exact exposure v156 run `33968329277`: SUCCESS.
- Exact exposure Pages run `33968329012`: SUCCESS; build, deploy and report jobs all succeeded.
- Desktop 1312×1199 and mobile 390×844 steady-state tests remained stable for 12 seconds with bounded polling, no repeated Dashboard patching, no material DOM churn and no page-level horizontal overflow.
- Both deterministic views physically navigate Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard.
- Additional no-fixture mobile smoke remained responsive for 12 seconds and physically opened Fluxo Diário. CI had no authenticated financial session, so this is not authenticated financial/data E2E.

## Integration / exposure
- v156 was integrated to `main` by normal fast-forward, force=false.
- Controlled homologation exposure commit: `f3e0fde39d81a38f2d95c3f39e954b333e2482d9`.
- `homologacao-current.json` points to `v156` / `wip35-v156-candidate.html` with `promotion_status:not_promoted`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Protected public `index.html` remains unchanged; public promotion remains unauthorized/not done.

## Current material gate
- User should leave the real authenticated v156 open for at least 20–30 seconds and confirm the prior `page isn't responding` symptom does not recur.
- Then physically verify Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard and assess the liquidity-first hierarchy / scaled chart with real data.
- Authenticated visual/data E2E remains pending and is explicitly not claimed.

## Open dependencies preserved
- Server-side incremental transaction search + total + Excel-compatible CSV.
- Planning/FGTS recalculation under the no-future-accrual rule, with first-negative and management/action dates separated.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Authenticated classification lifecycle; authenticated PDF/image interpret→review; natural-liquidity save→refresh→visible.
- Append-only auditable cancellation/reversal semantics.
- Mastercard/Visa documentary recovery.
- CIPÓ unresolved documentary/reconciliation gaps remain unchanged.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank and any consent/spend/provider decision.
- Historical pending-item audit back to 07/07/2026.
- Public promotion only after explicit user authorization.
