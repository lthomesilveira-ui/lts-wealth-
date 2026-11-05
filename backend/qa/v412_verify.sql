-- Independent behavioral checks. Amounts, owners, evidence and dates are synthetic.
SELECT qa_v412.install_test_adapters();

DO $tests$
DECLARE p jsonb;h jsonb;s jsonb;j jsonb;a jsonb;b jsonb;failed boolean;
BEGIN
 p:=qa_v412.policy('fixed','{"amount_brl":100}');
 PERFORM qa_v412.set_policy(p-'approved_on');
 PERFORM qa_v412.expect_error('missing approval date rejected',
  'SELECT lts_projection_private_v412.owner_policy(qa_v412.owner())');
 PERFORM qa_v412.set_policy(jsonb_set(p,'{rules,0}',(p#>'{rules,0}')-'starts_on'));
 PERFORM qa_v412.expect_error('missing start date rejected',
  'SELECT lts_projection_private_v412.owner_policy(qa_v412.owner())');
 PERFORM qa_v412.set_policy(p);
 p:=qa_v412.policy('history_total_budget')||jsonb_build_object('_history_reference',qa_v412.reference());
 SELECT jsonb_agg(jsonb_build_object('series_key','synthetic','month',make_date(2020,n,1),
  'amount_brl',1200,'coverage','complete','source_refs',jsonb_build_array('synthetic-'||n))ORDER BY n)
 INTO h FROM generate_series(1,12)n;
 s:=jsonb_build_array(qa_v412.slot());
 j:=lts_projection_private_v412.calculate(p,jsonb_build_array(h->0),s,'2021-01-01');
 PERFORM qa_v412.assert('partial new window retains complete reference',
  j#>>'{series,0,reference_amount_brl}'='1000' AND (j#>>'{series,0,reference_stale}')::boolean
  AND (j#>>'{events,0,signed_amount}')::numeric=-1000,j);
 SELECT jsonb_agg(jsonb_set(v,'{coverage}','"observed"')) INTO a FROM jsonb_array_elements(h)v;
 j:=lts_projection_private_v412.calculate(p,a,s,'2021-01-01');
 PERFORM qa_v412.assert('twelve observed months do not become twelve covered months',
  (j#>>'{series,0,coverage_months}')::int=0 AND (j#>>'{series,0,observed_months}')::int=12
  AND (j#>>'{events,0,signed_amount}')::numeric=-1000,j);
 j:=lts_projection_private_v412.calculate(p,h,s,'2021-01-01');
 PERFORM qa_v412.assert('complete new window rebases nominal mean',
  (j#>>'{series,0,reference_amount_brl}')::numeric=1200
  AND NOT(j#>>'{series,0,reference_stale}')::boolean,j);
 j:=lts_projection_private_v412.calculate(p-'_history_reference',jsonb_build_array(h->0),s,'2021-01-01');
 PERFORM qa_v412.assert('partial history alone generates no mean',jsonb_array_length(j->'events')=0,j);
 a:=jsonb_set(p,'{_history_reference,series,0,window_from}','"2021-01-01"');
 a:=jsonb_set(a,'{_history_reference,series,0,window_to}','"2021-12-31"');
 PERFORM qa_v412.expect_error('future reference cannot supply current mean',format(
  'SELECT lts_projection_private_v412.calculate(%L::jsonb,%L::jsonb,%L::jsonb,%L::date)',a,'[]',s,'2021-01-01'));
 a:=lts_projection_private_v412.calculate(p,'[]','[]','2020-12-31');
 b:=lts_projection_private_v412.calculate(p,'[]','[]','2021-01-01');
 PERFORM qa_v412.assert('horizon extends exactly at new calendar year',
  a->>'horizon_end'='2025-12-31' AND b->>'horizon_end'='2026-12-31',jsonb_build_array(a->'horizon_end',b->'horizon_end'));
 j:=lts_projection_private_v412.calculate(p,h,jsonb_build_array(qa_v412.slot('{"known_amount_brl":300}')),'2021-01-01');
 PERFORM qa_v412.assert('total budget adds only uncovered residual',
  (j#>>'{events,0,signed_amount}')::numeric=-900
  AND (j#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=1200,j);
 j:=lts_projection_private_v412.calculate(p,h,jsonb_build_array(qa_v412.slot('{"known_amount_brl":1500}')),'2021-01-01');
 PERFORM qa_v412.assert('known obligations above budget are preserved',jsonb_array_length(j->'events')=0
  AND (j#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=1500,j);
 j:=lts_projection_private_v412.calculate(p,h,jsonb_build_array(qa_v412.slot('{"known_amount_brl":300,"authoritative":true}')),'2021-01-01');
 PERFORM qa_v412.assert('closed invoice does not receive a budget complement',jsonb_array_length(j->'events')=0
  AND (j#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=300,j);
 SELECT jsonb_agg(CASE WHEN ord>9 THEN jsonb_set(v,'{amount_brl}','0')ELSE v END ORDER BY ord)
 INTO a FROM jsonb_array_elements(h)WITH ORDINALITY x(v,ord);
 j:=lts_projection_private_v412.calculate(p,a,s,'2021-01-01');
 PERFORM qa_v412.assert('complete corpus zero spending months remain in denominator',
  (j#>>'{series,0,coverage_months}')::int=12 AND (j#>>'{series,0,months_with_spend}')::int=9
  AND (j#>>'{series,0,reference_amount_brl}')::numeric=900,j);
 SELECT jsonb_agg(jsonb_build_object('series_key','synthetic','month',date '2020-01-01'+n-1,
  'amount_brl',100,'coverage','complete'))INTO a FROM generate_series(1,12)n;
 PERFORM qa_v412.expect_error('twelve dates in one month are not twelve competencies',format(
  'SELECT lts_projection_private_v412.calculate(%L::jsonb,%L::jsonb,%L::jsonb,%L::date)',p,a,s,'2021-01-01'));
 p:=qa_v412.policy('inflated_calendar','{"annual_rate":0.05,"base_year":2020}');
 s:=jsonb_build_array(qa_v412.slot('{"known_amount_brl":100,"replacement_amount_brl":100,"replacement_refs":[],"base_amount_brl":100}'));
 PERFORM qa_v412.expect_error('positive replacement requires exact identities',format(
  'SELECT lts_projection_private_v412.calculate(%L::jsonb,%L::jsonb,%L::jsonb,%L::date)',p,'[]',s,'2021-01-01'));
 s:=jsonb_build_array(qa_v412.slot('{"known_amount_brl":150,"replacement_amount_brl":0,"base_amount_brl":100}'));
 j:=lts_projection_private_v412.calculate(p,'[]',s,'2021-01-01');
 PERFORM qa_v412.assert('preserved inflation slot remains in annual total',jsonb_array_length(j->'events')=0
  AND (j#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=150,j);
 s:=jsonb_build_array(qa_v412.slot('{"base_amount_brl":100}'),
  qa_v412.slot('{"event_date":"2022-02-15","base_amount_brl":100}'));
 a:=lts_projection_private_v412.calculate(p,'[]',s,'2021-01-01');
 b:=lts_projection_private_v412.calculate(p,'[]',s,'2021-01-01');
 PERFORM qa_v412.assert('inflation derives once from base on every reread',a=b
  AND (a#>>'{events,0,signed_amount}')::numeric=-105
  AND (a#>>'{events,1,signed_amount}')::numeric=-110.25,a);
 p:=qa_v412.policy('salary_net','{"direction":"income","amount_brl":1000}');
 j:=lts_projection_private_v412.calculate(p,'[]',jsonb_build_array(qa_v412.slot('{"withholding_known":true,"withholding_brl":-100}')),'2021-01-01');
 PERFORM qa_v412.assert('negative withholding never increases salary',jsonb_array_length(j->'events')=0
  AND (j#>>'{series,0,unresolved_periods}')::int=1,j);
END $tests$;

DO $tests$
DECLARE j jsonb;a jsonb;b jsonb;n int;total numeric;hash_before text;
BEGIN
 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('inflated_calendar','{"annual_rate":0.05,"base_year":2020}'));
 INSERT INTO qa_v412.calendar(series_key,template_year,event_month,event_day,amount_brl,source_ref)
 SELECT 'synthetic',2020,m,14,100,'synthetic-tax:'||m FROM generate_series(2,11)m;
 INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES('2021-01-10','Itaú','synthetic',-1000,'legacy_fix86','old-tax-estimate','legacy_projection_adjusted'),
 ('2021-03-10','Itaú','unrelated',-50,'document','unrelated-ref','confirmed'),
 ('2021-04-15','Itaú','synthetic',50,'legacy_fix86','tax-refund-legacy','legacy_projection_adjusted'),
 ('2021-04-20','Itaú','synthetic',20,'document','tax-refund-document','confirmed');
 hash_before:=qa_v412.financial_hash();
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 SELECT count(*)::int,sum((v->>'signed_amount')::numeric)INTO n,total FROM jsonb_array_elements(j->'events')v
 WHERE v->>'event_date' BETWEEN '2021-01-01' AND '2021-12-31';
 PERFORM qa_v412.assert('ten tax installments replace one expense estimate and preserve refunds',n=10 AND total=-1050
  AND j->'replacement_refs'='["old-tax-estimate"]'::jsonb,j);
 INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES('2021-02-15','Itaú','synthetic',-150,'document','documented-tax-month','confirmed');
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 SELECT count(*)::int INTO n FROM jsonb_array_elements(j->'events')v
 WHERE v->>'event_date' BETWEEN '2021-02-01' AND '2021-02-28';
 PERFORM qa_v412.assert('documentary tax month keeps identity without second projection',n=0
  AND NOT(j->'replacement_refs'?'documented-tax-month') AND j->'replacement_refs'?'old-tax-estimate',j);
 a:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 b:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 PERFORM qa_v412.assert('repeated builder is deterministic',a=b);
 hash_before:=qa_v412.financial_hash();
 PERFORM lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 PERFORM qa_v412.assert('building projections does not change financial sources',hash_before=qa_v412.financial_hash());

 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('history_total_budget','{"card_family":"synthetic_shift","due_day":12}'));
 INSERT INTO qa_v412.history(series_key,month,amount_brl,coverage)
 SELECT 'synthetic',m::date,1000,'complete' FROM generate_series(date '2019-11-01',date '2020-10-01',interval '1 month')m;
 INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES('2021-02-20','Itaú','synthetic',-200,'card_invoice','closed-invoice','confirmed');
 INSERT INTO qa_v412.cycles(series_key,reference_month,due_date,amount_brl,closed,paid,complete)
 VALUES('synthetic','2021-02-01','2021-02-20',200,false,false,true);
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 SELECT v INTO a FROM jsonb_array_elements(j->'events')v WHERE v->>'event_date' BETWEEN '2021-02-01' AND '2021-02-28';
 PERFORM qa_v412.assert('canonical card date is not transitioned twice',a->>'event_date'='2021-02-20'
  AND (a->>'signed_amount')::numeric=-800,a);
 UPDATE qa_v412.cycles SET closed=true;
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 PERFORM qa_v412.assert('closed card cycle preserves documented amount only',NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(j->'events')v WHERE v->>'event_date' BETWEEN '2021-02-01' AND '2021-02-28'),j);
 UPDATE qa_v412.cycles SET closed=false,amount_brl=300;
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 PERFORM qa_v412.assert('open card mismatch remains unresolved rather than topped up',
  j#>'{series,0,warnings}'?'unreconciled_periods' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'events')v
   WHERE v->>'event_date' BETWEEN '2021-02-01' AND '2021-02-28'),j);

 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('salary_net','{"series_key":"salary","description":"Salário líquido",
 "direction":"income","amount_brl":1000,"due_day":28,"withholding_commitment":"synthetic-loan",
 "withholding_ends_on":"2022-12-31","withholding_end_source_ref":"synthetic-contract-end"}'));
 INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES('2020-11-28','Itau','Salário',1000,'financial_events','existing-gross','confirmed');
 INSERT INTO qa_v412.withholding VALUES(qa_v412.owner(),'existing-gross',-250);
 INSERT INTO public.lts_commitment_documentary_schedule VALUES
 (qa_v412.owner(),'synthetic-loan','2020-11-25',250),(qa_v412.owner(),'synthetic-loan','2020-12-25',300);
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 PERFORM qa_v412.assert('real salary normalizer preserves existing net once',NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(j->'events')v WHERE v->>'event_date' BETWEEN '2020-11-01' AND '2020-11-30')
  AND (SELECT signed_amount FROM lts_projection_private_v412.base_flow(qa_v412.owner(),'2020-11-01','2020-11-30'))=750,j);
 SELECT v INTO a FROM jsonb_array_elements(j->'events')v WHERE v->>'event_date'='2020-12-28';
 SELECT v INTO b FROM jsonb_array_elements(j->'events')v WHERE v->>'event_date'='2023-01-28';
 PERFORM qa_v412.assert('new salary subtracts documentary installment once and stops at evidenced end',
  (a->>'signed_amount')::numeric=700 AND (b->>'signed_amount')::numeric=1000,jsonb_build_array(a,b));
 PERFORM qa_v412.assert('missing salary installment is not assumed zero',NOT EXISTS(
  SELECT 1 FROM jsonb_array_elements(j->'events')v WHERE v->>'event_date' BETWEEN '2021-01-01' AND '2021-12-31'),j);

 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('repeat_calendar','{"direction":"income"}'));
 INSERT INTO qa_v412.calendar(series_key,template_year,event_month,event_day,amount_brl,source_ref)
 VALUES('synthetic',2020,3,20,400,'synthetic-annual-benefit');
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-04');
 SELECT count(*)::int,sum((v->>'signed_amount')::numeric)INTO n,total FROM jsonb_array_elements(j->'events')v
 WHERE v->>'event_date' BETWEEN '2021-01-01' AND '2021-12-31';
 PERFORM qa_v412.assert('annual benefit stays one annual receipt without monthly duplication',n=1 AND total=400,j);

 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":100}'));
 INSERT INTO public.lts_recurring_plan_v366 VALUES(qa_v412.owner(),'synthetic','saida','2020-11-04T10:00:00Z','2020-11-05',NULL,false,'fixed');
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-06');
 PERFORM qa_v412.assert('earlier decision does not override later policy activation',jsonb_array_length(j->'events')>0,j);
 UPDATE public.lts_recurring_plan_v366 SET confirmed_at='2020-11-04T16:00:00Z';
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-06');
 PERFORM qa_v412.assert('later cancellation also prevents new horizon years',jsonb_array_length(j->'events')=0,j);
 UPDATE public.lts_recurring_plan_v366 SET active=true,ends_on='2021-06-30';
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2020-11-06');
 PERFORM qa_v412.assert('later end date bounds the full rolling horizon',jsonb_array_length(j->'events')>0
  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'events')v WHERE(v->>'event_date')::date>'2021-06-30'),j);
END $tests$;

DO $tests$
DECLARE j jsonb;a jsonb;old_state jsonb;n bigint;epoch bigint;hash_before text;
BEGIN
 PERFORM qa_v412.reset();PERFORM qa_v412.set_policy(qa_v412.policy('history_total_budget'));
 INSERT INTO qa_v412.history(series_key,month,amount_brl,coverage)
 SELECT 'synthetic',m::date,1000,'complete' FROM generate_series(date '2019-11-01',date '2020-10-01',interval '1 month')m;
 INSERT INTO public.lts_flow_future_read_cache VALUES(qa_v412.owner()),(qa_v412.owner(2));
 INSERT INTO public.lts_flow_future_read_cache_v2 VALUES(qa_v412.owner()),(qa_v412.owner(2));
 INSERT INTO public.lts_v229_read_cache VALUES(qa_v412.owner()),(qa_v412.owner(2));
 INSERT INTO public.lts_dashboard_cockpit_cache VALUES(qa_v412.owner()),(qa_v412.owner(2));
 INSERT INTO public.lts_product_read_cache VALUES(qa_v412.owner()),(qa_v412.owner(2));
 j:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2020-11-04');
 a:=lts_projection_private_v412.reference_state(qa_v412.owner());
 PERFORM qa_v412.assert('complete reference is stored with audit and correct hash',
  (j->>'changed')::boolean AND(a->>'revision')::int=1 AND(a#>>'{series,0,mean_brl}')::numeric=1000
  AND(SELECT count(*)FROM public.audit_log)=1 AND EXISTS(SELECT 1 FROM public.legacy_namespace
   WHERE chave='lts_projection_reference_v412' AND sha256=encode(sha256(convert_to(valor_bruto,'UTF8')),'hex')),j);
 PERFORM qa_v412.assert('all five reader caches invalidate only the selected owner',
  (SELECT count(*)=5 AND bool_and(user_id=qa_v412.owner(2))FROM(
   SELECT user_id FROM public.lts_flow_future_read_cache
   UNION ALL SELECT user_id FROM public.lts_flow_future_read_cache_v2
   UNION ALL SELECT user_id FROM public.lts_v229_read_cache
   UNION ALL SELECT user_id FROM public.lts_dashboard_cockpit_cache
   UNION ALL SELECT user_id FROM public.lts_product_read_cache)remaining));
 old_state:=a;SELECT count(*)INTO n FROM public.audit_log;
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e;
 j:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2020-11-04');
 PERFORM qa_v412.assert('reference replay changes neither revision audit nor epoch',
  NOT(j->>'changed')::boolean AND old_state=lts_projection_private_v412.reference_state(qa_v412.owner())
  AND n=(SELECT count(*)FROM public.audit_log)AND epoch=(SELECT e.epoch FROM public.lts_read_cache_epoch_v242 e),j);
 j:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2021-01-01');
 PERFORM qa_v412.assert('incomplete annual window keeps prior complete snapshot',
  NOT(j->>'changed')::boolean AND(j->>'deferred_series')::int=1
  AND old_state=lts_projection_private_v412.reference_state(qa_v412.owner()),j);
 INSERT INTO qa_v412.history(series_key,month,amount_brl,coverage)
 VALUES('synthetic','2020-11-01',2200,'complete'),('synthetic','2020-12-01',2200,'complete');
 j:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2021-01-01');
 a:=lts_projection_private_v412.reference_state(qa_v412.owner());
 PERFORM qa_v412.assert('complete annual refresh records before and after',
  (j->>'changed')::boolean AND(a->>'revision')::int=2 AND(a#>>'{series,0,mean_brl}')::numeric=1200
  AND EXISTS(SELECT 1 FROM public.audit_log WHERE details#>>'{previous,revision}'='1'
   AND details#>>'{current,revision}'='2'),j);
 j:=lts_projection_private_v412.refresh_reference(qa_v412.owner(2),'2021-01-01');
 PERFORM qa_v412.assert('owner without policy gets no reference from another owner',
  NOT(j->>'changed')::boolean AND lts_projection_private_v412.reference_state(qa_v412.owner(2))->'series'='[]'::jsonb,j);
 UPDATE qa_v412.history SET coverage='documented_zero',amount_brl=10000 WHERE month='2020-11-01';
 PERFORM qa_v412.expect_error('writer rejects positive documented zero',
  $$SELECT lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2021-01-01')$$);
 UPDATE public.legacy_namespace SET sha256='wrong' WHERE chave='lts_projection_reference_v412';
 PERFORM qa_v412.expect_error('corrupted stored reference is an error rather than empty success',
  $$SELECT lts_projection_private_v412.reference_state(qa_v412.owner())$$);
END $tests$;

DO $tests$
DECLARE p jsonb;a jsonb;b jsonb;hash_before text;d date;
BEGIN
 PERFORM qa_v412.reset();
 d:=(date_trunc('month',current_date)+interval '2 months')::date+14;
 p:=qa_v412.policy('fixed','{"amount_brl":100}');
 p:=jsonb_set(p,'{approved_on}',to_jsonb(current_date));
 p:=jsonb_set(p,'{rules,0,starts_on}',to_jsonb(current_date+1));
 PERFORM qa_v412.set_policy(p);
 INSERT INTO qa_v412.raw_flow(user_id,event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES(qa_v412.owner(2),d,'Itaú','other owner',321,'document','owner-two-row','confirmed'),
 (qa_v412.owner(),d,'Itaú','unrelated',-50,'document','owner-one-row','confirmed');
 SELECT jsonb_agg(to_jsonb(x)ORDER BY event_date,source_ref)INTO a
 FROM lts_projection_private_v412.base_flow(qa_v412.owner(2),current_date,d+31)x;
 SELECT jsonb_agg(to_jsonb(x)ORDER BY event_date,source_ref)INTO b
 FROM public.lts_corrected_cashflow_operational_v1(qa_v412.owner(2),current_date,d+31)x;
 PERFORM qa_v412.assert('no-policy operational rows preserve baseline exactly',a=b,jsonb_build_object('before',a,'after',b));
 hash_before:=qa_v412.financial_hash();
 SELECT jsonb_agg(to_jsonb(x)ORDER BY event_date,source_ref)INTO a
 FROM public.lts_corrected_cashflow_operational_v1(qa_v412.owner(),current_date,d+31)x;
 SELECT jsonb_agg(to_jsonb(x)ORDER BY event_date,source_ref)INTO b
 FROM public.lts_corrected_cashflow_operational_v1(qa_v412.owner(),current_date,d+31)x;
 PERFORM qa_v412.assert('integrated operational overlay is stable and nonduplicating',a=b
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(a)v WHERE v->>'source'='planning_projection_v412')
  AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a)v GROUP BY v->>'source_ref' HAVING count(*)>1)
  AND hash_before=qa_v412.financial_hash(),a);
 SELECT jsonb_agg(to_jsonb(x)ORDER BY event_date,source_ref)INTO a
 FROM public.lts_corrected_cashflow_operational_v1(qa_v412.owner(),current_date-30,current_date)x;
 SELECT jsonb_agg(to_jsonb(x)ORDER BY event_date,source_ref)INTO b
 FROM lts_projection_private_v412.base_flow(qa_v412.owner(),current_date-30,current_date)x;
 PERFORM qa_v412.assert('past and realized interval stays baseline',a IS NOT DISTINCT FROM b);
 PERFORM set_config('v412_test.owner',qa_v412.owner(2)::text,false);
 a:=public.lts_browser_projection_policy_v412();
 PERFORM qa_v412.assert('browser reader derives synthetic current owner only',a->>'enabled'='false',a);
 PERFORM set_config('v412_test.owner',qa_v412.owner()::text,false);
 a:=public.lts_browser_projection_policy_v412();
 PERFORM qa_v412.assert('browser payload excludes internal events and replacement refs',
  a->>'enabled'='true' AND NOT(a?'events')AND NOT(a?'replacement_refs'),a);
 INSERT INTO public.lts_recurring_plan_v366 VALUES(qa_v412.owner(2),'other','saida',now(),current_date+1,NULL,true,'fixed');
 PERFORM public.lts_recurring_maintenance_v366();
 PERFORM qa_v412.assert('existing daily maintenance covers policy and legacy-plan owners',
  (SELECT count(DISTINCT user_id)FROM qa_v412.materializer_calls)=2
  AND EXISTS(SELECT 1 FROM qa_v412.materializer_calls WHERE user_id=qa_v412.owner())
  AND EXISTS(SELECT 1 FROM qa_v412.materializer_calls WHERE user_id=qa_v412.owner(2)));
 PERFORM qa_v412.assert('protected predecessor metadata remains installed',NOT EXISTS(
  SELECT 1 FROM qa_v412.protected_before b JOIN pg_proc p ON p.oid=to_regprocedure(b.signature)
  WHERE p.proacl::text IS DISTINCT FROM b.acl OR p.proowner<>b.owner
   OR p.proconfig IS DISTINCT FROM b.config OR p.prosecdef<>b.security));
 PERFORM qa_v412.assert('private owner-param helpers stay unavailable to browser roles',
  NOT has_function_privilege('authenticated','lts_projection_private_v412.build(uuid,date)','EXECUTE')
  AND NOT has_function_privilege('anon','lts_projection_private_v412.build(uuid,date)','EXECUTE')
  AND has_function_privilege('service_role','lts_projection_private_v412.build(uuid,date)','EXECUTE')
  AND has_function_privilege('authenticated','public.lts_browser_projection_policy_v412()','EXECUTE')
  AND NOT has_function_privilege('anon','public.lts_browser_projection_policy_v412()','EXECUTE'));
 INSERT INTO qa_v412.saved VALUES('metadata_before_rollback',jsonb_build_object(
  'namespace',(SELECT coalesce(jsonb_agg(to_jsonb(n)ORDER BY id),'[]')FROM public.legacy_namespace n),
  'audit',(SELECT coalesce(jsonb_agg(to_jsonb(audit_row)ORDER BY id),'[]')FROM public.audit_log audit_row),
  'financial_hash',qa_v412.financial_hash()));
END $tests$;
