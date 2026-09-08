# Canonical app v1.19 — UX closure checkpoint

Date: 2026-09-08

## Scope closed

- Completed the executable holistic UX audit against the official Dashboard model, the recovered Homologação/Execução decision ledger and the protected V150/V151+ behavior floor.
- Removed the duplicated Flow `Hoje` preset while keeping the dedicated action and the nine distinct period presets.
- Replaced raw provider/session/backend messages on all canonical product surfaces with safe user guidance; bounded technical detail remains only in `window.__LTS_CANONICAL_DIAGNOSTICS` for diagnosis and is never rendered as normal product copy.
- Added associated login labels, live feedback, `aria-current`, `aria-pressed`, `aria-expanded`, descriptive Flow expand labels, modal focus management and Escape close.
- Added global keyboard focus visibility and reduced-motion handling.
- Raised mobile navigation, control-target and secondary-copy legibility, including 16 px form controls to avoid iOS input zoom and a 44 px navigation target.
- Preserved every financial truth, historical correction, append-only mutation boundary and documentary gap. No product value, classification or economic rule changed.

## Exact release evidence

- Product commit: `37781c3b11389789716781accca6c1fdabea461c`; tree `626437edfa47d12be4a061f3ff6c88e077ae2304`.
- Manifest/exposure commit shared by active recovery, `canonical-app-v1` and `main`: `59222846a5c7e67c923790da9ad4088df9781fa4`; tree `5b34ab00cecf338c51eeb97f94d339a4bb025b03`.
- Contract: `safe-errors-accessible-controls-readable-mobile-v1`.
- Recovery browser gate / candidate smoke: `34279813550` / `34279813574` — SUCCESS.
- Canonical browser gate / candidate smoke: `34281714299` / `34281714284` — SUCCESS.
- Main candidate smoke / Pages before manifest exposure: `34281930573` / `34281929787` — SUCCESS.
- Post-exposure active/canonical/main candidate smokes: `34282394183` / `34282421576` / `34282451603` — SUCCESS.
- Post-exposure Pages: `34282450565` — SUCCESS.
- Recovery artifact: `10077205170`, digest `sha256:799e68e527c299577940324894de8384ec27985f42c435a666c2e22125869170`.
- Canonical artifact: `10077915479`, digest `sha256:9a57901ea993b6d7ad1c0a80f2a8b95f00ce8bc812a40a3f4c6a2e475af5c224`.
- Fixed homologation resolves to `canonical-app.html?homologacao=37781c3b11389789716781accca6c1fdabea461c`, loads `?v=20260908-ux19`, renders the truthful blank signed-out login with associated labels/live feedback and contains no iframe.

## Visual and interaction evidence

- Desktop Chromium at 1312×1199 preserves the approved single-screen Dashboard hierarchy and density with no overflow.
- Mobile WebKit at 390×844 has no horizontal clipping; Dashboard, Flow and Updates remain intentionally scrollable and readable.
- Flow exposes exactly one `Hoje` action, nine period presets, no rejected yellow full-row treatment and a valid 2029 day.
- The permanent gate rejects raw error rendering, duplicate `Hoje`, missing accessibility state, missing Escape modal handling, undersized mobile navigation and loss of the V1.18→V1.9 protected contracts.
- Local browser launch was unavailable because this execution environment denied the Chromium singleton socket; CI Chromium/WebKit artifacts and the live fixed-link inspection are the release evidence. This is an environment limitation, not an application error.

## Decisions and rejected alternatives

- Kept one dedicated `Hoje` action instead of two competing shortcuts.
- Kept technical diagnostics available internally instead of exposing raw JWT/checksum/provider text or erasing diagnostic evidence.
- Kept six primary routes on mobile; recovered management capabilities remain grouped in `Atualizações` rather than adding navigation clutter.
- Kept the final Reports visual unimplemented because no approved standalone model was recovered; the existing Reports capability remains discoverable in Central de Gestão.
- Kept truthful empty/unavailable states instead of synthetic values or decorative filler on sparse real-data routes.
- Kept the public root untouched; homologation and public promotion remain separate decisions.

## Preserved open boundaries

- Authenticated real save→refresh/readback for Flow mutations, classification, liquidity, documents, search/CSV and backup/restore remains open because no authenticated user session is available in the execution browser.
- Physical-iPhone E2E remains open because the execution environment cannot operate the user's device.
- Bradesco/Cofrinho, card-document, RSU, CIPÓ 396 and Volvo evidence gaps remain documentary items and were not inferred away.
- Public `index.html` remains protected at blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; promotion remains unauthorized.
