"""Native PostgreSQL fixture for the pending-income reader; synthetic sources only."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
print(r"""
BEGIN;
SET LOCAL statement_timeout='8s';
SET LOCAL TimeZone='America/Sao_Paulo';
CREATE SCHEMA lts_income_private;
GRANT USAGE ON SCHEMA lts_income_private TO authenticated,service_role;
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE u uuid:=nullif(current_setting('lts.fixture.owner',true),'')::uuid;
BEGIN IF u IS NULL THEN RAISE EXCEPTION 'Acesso não autorizado.';END IF;RETURN u;END $$;
SELECT set_config('lts.fixture.owner','00000000-0000-4000-8000-000000000001',true);
CREATE TABLE public.accounts(user_id uuid,institution text,is_active boolean,metadata jsonb);
CREATE TABLE public.v340_history(user_id uuid,event_date date,account text,description text,signed_amount numeric,
 source text,source_ref text,category text,open_finance_id uuid,internal_transfer boolean DEFAULT false,
 excluded_from_spend boolean DEFAULT false,confidence text);
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,institution_code text,posting_date date,
 signed_amount numeric,description_raw text,normalized_payload jsonb,occurred_at timestamptz,
 raw_hash text,provider_deleted_at timestamptz);
CREATE TABLE public.financial_events(id uuid,user_id uuid,legacy_id text,event_date date,amount numeric,
 is_projection boolean DEFAULT false,is_suppressed boolean DEFAULT false,is_internal_transfer boolean DEFAULT false,
 nature text DEFAULT 'income',status text DEFAULT 'confirmed');
CREATE TABLE public.evento_base(usuario_id uuid,idx integer,dados jsonb);
CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,category_label text);
CREATE TABLE public.lts_v229_documentary_match(user_id uuid,staging_id uuid,bank text,signed_amount numeric,canonical_date date,source_ref text);
CREATE FUNCTION public.lts_historical_effective_cash_v5(u uuid,a date,b date)
RETURNS TABLE(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,
 category text,open_finance_id uuid,internal_transfer boolean,excluded_from_spend boolean,confidence text)
LANGUAGE sql AS $$SELECT event_date,account,description,signed_amount,source,source_ref,category,open_finance_id,
 internal_transfer,excluded_from_spend,confidence FROM public.v340_history WHERE user_id=u AND event_date BETWEEN a AND b$$;
CREATE FUNCTION public.lts_flow_classification_decision_v1(u uuid,x jsonb) RETURNS jsonb LANGUAGE sql AS $$SELECT x$$;
CREATE FUNCTION public.lts_open_finance_checking_positions_v1(u uuid) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_array(jsonb_build_object('bank','Itaú','as_of','2020-12-31T23:59:59Z','payload',jsonb_build_object('provider_account_id','fixture-account')))$$;
CREATE FUNCTION public.lts_bank_posted_rows_v231(u uuid) RETURNS SETOF public.lts_open_finance_staging LANGUAGE sql AS $$
 SELECT * FROM public.lts_open_finance_staging WHERE user_id=u AND normalized_payload->>'status'='POSTED' AND provider_deleted_at IS NULL$$;
CREATE FUNCTION public.lts_documented_bank_event_identity_v242(u uuid,i uuid,x jsonb) RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
CREATE FUNCTION lts_income_private.own_credits_v296(u uuid,a date,b date) RETURNS TABLE(credit_id uuid) LANGUAGE sql AS $$SELECT NULL::uuid WHERE false$$;
CREATE FUNCTION public.lts_bank_known_classification_v231(u uuid,i uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
CREATE FUNCTION public.lts_bank_own_global_return_v1(u uuid,i uuid) RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
CREATE FUNCTION public.lts_bank_fgts_combined_receipt_v261(u uuid,i uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT NULL::jsonb$$;
CREATE FUNCTION lts_income_private.category_v296(u uuid,description text,category text) RETURNS text LANGUAGE sql STABLE AS $$SELECT category$$;
INSERT INTO public.accounts VALUES('00000000-0000-4000-8000-000000000001','Itaú',true,'{"evidence_sha256":"synthetic","balance_as_of":"2020-01-01"}');
INSERT INTO public.v340_history(user_id,event_date,account,description,signed_amount,source,source_ref,category)
SELECT '00000000-0000-4000-8000-000000000001','2020-02-01','Itaú','Synthetic receipt '||n,100+n,'legacy_fix86','evento_base:'||n,c
FROM (VALUES(1,NULL::text),(2,'Salário'),(3,'A known'),(3,'Sem categoria'),
 (4,'Classificação pendente'),(4,'Z known'),(5,''),(6,'A classificar'),(7,'Sem categoria'),
 (8,'Não identificado'),(9,'—'),(10,'Renda'),(11,'CLASSIFICAÇÃO   PENDENTE')) f(n,c);
INSERT INTO public.evento_base SELECT user_id,split_part(source_ref,':',2)::integer,
 jsonb_build_object('efeito','entrada','valor',signed_amount) FROM public.v340_history GROUP BY user_id,source_ref,signed_amount;
INSERT INTO public.lts_v178_review_decision VALUES('00000000-0000-4000-8000-000000000001','evento_base','4','Classificação pendente');
INSERT INTO public.v340_history(user_id,event_date,account,description,signed_amount,source,source_ref,category)
VALUES('00000000-0000-4000-8000-000000000001','2020-03-01','Bradesco','Fixture financial receipt',300,'financial_events','00000000-0000-4000-8000-000000000030','A classificar'),
 ('00000000-0000-4000-8000-000000000001','2020-03-02','C6','Uneditable receipt',12,'unmapped','unmapped-1','A classificar'),
 ('00000000-0000-4000-8000-000000000099','2020-02-01','Itaú','Other owner receipt',900,'legacy_fix86','evento_base:99','A classificar');
INSERT INTO public.financial_events(id,user_id,event_date,amount) VALUES('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000001','2020-03-01',300);
INSERT INTO public.lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001','341','2020-04-01',250,'Fixture bank receipt',
 '{"status":"POSTED","provider_account_id":"fixture-account"}','2020-04-01T12:00:00Z','fixture-raw-hash',NULL);
INSERT INTO public.v340_history(user_id,event_date,account,description,signed_amount,source,source_ref,category,internal_transfer,excluded_from_spend)
VALUES('00000000-0000-4000-8000-000000000001','2020-04-02','Itaú','Own transfer',200,'legacy_fix86','evento_base:80','A classificar',true,false),
 ('00000000-0000-4000-8000-000000000001','2020-04-03','Itaú','Excluded receipt',200,'legacy_fix86','evento_base:81','A classificar',false,true),
 ('00000000-0000-4000-8000-000000000001','2020-04-04','Itaú','Negative entry',-200,'legacy_fix86','evento_base:82','A classificar',false,false);
""")
print((ROOT / 'backend/qa/fixtures/v340_income_readers.sql').read_text())
print(r"""
REVOKE ALL ON FUNCTION lts_income_private.rows_v296(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.rows_v296(uuid,date,date) TO service_role;
REVOKE ALL ON FUNCTION lts_income_private.queue_v296(date,date,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION lts_income_private.queue_v296(date,date,integer,integer,text) TO authenticated,service_role;
REVOKE ALL ON FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text) TO authenticated,service_role;
CREATE TEMP TABLE v340_protected AS SELECT oid,to_jsonb(p)-'prosrc' attributes,pg_get_functiondef(oid) definition
 FROM pg_proc p WHERE oid IN('lts_income_private.rows_v296(uuid,date,date)'::regprocedure,
 'lts_income_private.queue_v296(date,date,integer,integer,text)'::regprocedure,
 'public.lts_browser_income_review_queue_v296(date,date,integer,integer,text)'::regprocedure);
CREATE TEMP TABLE v340_sources AS SELECT jsonb_build_object(
 'history',(SELECT jsonb_agg(to_jsonb(x)) FROM public.v340_history x),
 'raw',(SELECT jsonb_agg(to_jsonb(x)) FROM public.lts_open_finance_staging x),
 'financial',(SELECT jsonb_agg(to_jsonb(x)) FROM public.financial_events x),
 'legacy',(SELECT jsonb_agg(to_jsonb(x)) FROM public.evento_base x),
 'decisions',(SELECT jsonb_agg(to_jsonb(x)) FROM public.lts_v178_review_decision x)) j;
CREATE TEMP TABLE v340_cases AS SELECT off,lim,q,a,b,
 public.lts_browser_income_review_queue_v296(a,b,off,lim,q) expected
 FROM (VALUES(0,25,NULL::text,DATE '2020-01-01',DATE '2020-12-31'),(0,2,NULL,'2020-01-01','2020-12-31'),
 (2,2,NULL,'2020-01-01','2020-12-31'),(100,25,NULL,'2020-01-01','2020-12-31'),
 (0,25,'Synthetic receipt 4','2020-01-01','2020-12-31'),(0,25,'CLASSIFICACAO','2020-01-01','2020-12-31'),
 (0,25,'Itau','2020-01-01','2020-12-31'),(0,25,'not found','2020-01-01','2020-12-31'),
 (0,25,'   ','2020-01-01','2020-12-31'),(0,25,NULL,'2019-01-01','2019-12-31')) f(off,lim,q,a,b);
CREATE TEMP TABLE v340_full_rows AS SELECT x FROM lts_income_private.rows_v296('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')x;
""")
patch = (ROOT / 'backend/patches/v340/income_review_work.sql').read_text()
print(patch)
print("""
DO $rejections$
DECLARE target regprocedure;message text;checked integer:=0;
BEGIN
 FOREACH target IN ARRAY ARRAY[
  'lts_income_private.rows_v296(uuid,date,date)'::regprocedure,
  'lts_income_private.queue_v296(date,date,integer,integer,text)'::regprocedure,
  'lts_income_private.review_rows_v340(uuid,date,date)'::regprocedure] LOOP
  BEGIN
   EXECUTE replace(pg_get_functiondef(target),E'BEGIN\\n',E'BEGIN\\n -- fixture definition drift\\n');
   BEGIN
    EXECUTE $migration$""" + patch + """$migration$;
    RAISE EXCEPTION USING ERRCODE='V3400',MESSAGE='Changed dependency accepted';
   EXCEPTION WHEN SQLSTATE 'V3400' THEN RAISE;WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS message=MESSAGE_TEXT;
    IF message NOT LIKE 'V340 %' THEN RAISE;END IF;
    checked:=checked+1;
   END;
   RAISE EXCEPTION USING ERRCODE='V3401',MESSAGE='rollback fixture drift';
  EXCEPTION WHEN SQLSTATE 'V3401' THEN NULL;END;
 END LOOP;
 IF checked<>3 THEN RAISE EXCEPTION 'Definition rejection cases missing';END IF;
 PERFORM set_config('lts.v340.definition_rejections',checked::text,true);
END $rejections$;
""")
print(r"""
DO $test$
DECLARE r record;actual jsonb;rejections integer:=0;
BEGIN
 FOR r IN SELECT * FROM v340_cases LOOP
  actual:=public.lts_browser_income_review_queue_v296(r.a,r.b,r.off,r.lim,r.q);
  IF actual IS DISTINCT FROM r.expected THEN RAISE EXCEPTION 'Queue output changed: %',r;END IF;
 END LOOP;
 IF (SELECT expected->>'row_count' FROM v340_cases LIMIT 1)<>'11'
 THEN RAISE EXCEPTION 'Nonempty fixture did not cover all pending categories';END IF;
 IF EXISTS(SELECT 1 FROM lts_income_private.review_rows_v340('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')x WHERE x->>'decision_ref'='3')
 OR NOT EXISTS(SELECT 1 FROM lts_income_private.review_rows_v340('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')x WHERE x->>'decision_ref'='4')
 THEN RAISE EXCEPTION 'Duplicate winner changed before category filtering';END IF;
 IF (SELECT jsonb_agg(x ORDER BY x::text) FROM v340_full_rows) IS DISTINCT FROM
 (SELECT jsonb_agg(x ORDER BY x::text) FROM lts_income_private.rows_v296('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31')x)
 THEN RAISE EXCEPTION 'Canonical full-income rows changed';END IF;
 FOR r IN SELECT * FROM (VALUES(NULL::date,DATE '2020-12-31'),(DATE '2020-01-02',DATE '2020-01-01'),
 (DATE '2010-01-01',DATE '2020-01-01'),(current_date,current_date+1))f(a,b) LOOP
  BEGIN PERFORM * FROM lts_income_private.review_rows_v340('00000000-0000-4000-8000-000000000001',r.a,r.b);
   RAISE EXCEPTION USING ERRCODE='V3400',MESSAGE='Invalid period accepted';
  EXCEPTION WHEN SQLSTATE 'V3400' THEN RAISE;WHEN OTHERS THEN rejections:=rejections+1;END;
 END LOOP;
 FOR r IN SELECT * FROM (VALUES(-1,25,NULL::text),(0,0,NULL),(0,101,NULL),(NULL,25,NULL),(0,25,repeat('x',301)))f(off,lim,q) LOOP
  BEGIN PERFORM public.lts_browser_income_review_queue_v296('2020-01-01','2020-12-31',r.off,r.lim,r.q);
   RAISE EXCEPTION USING ERRCODE='V3400',MESSAGE='Invalid filter accepted';
  EXCEPTION WHEN SQLSTATE 'V3400' THEN RAISE;WHEN OTHERS THEN rejections:=rejections+1;END;
 END LOOP;
 BEGIN PERFORM * FROM lts_income_private.review_rows_v340('00000000-0000-4000-8000-000000000099','2020-01-01','2020-12-31');
  RAISE EXCEPTION USING ERRCODE='V3400',MESSAGE='Other owner accepted';
 EXCEPTION WHEN SQLSTATE 'V3400' THEN RAISE;WHEN OTHERS THEN rejections:=rejections+1;END;
 IF has_function_privilege('anon','lts_income_private.review_rows_v340(uuid,date,date)','EXECUTE')
 OR has_function_privilege('authenticated','lts_income_private.review_rows_v340(uuid,date,date)','EXECUTE')
 OR NOT has_function_privilege('service_role','lts_income_private.review_rows_v340(uuid,date,date)','EXECUTE')
 THEN RAISE EXCEPTION 'Private worker ACL changed';END IF;
 EXECUTE 'SET LOCAL ROLE authenticated';
 actual:=public.lts_browser_income_review_queue_v296('2020-01-01','2020-12-31');
 IF actual->>'row_count'<>'11' THEN RAISE EXCEPTION 'Authenticated wrapper failed';END IF;
 BEGIN PERFORM * FROM lts_income_private.review_rows_v340('00000000-0000-4000-8000-000000000001','2020-01-01','2020-12-31');
  RAISE EXCEPTION 'Private worker callable';EXCEPTION WHEN insufficient_privilege THEN rejections:=rejections+1;END;
 EXECUTE 'RESET ROLE';
 EXECUTE 'SET LOCAL ROLE anon';
 BEGIN PERFORM public.lts_browser_income_review_queue_v296('2020-01-01','2020-12-31');
  RAISE EXCEPTION 'Anonymous queue callable';EXCEPTION WHEN insufficient_privilege THEN rejections:=rejections+1;END;
 EXECUTE 'RESET ROLE';
 PERFORM set_config('lts.fixture.owner','',true);
 BEGIN PERFORM public.lts_browser_income_review_queue_v296('2020-01-01','2020-12-31');
  RAISE EXCEPTION USING ERRCODE='V3400',MESSAGE='Missing owner accepted';
 EXCEPTION WHEN SQLSTATE 'V3400' THEN RAISE;WHEN OTHERS THEN rejections:=rejections+1;END;
 PERFORM set_config('lts.fixture.owner','00000000-0000-4000-8000-000000000001',true);
 PERFORM set_config('lts.v340.rejections',rejections::text,true);
END $test$;
CREATE TEMP TABLE v340_replay AS SELECT pg_get_functiondef('lts_income_private.review_rows_v340(uuid,date,date)'::regprocedure) worker,
 pg_get_functiondef('lts_income_private.queue_v296(date,date,integer,integer,text)'::regprocedure) queue;
""")
print(patch)
print(r"""
DO $test$
BEGIN
 IF (SELECT worker FROM v340_replay) IS DISTINCT FROM pg_get_functiondef('lts_income_private.review_rows_v340(uuid,date,date)'::regprocedure)
 OR (SELECT queue FROM v340_replay) IS DISTINCT FROM pg_get_functiondef('lts_income_private.queue_v296(date,date,integer,integer,text)'::regprocedure)
 THEN RAISE EXCEPTION 'Replay changed the reader';END IF;
 IF EXISTS(SELECT 1 FROM v340_protected b JOIN pg_proc p ON p.oid=b.oid WHERE b.attributes IS DISTINCT FROM to_jsonb(p)-'prosrc'
 OR (p.proname<>'queue_v296' AND b.definition IS DISTINCT FROM pg_get_functiondef(p.oid)))
 THEN RAISE EXCEPTION 'Protected function or attributes changed';END IF;
 IF (SELECT j FROM v340_sources) IS DISTINCT FROM(SELECT jsonb_build_object(
 'history',(SELECT jsonb_agg(to_jsonb(x)) FROM public.v340_history x),
 'raw',(SELECT jsonb_agg(to_jsonb(x)) FROM public.lts_open_finance_staging x),
 'financial',(SELECT jsonb_agg(to_jsonb(x)) FROM public.financial_events x),
 'legacy',(SELECT jsonb_agg(to_jsonb(x)) FROM public.evento_base x),
 'decisions',(SELECT jsonb_agg(to_jsonb(x)) FROM public.lts_v178_review_decision x)))
 THEN RAISE EXCEPTION 'Source records changed';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'version',340,'queue_cases',(SELECT count(*) FROM v340_cases),
 'rejection_cases',current_setting('lts.v340.rejections')::integer,'pending_rows',11,
 'definition_rejection_cases',current_setting('lts.v340.definition_rejections')::integer,
 'duplicate_winners_exact',true,'full_income_worker_exact',true,'queue_json_and_tokens_exact',true,
 'source_records_unchanged',true,'function_attributes_exact',true,'owner_checks',true,
 'private_worker_access_denied',true,'anonymous_access_denied',true,'replay_noop',true,
 'dependency_fixture_not_production_certificate',true) receipt;
ROLLBACK;
""")
