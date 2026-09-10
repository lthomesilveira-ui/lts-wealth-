# LTS Wealth — Canonical v1.24 Responsive Dashboard Readability Checkpoint

Date: 10/09/2026 01:00 BRT (America/Sao_Paulo)

Status: `VERDE_AUTOMATICO` for the bounded product package. Authenticated real-data/write lifecycles and physical-iPhone material homologation remain open and are not claimed.

## Scope and authorization

The user authorized autonomous continuation of the product improvements already discussed, with the condition that the agreed brief and accumulated feedback remain protected. This package addresses the measurable Dashboard readability gap without changing financial facts, backend contracts, route ownership or the protected public entry point.

The operational sources of truth used were the current GitHub line, mandatory continuity documents, immutable checkpoints through canonical v1.23 and the approved 1312×1199 Dashboard reference. Chat reconstruction was not required.

## Protected predecessor

- Canonical v1.23 exact product: `7f6bac39ec0705e21a498b416762276ea3b8dbea`.
- Canonical v1.23 exposure: `d804eb0b5e972d2e86f8abc57d375e4de3e82219`.
- Immutable predecessor: `backups/CANONICAL_APP_V123_DAILY_USE_FLOW_CLOSURE_CHECKPOINT_2026-09-09.md`.
- Public `index.html` protected blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Problem proved before implementation

The published Dashboard was structurally correct but applied the compact 1312×1199 density to other wide viewports. At 1363×936, objective computed sizes included 6.5 px planning support text, 6.7 px evidence text, 7.3–8 px liquidity-layer/legend values and 9.5–10 px operational actions/rows. Passing a full-page screenshot therefore did not prove comfortable day-to-day readability.

The approved official reference remains authoritative for the 1312×1199 composition. It does not require the same micro-density on a shorter notebook viewport, an intermediate canvas or mobile.

## Product implementation

- Build: `LTS v1.24`.
- Exact product commit: `39cb869f27f7a5eb7e5f6c57ed125f7b2d2aa4fc`.
- Product tree: `69086fe6deb874af855843825da8ea738f6ee7ae`.
- Fixed-manifest exposure commit: `084a3521b0b42a2f15b8ec18348dc90f7bdc2d65`.
- Exposure tree: `b4715f4c462f40c8f82601404cbabb4f6d41f31d`.
- Asset cache key: `20260910-dashboard24`.
- Responsive contract: `executive-readable-breakpoints-v1`.

Changed product/gate files:

- `canonical-dashboard-fidelity.css`
- `canonical-app.html`
- `canonical-liquidity.js`
- `.github/scripts/lts_canonical_v157plus_browser_gate.js`
- `.github/workflows/canonical-v157plus-product-recovery.yml`
- `.github/workflows/canonical-app.yml`
- `.github/workflows/candidate-smoke.yml`
- `homologacao-current.json` in the separate exposure commit

## Responsive profiles

### Approved reference — 1312×1199

- Keeps the compact five-KPI, three-column main and three-column lower composition.
- Retains the V1.15 single-screen density ceiling and all four liquidity layers.
- Compact chart limits remain at 185 px for overview and 168 px for Planning.
- Page and Dashboard bottom must fit the official viewport.

### Notebook — 1366×900

- Keeps the executive five/three/three track hierarchy while allowing intentional vertical scroll.
- Measured final Dashboard: 1366 px client/scroll width, 1332 px page height, 145 px KPI cards, 218 px overview chart and 205 px Planning chart.
- Measured final operational fonts include 12.5 px KPI labels, 10–10.5 px KPI support, 16.5 px panel titles, 11 px actions, 9.5–11.2 px rows/legends and 9 px Planning support.

### Intermediate — 1024×900

- Uses a six-track KPI composition: first three cards span two tracks and the last two span three tracks.
- Liquidity and Planning become full-width decision panels; two-column secondary groups remain where space supports them.
- Measured final Dashboard: 1024 px client/scroll width, 2461 px page height, minimum KPI width 264 px for the first row, 226 px overview chart and 214 px Planning chart.
- Measured final operational fonts include 12.5 px KPI labels, 10–10.5 px KPI support, 17 px panel titles, 11.5 px actions/rows and 9.5–11 px legends/layers.

### Mobile — 390×844

- Keeps the intended single-column decision order and six-destination navigation.
- Planning decision becomes static above its chart; no absolute callout can cover the plot.
- Minimum KPI width is 165 px, action targets are at least 35.5 px high and the Planning chart remains at or below 170 px.
- Font floors cover labels, metadata, signals, actions, rows, legends, layers, Planning support and the mobile navigation.

## Financial and product invariants preserved

- Five KPIs remain, in order: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`.
- Observed values remain distinct from projected values after `as_of`.
- Position, base operational, scheduled conditional RSUs and documentary restricted FGTS remain separate layers.
- FGTS remains documentary/restricted around D+30, never automatic current/D+3 cash and without invented future accrual.
- `Próximos Compromissos` remains sourced only from a card due and contractual `next_due`; operational tasks stay in `Atualizações`.
- V151 management/action date remains distinct from the exact first-negative date; no negative chart point is interpolated.
- Canonical v1.23 open/closed invoice truth, nine-layer mobile disclosure and append-only edit/postpone/duplicate/split/cancel lifecycle remain regression-protected.
- No financial amount, classification, merchant, recurrence, competence, valuation, tax or documentary association changed.

## Permanent automated evidence

New `assertDashboardReadability` checks:

- declared DOM/status contract;
- `scrollWidth <= clientWidth + 1`;
- exact responsive grid-track expectations;
- five nonzero KPI geometries;
- minimum computed fonts per profile;
- notebook chart-height floor;
- intermediate full-width liquidity/Planning ratios;
- mobile static Planning callout, KPI width, action height and chart ceiling;
- protected reference single-screen geometry.

The existing full suite remains intact: Dashboard, Flow, Despesas, Patrimônio, Cartões, Atualizações, Central de Gestão, route/session continuity, truthful signed-out state and future-issued JWT recovery.

## Gate history

The first candidate `d9e6b24458c9f7b7d7920e1adeb4b01eac02bb36` was not integrated. Recovery run `34434472426` correctly rejected a mobile Planning height of 431 px against the protected 430 px ceiling. The final product reduces only the mobile chart by 2 px; no content or semantic layer was removed.

Final successful evidence:

- Active recovery gate `34434661341`: SUCCESS.
- Active candidate smoke `34434661330`: SUCCESS.
- Canonical gate `34435078818`: SUCCESS.
- Canonical candidate smoke `34435078779`: SUCCESS.
- Main candidate smoke `34435242921`: SUCCESS.
- Main Pages `34435242177`: SUCCESS.
- Post-exposure active/canonical/main smokes `34435460592` / `34435523608` / `34435568259`: SUCCESS.
- Post-exposure Pages `34435567557`: SUCCESS.

Artifacts:

- Recovery artifact `10135754220`, 4,823,756 bytes, digest `sha256:fde8eceb5d07106dac1ba84db09d4c30a27d856cff78fac1a8698850c9b7312e`.
- Canonical artifact `10135897969`, 4,808,607 bytes, digest `sha256:eab76d8c7dcab132be5d09ca7a5b3cae44dc8819f56f1f14733cf5156778d7b8`.
- Both artifacts contain `lts-canonical-definition-of-done-receipt-v1` plus `canonical-dashboard-desktop.png`, `canonical-dashboard-laptop.png`, `canonical-dashboard-intermediate.png` and `canonical-dashboard-mobile.png`.

Static/local checks passed: JS parsing for loader/gate/inline application, YAML parsing for all changed workflows, CSS brace validation, version/asset/contract checks, candidate smoke, 197/197 button audit and `git diff --check`.

## Published verification

Fixed URL: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.

The live browser resolved to `canonical-app.html?homologacao=39cb869f27f7a5eb7e5f6c57ed125f7b2d2aa4fc...#Dashboard`, loaded `canonical-dashboard-fidelity.css?v=20260910-dashboard24` and `canonical-liquidity.js?v=20260910-dashboard24`, showed the truthful signed-out login, used zero iframes, had no fixture parameter/badge, exposed no financial fixture UI and displayed no raw provider/application error.

The manifest remains `promotion_status: not_promoted`. Public `index.html` was not changed or promoted.

## Evidence boundary and next gate

This checkpoint proves deterministic product structure, interaction regression and responsive visual geometry. It does not claim:

- authenticated real Dashboard rendering;
- real save→refresh mutation/readback;
- real document upload/register/interpret/review;
- real backup/restore;
- physical-iPhone behavior;
- public-root promotion.

The next material gate is the authenticated real lifecycle plus physical-iPhone walkthrough. Documentary gaps such as Bradesco/Cofrinho, incomplete card evidence, RSU settlement detail, CIPÓ and Volvo remain open and must not be closed by inference.
