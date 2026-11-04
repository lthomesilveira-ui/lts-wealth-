"""Extend the real V381/V399/V402 synthetic reader chain for ingestion tests."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
print("SET TIME ZONE 'America/Sao_Paulo';")
print("CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions;")
print("CREATE SCHEMA cron; CREATE SCHEMA net;")
print("CREATE TABLE public.usuario(id uuid PRIMARY KEY);INSERT INTO public.usuario VALUES('11111111-1111-4111-8111-111111111111');")
print("CREATE FUNCTION public.lts_open_finance_pilot_owner_v1()RETURNS uuid LANGUAGE sql AS $$SELECT '11111111-1111-4111-8111-111111111111'::uuid$$;")
print("CREATE TABLE public.qa_http_requests(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,payload jsonb);")
print("CREATE FUNCTION net.http_post(url text,body jsonb,headers jsonb,timeout_milliseconds integer)RETURNS bigint LANGUAGE sql AS $$INSERT INTO public.qa_http_requests(payload)VALUES(body)RETURNING id$$;")
print("CREATE TABLE public.lts_of_recovery_attempt_v245(institution_code text,http_request_id bigint,requested_at timestamptz DEFAULT now());")
print("CREATE TABLE public.lts_open_finance_job(id uuid DEFAULT gen_random_uuid(),user_id uuid,action text,token_hash text,created_at timestamptz DEFAULT now(),expires_at timestamptz,consumed_at timestamptz,http_request_id bigint);")
print("ALTER TABLE public.lts_open_finance_connection ADD institution_name text,ADD connection_mode text,ADD scopes jsonb,ADD status text DEFAULT 'connected',ADD consent_expires_at timestamptz,ADD metadata jsonb DEFAULT '{}',ADD last_attempt_at timestamptz,ADD last_success_at timestamptz,ADD last_error_code text,ADD last_error_summary text,ADD updated_at timestamptz DEFAULT now(),ADD UNIQUE(user_id,provider,provider_connection_ref);")
print("ALTER TABLE public.lts_open_finance_connection ALTER id SET DEFAULT gen_random_uuid();")
print("ALTER TABLE public.lts_open_finance_sync_run ADD provider_run_ref text,ADD trigger_type text,ADD raw_count integer DEFAULT 0,ADD normalized_count integer DEFAULT 0,ADD exact_match_count integer DEFAULT 0,ADD candidate_match_count integer DEFAULT 0,ADD promoted_count integer DEFAULT 0,ADD blocked_count integer DEFAULT 0,ADD error_code text,ADD error_summary text,ADD metadata jsonb DEFAULT '{}',ADD created_at timestamptz DEFAULT now();ALTER TABLE public.lts_open_finance_sync_run ALTER started_at SET DEFAULT now();")
print("ALTER TABLE public.lts_open_finance_observation ADD reconciliation jsonb,ADD ingest_action text;ALTER TABLE public.lts_open_finance_observation ALTER id SET DEFAULT gen_random_uuid();ALTER TABLE public.lts_open_finance_observation ALTER observed_at SET DEFAULT now();")
print("ALTER TABLE public.lts_open_finance_staging ADD sync_run_id uuid,ADD institution_name text,ADD reference_month date,ADD description_normalized text,ADD match_status text,ADD matched_source_table text,ADD matched_source_ref text,ADD match_confidence numeric,ADD promotion_status text,ADD promotion_source_table text,ADD promotion_source_ref text,ADD block_reason text,ADD first_seen_at timestamptz DEFAULT now(),ADD last_seen_at timestamptz DEFAULT now(),ADD created_at timestamptz DEFAULT now(),ADD updated_at timestamptz DEFAULT now(),ADD source_event_type text,ADD provider_updated_at timestamptz,ADD UNIQUE(user_id,provider,resource_type,provider_record_id);ALTER TABLE public.lts_open_finance_staging ALTER id SET DEFAULT gen_random_uuid();")
print("CREATE TABLE public.lts_backup_supplement_v380(user_id uuid,snapshot_date date,payload_sha256 text,payload_bytes bigint,counts jsonb,PRIMARY KEY(user_id,snapshot_date));")
print("CREATE FUNCTION public.lts_backup_snapshot_take_v380(p_user_id uuid,p_snapshot_date date)RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO public.lts_backup_supplement_v380 VALUES(p_user_id,p_snapshot_date,'synthetic-only',123,jsonb_build_object('transaction_isolation',current_setting('transaction_isolation')));RETURN '{\"ok\":true,\"inserted\":true}'::jsonb;END$$;")
print("CREATE TABLE cron.job(jobid bigint PRIMARY KEY,schedule text,command text,active boolean,jobname text,username text);")
print("INSERT INTO cron.job VALUES(1,'15 6 * * *','SET statement_timeout = ''90s''; select public.lts_backup_snapshot_take_v380(''11111111-1111-4111-8111-111111111111''::uuid,current_date);',true,'lts_daily_backup_snapshot','postgres'),(4,'15 * * * *','synthetic-bank-enqueue',true,'sync','postgres');")
print("CREATE FUNCTION cron.alter_job(job_id bigint,schedule text DEFAULT NULL,command text DEFAULT NULL)RETURNS void LANGUAGE sql AS $$UPDATE cron.job j SET schedule=coalesce($2,j.schedule),command=coalesce($3,j.command)WHERE j.jobid=$1$$;")
for p in sorted((Path(__file__).parent/'baseline').glob('*.sql')):
 if p.name!='lts_backup_export_v1.sql':print(p.read_text().rstrip().rstrip(';')+';')
print("CREATE TABLE public.qa_history_v403 AS SELECT jsonb_agg(to_jsonb(o)ORDER BY id) j FROM public.lts_open_finance_observation o;")
print("CREATE TABLE public.qa_financial_v403 AS SELECT jsonb_build_object('assets',(SELECT jsonb_agg(to_jsonb(a)ORDER BY id)FROM public.asset_positions a),'events',(SELECT jsonb_agg(to_jsonb(e)ORDER BY id)FROM public.financial_events e),'movements',(SELECT jsonb_agg(to_jsonb(m)ORDER BY id)FROM public.lts_liquidity_movement m),'locks',(SELECT jsonb_agg(to_jsonb(l)ORDER BY lock_key)FROM public.lts_validated_lock_registry l))j;")
print("GRANT USAGE ON SCHEMA public,extensions,cron,net TO service_role;GRANT ALL ON ALL TABLES IN SCHEMA public,cron TO service_role;GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;")
print("CREATE TABLE public.qa_results_v403(name text PRIMARY KEY);CREATE FUNCTION public.qa_assert_v403(p_name text,p_pass boolean)RETURNS void LANGUAGE plpgsql AS $$BEGIN IF NOT coalesce(p_pass,false)THEN RAISE EXCEPTION 'FAIL:%',p_name;END IF;INSERT INTO public.qa_results_v403 VALUES(p_name);END$$;")
print("""
CREATE FUNCTION public.qa_record_v403(p_kind text,p_id text,p_value numeric DEFAULT 10,p_tick timestamptz DEFAULT '2020-01-02T12:00:00Z')
RETURNS jsonb LANGUAGE sql AS $f$
 WITH raw AS(SELECT jsonb_build_object('id',p_id,'itemId','synthetic-item','code',CASE p_id WHEN 'component-a'THEN'SYNTHETIC-A'WHEN'component-b'THEN'SYNTHETIC-B'ELSE NULL END,
 'currencyCode','BRL','status','ACTIVE','balance',p_value,'amount',p_value+5,'taxes',5,'date',(current_date+3)::text||'T00:00:00Z','updatedAt',p_tick)j),
 norm AS(SELECT jsonb_build_object('item_id','synthetic-item','amount',p_value,'net_valuation',p_value,'amount_semantics','net_valuation','provider_id',p_id,'source_sync_at',p_tick,'account_type',CASE WHEN p_kind='balance'THEN'CHECKING_ACCOUNT'END)j)
 SELECT jsonb_build_object('resource_type',p_kind,'provider_record_id','synthetic-item:'||p_id,'raw_hash',encode(sha256(convert_to(raw.j::text,'UTF8')),'hex'),
 'raw_payload',raw.j,'normalized_payload',norm.j,'reconciliation',jsonb_build_object('classification','new'),'currency','BRL','description_raw',p_kind,'signed_amount',p_value,'provider_updated_at',p_tick)
 FROM raw,norm;
 $f$;
 CREATE FUNCTION public.qa_run_v403(p_run uuid)RETURNS void LANGUAGE sql AS $f$
 INSERT INTO public.lts_open_finance_sync_run(id,user_id,connection_id,status,started_at,metadata)VALUES(p_run,'11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333','running',clock_timestamp(),'{}');
 $f$;
 CREATE FUNCTION public.qa_batch_v403(p_run uuid,p_records jsonb)RETURNS jsonb LANGUAGE sql AS $f$
 SELECT public.lts_open_finance_stage_batch_v1('11111111-1111-4111-8111-111111111111','33333333-3333-4333-8333-333333333333',p_run,p_records);
 $f$;
 CREATE FUNCTION public.qa_finish_v403(p_run uuid,p_count int,p_status text DEFAULT 'success')RETURNS jsonb LANGUAGE sql AS $f$
 SELECT public.lts_open_finance_finish_itau_v1('11111111-1111-4111-8111-111111111111',p_run,p_status,jsonb_build_object('expected_count',p_count,'coverage','[]'::jsonb),NULL);
 $f$;
 """)
