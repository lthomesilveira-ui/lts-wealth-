# LTS Health isolation runbook

This runbook contains architecture and validation rules only. It must never contain private health rows, exported files, service-role keys, passwords, access tokens, user UUIDs, or user-specific medical content.

## Current topology

- Temporary source/bridge: Supabase project `tadhkamnwtsbdozwkyut`.
- Dedicated target: Supabase project `plztdqyuqcjohiimudnr`.
- Temporary public frontend: `/health/` in `lthomesilveira-ui/lts-wealth-`.
- Final frontend: dedicated Health repository, once created and connected.
- Frontend backend selection is isolated in `health/config.js`; normal app code must not hardcode a Supabase project.
- The active frontend remains `bridge` until every data, storage, auth and smoke-test gate passes.

## Readiness status

Validated non-destructively on 2026-08-27:

- The dedicated Supabase Health project exists and is active/healthy.
- All 22 canonical `health_*` tables exist in both source and target.
- Column signatures and constraint signatures match table-for-table between source and target.
- RLS is enabled on every canonical Health table in both projects.
- `health_uploads` and `health_ingestion_previews` now use the same four owner-scoped SELECT/INSERT/UPDATE/DELETE policies in the dedicated target as the bridge.
- `health-inbox` is private in both projects with the same size/MIME contract and four owner-folder storage policies.
- The dedicated project is intentionally data-empty before cutover; no partial data migration has been accepted.
- The dedicated project still requires the intended owner account to be created/authenticated before row or storage migration.
- A dedicated GitHub Health repository is still required before the frontend can be physically separated from the Wealth repository.

These facts are readiness state only. Private row counts, date ranges and health records are deliberately not committed to Git.

## Canonical schema inventory

`health_activity_records`, `health_body_composition`, `health_daily_nutrition`, `health_data_quality_issues`, `health_data_requests`, `health_documents`, `health_import_log`, `health_ingestion_previews`, `health_insights`, `health_lab_results`, `health_medication_events`, `health_medication_regimens`, `health_metrics`, `health_nutrition_meals`, `health_predictions`, `health_segmental_composition`, `health_service_import_audit`, `health_uploads`, `health_workout_exercises`, `health_workout_plans`, `health_workout_sets`, `health_workouts`.

Views, indexes, constraints and policies are validated separately from row data. Target table/constraint signatures must match before any row copy. The target owner must exist in `auth.users` before inserting owner-bound rows or copying owner-prefixed storage objects.

Reusable non-sensitive verification SQL lives in `health/supabase/readiness_checks.sql`. Run it separately against source and target and compare outputs outside the public repository.

## Storage and functions

- Private bucket: `health-inbox`.
- Object ownership convention: first path segment is the authenticated user UUID.
- Edge function: `health-inspect-upload` with JWT verification enabled.
- The source and target function bundle hashes must match before cutover.
- Never copy Storage objects into GitHub; object bytes move only private-source → private-target.

## Migration sequence

1. Freeze high-volume feature expansion.
2. Inventory source schema, policies, constraints, row counts, date ranges, quarantine state, uploads, storage object counts and function hashes.
3. Validate the dedicated target schema without changing Wealth tables or policies.
4. Create/authenticate the owner account in the dedicated Health project.
5. Re-run the source checkpoint immediately before copy so late bridge writes are included.
6. Copy only `health_*` rows, preserving row IDs and provenance while remapping only `user_id` and owner UUID references that must follow the dedicated Auth identity.
7. Copy private `health-inbox` objects, preserving paths apart from the required owner-prefix remap.
8. Re-run row counts, ID-set parity, non-null `source_record_id` uniqueness, date-range parity, workout quarantine parity and storage inventory parity.
9. Smoke-test the dedicated backend while the public app still points to the bridge.
10. Create/connect the dedicated GitHub Health repository and copy only Health frontend/runtime files and non-sensitive migration documentation defined by `REPO_SPLIT_MANIFEST.md`.
11. Publish the isolated frontend first without changing the bridge source.
12. Switch the isolated frontend configuration to the dedicated Health Supabase project only after authenticated smoke tests pass.
13. Keep the shared source intact as rollback until a post-cutover observation window has passed.

## Cutover gates

- All 22 canonical table column/constraint signatures match.
- RLS and owner-scoped table/storage policies match the approved Health contract.
- No source table count differs from target.
- Row ID sets match for every migrated table.
- No duplicate non-null `source_record_id` exists where that field is canonical.
- Min/max dates match for each dated table.
- Canonical/quarantined workout counts match.
- `health-inbox` object count and total bytes match.
- `health-inspect-upload` bundle hash matches and JWT verification is enabled.
- Main app can authenticate, load canonical data, preserve quarantines, and upload/inspect a test file without destructive operations.
- Dedicated repo contains no private health exports, storage objects, dumps, sessions, secret keys or clinical rows.
- Public frontend is not switched until all prior gates pass.

## Rollback

Rollback is configuration-first: restore the previous `health/config.js` backend mode or previous deployment. Do not delete or mutate the shared source during cutover. The target can be re-seeded idempotently because canonical row IDs are preserved. Storage copies use user-prefixed paths and can be repeated only inside the dedicated private bucket.

Rollback must remain possible until the dedicated app has passed authenticated post-cutover smoke tests and the bridge has a retained final checkpoint.
