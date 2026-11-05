-- Disposable synthetic PostgreSQL fixtures. No production rows, credentials or JWTs.
SET TimeZone='America/Sao_Paulo';
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
END $roles$;
CREATE SCHEMA qa_v415;
CREATE SCHEMA auth;
CREATE SCHEMA cron;
CREATE SCHEMA lts_projection_private_v412;
CREATE TABLE qa_v415.results(name text PRIMARY KEY,pass boolean NOT NULL CHECK(pass),details jsonb);
CREATE TABLE qa_v415.config(key text PRIMARY KEY,value jsonb);
INSERT INTO qa_v415.config VALUES ('mode','"normal"'),('pause_stage','null'),('c6_complete','true');
CREATE SEQUENCE qa_v415.heavy_calls;
CREATE TABLE qa_v415.calls(id bigint GENERATED ALWAYS AS IDENTITY,stage text,owner_id uuid);
CREATE FUNCTION qa_v415.owner(p_number integer DEFAULT 1) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE p_number WHEN 1 THEN '11111111-1111-4111-8111-111111111111'::uuid
 WHEN 2 THEN '22222222-2222-4222-8222-222222222222'::uuid
 ELSE '33333333-3333-4333-8333-333333333333'::uuid END
$$;
CREATE FUNCTION qa_v415.check(p_name text,p_pass boolean,p_details jsonb DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$BEGIN
 IF p_pass IS DISTINCT FROM true THEN RAISE EXCEPTION 'V415 check failed: %',p_name USING DETAIL=coalesce(p_details::text,''); END IF;
 INSERT INTO qa_v415.results VALUES(p_name,true,p_details);
END$$;
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,deleted_at timestamptz,banned_until timestamptz,is_anonymous boolean DEFAULT false);
INSERT INTO auth.users(id,email) VALUES
 (qa_v415.owner(1),'first@example.invalid'),(qa_v415.owner(2),'second@example.invalid'),
 (qa_v415.owner(3),'inactive@example.invalid');
CREATE TABLE public.lts_allowed_users(email text PRIMARY KEY,active boolean NOT NULL);
INSERT INTO public.lts_allowed_users VALUES
 ('first@example.invalid',true),('SECOND@example.invalid',true),('inactive@example.invalid',false);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('app.synthetic_uid',true),'')::uuid
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce((SELECT jsonb_build_object('email',u.email) FROM auth.users u WHERE u.id=auth.uid()),'{}'::jsonb)
$$;
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='public' AS $function$
declare v_uid uuid:=auth.uid(); v_email text:=lower(coalesce(auth.jwt()->>'email',''));
begin
  if v_uid is null or v_email='' then raise exception 'unauthorized' using errcode='42501'; end if;
  if not exists(select 1 from public.lts_allowed_users a where a.active=true and lower(a.email)=v_email) then
    raise exception 'forbidden' using errcode='42501';
  end if;
  return v_uid;
end $function$;
CREATE TABLE public.lts_product_read_cache(user_id uuid PRIMARY KEY,payload_version text,payload jsonb,refreshed_at timestamptz,source text);
CREATE TABLE public.lts_dashboard_cockpit_cache(user_id uuid PRIMARY KEY,as_of date,source_product_refreshed_at timestamptz,payload jsonb);
CREATE TABLE public.lts_flow_future_read_cache(user_id uuid PRIMARY KEY,payload jsonb);
CREATE TABLE public.lts_flow_future_read_cache_v2(user_id uuid PRIMARY KEY,payload jsonb);
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text,
 PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
CREATE TABLE public.lts_open_finance_staging(id text PRIMARY KEY,user_id uuid,sync_run_id text,last_seen_at timestamptz,updated_at timestamptz);
CREATE TABLE public.card_invoices(id text PRIMARY KEY,user_id uuid,amount numeric,metadata jsonb);
CREATE TABLE public.lts_card_document_supplement_v234(id text PRIMARY KEY,user_id uuid,amount numeric);
CREATE TABLE public.lts_card_documentary_payment_link_v272(id text PRIMARY KEY,user_id uuid,amount numeric);
CREATE TABLE public.lts_card_settlement_expense_contract_v273(payment_source_id text PRIMARY KEY,user_id uuid,amount numeric);
INSERT INTO public.lts_open_finance_staging VALUES
 ('first-receipt',qa_v415.owner(1),'first-sync','2026-11-05T10:00:00Z','2026-11-05T10:00:00Z'),
 ('second-receipt',qa_v415.owner(2),'second-sync','2026-11-05T10:00:00Z','2026-11-05T10:00:00Z');
INSERT INTO public.card_invoices VALUES('first-invoice',qa_v415.owner(1),25,'{"keep":true}'),('second-invoice',qa_v415.owner(2),30,'{"keep":true}');
INSERT INTO public.lts_card_document_supplement_v234 VALUES('first-doc',qa_v415.owner(1),25);
INSERT INTO public.lts_card_documentary_payment_link_v272 VALUES('first-link',qa_v415.owner(1),25);
INSERT INTO public.lts_card_settlement_expense_contract_v273 VALUES('first-settlement',qa_v415.owner(1),25);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY CHECK(singleton),epoch bigint NOT NULL);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,415);
CREATE TABLE public.lts_access_audit(user_id uuid,email text,action text,meta jsonb);
CREATE TABLE public.financial_events(id text PRIMARY KEY,user_id uuid,event_date date,amount numeric,metadata jsonb);
INSERT INTO public.financial_events VALUES
 ('first-document',qa_v415.owner(1),'2026-10-01',123.45,'{"original":"retain","nested":[0,false,null]}'),
 ('second-document',qa_v415.owner(2),'2026-10-02',678.90,'{"original":"other owner"}');
CREATE TABLE public.accounts(id text PRIMARY KEY,user_id uuid,metadata jsonb);
INSERT INTO public.accounts VALUES
 ('first-account',qa_v415.owner(1),'{"balance":123.45,"source":"synthetic-original"}'),
 ('second-account',qa_v415.owner(2),'{"balance":678.90,"source":"other-owner"}');
CREATE TABLE public.legacy_namespace(usuario_id uuid,chave text,valor jsonb,PRIMARY KEY(usuario_id,chave));
INSERT INTO public.legacy_namespace VALUES(qa_v415.owner(1),'lts_owner_projection_policy_v412','{"keep":[1,2,3],"historical":true}');
CREATE TABLE public.lts_recurring_plan_v366(user_id uuid,active boolean,value_kind text);
INSERT INTO public.lts_recurring_plan_v366 VALUES(qa_v415.owner(1),true,'fixed');
CREATE FUNCTION qa_v415.source_hash() RETURNS text LANGUAGE plpgsql AS $$
DECLARE t text;h text;parts text:='';BEGIN
 FOREACH t IN ARRAY ARRAY['public.financial_events','public.accounts','public.legacy_namespace','public.lts_recurring_plan_v366','auth.users','public.lts_allowed_users',
  'public.lts_open_finance_staging','public.card_invoices','public.lts_card_document_supplement_v234','public.lts_card_documentary_payment_link_v272','public.lts_card_settlement_expense_contract_v273'] LOOP
  EXECUTE 'SELECT md5(coalesce(string_agg(to_jsonb(x)::text,''|'' ORDER BY to_jsonb(x)::text),'''')) FROM '||t||' x' INTO h;
  parts:=parts||t||h;
 END LOOP;
 RETURN md5(parts);
END$$;
CREATE TABLE qa_v415.original_sources AS SELECT qa_v415.source_hash() AS digest;
CREATE FUNCTION qa_v415.note(p_stage text,p_owner uuid DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$BEGIN
 PERFORM nextval('qa_v415.heavy_calls');
 INSERT INTO qa_v415.calls(stage,owner_id) VALUES(p_stage,p_owner);
 IF (SELECT value#>>'{}' FROM qa_v415.config WHERE key='pause_stage')=p_stage THEN
  -- Native concurrency gate holds 415001999; 415001997 identifies the paused worker.
  PERFORM pg_advisory_xact_lock(415001997::bigint);
  PERFORM pg_advisory_xact_lock(415001999::bigint);
 END IF;
END$$;
CREATE FUNCTION qa_v415.count_calls() RETURNS bigint LANGUAGE sql AS $$
 SELECT CASE WHEN is_called THEN last_value ELSE 0 END FROM qa_v415.heavy_calls
$$;
CREATE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid) RETURNS text LANGUAGE sql STABLE AS $$
 SELECT 'synthetic-source:'||p_user_id::text||':'||epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton
$$;
CREATE FUNCTION public.lts_dashboard_payload_key_v240(p_payload jsonb) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT md5((p_payload-'canonical_summary')::text)
$$;
CREATE FUNCTION qa_v415.full_payload(p_owner uuid,p_canonical boolean DEFAULT true) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE j jsonb;BEGIN
 j:=jsonb_build_object(
  'version','lts-product-fix86-v36','owner_fixture',p_owner,
  'dashboard',jsonb_build_object('fixture_total',123.45,'unknown_dashboard',jsonb_build_array(false,NULL,7)),
  'flow',jsonb_build_object('version','canonical-flow-v240-cache','from',current_date,'to',current_date+365,
    'days',jsonb_build_array(jsonb_build_object('date',current_date,'fix86_columns',jsonb_build_object('saldo_final',123.45)),
      jsonb_build_object('date',current_date+1,'fix86_columns',jsonb_build_object('saldo_final',1000),
       'C6',jsonb_build_object('balance',40),'Consolidado',jsonb_build_object('balance',90),'Itau',jsonb_build_object('balance',50))),
    'events',jsonb_build_array(jsonb_build_object('source_ref','synthetic-original','signed_amount',123.45),
      jsonb_build_object('source','card_invoice','account','C6','event_date',current_date+1,'signed_amount',-25))),
  'expenses',jsonb_build_object('keep','expense-history'),
  'wealth',jsonb_build_object('keep','wealth-history'),
  'wealth_executive',jsonb_build_object('keep','wealth-executive'),
  'commitments',jsonb_build_array('commitment'),
  'planning',jsonb_build_object('keep','planning'),
  'planning_executive',jsonb_build_object('keep','planning-executive'),
  'planning_ladder',jsonb_build_object('keep','planning-ladder'),
  'input',jsonb_build_object('keep','input'),
  'backup',jsonb_build_object('keep','backup'),
  'product_contract',jsonb_build_object('keep','product-contract'),
  'documentary_commitments',jsonb_build_object('keep','documentary-commitments'),
  'card_instruments',jsonb_build_array('instrument'),
  'commitment_schedules',jsonb_build_array('schedule'),
  'navigation',jsonb_build_array('Dashboard','Fluxo','Despesas'),
  'card_operating',jsonb_build_object('keep','cards'),
  'card_classification_review',jsonb_build_object('category_options',jsonb_build_array('fixture')),
  'semantic_review',jsonb_build_object('items','[]'::jsonb),
  'updates',jsonb_build_object('freshness',jsonb_build_object('today',current_date),
    'document_change_summary_version','document-change-summary-v1','unknown_update',jsonb_build_object('nested',jsonb_build_array(1,true,NULL))),
  'unknown_future_branch',jsonb_build_object('owner',p_owner,'deep',jsonb_build_array(1,false,NULL,jsonb_build_object('preserve','exact')))
 );
 IF p_canonical THEN
  j:=j||jsonb_build_object('canonical_summary',jsonb_build_object('version','v240','as_of',current_date,
   'source_key',public.lts_dashboard_source_key_v240(p_owner),
   'payload_key',public.lts_dashboard_payload_key_v240(j),'financial_fact_changed',false));
 END IF;
 RETURN j;
END$$;
CREATE FUNCTION qa_v415.seed_cache(p_owner uuid,p_canonical boolean DEFAULT true) RETURNS void LANGUAGE plpgsql AS $$BEGIN
 INSERT INTO public.lts_product_read_cache VALUES(p_owner,'lts-product-fix86-v36',qa_v415.full_payload(p_owner,p_canonical),now(),'synthetic-existing')
 ON CONFLICT(user_id) DO UPDATE SET payload_version=excluded.payload_version,payload=excluded.payload,refreshed_at=excluded.refreshed_at,source=excluded.source;
 PERFORM public.lts_c6_completeness_state_v269(p_owner);
END$$;
CREATE FUNCTION public.lts_product_read_cached_v1(p_user_id uuid) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='public' AS $$
 SELECT CASE WHEN c.user_id IS NULL THEN NULL ELSE jsonb_build_object('payload',c.payload,'payload_version',c.payload_version,
 'refreshed_at',c.refreshed_at,'source',c.source) END
 FROM(SELECT p_user_id AS requested_user)r LEFT JOIN public.lts_product_read_cache c ON c.user_id=r.requested_user
$$;
CREATE FUNCTION public.lts_product_payload_fix86_v36(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN
 PERFORM qa_v415.note('v36',p_user_id);RETURN qa_v415.full_payload(p_user_id,false);
END$$;
CREATE FUNCTION public.lts_refresh_product_read_cache_v2(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public' SET TimeZone='America/Sao_Paulo' AS $$
DECLARE j jsonb;mode text;BEGIN
 PERFORM qa_v415.note('v2',p_user_id);
 j:=public.lts_product_payload_fix86_v36(p_user_id);
 SELECT value#>>'{}' INTO mode FROM qa_v415.config WHERE key='mode';
 IF mode='partial_v2' THEN j:='{"version":"lts-product-fix86-v36","partial":true}'; END IF;
 INSERT INTO public.lts_product_read_cache VALUES(p_user_id,'lts-product-fix86-v36',j,now(),'synthetic-v2')
 ON CONFLICT(user_id) DO UPDATE SET payload=excluded.payload,payload_version=excluded.payload_version,refreshed_at=excluded.refreshed_at,source=excluded.source;
 RETURN jsonb_build_object('ok',true,'payload_version','lts-product-fix86-v36','refreshed_at',now());
END$$;
CREATE FUNCTION public.lts_refresh_product_read_cache_operational_v5(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' SET statement_timeout='45s' AS $$
DECLARE j jsonb;mode text;k text;pk text;BEGIN
 PERFORM qa_v415.note('v5',p_user_id);
 SELECT payload INTO j FROM public.lts_product_read_cache WHERE user_id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'product cache unavailable'; END IF;
 -- Match lower derived-cache row locks held by the real anchor during calculation.
 UPDATE public.lts_flow_future_read_cache_v2 SET payload=payload WHERE user_id=p_user_id;
 PERFORM qa_v415.note('v5_locked',p_user_id);
 k:=public.lts_dashboard_source_key_v240(p_user_id);pk:=public.lts_dashboard_payload_key_v240(j);
 IF j#>>'{canonical_summary,source_key}'=k AND j#>>'{canonical_summary,payload_key}'=pk THEN
  INSERT INTO qa_v415.calls(stage,owner_id) VALUES('v5_short_circuit',p_user_id);
  RETURN '{"ok":true,"cache_hit":true,"version":"canonical-cache-v240"}'::jsonb;
 END IF;
 INSERT INTO qa_v415.calls(stage,owner_id) VALUES('v5_recalculate',p_user_id);
 SELECT value#>>'{}' INTO mode FROM qa_v415.config WHERE key='mode';
 -- Preserve arbitrary branches, matching the real anchor's top-level JSONB merge.
 j:=j||jsonb_build_object('flow',qa_v415.full_payload(p_user_id,false)->'flow',
   'updates',qa_v415.full_payload(p_user_id,false)->'updates');
 j:=j||jsonb_build_object('canonical_summary',jsonb_build_object('version','v240','as_of',current_date,
   'source_key',k,'payload_key',public.lts_dashboard_payload_key_v240(j),'financial_fact_changed',false));
 IF mode='partial_v5' THEN j:='{"version":"lts-product-fix86-v36","partial":true}'; END IF;
 IF mode='wrong_day' THEN j:=jsonb_set(j,'{canonical_summary,as_of}',to_jsonb((current_date-1)::text)); END IF;
 IF mode='missing_current_day' THEN j:=jsonb_set(j,'{flow,days}','[]'); END IF;
 UPDATE public.lts_product_read_cache SET payload=j,refreshed_at=now(),source='synthetic-v5',
   payload_version=CASE WHEN mode='wrong_version' THEN 'unexpected-contract' ELSE 'lts-product-fix86-v36' END
 WHERE user_id=p_user_id;
 INSERT INTO public.lts_dashboard_cockpit_cache VALUES(p_user_id,current_date,now(),j->'dashboard')
 ON CONFLICT(user_id) DO UPDATE SET payload=excluded.payload,as_of=excluded.as_of,source_product_refreshed_at=excluded.source_product_refreshed_at;
 IF mode='raise_after_write' THEN RAISE EXCEPTION 'private synthetic failure that must never reach public status' USING ERRCODE='XX000'; END IF;
 IF mode='cancel_after_write' THEN RAISE EXCEPTION 'synthetic statement cancellation' USING ERRCODE='57014'; END IF;
 IF mode='epoch_after_write' THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton; END IF;
 RETURN '{"ok":true,"cache_hit":false,"version":"canonical-cache-v240"}'::jsonb;
END$$;
-- Real browser dependencies are observable and must not execute on an empty-cache response.
CREATE FUNCTION public.lts_card_read_start_v269(uuid) RETURNS text LANGUAGE plpgsql AS $$BEGIN PERFORM qa_v415.note('card_read_start',$1);RETURN 'qa';END$$;
CREATE FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN PERFORM qa_v415.note('card_read_finish',$1);RETURN $3;END$$;
CREATE FUNCTION public.lts_c6_completeness_state_v269(uuid) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN PERFORM qa_v415.note('completeness',$1);RETURN '{}';END$$;
CREATE FUNCTION public.lts_card_cycles_v226(uuid) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN
 PERFORM qa_v415.note('c6_cycles_cold',$1);
 RETURN jsonb_build_object('complete',(SELECT value FROM qa_v415.config WHERE key='c6_complete'),
  'incomplete_families',CASE WHEN(SELECT value FROM qa_v415.config WHERE key='c6_complete')='false'::jsonb THEN '["c6"]'::jsonb ELSE '[]'::jsonb END);
END$$;
CREATE FUNCTION public.lts_product_card_completeness_v269(jsonb,jsonb) RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_browser_enrich_flow_bank_gross_v1(jsonb) RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_debt_evidence_read_v357(uuid,date) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN PERFORM qa_v415.note('debt_read',$1);RETURN '{}';END$$;
CREATE FUNCTION public.lts_current_debt_overlay_v357(jsonb,jsonb,text) RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_card_cycles_presentation_v355(uuid) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN PERFORM qa_v415.note('card_cycles',$1);RETURN '{}';END$$;
CREATE FUNCTION public.lts_product_card_operating_overlay_v355(jsonb,jsonb,date) RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION lts_projection_private_v412.refresh_reference(uuid,date) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN
 PERFORM qa_v415.note('refresh_reference',$1);RETURN '{"ok":true,"reference":"synthetic"}';
END$$;
CREATE FUNCTION public.lts_recurring_materialize_v366(uuid,date) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN
 PERFORM qa_v415.note('materialize_fixed',$1);RETURN '{"ok":true,"materialized":true}';
END$$;
CREATE FUNCTION lts_projection_private_v412.read_policy() RETURNS jsonb LANGUAGE sql AS $$
 SELECT '{"ok":true,"policy":{"keep":"original-policy"},"unknown_policy":[false,null,1]}'::jsonb
$$;
-- Minimal pg_cron metadata/API doubles. Scheduling itself is not simulated or certified.
CREATE TABLE cron.job(jobid bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,schedule text,command text,nodename text DEFAULT 'localhost',nodeport integer DEFAULT 5432,database text DEFAULT 'postgres',username text DEFAULT 'postgres',active boolean DEFAULT true,jobname text UNIQUE);
INSERT INTO cron.job(jobid,schedule,command,jobname) VALUES
 (2,'5 3 * * *','select public.lts_refresh_product_read_cache_operational_v5(user_id) from public.lts_product_read_cache order by user_id;','lts_product_read_cache_operational_daily_v1'),
 (99,'0 2 * * *','select ''unrelated-maintenance-sentinel'';','unrelated-fixture-job');
SELECT setval(pg_get_serial_sequence('cron.job','jobid'),100,false);
CREATE FUNCTION cron.schedule(job_name text,schedule text,command text) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE n bigint;BEGIN
 INSERT INTO cron.job(jobname,schedule,command) VALUES(job_name,schedule,command)
 ON CONFLICT(jobname) DO UPDATE SET schedule=excluded.schedule,command=excluded.command RETURNING jobid INTO n;RETURN n;
END$$;
CREATE FUNCTION cron.alter_job(job_id bigint,schedule text DEFAULT NULL,command text DEFAULT NULL,database text DEFAULT NULL,username text DEFAULT NULL,active boolean DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$BEGIN
 UPDATE cron.job j SET schedule=coalesce(alter_job.schedule,j.schedule),command=coalesce(alter_job.command,j.command),
 database=coalesce(alter_job.database,j.database),username=coalesce(alter_job.username,j.username),active=coalesce(alter_job.active,j.active)
 WHERE j.jobid=job_id;
END$$;
CREATE FUNCTION cron.unschedule(job_id bigint) RETURNS boolean LANGUAGE plpgsql AS $$BEGIN DELETE FROM cron.job WHERE jobid=job_id;RETURN FOUND;END$$;
CREATE FUNCTION cron.unschedule(job_name text) RETURNS boolean LANGUAGE plpgsql AS $$BEGIN DELETE FROM cron.job WHERE jobname=job_name;RETURN FOUND;END$$;
CREATE TABLE qa_v415.original_cron AS TABLE cron.job;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA public,auth TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION auth.uid(),auth.jwt() TO authenticated,service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT USAGE ON SCHEMA lts_projection_private_v412 TO service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON FUNCTION public.lts_browser_assert_user_v1() TO authenticated;
CREATE TABLE qa_v415.stub_functions AS
SELECT p.oid::regprocedure::text AS signature,pg_get_functiondef(p.oid) AS definition
FROM pg_proc p WHERE p.oid IN('public.lts_refresh_product_read_cache_v2(uuid)'::regprocedure,
 'public.lts_refresh_product_read_cache_operational_v5(uuid)'::regprocedure);
