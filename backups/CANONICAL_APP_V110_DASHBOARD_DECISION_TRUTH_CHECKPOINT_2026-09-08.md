# Canonical app v1.10 Dashboard Decision Truth checkpoint — 08/09/2026

## Purpose
- Preserve the exact Dashboard model chosen after reconciling the approved visual reference, the V150/V151+ validated behavior and the current backend contracts.
- Prevent future work from presenting a projection as a fact or an operational review task as a financial commitment.
- Keep automatic browser evidence separate from authenticated real-data and physical-device proof.

## Exact release
- Repository: `lthomesilveira-ui/lts-wealth-`.
- Product commit: `de4362d90560424a332f77ce22e665729cd7d88f`.
- Product tree: `e22f5f4ee20f174a3e3ee681a68ae4a48ab614d6`.
- Fixed-manifest exposure commit: `661be37ea45425a30dd3a35c7605d1921db94559`.
- Exposure tree: `dd80edcf6d2877cdd0031e4be334e4978428ab13`.
- Dashboard contract: `reference-fact-projection-commitments-v2`.
- Projection contract: `fact-before-asof-projection-after-asof-v1`.
- Commitment source: `product-commitments-plus-card-due`.
- Build label: `LTS v1.10`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` remains blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; `promotion_status:not_promoted` remains binding.

## Decision model protected
- The official 1312×1199 reference governs visual hierarchy and density, never financial values.
- Both Dashboard liquidity charts classify each horizon using `as_of`, date and the backend status/basis fields.
- Position through the cut-off is observed; later dates are projection. Projection uses a dashed line and outlined points, explicit legend/cut-off text and an accessible chart label.
- `Próximos Compromissos` reads only the next card invoice and `product.commitments.commitments` rows with an explicit `next_due`.
- Historical `first_date` is not inferred as a future due date. A missing next due date is omitted honestly.
- `cockpit.work.top_actions` remains in `Atualizações`; classification, card-review and planning work cannot leak into the commitment panel.
- Commitment rows and the panel action route to `Fluxo Diário`, preserving the single-owner six-route architecture.

## V150/V151+ preservation
- Canonical v1.9 Flow contract `v150-validated-flow-plus-v157-liquidity-v1` remains unchanged underneath v1.10.
- The full regression suite still covers Hoje, exactly five future days, four account views, ten presets, 14 consolidated liquidity/economic layers, semantic salary/transfer labels, inline reconciled invoice detail, scroll preservation and append-only edit/duplicate/split/cancel.
- V153 remains the recorded historical regression point. No wrapper or iframe architecture was restored.

## Deterministic evidence
- Local permanent gate: PASS in Chromium desktop 1312×1199 and mobile 390×844.
- Recovery product gate `34225155424`: SUCCESS in Chromium desktop + WebKit mobile.
- Recovery candidate smoke `34225155422`: SUCCESS.
- Canonical gate `34225365210`: SUCCESS on the same product commit.
- Canonical candidate smoke `34225365141`: SUCCESS.
- Main candidate smoke `34225542803`: SUCCESS.
- GitHub Pages `34225541791`: SUCCESS.
- Post-exposure recovery/canonical/main smokes `34225917363` / `34225967201` / `34226016981`: SUCCESS.
- Post-exposure GitHub Pages `34226016118`: SUCCESS.
- Recovery artifact `10055417140`, digest `sha256:46b285161dd778294e9d5161bbe6faa71d96e7bb31188b6b25bcc5adb608e33b`.
- Canonical artifact `10055499807`, digest `sha256:a255c1a04e8a5b7f33ef5a199ad3b24c34fdd1bf8ed7f05245026f520373a841`.
- Gate assertions cover two fact/projection charts, observed/projected point counts, dashed projection, three documentary commitment rows, non-leakage of three review tasks, commitment→Flow navigation, all six routes, route/session continuity, Central de Gestão, truthful unauthenticated state and no desktop/mobile horizontal overflow.

## Live fixed-URL evidence
- The fixed URL resolved to `canonical-app.html?homologacao=de4362d90560424a332f77ce22e665729cd7d88f&…#Dashboard`.
- GitHub Pages loaded `canonical-liquidity.js?v=20260908-dashboard-truth10`.
- Signed-out state rendered the real LTS Wealth login, not a fixture Dashboard.
- Zero iframes and zero fixture badge/financial Dashboard content were present while unauthenticated.

## Validation boundary
- Fixture values exist only behind the explicit deterministic test mode; they are not user data and are not exposed in the signed-out homologation.
- CI does not prove an authenticated financial session or a physical iPhone.
- Authenticated real Dashboard values, Flow writes/readback, invoice detail, classification, search/CSV, document interpretation and backup/restore remain separate open gates.
- Physical-iPhone post-fix validation remains open and must not be inferred from WebKit CI.
- Public-root promotion is not authorized and was not performed.

## Next execution sequence
1. Preserve v1.10 product `de4362d…` and exposure `661be37…` as the Dashboard regression baseline.
2. Continue evidence-led detail convergence and remaining product P0 without changing financial truth or restoring wrappers.
3. Close authenticated real-data/write and physical-device receipt rows only with actual evidence.
4. Preserve every documentary/classification/reconciliation/Open Finance dependency in the master backlog; provider, consent and spend remain explicit user decisions.
