# LTS Health isolation runbook

This runbook contains architecture and validation rules only. It must never contain private health rows, exported files, service-role keys, passwords, access tokens, or user-specific medical content.

## Current topology

- Temporary source/bridge: Supabase project `tadhkamnwtsbdozwkyut`.
- Dedicated target: Supabase project `plztdqyuqcjohiimudnr`.
- Temporary public frontend: `/health/` in `lthomesilveira-ui/lts-wealth-`.
- Final frontend: dedicated Health repository, once created and connected.
- Frontend backend selection is isolated in `health/config.js`; normal app code must not hardcode a Supabase project.

## Canonical schema inventory

`health_activity_records`, `health_body_composition`, `health_daily_nutrition`, `health_data_quality_issues`, `health_data_requests`, `health_documents`, `health_import_log`, `health_ingestion_previews`, `health_insights`, `health_lab_results`, `health_medication_events`, `health_medication_regimens`, `health_metrics`, `health_nutrition_meals`, `health_predictions`, `health_segmental_composition`, `health_service_import_audit`, `health_uploads`, `health_workout_exercises`, `health_workout_plans`, `health_workout_sets`, `health_workouts`.

Views, indexes, constraints and policies are validated separately from row data. Source foreign keys to `auth.users` are intentionally not required in the empty target until the target owner account exists; all canonical uniqueness constraints must exist before data copy.

## Storage and functions

- Private bucket: `health-inbox`.
- Object ownership convention: first path segment is the authenticated user UUID.
- Edge function: `health-inspect-upload` with JWT verification enabled.
- The source and target function bundle hashes must match before cutover.

## Migration sequence

1. Freeze high-volume feature expansion.
2. Inventory source schema, policies, constraints, row counts, date ranges, quarantine state, uploads, storage object counts and function hashes.
3. Validate the dedicated target schema without changing Wealth tables or policies.
4. Create/authenticate the owner account in the dedicated Health project.
5. Copy only `health_*` rows, preserving row IDs and provenance while remapping only `user_id` and the user-owned storage path prefix.
6. Copy private `health-inbox` objects.
7. Re-run row counts, ID-set parity, non-null `source_record_id` uniqueness, date-range parity, workout quarantine parity and storage inventory parity.
8. Smoke-test the dedicated backend while the public app still points to the bridge.
9. Create/connect the dedicated GitHub Health repository and copy only Health frontend/runtime files and non-sensitive migration documentation.
10. Switch the dedicated frontend configuration to the dedicated Health Supabase project.
11. Run authenticated app smoke tests before changing any public navigation/linking.
12. Keep the shared source intact as rollback until a post-cutover observation window has passed.

## Cutover gates

- No source table count differs from target.
- Row ID sets match for every migrated table.
- No duplicate non-null `source_record_id` exists where that field is canonical.
- Min/max dates match for each dated table.
- Canonical/quarantined workout counts match.
- `health-inbox` object count and total bytes match.
- `health-inspect-upload` bundle hash matches and JWT verification is enabled.
- RLS is enabled on all exposed Health tables; target access is owner-scoped.
- Main app can authenticate, load canonical data, preserve quarantines, and upload/inspect a test file without destructive operations.
- Public frontend is not switched until all prior gates pass.

## Rollback

Rollback is configuration-first: restore the previous `health/config.js` backend values or previous deployment. Do not delete or mutate the shared source during cutover. The target can be re-seeded idempotently because row IDs are preserved. Storage copies use user-prefixed paths and can be repeated with upsert only in the dedicated target.
