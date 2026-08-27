# LTS Health split plan

Status: PREPARED, NOT CUT OVER.

## Guardrails
- LTS Wealth Supabase remains the temporary source/rollback bridge until validation is complete.
- Do not modify LTS Wealth schema/security as part of the Health split.
- Do not place private health rows, files, credentials, or exports in GitHub.
- Preserve provenance, source_record_id, quarantine state, source payloads, and original upload paths/content.
- Cutover is config-only after target parity checks pass.

## Source project
- Project: LTS Wealth (temporary bridge)
- Region: sa-east-1
- Health tables: 22 base health_* tables plus health_domain_coverage and health_workout_migration_audit views.
- Storage bucket: health-inbox, private, 50 MB/file.
- Health Edge Function: health-inspect-upload v5, JWT required.

## Target project
- Project: LTS Health
- Region: sa-east-1
- Health schema already provisioned.
- health-inbox bucket already provisioned, private, 50 MB/file.
- health-inspect-upload deployed with the same code hash as source, JWT required.
- Target data remains empty until owner authentication exists and migration executes.

## Source checkpoint (2026-08-27)
These are operational counts only, not private record content.

| Table | Rows |
|---|---:|
| health_activity_records | 3794 |
| health_body_composition | 35 |
| health_daily_nutrition | 2289 |
| health_data_quality_issues | 25 |
| health_data_requests | 6 |
| health_documents | 23 |
| health_import_log | 2 |
| health_ingestion_previews | 1 |
| health_insights | 7 |
| health_lab_results | 33 |
| health_medication_events | 27 |
| health_medication_regimens | 6 |
| health_metrics | 1096 |
| health_nutrition_meals | 4901 |
| health_predictions | 0 |
| health_segmental_composition | 4 |
| health_service_import_audit | 0 |
| health_uploads | 1 |
| health_workout_exercises | 62 |
| health_workout_plans | 9 |
| health_workout_sets | 137 |
| health_workouts | 43 |

Source storage checkpoint: 1 object, 159,993 bytes.

## Migration phases
1. Freeze domain expansion; source remains read/write only for continuity.
2. Create/authenticate owner in dedicated Health project.
3. Copy storage first or in lockstep with health_uploads path remapping.
4. Copy health_* tables idempotently, remapping only user_id to the target owner.
5. Validate exact row counts table-by-table.
6. Validate source_record_id uniqueness where present.
7. Validate date ranges per domain against source.
8. Validate canonical workout count and quarantine count separately.
9. Validate 62 exercises / 137 sets parity and referential linkage.
10. Validate RLS owner isolation and private storage policies.
11. Run target health-inspect-upload smoke with a non-destructive test artifact or existing migrated upload.
12. Switch frontend config to target project only after all gates pass.
13. Keep source untouched for rollback through a defined observation window.

## Rollback
Frontend cutover must be reversible by restoring the previous Supabase URL/publishable key. No source rows are deleted during migration. No destructive cleanup of the shared project occurs during cutover.

## Cutover gates
- [ ] Target owner authenticated
- [ ] All source/target row counts equal
- [ ] source_record_id duplicate checks = 0 unexpected duplicates
- [ ] Date range parity complete
- [ ] 42 canonical workouts + 1 quarantine preserved
- [ ] 62 exercises + 137 sets preserved
- [ ] MyFitnessPal/nutrition counts preserved
- [ ] Activity/metrics counts preserved
- [ ] 25 data-quality records preserved with statuses
- [ ] health-inbox object count/bytes validated
- [ ] RLS and storage policies validated
- [ ] health-inspect-upload target smoke passed
- [ ] Public app smoke passed against target
- [ ] Rollback config tested
- [ ] Dedicated GitHub Health repository created and receives Health frontend before final separation from Wealth repo
