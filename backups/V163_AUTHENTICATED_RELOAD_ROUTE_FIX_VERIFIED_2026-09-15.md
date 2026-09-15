# V163 authenticated reload route fix — verified release receipt

Date: 15/09/2026

Status: **FIXED, PUBLISHED AND VERIFIED IN AN AUTHENTICATED REAL BROWSER SESSION; HUMAN/PHYSICAL-DEVICE ACCEPTANCE OPEN**

## Discovery and root cause

After the post-login rearm correction, a fresh authenticated full-page reload was tested rather than inferred from the successful login transition. It reproduced the previous Flow-first screen. The V163 Dashboard initial route still depended on V162 completing its Flow data read; on real network latency, the bounded V163 boot could end before that read returned. A controlled test that delayed the Flow read also exposed an ordering race in the first proposed correction: Dashboard could render before V162 installed its own initial route and then be replaced by Flow.

The final correction waits for V162's `route_applied_at` evidence, not for `last_flow_done`. This guarantees that the preserved Flow runtime has installed its route before V163 selects Dashboard, while the Flow network read may continue independently. No financial reader/writer, source value, reconciled expense rule, taxonomy, database, V150/V151 Flow behavior or protected public root changed.

## Exact release evidence

- branch: `work/v163-authenticated-load-route-fix-20260915`;
- tested/integrated code head: `cc56a579f92449db7c5e84b3d5f5b7e7d30ca74e`;
- runtime cache key: `20260915-authenticated-route-v4`;
- branch V163 gate: `34984933473` — SUCCESS;
- artifact: `10402802222`;
- digest: `sha256:10062922ed063865c4be096d2e081cd211e6541837e0fad53de3ffe35e56ef19`;
- main V163 gate: `34985040685` — SUCCESS;
- native GitHub Pages: `34985038626` — SUCCESS.

The automated gate covers 1440 px notebook, 390 px mobile, signed-out form login and a four-second delayed Flow read. Its financial payload is explicitly controlled fixture data, not validation of user values.

## Published real-session verification

After Pages completed, the published V163 candidate was opened with the existing authenticated LTS Wealth session. It displayed the executive Dashboard directly, without clicking a route, and loaded runtime `lts-dashboard-executive-v1.js?v=20260915-authenticated-route-v4`. Dashboard → Fluxo Diário → Dashboard passed. A full reload of the same URL again opened Dashboard directly and did not show the login form. Exact private financial values and credentials are not recorded in this public receipt.

This proves the delivered authenticated initial-route and navigation behavior. It does not substitute for the user's visual/financial acceptance on notebook and phone, certify every source document or authorize public-root promotion.

## Remaining gates

- user review of the Dashboard presentation and visible real financial answers;
- iterative layout/information adjustments requested from practical use;
- physical-phone evidence and independent Patrimônio verification;
- public-root promotion remains a separate explicit decision.
