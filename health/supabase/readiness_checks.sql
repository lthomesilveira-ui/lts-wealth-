-- LTS Health isolation readiness checks
-- Architecture-only verifier. Contains no private health rows, user UUIDs, tokens or secrets.
-- Run separately against the temporary bridge and dedicated Health project, then compare outputs.

-- 1) Canonical table/schema/constraint/RLS signature inventory.
with health_tables as (
  select c.oid, c.relname as table_name, c.relrowsecurity as rls_enabled
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and c.relname like 'health_%'
)
select
  h.table_name,
  h.rls_enabled,
  (select count(*) from pg_policy p where p.polrelid = h.oid) as policy_count,
  md5(coalesce((
    select string_agg(
      a.attname || ':' || pg_catalog.format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull::text,
      ',' order by a.attnum
    )
    from pg_attribute a
    where a.attrelid = h.oid and a.attnum > 0 and not a.attisdropped
  ), '')) as column_signature,
  md5(coalesce((
    select string_agg(
      con.conname || ':' || con.contype::text || ':' || pg_get_constraintdef(con.oid, true),
      '|' order by con.conname
    )
    from pg_constraint con
    where con.conrelid = h.oid
  ), '')) as constraint_signature
from health_tables h
order by h.table_name;

-- 2) Owner-scoped Health table policies. Compare name, command, role and predicates.
select schemaname, tablename, policyname, cmd, roles::text, qual, with_check
from pg_policies
where schemaname = 'public' and tablename like 'health_%'
order by tablename, cmd, policyname;

-- 3) Health storage bucket configuration.
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'health-inbox';

-- 4) Health storage owner policies.
select policyname, cmd, roles::text, qual, with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and (
    coalesce(qual, '') like '%health-inbox%'
    or coalesce(with_check, '') like '%health-inbox%'
  )
order by policyname;

-- 5) Auth readiness only. Do not export auth rows.
select count(*)::int as auth_user_count from auth.users;

-- 6) Canonical row-count checkpoint. Outputs counts only, never private row contents.
select * from (
  select 'health_activity_records' table_name, count(*)::bigint row_count from health_activity_records
  union all select 'health_body_composition', count(*) from health_body_composition
  union all select 'health_daily_nutrition', count(*) from health_daily_nutrition
  union all select 'health_data_quality_issues', count(*) from health_data_quality_issues
  union all select 'health_data_requests', count(*) from health_data_requests
  union all select 'health_documents', count(*) from health_documents
  union all select 'health_import_log', count(*) from health_import_log
  union all select 'health_ingestion_previews', count(*) from health_ingestion_previews
  union all select 'health_insights', count(*) from health_insights
  union all select 'health_lab_results', count(*) from health_lab_results
  union all select 'health_medication_events', count(*) from health_medication_events
  union all select 'health_medication_regimens', count(*) from health_medication_regimens
  union all select 'health_metrics', count(*) from health_metrics
  union all select 'health_nutrition_meals', count(*) from health_nutrition_meals
  union all select 'health_predictions', count(*) from health_predictions
  union all select 'health_segmental_composition', count(*) from health_segmental_composition
  union all select 'health_service_import_audit', count(*) from health_service_import_audit
  union all select 'health_uploads', count(*) from health_uploads
  union all select 'health_workout_exercises', count(*) from health_workout_exercises
  union all select 'health_workout_plans', count(*) from health_workout_plans
  union all select 'health_workout_sets', count(*) from health_workout_sets
  union all select 'health_workouts', count(*) from health_workouts
) counts
order by table_name;

-- 7) Canonical quarantine checkpoint.
select record_status, is_canonical, count(*)::bigint as row_count
from health_workouts
group by record_status, is_canonical
order by record_status, is_canonical;

-- 8) Non-null source_record_id duplicate gate.
-- Every returned duplicate count must be zero before and after migration.
select * from (
  select 'health_activity_records' table_name, count(*)::bigint duplicate_groups from (select user_id, source_record_id from health_activity_records where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_body_composition', count(*) from (select user_id, source_record_id from health_body_composition where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_daily_nutrition', count(*) from (select user_id, source_record_id from health_daily_nutrition where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_data_quality_issues', count(*) from (select user_id, source_record_id from health_data_quality_issues where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_documents', count(*) from (select user_id, source_record_id from health_documents where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_lab_results', count(*) from (select user_id, source_record_id from health_lab_results where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_medication_events', count(*) from (select user_id, source_record_id from health_medication_events where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_medication_regimens', count(*) from (select user_id, source_record_id from health_medication_regimens where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_metrics', count(*) from (select user_id, source_record_id from health_metrics where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_nutrition_meals', count(*) from (select user_id, source_record_id from health_nutrition_meals where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_segmental_composition', count(*) from (select user_id, source_record_id from health_segmental_composition where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_workout_exercises', count(*) from (select user_id, source_record_id from health_workout_exercises where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_workout_plans', count(*) from (select user_id, source_record_id from health_workout_plans where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_workout_sets', count(*) from (select user_id, source_record_id from health_workout_sets where source_record_id is not null group by 1,2 having count(*) > 1) d
  union all select 'health_workouts', count(*) from (select user_id, source_record_id from health_workouts where source_record_id is not null group by 1,2 having count(*) > 1) d
) duplicates
order by table_name;

-- 9) Date-range parity gate. Compare bridge and dedicated outputs exactly after data copy.
select * from (
  select 'health_activity_records' table_name, min(activity_date)::text date_min, max(activity_date)::text date_max from health_activity_records
  union all select 'health_body_composition', min(measured_at)::text, max(measured_at)::text from health_body_composition
  union all select 'health_daily_nutrition', min(nutrition_date)::text, max(nutrition_date)::text from health_daily_nutrition
  union all select 'health_documents', min(document_date)::text, max(document_date)::text from health_documents
  union all select 'health_lab_results', min(collection_date)::text, max(collection_date)::text from health_lab_results
  union all select 'health_medication_events', min(event_date)::text, max(event_date)::text from health_medication_events
  union all select 'health_metrics', min(measured_at)::date::text, max(measured_at)::date::text from health_metrics
  union all select 'health_nutrition_meals', min(meal_date)::text, max(meal_date)::text from health_nutrition_meals
  union all select 'health_segmental_composition', min(measured_at)::text, max(measured_at)::text from health_segmental_composition
  union all select 'health_workout_exercises', min(workout_date)::text, max(workout_date)::text from health_workout_exercises
  union all select 'health_workout_plans', min(plan_date)::text, max(plan_date)::text from health_workout_plans
  union all select 'health_workout_sets', min(workout_date)::text, max(workout_date)::text from health_workout_sets
  union all select 'health_workouts', min(workout_date)::text, max(workout_date)::text from health_workouts
) ranges
order by table_name;

-- 10) Storage inventory checkpoint. Counts/bytes only; never export object contents here.
select count(*)::bigint as object_count, coalesce(sum((metadata->>'size')::bigint),0)::bigint as total_bytes
from storage.objects
where bucket_id = 'health-inbox';
