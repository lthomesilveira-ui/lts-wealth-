# Canonical app v1.15 Dashboard Density checkpoint — 08/09/2026

## Purpose
- Close the measurable desktop-density gap between the current canonical Dashboard and the approved 1312×1199 reference without changing financial truth.
- Keep the whole executive Dashboard visible in the approved desktop canvas while preserving the responsive mobile composition.
- Preserve canonical v1.14 document review, v1.13 classification-first guided intake, v1.12 reviewed input, v1.11 liquidity layers, v1.10 decision truth, v1.9 V150/V151+ Flow parity and every security/session baseline.

## Exact release
- Repository: `lthomesilveira-ui/lts-wealth-`.
- Product parent: v1.14 documentation closure `174119a7ada81b58cd39c6693493d2e138480c62`.
- Exact remote product commit: `a0a2675e6a9c9b3ffe4d9b0bc1fab222a48bc347`.
- Exact product tree: `667ef2fcae8c5630b5a60b4d62ee2986ad438e92`.
- Fixed-manifest exposure commit: `b1998a9178ef3a8eec90dd47aa21e31dad8c868a`.
- Exposure tree: `f8a68fa98658f1718eccfd6b716f4607ad2d516e`.
- Local product commit `cdea9cf…` and local exposure `617fcdd…` have the exact same product/exposure trees; SHA differences are only lineage.
- Dashboard density contract: `approved-1312x1199-single-screen-v1`.
- Build label: `LTS v1.15`.
- Asset cache tag: `20260908-dashboard-density15`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` remains blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; `promotion_status:not_promoted` remains binding.

## Recovered decision and product change
- The official Dashboard reference is a 1312×1199 executive canvas that shows the complete page without vertical scrolling.
- Before v1.15, the canonical page measured 1325 px at the same viewport, leaving a concrete 126 px overflow beyond the 1199 px canvas.
- V1.15 reduces only the desktop chart/legend vertical footprint: the main liquidity panel moves from 350 px to 295 px and the bottom planning panel from 373 px to 297 px.
- Both layered-liquidity legends remain visible on one line with the same four meanings: current position, operating base, scheduled vestings and documentary FGTS D+30.
- The post-change document height is 1199 px and the Dashboard bottom is 1184 px at viewport 1312×1199.
- Mobile remains intentionally scrollable and keeps all cards, routes, semantics and interaction targets without horizontal clipping.
- No balance, projection, commitment, date, classification, document association or Supabase behavior changed.

## Regression contract
- `data-dashboard-density-contract="approved-1312x1199-single-screen-v1"` is emitted by the Dashboard and mirrored in `__LTS_CANONICAL_DASHBOARD_STATUS`.
- `__LTS_CANONICAL_RECOVERY_STATUS` exposes one density contract under build `LTS v1.15`.
- The permanent gate fails if desktop document height or Dashboard bottom exceeds the 1312×1199 viewport.
- The gate also caps the desktop current-liquidity panel at 315 px and proves both four-item legends remain present.
- Existing V150 Flow interaction, V149 document review, classification-first Updates, reviewed input, route/session, no-write fixture and mobile overflow tests remain in the same gate.

## Deterministic evidence
- `git diff --check`: PASS.
- `node --check` for the loader and permanent browser gate: PASS.
- All three changed workflow YAML files parsed successfully.
- Local permanent browser gate: PASS in Chromium desktop 1312×1199 and mobile 390×844, including future-JWT recovery.
- Local visual review: full desktop Dashboard fits the reference canvas; mobile remains readable and unclipped.
- Protected `index.html` hash remained exact.
- Product recovery gate/smoke `34256124696` / `34256124706`: SUCCESS.
- Canonical product gate/smoke `34256598442` / `34256598444`: SUCCESS.
- Main product smoke/Pages `34256889054` / `34256887644`: SUCCESS.
- Post-exposure active/canonical/main smokes `34257179939` / `34257183053` / `34257139985`: SUCCESS.
- Post-exposure Pages `34257139795`: SUCCESS.
- Recovery artifact `10067974348`, digest `sha256:302bccf618422a2d0a2ade4fd696441a71f8c490707be3aa54f75afce974412d`.
- Canonical artifact `10068181842`, digest `sha256:1b2c2310394b6d834d88ba015d596648e88ae517489b54f40e89c7c17e6380d5`.
- Product Pages artifact `10068220079`, digest `sha256:89f886e91e2b1b88520969fed3ac163322a3989438146138d0dd04a95c73a081`.
- Exposure Pages artifact `10068319425`, digest `sha256:9820c15422ab8226db2edd51490ba328b08d933a6c1b07f05a50f3614db1f228`.

## Live fixed-URL evidence
- The fixed URL resolved to `canonical-app.html?homologacao=a0a2675…#Dashboard`.
- GitHub Pages loaded `canonical-dashboard-fidelity.css`, `canonical-liquidity.js` and `canonical-liquidity-core.js` with `?v=20260908-dashboard-density15`.
- A clean signed-out browser rendered the real LTS Wealth login with blank email/password fields.
- Zero iframes, zero fixture badges, zero raw JWT text and zero application load errors were present.
- Browser logs contained no product-origin error; only browser-extension metadata noise was observed.

## Validation boundary
- Local and CI fixture gates prove density, responsive layout and preservation of the existing deterministic product contracts.
- Signed-out live verification proves exact exposure and safe unauthenticated behavior; it does not prove real financial data.
- No authenticated classification, reviewed-input, liquidity, Flow mutation, document lifecycle, backup/restore apply or real-data Dashboard write/readback is claimed.
- Physical-iPhone authenticated validation remains open and cannot be inferred from Chromium/WebKit CI.
- Public-root promotion is not authorized and was not performed.

## Next execution sequence
1. Preserve product `a0a2675…`, exposure `b1998a9…`, the 1312×1199 density contract and every v1.14→v1.9 protected contract.
2. Continue the two-project historical audit and implement the next gap only when supported by recovered user feedback or an approved model.
3. Execute authenticated real-data/write/document/backup lifecycles when an authenticated identity is available; do not manufacture credentials or claim completion from fixtures.
4. Keep physical-iPhone validation, Open Finance provider/consent/spend and public-root promotion explicit decisions/access boundaries.
