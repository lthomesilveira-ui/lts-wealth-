# LTS Health · Supabase contract

Canonical runtime project: `tadhkamnwtsbdozwkyut`.

## `health-inspect-upload`

Production function: version 5, `verify_jwt=true`.
Production SHA-256: `3fa34ac7f99880473a93c4d8929d207fb20f156f8c647906bec32903a077a260`.

The `/health/` client uploads originals to the private `health-inbox` bucket under the authenticated user's folder, inserts `health_uploads.status='uploaded'`, then invokes this function with `upload_id`.

Supported automatic normalization in v5:

- MyFitnessPal CSV/ZIP: daily calories/macros from values explicitly present in the export. Missing macros are never estimated.
- Apple Health ZIP/XML: ActivitySummary active energy, exercise minutes and stand hours; sleep duration is computed from the union of `asleep` intervals so overlapping intervals are not double-counted. Granular steps are preserved in the source file but not summed automatically because multiple devices/sources can overlap.

Inspection-only / specialized-parser candidates:

- Polar CSV/JSON
- historical lab CSV/JSON; PDF/image originals are preserved for later validated extraction
- body-composition and training sources not already covered by a specialized parser

Valid `health_uploads` state flow is limited to the table constraint: `uploaded`, `queued`, `processing`, `review_required`, `imported`, `rejected`. Version 5 maps parser failures to `rejected`, successful automatic imports to `imported`, unresolved specialized parsing to `review_required`, and inspected candidates to `processing`.

Do not introduce source-less backfills. Raw source, preview, normalized record and derived insight/prediction must remain separate layers. Quarantined records do not participate in canonical calculations.
