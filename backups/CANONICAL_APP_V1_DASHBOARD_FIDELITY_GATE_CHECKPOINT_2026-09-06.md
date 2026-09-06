# LTS Wealth — Canonical App v1 Dashboard fidelity gate checkpoint — 06/09/2026

## Purpose
Immutable evidence for the first visual-fidelity refinement of the single canonical Dashboard after the liquidity UI package, preserving the existing financial/read-model contract and the protected public fallback.

## Source state
- Gated source commit: `6126bfbf108be1f3206279723425a5435c5e2631`.
- Post-gate cleanup head: `aec1059ef40a0fe1a7c6c5fe560936abef0b87d0`; cleanup only removed the one-shot integrator.
- `canonical-app.html` blob: `b16aa50d54d7f7253129a4d15cc281efe2b45b92`.
- `canonical-dashboard-fidelity.css` blob: `c45416536c79a35a7f8547acab4a52c07e4ddf50`.
- Permanent gate workflow includes the fidelity stylesheet in its path/static/browser contract.
- Protected public `index.html` remains unchanged; public-root promotion is not authorized.

## Scope
Presentation-only fidelity work:
- desktop left rail width/density refined;
- Dashboard header and KPI framing refined;
- three Dashboard grid bands resized toward the approved executive composition;
- wealth/distribution/bank panels tightened;
- cash-flow, expense, commitment, planning, FGTS and pending-update panels rebalanced;
- expense-ranking black border regression removed;
- mobile card geometry kept responsive without changing the six physical routes.

No financial formula, classification, backend RPC, liquidity contract, planning invariant, documentary evidence or public-root behavior was changed by this package.

## Deterministic gate
GitHub Actions run `34056854438`: **SUCCESS**.
- Chromium desktop: 1312×1199.
- WebKit mobile: 390×844.
- Static contract: PASS.
- Browser contract: PASS.
- Dashboard fidelity stylesheet loaded: PASS.
- Dashboard nine-panel density assertion: PASS.
- Expense-ranking border regression assertion: PASS.
- Five liquidity-first KPIs: PASS.
- Six routes: PASS.
- Fluxo account switching: PASS.
- Despesas dual lens/drilldown: PASS.
- Patrimônio/Cartões: PASS.
- Atualizações search/CSV/classification/documents/liquidity preview: PASS.
- Horizontal overflow / iframe / unauthenticated truth: PASS.

Artifact `9996230152`, digest `sha256:57755a6347d756b743eb8668863b62002fc065d590378ac18800a964b0c5d8d0`.
Visual evidence includes `canonical-desktop.png`, `canonical-mobile.png` and `canonical-updates.png`.

## Visual review against approved reference
The gated desktop screenshot is materially closer to the approved reference in panel proportions, spacing, executive density, distribution/bank balance and bottom planning/FGTS/update composition. The prior heavy black borders in Principais Despesas are removed.

This is not recorded as pixel-perfect parity. Remaining differences are intentionally kept open rather than fabricated: the approved reference has richer navigation and some chart/KPI detail that the canonical product will only show when backed by real product routes/data. No fake modules or fake financial series were introduced to imitate the reference.

## Truth boundaries
- Deterministic fixture is test-only and does not prove authenticated financial writes.
- Real authenticated liquidity save→refresh→visible remains pending.
- Authenticated physical-iPhone visual/data E2E remains pending and is not claimed.
- Public `index.html` remains protected/not promoted.

## Next
After normal no-force integration and fixed-homologation exposure, continue the Dashboard fidelity P0 on the same canonical architecture, prioritizing real-data visual richness and avoiding synthetic financial facts.
