-- Run as a diagnostic transaction; all category decisions and audit rows roll back.
BEGIN;
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL statement_timeout='60s';
DO $qa$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();r jsonb;p jsonb;s jsonb;cat text;
 before_sources text;after_sources text;denied boolean;checks jsonb:='[]';
BEGIN
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated',
  'email',(SELECT email FROM auth.users WHERE id=u))::text,true);
 SELECT md5(jsonb_build_object(
  'bank',(SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM public.lts_open_finance_staging x WHERE user_id=u),
  'financial',(SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM public.financial_events x WHERE user_id=u),
  'legacy',(SELECT jsonb_agg(to_jsonb(x) ORDER BY idx) FROM public.evento_base x WHERE usuario_id=u),
  'expenses',(SELECT jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text) FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x))::text) INTO before_sources;
 SELECT category INTO cat FROM public.lts_category_catalog WHERE user_id=u AND active AND category='Reembolso Organon';
 IF cat IS NULL THEN RAISE EXCEPTION 'QA canonical category missing';END IF;
 FOR r IN SELECT x FROM lts_income_private.rows_v296(u,'2013-10-10',current_date)x
  WHERE x->>'editable'='true' AND x->>'category'='A classificar'
  AND x->>'source' IN('open_finance','legacy_fix86')
  ORDER BY CASE x->>'source' WHEN 'open_finance' THEN 0 ELSE 1 END,x->>'event_date' DESC
 LOOP
  IF checks ? (r->>'source') THEN CONTINUE;END IF;
  p:=public.lts_browser_income_category_v183(r->>'source',r->>'source_ref',(r->>'event_date')::date,r->>'account',(r->>'signed_amount')::numeric,NULL,NULL);
  IF p->>'editable'<>'true' OR NOT(p->'options' ? cat) THEN RAISE EXCEPTION 'Preview/category registry mismatch';END IF;
  denied:=false;
  BEGIN PERFORM public.lts_browser_income_category_v183(r->>'source',r->>'source_ref',(r->>'event_date')::date,r->>'account',-1,cat,p->>'token');
  EXCEPTION WHEN OTHERS THEN denied:=true;END;
  IF NOT denied THEN RAISE EXCEPTION 'Negative income accepted';END IF;
  denied:=false;
  BEGIN PERFORM public.lts_browser_income_category_v183(r->>'source',r->>'source_ref',(r->>'event_date')::date,r->>'account',(r->>'signed_amount')::numeric,cat,'stale-token');
  EXCEPTION WHEN OTHERS THEN denied:=true;END;
  IF NOT denied THEN RAISE EXCEPTION 'Stale token accepted';END IF;
  s:=public.lts_browser_income_category_v183(r->>'source',r->>'source_ref',(r->>'event_date')::date,r->>'account',(r->>'signed_amount')::numeric,cat,p->>'token');
  IF s->>'saved'<>'true' OR s->>'cash_changed'<>'false' THEN RAISE EXCEPTION 'Category save failed';END IF;
  IF EXISTS(SELECT 1 FROM public.lts_v178_review_decision WHERE user_id=u AND source_table=r->>'source_table'
   AND source_ref=r->>'decision_ref' AND beneficiary IS NOT NULL) THEN RAISE EXCEPTION 'Person inferred';END IF;
  checks:=checks||jsonb_build_array(r->>'source');
  EXIT WHEN jsonb_array_length(checks)=2;
 END LOOP;
 IF jsonb_array_length(checks)<>2 THEN RAISE EXCEPTION 'Both bank and legacy writers must be exercised';END IF;
 SELECT md5(jsonb_build_object(
  'bank',(SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM public.lts_open_finance_staging x WHERE user_id=u),
  'financial',(SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM public.financial_events x WHERE user_id=u),
  'legacy',(SELECT jsonb_agg(to_jsonb(x) ORDER BY idx) FROM public.evento_base x WHERE usuario_id=u),
  'expenses',(SELECT jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text) FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x))::text) INTO after_sources;
 IF before_sources IS DISTINCT FROM after_sources THEN RAISE EXCEPTION 'Financial sources or expenses changed';END IF;
 IF has_function_privilege('anon','public.lts_browser_income_review_queue_v296(date,date,integer,integer,text)','EXECUTE')
 OR has_function_privilege('anon','lts_income_private.queue_v296(date,date,integer,integer,text)','EXECUTE')
 OR(SELECT prosecdef FROM pg_proc WHERE oid='public.lts_browser_income_review_queue_v296(date,date,integer,integer,text)'::regprocedure)
 OR has_function_privilege('authenticated','lts_income_private.rows_v296(uuid,date,date)','EXECUTE')
 OR NOT has_function_privilege('authenticated','public.lts_browser_income_review_queue_v296(date,date,integer,integer,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Income reader ACL mismatch';END IF;
 PERFORM set_config('lts.v296.qa',jsonb_build_object('pass',true,'writers',checks,'negative_rejected',true,
  'stale_rejected',true,'person_inferred',false,'all_financial_sources_and_expenses_unchanged',true,'rolled_back',true)::text,true);
END $qa$;
SELECT current_setting('lts.v296.qa')::jsonb AS result;
ROLLBACK;
