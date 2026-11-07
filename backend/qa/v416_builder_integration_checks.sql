-- Disposable synthetic database only. Exercise the actual full builder after wiring.
DO $old_policy$
DECLARE p jsonb;j jsonb;
BEGIN
 PERFORM qa_v412.reset();
 p:=qa_v412.policy('fixed','{"amount_brl":100}');
 PERFORM qa_v412.set_policy(p);
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2021-01-15');
 PERFORM qa_v412.assert('wired builder still executes existing unscoped policy',jsonb_array_length(j->'events')>0,j);
END $old_policy$;

-- Extend this disposable source adapter to expose the fields used by production.
ALTER TABLE public.qa_adapter_expenses ADD COLUMN account_source text, ADD COLUMN purchase_date date;
DROP FUNCTION public.lts_v229_expense_rows(uuid,date,date);
CREATE FUNCTION public.lts_v229_expense_rows(p_user_id uuid,p_from date,p_to date)
RETURNS SETOF public.qa_adapter_expenses LANGUAGE sql STABLE AS $f$
 SELECT e.* FROM public.qa_adapter_expenses e WHERE e.user_id=p_user_id AND e.event_date BETWEEN p_from AND p_to
$f$;

DO $integrated$
DECLARE p jsonb;j jsonb;r jsonb;h text;before_count bigint;d date;
BEGIN
 PERFORM qa_v412.reset();
 DELETE FROM public.qa_adapter_expenses;
 DELETE FROM public.qa_adapter_cycles;
 p:=qa_v412.policy('history_total_budget','{"source_kind":"card_invoice","card_family":"test","history_window_months":3,"card_budget_mode":"scoped","budget_definition":{"decision_ref":"synthetic-explicit","source_accounts":["Test card"],"excluded_categories":["Past event"],"allowances":[{"id":"care","descriptions":["Test clinic"],"legacy_through":"2020-12-31","beneficiary":"Person A","amount_brl":80,"funded_by_series":"synthetic"}]}}');
 PERFORM qa_v412.set_policy(p);
 INSERT INTO qa_v412.history(series_key,month,amount_brl,coverage)
 SELECT 'synthetic',x::date,200,'complete' FROM generate_series(timestamp '2020-10-01',timestamp '2020-12-01',interval '1 month')x;
 INSERT INTO public.qa_adapter_expenses(user_id,row_key,event_date,competence_month,amount,category,description,source_table,source_ref,coverage_mode,account_source,purchase_date)
 SELECT qa_v412.owner(),x::date||':'||n,x::date,x::date,CASE n WHEN 1 THEN 100 WHEN 2 THEN 60 ELSE 40 END,
  CASE n WHEN 1 THEN 'General' WHEN 2 THEN 'Past event' ELSE 'Care' END,
  CASE n WHEN 1 THEN 'Food' WHEN 2 THEN 'Past event' ELSE 'Test clinic' END,
  'card_purchase_detail',x::date||':'||n,'card_detail_structured','Test card','2020-09-01'
 FROM generate_series(timestamp '2020-10-01',timestamp '2020-12-01',interval '1 month')x CROSS JOIN generate_series(1,3)n;
 INSERT INTO qa_v412.cycles(series_key,reference_month,due_date,amount_brl,closed,paid,complete)
 VALUES('synthetic','2021-02-01','2021-02-15',100,false,false,true);
 INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES('2021-02-15','Itaú','synthetic',-100,'document','synthetic-known','confirmed');
 INSERT INTO public.qa_adapter_cycles VALUES(qa_v412.owner(),'{"cards":[{"family":"test","cycles":[{"due_date":"2021-02-15","amount":100,"items":[{"source_id":"ordinary","amount":20,"description":"Food","category":"General"},{"source_id":"old","amount":80,"description":"Test clinic","category":"Care","purchase_date":"2020-10-01"}]}]}]}');
 h:=qa_v412.financial_hash();
 j:=lts_projection_private_v412.build(qa_v412.owner(),'2021-01-15');
 PERFORM qa_v412.assert('full scoped builder reconciles source detail and calendar',
  (j#>>'{series,0,reference_amount_brl}')::numeric=180 AND (j#>>'{series,0,coverage_months}')::int=3
  AND (j#>>'{series,0,unresolved_periods}')::int=0,j);
 SELECT x INTO r FROM jsonb_array_elements(j->'events')x WHERE x->>'event_date'='2021-02-15';
 PERFORM qa_v412.assert('full scoped builder preserves old obligations outside new allowance',
  (r->>'known_amount_brl')::numeric=100 AND (r->>'signed_amount')::numeric=-160
  AND (r->>'budget_total_brl')::numeric=260,r);
 r:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2021-01-15');
 PERFORM qa_v412.assert('full reference updater stores only the compatible reduced scope',
  r->>'changed'='true' AND (lts_projection_private_v412.reference_state(qa_v412.owner())#>>'{series,0,mean_brl}')::numeric=100
  AND lts_projection_private_v412.reference_state(qa_v412.owner())#>>'{series,0,scope_digest}'=md5((p#>'{rules,0,budget_definition}')::text),r);
 r:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2021-01-15');
 PERFORM qa_v412.assert('same scoped reference is not rewritten',r->>'changed'='false',r);
 PERFORM qa_v412.assert('scoped full reads preserve financial sources',h=qa_v412.financial_hash());
 PERFORM qa_v412.assert('private scope helpers are unavailable to browser roles',NOT EXISTS(
  SELECT 1 FROM pg_proc f JOIN pg_namespace n ON n.oid=f.pronamespace
  WHERE n.nspname='lts_projection_private_v412' AND f.proname LIKE 'scope%v416'
   AND (has_function_privilege('anon',f.oid,'EXECUTE') OR has_function_privilege('authenticated',f.oid,'EXECUTE'))));
END $integrated$;
