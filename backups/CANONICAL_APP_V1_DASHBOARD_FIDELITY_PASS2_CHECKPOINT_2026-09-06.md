# LTS Wealth — Immutable Checkpoint — Canonical Dashboard Fidelity Pass 2 — 06/09/2026

## Scope
Second presentation-only fidelity pass over `canonical-app.html`, keeping the approved single-app architecture and all financial/business contracts unchanged.

## Source / gate evidence
- Candidate source: `aefe42a9a16e4dd53cb56f03aa4923196af5c958` on `canonical-app-v1`.
- Changed product file: `canonical-dashboard-fidelity.css` only; resulting blob `3cb87ed9d7973fc08711c3be9d7603dcb50e3351`.
- `canonical-app.html`, `canonical-liquidity.js`, backend contracts and protected `index.html` were not changed by this pass.
- Canonical app gate run `34058718596`: **SUCCESS**.
- Deterministic browsers: Chromium desktop 1312×1199 and WebKit mobile 390×844.
- Gate artifact `9996783057`; digest `sha256:1308f45af6e1365e8a9a01be1506d5187539b42849c4a8cf29e4ac46cb81d520`.
- Canonical candidate smoke run `34058718591`: **SUCCESS**.

## Visual result
Compared against the official approved 1312×1199 reference and the pass-1 screenshots. Pass 2 is materially closer in executive density and hierarchy:
- removes the non-reference desktop sidebar helper block without removing any real route;
- refines header/date/status framing, KPI proportions and card hierarchy;
- makes the truthful no-history Patrimônio state visually chart-like without fabricating historical bars or values;
- improves distribution, bank-position and cash-flow density;
- removes the oversized duplicate expense hero inside `Principais Despesas`, preserving the ranked real-data list and the KPI amount elsewhere;
- refines commitments, Planning, FGTS and Atualizações hierarchy/readability;
- mobile gate remains green with no route/functional regression.

## Truth boundaries
- This is not a claim of pixel-perfect parity.
- Fixture screenshots are deterministic QA evidence, not authenticated user financial evidence.
- No synthetic user-facing financial series were added. Missing wealth history remains explicitly unavailable.
- No authenticated physical-iPhone E2E was performed or claimed.
- `promotion_status` remains `not_promoted`; public `index.html` remains protected and unchanged.

## Next
After documentation sync and final branch audit, fast-forward `main` normally if clean; then update fixed homologation to the integrated pass-2 candidate and verify release/Pages evidence before presenting it as the newest testable build.
