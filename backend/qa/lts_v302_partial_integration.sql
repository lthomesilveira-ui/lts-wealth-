-- Private integration trial. Supply the reviewed manifest in lts.v302.input.
-- All original data, functions, memo invalidation and new bindings roll back.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='25s';
SET LOCAL lock_timeout='2s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
UPDATE public.lts_v229_read_cache SET as_of='2000-01-01',source_fingerprint='v302-partial-trial-rollback',refreshed_at='2000-01-01'
WHERE user_id=public.lts_open_finance_pilot_owner_v1();
CREATE TEMP TABLE v302_before ON COMMIT DROP AS
WITH p AS(SELECT public.lts_open_finance_pilot_owner_v1() u,current_setting('lts.v302.input')::jsonb m),
target AS(SELECT f.* FROM public.financial_events f,p WHERE user_id=u AND id=(m->>'event_id')::uuid)
SELECT
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(f) ORDER BY id)::text,'[]')) FROM public.financial_events f,p
  WHERE user_id=u AND id<>(m->>'event_id')::uuid) other_events,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(d) ORDER BY source_table,source_ref)::text,'[]')) FROM public.lts_v178_review_decision d,p WHERE user_id=u) decisions,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY id)::text,'[]')) FROM public.lts_open_finance_staging s,p WHERE user_id=u) sources,
 (SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY financial_event_id),'[]') FROM public.lts_realized_bank_sources_v238((SELECT u FROM p))r) prior_realized,
 (SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM public.lts_v229_expense_rows((SELECT u FROM p),'2013-10-10',current_date)r) expenses,
 (SELECT jsonb_object_agg(proname,jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'definer',prosecdef,'volatility',provolatile,'config',proconfig))
  FROM pg_proc WHERE oid IN('public.lts_realized_bank_sources_v238(uuid)'::regprocedure,
  'public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure,'public.lts_corrected_cashflow_v1(uuid,date,date)'::regprocedure,
  'public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)'::regprocedure)) attributes,
 public.lts_browser_flow_v242((SELECT event_date-1 FROM target),(SELECT event_date+1 FROM target)) flow;
\ir ../patches/v302/partial_obligation_evidence.sql
\ir lts_v302_partial_evidence.sql
\ir ../operations/reconcile_partial_obligation_v302.sql
SELECT set_config('lts.v302.first_receipt',current_setting('lts.v302.receipt'),true);
CREATE TEMP TABLE v302_after ON COMMIT DROP AS
WITH p AS(SELECT public.lts_open_finance_pilot_owner_v1() u,current_setting('lts.v302.input')::jsonb m),
target AS(SELECT f.* FROM public.financial_events f,p WHERE user_id=u AND id=(m->>'event_id')::uuid)
SELECT
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(f) ORDER BY id)::text,'[]')) FROM public.financial_events f,p
  WHERE user_id=u AND id<>(m->>'event_id')::uuid) other_events,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(d) ORDER BY source_table,source_ref)::text,'[]')) FROM public.lts_v178_review_decision d,p WHERE user_id=u) decisions,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY id)::text,'[]')) FROM public.lts_open_finance_staging s,p WHERE user_id=u) sources,
 (SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY financial_event_id),'[]') FROM public.lts_realized_bank_sources_v238((SELECT u FROM p))r
  WHERE financial_event_id<>(SELECT (m->>'event_id')::uuid FROM p)) prior_realized,
 (SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM public.lts_v229_expense_rows((SELECT u FROM p),'2013-10-10',current_date)r
  WHERE NOT(r.source_table='financial_events' AND r.source_ref=(SELECT m->>'event_id' FROM p))) expenses,
 (SELECT jsonb_object_agg(proname,jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'definer',prosecdef,'volatility',provolatile,'config',proconfig))
  FROM pg_proc WHERE oid IN('public.lts_realized_bank_sources_v238(uuid)'::regprocedure,
  'public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure,'public.lts_corrected_cashflow_v1(uuid,date,date)'::regprocedure,
  'public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)'::regprocedure)) attributes,
 public.lts_browser_flow_v242((SELECT event_date-1 FROM target),(SELECT event_date+1 FROM target)) flow;
DO $parity$
DECLARE k text;
BEGIN
 FOREACH k IN ARRAY ARRAY['other_events','decisions','sources','prior_realized','expenses','attributes'] LOOP
  IF (SELECT to_jsonb(b)->k FROM v302_before b) IS DISTINCT FROM (SELECT to_jsonb(a)->k FROM v302_after a)
  THEN RAISE EXCEPTION 'V302 unrelated data or function attribute changed: %',k;END IF;
 END LOOP;
 IF (SELECT flow#>'{flow,historical,days}' FROM v302_before) IS DISTINCT FROM
 (SELECT flow#>'{flow,historical,days}' FROM v302_after) THEN RAISE EXCEPTION 'V302 historical day fields changed';END IF;
END $parity$;
CREATE TEMP TABLE v302_replay_before ON COMMIT DROP AS
SELECT md5(to_jsonb(f)::text) event_hash,
 (SELECT count(*) FROM public.audit_log WHERE user_id=f.user_id AND action='reconcile_confirmed_partial_obligation' AND entity_id=f.id::text) audit_count
FROM public.financial_events f WHERE user_id=public.lts_open_finance_pilot_owner_v1()
AND id=(current_setting('lts.v302.input')::jsonb->>'event_id')::uuid;
\ir ../operations/reconcile_partial_obligation_v302.sql
DO $replay$
BEGIN
 IF current_setting('lts.v302.receipt')::jsonb->>'status'<>'already_reconciled'
 OR (SELECT md5(to_jsonb(f)::text) FROM public.financial_events f WHERE user_id=public.lts_open_finance_pilot_owner_v1()
 AND id=(current_setting('lts.v302.input')::jsonb->>'event_id')::uuid) IS DISTINCT FROM (SELECT event_hash FROM v302_replay_before)
 OR (SELECT count(*) FROM public.audit_log WHERE user_id=public.lts_open_finance_pilot_owner_v1()
 AND action='reconcile_confirmed_partial_obligation' AND entity_id=current_setting('lts.v302.input')::jsonb->>'event_id')
 IS DISTINCT FROM (SELECT audit_count FROM v302_replay_before)
 THEN RAISE EXCEPTION 'V302 reapplication is not a no-op';END IF;
END $replay$;
SELECT jsonb_build_object('status','PASS','synthetic',current_setting('lts.v302.synthetic_receipt')::jsonb,
 'first_application',current_setting('lts.v302.first_receipt')::jsonb,'reapplication',current_setting('lts.v302.receipt')::jsonb,
 'source_and_unrelated_data_parity',true,'original_function_attributes_preserved',true,'historical_day_fields_exact',true,
 'before_flow',(SELECT flow FROM v302_before),'after_flow',(SELECT flow FROM v302_after)) receipt;
ROLLBACK;
