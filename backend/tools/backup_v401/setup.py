"""Exercise the real V380 -> V387 -> V398 pipeline with synthetic records only."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def migration(path):
    print((ROOT/path).read_text())

migration('backend/tools/backup_v380/fixture.sql')
print("""
SET TIME ZONE 'America/Sao_Paulo';
CREATE TABLE public.fixture_results(label text PRIMARY KEY,pass boolean NOT NULL);
CREATE FUNCTION public.fixture_expect(ok boolean,label text)RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'Failed: %',label;END IF;
 INSERT INTO public.fixture_results VALUES(label,true);
END$$;
CREATE SEQUENCE public.fixture_legacy_calls;
GRANT USAGE,SELECT ON SEQUENCE public.fixture_legacy_calls TO service_role;
DO $$DECLARE definition text:=pg_get_functiondef('public.lts_backup_snapshot_take_v1(uuid,date)'::regprocedure);
BEGIN
 IF position('begin insert into' IN definition)=0 THEN RAISE EXCEPTION 'Legacy fixture changed';END IF;
 EXECUTE replace(definition,'begin insert into','begin perform nextval(''public.fixture_legacy_calls''); insert into');
END$$;
INSERT INTO cron.job VALUES(2,'unrelated_job','select 1;','0 * * * *',true);
INSERT INTO public.usuario(id,email)VALUES
 ('00000000-0000-4000-8000-000000000003','owner-three@example.invalid'),
 ('00000000-0000-4000-8000-000000000004','owner-four@example.invalid'),
 ('00000000-0000-4000-8000-000000000005','owner-five@example.invalid'),
 ('00000000-0000-4000-8000-000000000006','owner-six@example.invalid');
CREATE TABLE public.fixture_job_before AS TABLE cron.job;
""")
migration('backend/patches/v380/daily_modern_backup.sql')
print("""
SELECT public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000001');
CREATE SCHEMA lts_cash_alert_private_v377;
CREATE SCHEMA lts_account_reminder_private_v387;
CREATE TABLE lts_cash_alert_private_v377.delivery(token text PRIMARY KEY,user_id uuid,sent_at timestamptz DEFAULT now(),report jsonb);
CREATE TABLE lts_account_reminder_private_v387.delivery(token text PRIMARY KEY,user_id uuid,sent_at timestamptz DEFAULT now(),report jsonb);
INSERT INTO lts_cash_alert_private_v377.delivery(token,user_id,report)VALUES
 ('four-cash','00000000-0000-4000-8000-000000000004','{}'),
 ('three-cash','00000000-0000-4000-8000-000000000003','{}');
INSERT INTO lts_account_reminder_private_v387.delivery(token,user_id,report)VALUES
 ('four-accounts','00000000-0000-4000-8000-000000000004','{}'),
 ('three-accounts','00000000-0000-4000-8000-000000000003','{}');
GRANT USAGE ON SCHEMA lts_cash_alert_private_v377,lts_account_reminder_private_v387 TO service_role;
GRANT SELECT ON lts_cash_alert_private_v377.delivery,lts_account_reminder_private_v387.delivery TO service_role;
""")
migration('backend/patches/v387/notification_backup.sql')
print("""
SELECT public.lts_backup_snapshot_take_v380('00000000-0000-4000-8000-000000000002');
CREATE TABLE public.fixture_old_archives AS
 SELECT user_id,snapshot_date,payload_sha256,payload_bytes,counts FROM public.lts_backup_supplement_v380;
CREATE TABLE public.lts_family_loan_v398(user_id uuid,commitment_id text,starts_on date,original_principal numeric);
CREATE TABLE public.lts_savings_rate_v398(period_start date,period_end date,rate_pct numeric);
INSERT INTO public.lts_family_loan_v398 VALUES
 ('00000000-0000-4000-8000-000000000003','family-three','2025-01-01',1000),
 ('00000000-0000-4000-8000-000000000004','family-four','2025-01-01',2000);
INSERT INTO public.lts_savings_rate_v398 VALUES('2025-01-01','2025-02-01',0.5),('2025-02-01','2025-03-01',0.6);
GRANT SELECT ON public.lts_family_loan_v398,public.lts_savings_rate_v398 TO service_role;
""")
migration('backend/patches/v398/family_backup.sql')
print("""
DO $$
DECLARE u uuid:='00000000-0000-4000-8000-000000000003';j jsonb;c jsonb;b public.lts_backup_snapshot%rowtype;
BEGIN
 j:=public.lts_backup_modern_export_v380(u);
 PERFORM public.fixture_expect(jsonb_object_length=33,'baseline_export_contains_33') FROM (SELECT count(*)jsonb_object_length FROM jsonb_object_keys(j->'tables'))x;
 BEGIN
  PERFORM public.lts_backup_snapshot_take_v380(u);
  RAISE EXCEPTION 'Old writer unexpectedly accepted33';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>'incomplete modern backup'THEN RAISE;END IF;
 END;
 PERFORM public.fixture_expect(NOT EXISTS(SELECT 1 FROM public.lts_backup_snapshot WHERE user_id=u),'baseline_failure_rolls_back_legacy_capture');
 PERFORM public.fixture_expect(NOT EXISTS(SELECT 1 FROM public.lts_backup_supplement_v380 WHERE user_id=u),'baseline_failure_leaves_no_supplement');
 -- Build one valid synthetic33-table archive to reproduce the reader failure.
 PERFORM public.lts_backup_snapshot_take_v1(u,current_date);
 SELECT * INTO STRICT b FROM public.lts_backup_snapshot WHERE user_id=u;
 SELECT jsonb_object_agg(key,jsonb_array_length(value))INTO c FROM jsonb_each(j->'tables');
 INSERT INTO public.lts_backup_supplement_v380(user_id,snapshot_date,legacy_payload_hash,legacy_sha256,legacy_created_at,payload,payload_sha256,payload_bytes,counts)
 VALUES(u,current_date,b.payload_hash,encode(sha256(convert_to(b.payload::text,'UTF8')),'hex'),b.created_at,j,
 encode(sha256(convert_to(j::text,'UTF8')),'hex'),octet_length(convert_to(j::text,'UTF8')),c);
 BEGIN
  PERFORM public.lts_backup_bundle_read_v380(u,current_date);
  RAISE EXCEPTION 'Old reader unexpectedly accepted33';
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM<>'modern backup manifest mismatch'THEN RAISE;END IF;
 END;
 PERFORM public.fixture_expect(true,'baseline_reader_rejects_valid_33');
END$$;
""")
