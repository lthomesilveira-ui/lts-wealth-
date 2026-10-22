-- All fields and multiplicity of five financial source/decision sets must stay exact.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='25s';
SET LOCAL lock_timeout='1s';
CREATE TEMP TABLE v298_source_before ON COMMIT DROP AS select jsonb_object_agg(name,summary) from (select 'evento_base' name,jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) summary from (select md5(to_jsonb(r)::text) h from public.evento_base r where usuario_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'financial_events',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.financial_events r where user_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'staging',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.lts_open_finance_staging r where user_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'decisions',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.lts_v178_review_decision r where user_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'workbook',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.lts_card_workbook_evidence_v226 r where user_id=public.lts_open_finance_pilot_owner_v1()) q) summaries;
\ir ../patches/v298/review_source_lookup.sql
\ir ../patches/v298/review_normalization.sql
\ir ../patches/v298/c6_reuse.sql
\ir ../patches/v298/workbook_unchanged_row.sql
\ir ../patches/v298/card_cycle_reuse.sql
CREATE TEMP TABLE v298_source_after ON COMMIT DROP AS select jsonb_object_agg(name,summary) from (select 'evento_base' name,jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) summary from (select md5(to_jsonb(r)::text) h from public.evento_base r where usuario_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'financial_events',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.financial_events r where user_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'staging',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.lts_open_finance_staging r where user_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'decisions',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.lts_v178_review_decision r where user_id=public.lts_open_finance_pilot_owner_v1()) q union all select 'workbook',jsonb_build_object('count',count(*),'hash',md5(coalesce(string_agg(h,'' order by h),''))) from(select md5(to_jsonb(r)::text) h from public.lts_card_workbook_evidence_v226 r where user_id=public.lts_open_finance_pilot_owner_v1()) q) summaries;
DO $$ BEGIN
 IF (SELECT jsonb_object_agg FROM v298_source_before) IS DISTINCT FROM (SELECT jsonb_object_agg FROM v298_source_after)
 THEN RAISE EXCEPTION 'V298 financial source fingerprint changed'; END IF;
END $$;
SELECT 'PASS' result,jsonb_object_agg source_facts FROM v298_source_after;
ROLLBACK;
