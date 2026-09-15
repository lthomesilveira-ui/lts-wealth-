# LTS Wealth — Dashboard visual proposal package checkpoint

Date: 15/09/2026

Status: **PROPOSAL RECORDED — USER APPROVAL PENDING**

Branch: `work/dashboard-visual-proposal-20260915`

Parent: `80e5f5ff0a9a5833ff0f14f5021c282da7213779`

## Purpose

This checkpoint records the first Work continuity package requested by the user: recover the authoritative visual reference and real delivery state, audit the current application route ownership, and produce a complete notebook/mobile Dashboard proposal before any frontend implementation.

No approval is inferred from creation of this package. The Dashboard rejected on 10/09/2026 remains rejected. The proposal must receive explicit human approval before it can become an implementation baseline.

## Pre-write continuity evidence

- `origin/main` and `origin/recovery-v152-flow-20260910` were fetched and compared before the branch was created; both resolved to parent `80e5f5ff0a9a5833ff0f14f5021c282da7213779`.
- The fixed homologation manifest identifies V162 and product build `39e47fc60c40fa8f3796fab4f73f05dee5a89419` at `wip35-v162-candidate.html`.
- GitHub Pages run `34914204383` and its build/report/deploy jobs were confirmed complete and successful.
- The fixed URL was opened in a real browser and redirected to the expected candidate. It showed the real sign-in surface, not a fixture.
- No authorized private user session was available. Authenticated routes and personal financial values were therefore not represented as browser-validated.
- Public-root promotion remains `not_promoted`.
- The original official visual source was recovered at 1312×1199 with SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`, exactly matching `LTS_WEALTH_VISUAL_CONTRACT.md`.

## Current application audit captured by the proposal

- V162 intentionally preserves `index.html` and the V150/V151 Flow surface through `wip35-v162-flow-recovery.js` and `lts_browser_flow_v11`.
- Effective navigation starts at Fluxo Diário and currently omits Dashboard.
- Historical Dashboard code remains in the source but is not an approved product surface and was not re-enabled.
- Effective Despesas is the ex135 executive/monthly surface aligned by `lts-expense-screen-alignment.js` to `lts_browser_expense_executive_v3` and `lts_browser_expense_month_detail_v2`.
- Cartões, Patrimônio, Planejamento and Atualizações retain their documented reader lineages and open validation limits.

## Package files and SHA-256

| File | SHA-256 |
|---|---|
| `LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_2026-09-15.md` | `40623474ff7ea479fb1e2a6b130d334af9980962ff02df0e2067654574c91647` |
| `design/LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_NOTEBOOK_2026-09-15.svg` | `4c2db6f83ee50f68d79cbd97aa52bb203058d03275c123d1cff36e34d7b7d87a` |
| `design/LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_NOTEBOOK_2026-09-15.png` | `82b273698d173615c2e3f4494905cbacca3f4749578bd452653a4fe94c412235` |
| `design/LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_MOBILE_2026-09-15.svg` | `4f9fb86405e0bbb4fbf7299b1ef91a72f1f98a167a152222cc2de96668f30946` |
| `design/LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_MOBILE_2026-09-15.png` | `97925dd88a6b2463b86c92b49ee0ce73c3ce7e04af4804ed402760d1c3f58384` |

The SVG sources were parsed successfully. The PNG renderings have exact dimensions 1440×1260 and 1320×960 and were visually inspected after export.

## Product decisions embodied in the proposal

1. Dashboard is liquidity-first and uses the five contracted KPIs: Dinheiro em contas, Contas + curto prazo, RSUs vested, FGTS and Despesas (mês).
2. The official reference controls hierarchy, density, proportions, navigation and color language; its illustrative labels and money do not override LTS financial contracts.
3. Observed liquidity, operational projection, conditional RSUs and restricted FGTS are independently labeled.
4. Patrimônio remains secondary and visibly `em validação` until its independent asset/debt/availability/valuation/date-base gate closes.
5. Only invoices or contractual commitments with explicit dates enter Próximos compromissos.
6. Mobile is a purpose-built 390 px vertical composition with six persistent primary destinations and no horizontal page overflow.
7. The existing Despesas, Cartões and Patrimônio readers are preserved. The proposal changes presentation hierarchy, not the reconciled financial universe.
8. Private values are absent from all proposal assets.

## Explicit non-changes

This package does not modify:

- `index.html`, candidate HTML, Flow runtime, expense runtime or any active JavaScript/CSS;
- `homologacao.html`, `homologacao-current.json` or the protected public root;
- SQL, schemas, functions, grants, caches or private evidence;
- classifications, taxonomy, category equivalence status or financial arithmetic;
- V150/V151 Flow behavior, card settlement semantics, expense reconciliation or current V162 publication.

## Next gate

Wait for explicit user approval or requested corrections to `LTS_WEALTH_DASHBOARD_VISUAL_PROPOSAL_2026-09-15.md` and its notebook/mobile visuals. After approval, continue as the same sole executor in the branch lineage, implement a new Dashboard layer, run deterministic and regression tests, render the integrated candidate in notebook/mobile, compare it against the official source, and verify the exact deployed SHA. Do not promote the public root without a separate explicit authorization.
