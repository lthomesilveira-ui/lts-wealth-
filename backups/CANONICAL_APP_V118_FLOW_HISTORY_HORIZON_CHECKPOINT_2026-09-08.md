# Canonical app v1.18 — Flow history and horizon checkpoint

Date: 2026-09-08

## Scope closed

- Restored the validated V150/V151+ Flow floor without reviving the historical wrapper chain.
- Corrected the 01/01/2026 opening-balance presentation by deriving the prior close from the certified close and daily net; `Realizado` remains distinct from projection.
- Removed the rejected yellow full-row treatment from `Hoje`, preserving the validated column order, left-side expansion control and a discrete current-day marker.
- Extended the exact backend future-cache contract through the requested end date plus D+30 and proved a real 31/12/2029 row.
- Preserved separate Itaú, Bradesco and C6 views, internal-transfer neutrality, card-invoice non-duplication, append-only projection actions and the later canonical Dashboard/liquidity/document/classification capabilities.

## Exact release evidence

- Product commit: `692535276fe7948c386349254151538c0c9eddf8`.
- Manifest/exposure commit shared by active recovery, `canonical-app-v1` and `main`: `65cb675b613b70b7a26f97f86938a0b3ac72b584`.
- Recovery browser gate / candidate smoke: `34274496763` / `34274496830` — SUCCESS.
- Canonical browser gate / candidate smoke: `34274793717` / `34274793697` — SUCCESS.
- Main candidate smoke / Pages before manifest exposure: `34275276745` / `34275275447` — SUCCESS.
- Main candidate smoke / Pages after manifest exposure: `34276115233` / `34276114848` — SUCCESS.
- Recovery artifact: `10075192280`, digest `sha256:950d4f6923d895d0521ebb2389ef7bf0e5267cbf126de7810f429e87522dc587`.
- Fixed URL resolves to `canonical-app.html?homologacao=692535276fe7948c386349254151538c0c9eddf8`, loads `?v=20260908-flow18`, renders a truthful blank signed-out login and contains no iframe.

## Backend evidence

- Applied migration `canonical_flow_horizon_and_slice_guard_2026_09_08` in Supabase project `tadhkamnwtsbdozwkyut`.
- Exact-cache coverage is required through the requested period plus D+30; loose cache reselection was removed and failure is explicit.
- Real backend probe proved 01/01/2026 opening `216994.21`, net `-2120.00`, close `214874.21` and a real 31/12/2029 row.
- Workbook originals were read-only. Their 31/12/2026 and 31/12/2029 snapshots were inventoried as comparison evidence; no equality claim is made because the workbook contains older scenario layers, including obsolete future FGTS accrual that the app must not revive.

## Preserved open boundaries

- R$0.01 Bradesco / 06/08 Cofrinho and R$0.17 / R$186.10 timing questions remain documentary reconciliation items, not inferred fixes.
- Authenticated real mutation/readback, authenticated document lifecycle, full real-data visual walkthrough and a physical-iPhone E2E remain open and are not claimed by automated fixture gates.
- Public `index.html` remains protected at blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; public-root promotion remains unauthorized.
