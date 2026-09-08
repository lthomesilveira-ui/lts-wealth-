# Canonical app v1.11 Layered Liquidity checkpoint — 08/09/2026

## Purpose
- Preserve the recovered Dashboard requirement that liquidity evolution show separate operational, scheduled-RSU and restricted-FGTS layers.
- Keep the current evidenced position distinct from every future or contingent scenario.
- Preserve canonical v1.10 decision truth and canonical v1.9 V150/V151+ Flow interactions without restoring historical wrappers.

## Exact release
- Repository: `lthomesilveira-ui/lts-wealth-`.
- Product commit: `8a9c675ed3940da19a10c04e56249a315576045a`.
- Product tree: `56beae5ad63f7aae597d8a421474db2177ed7eca`.
- Fixed-manifest exposure commit: `04c051f19167e913079bb8e75b692f5fe430892c`.
- Exposure tree: `5d707ea6cea34f54852455a0eb9abc4dbb91f596`.
- Dashboard contract: `reference-layered-liquidity-commitments-v3`.
- Projection contract: `fact-before-asof-projection-after-asof-v1`.
- Liquidity-layer contract: `current-base-scheduled-rsu-restricted-fgts-v1`.
- Commitment source: `product-commitments-plus-card-due`.
- Build label: `LTS v1.11`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` remains blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; `promotion_status:not_promoted` remains binding.

## Recovered user intent protected
- On 05/09 the user explicitly liked the V155 visual direction but asked the Dashboard to prioritize bank cash, accounts plus short-term liquidity, vested RSUs and FGTS, with cash evolution split into account/short-term/RSU/FGTS layers.
- Feedback on 04–05/09 rejected visually plausible releases whose buttons or data failed on the iPhone; automatic evidence must not be confused with physical-device validation.
- Feedback on 07/09 made V150 the functional floor and required later improvements to accumulate rather than replace validated Flow behavior.
- The full recovered-feedback map, including 24/08 invoice/Flow semantics, is versioned in `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md` and `LTS_WEALTH_CONTINUITY_HANDOFF.md`.

## Financial and visual model protected
- The official 1312×1199 reference governs hierarchy and density, never financial values.
- Current liquidity is anchored from the evidenced cockpit `through_d3` position on `as_of` when the horizon contract has no same-day row.
- `current_liquidity_balance` is the base operational future series.
- `conditional_rsu_balance` is the scheduled-vesting scenario. It is visually conditional and never becomes current acquired wealth before vesting/settlement.
- `restricted_total_balance` is the FGTS-inclusive contingency series. FGTS remains documentary/restricted and approximately D+30; it is never current D+3 cash and no future FGTS contribution is invented.
- The Dashboard also labels the current components — accounts, D0/D1, vested RSUs and restricted FGTS — without summing conditional/restricted values into current cash.
- `Próximos Compromissos` remains limited to card due date plus product commitment rows with explicit `next_due`; operational review tasks remain in `Atualizações`.

## V150/V151+ preservation
- Canonical Flow contract remains `v150-validated-flow-plus-v157-liquidity-v1`.
- The same permanent suite still covers Hoje, exactly five future days, four account views, ten presets, 14 consolidated layers, semantic salary/transfer labels, inline reconciled invoice detail, preserved scroll and append-only edit/duplicate/split/cancel.
- V153 remains the recorded historical Flow regression point. V1.11 changes Dashboard rendering and its gate only; no Flow owner/backend/writer contract was replaced.

## Deterministic evidence
- Local permanent gate: PASS in Chromium desktop 1312×1199 and mobile 390×844.
- Local visual review found an FGTS marker class colliding with the FGTS panel height. The class was isolated and a maximum panel-height assertion was added before release.
- Recovery product gate `34229899061`: SUCCESS in Chromium desktop + WebKit mobile.
- Recovery candidate smoke `34229899074`: SUCCESS.
- Canonical gate `34230146792`: SUCCESS on the same product commit.
- Canonical candidate smoke `34230146827`: SUCCESS.
- Main candidate smoke `34230384306`: SUCCESS.
- GitHub Pages `34230382218`: SUCCESS.
- Post-exposure recovery/canonical/main smokes `34230610235` / `34230659383` / `34230705729`: SUCCESS.
- Post-exposure GitHub Pages `34230705397`: SUCCESS.
- Recovery artifact `10057369616`, digest `sha256:5939e41b70411530e1668546d83764ea48454e72598e0c1e7dc967a0414e87d2`.
- Canonical artifact `10057455711`, digest `sha256:b3cea9b02272be1495797ed8151fadcda8c3e865929729d648c12e43017aea34`.
- Gate assertions cover two layered charts, one current observed anchor, five base projected points, five scheduled-RSU conditional points, five restricted-FGTS points, legends, current composition, panel bounds, documentary commitments, all six routes, full Flow parity, route/session continuity, Central de Gestão, truthful unauthenticated state and no horizontal overflow.

## Live fixed-URL evidence
- The fixed URL resolved to `canonical-app.html?homologacao=8a9c675ed3940da19a10c04e56249a315576045a&…#Dashboard`.
- GitHub Pages loaded `canonical-liquidity.js?v=20260908-dashboard-layers11`.
- Signed-out state rendered the real LTS Wealth login, not a fixture Dashboard.
- Zero iframes and zero fixture badge/financial Dashboard content were present while unauthenticated.

## Validation boundary
- Fixture values exist only behind explicit deterministic test mode; they are not user data.
- CI does not prove an authenticated financial session or a physical iPhone.
- Authenticated real Dashboard values, Flow writes/readback, invoice detail, classification, search/CSV, document interpretation and backup/restore remain separate open gates.
- Physical-iPhone post-fix validation remains open and must not be inferred from WebKit CI.
- Public-root promotion is not authorized and was not performed.

## Next execution sequence
1. Preserve v1.11 product `8a9c675…` and exposure `04c051f…` as the current Dashboard baseline.
2. Continue the historical two-project audit and next coherent product-quality package without regressing v1.11 layers, v1.10 decision truth, v1.9 Flow parity or the security baseline.
3. Close authenticated real-data/write and physical-device receipt rows only with actual evidence.
4. Preserve every documentary/classification/reconciliation/Open Finance dependency; provider, consent, spend and public-root promotion remain explicit user decisions.
