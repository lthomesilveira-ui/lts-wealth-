DO $tests$
DECLARE p jsonb; history jsonb; slots jsonb; result jsonb; previous jsonb;
BEGIN
 p:=qa_v412.policy('history_total_budget','{"source_kind":"card_invoice"}')
  ||jsonb_build_object('_history_reference',qa_v412.reference());
 SELECT jsonb_agg(jsonb_build_object('series_key','synthetic','month',make_date(2020,n,1),
  'amount_brl',n*100,'coverage','complete','source_refs',jsonb_build_array('synthetic-'||n)) ORDER BY n)
 INTO history FROM generate_series(1,12)n;
 slots:=jsonb_build_array(qa_v412.slot('{"known_amount_brl":250}'),
  qa_v412.slot('{"event_date":"2021-03-15","authoritative":true,"known_amount_brl":450}'),
  qa_v412.slot('{"event_date":"2021-04-15","cancelled":true}'),
  qa_v412.slot('{"event_date":"2026-12-15","known_amount_brl":1300}'));
 result:=lts_projection_private_v412.calculate(p,history,slots,'2021-01-15');
 PERFORM qa_v412.assert('card uses latest three months; only uncovered amount added',
  (result#>>'{series,0,reference_amount_brl}')::numeric=1100
  AND result#>>'{series,0,expected_months}'='3'
  AND result#>>'{series,0,reference_window,from}'='2020-10-01'
  AND result#>>'{series,0,reference_window,to}'='2020-12-31'
  AND result#>>'{events,0,confidence}'='owner_authorized_3m_history'
  AND (result#>>'{events,0,signed_amount}')::numeric=-850
  AND jsonb_array_length(result->'events')=1
  AND result->>'horizon_end'='2026-12-31',result);
 result:=lts_projection_private_v412.calculate(p,history,slots,'2020-12-01');
 PERFORM qa_v412.assert('card window moves monthly and excludes the current month',
  (result#>>'{series,0,reference_amount_brl}')::numeric=1000
  AND result#>>'{series,0,reference_window,from}'='2020-09-01',result);
 result:=lts_projection_private_v412.calculate(p,history-11,slots,'2021-01-15');
 PERFORM qa_v412.assert('missing statement gives no mean and rejects old 12-month fallback',
  result#>>'{series,0,reference_amount_brl}' IS NULL
  AND result#>>'{series,0,coverage_months}'='2' AND jsonb_array_length(result->'events')=0,result);
 previous:='{"series":[{"series_key":"synthetic","coverage_months":3,"sum_brl":3000,"mean_brl":1000,
  "window_from":"2020-09-01","window_to":"2020-11-30","source_refs":["synthetic"]}]}';
 result:=lts_projection_private_v412.calculate(jsonb_set(p,'{_history_reference}',previous),
  jsonb_set(history,'{11,coverage}','"observed"'),slots,'2021-01-15');
 PERFORM qa_v412.assert('incomplete statement retains an identified compatible prior reference',
  (result#>>'{series,0,reference_amount_brl}')::numeric=1000
  AND result#>>'{series,0,reference_stale}'='true'
  AND result#>>'{series,0,reference_window,from}'='2020-09-01',result);
END $tests$;

DO $tests$
DECLARE result jsonb; saved jsonb;
BEGIN
 PERFORM qa_v412.reset();
 PERFORM qa_v412.set_policy(qa_v412.policy('history_total_budget',
  '{"source_kind":"card_invoice","card_family":"synthetic"}'));
 INSERT INTO qa_v412.history(series_key,month,amount_brl,coverage)
 VALUES('synthetic','2020-09-01',100,'complete'),('synthetic','2020-10-01',200,'complete'),
  ('synthetic','2020-11-01',300,'complete');
 result:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2020-12-01');
 saved:=lts_projection_private_v412.reference_state(qa_v412.owner());
 PERFORM qa_v412.assert('refresh stores three documented months per card',
  (result->>'changed')::boolean AND saved#>>'{series,0,coverage_months}'='3'
  AND (saved#>>'{series,0,mean_brl}')::numeric=200,result);
 result:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2021-01-01');
 PERFORM qa_v412.assert('refresh preserves reference while next statement is missing',
  NOT(result->>'changed')::boolean AND saved=lts_projection_private_v412.reference_state(qa_v412.owner()),result);
 INSERT INTO qa_v412.history(series_key,month,amount_brl,coverage)
 VALUES('synthetic','2020-12-01',400,'complete');
 result:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2021-01-02');
 saved:=lts_projection_private_v412.reference_state(qa_v412.owner());
 PERFORM qa_v412.assert('next complete window rolls reference forward',
  (result->>'changed')::boolean AND saved#>>'{series,0,window_to}'='2020-12-31'
  AND (saved#>>'{series,0,mean_brl}')::numeric=300,result);
 result:=lts_projection_private_v412.refresh_reference(qa_v412.owner(),'2020-12-01');
 PERFORM qa_v412.assert('older refresh cannot overwrite newer card reference',
  NOT(result->>'changed')::boolean AND saved=lts_projection_private_v412.reference_state(qa_v412.owner()),result);
END $tests$;

DO $tests$
DECLARE p jsonb; history jsonb; slot jsonb; result jsonb;
BEGIN
 p:=qa_v412.policy('history_total_budget','{"source_kind":"card_invoice","card_budget_mode":"scoped"}');
 SELECT jsonb_agg(jsonb_build_object('series_key','synthetic','month',make_date(2020,n,1),
  'amount_brl',100,'coverage','complete')) INTO history FROM generate_series(10,12)n;
 slot:=qa_v412.slot('{"known_amount_brl":200,"verified_budget_scopes":[
  {"scope":"general","consumed_brl":20},
  {"scope":"new_treatment","target_brl":80,"consumed_brl":15},
  {"scope":"supplies","target_brl":35,"consumed_brl":50}]}');
 result:=lts_projection_private_v412.calculate(p,history,jsonb_build_array(slot),'2021-01-15');
 PERFORM qa_v412.assert('old obligations do not consume new budget and excess in a scope does not offset another',
  (result#>>'{events,0,signed_amount}')::numeric=-145
  AND (result#>>'{events,0,budget_total_brl}')::numeric=345,result);
 result:=lts_projection_private_v412.calculate(p,history,jsonb_build_array(slot-'verified_budget_scopes'),'2021-01-15');
 PERFORM qa_v412.assert('unverified scoped obligations do not create a speculative complement',
  jsonb_array_length(result->'events')=0 AND result#>>'{series,0,unresolved_periods}'='1',result);
 result:=lts_projection_private_v412.calculate(p,history,
  jsonb_build_array(jsonb_set(slot,'{known_amount_brl}','50')),'2021-01-15');
 PERFORM qa_v412.assert('scope allocations above known obligations are rejected',
  jsonb_array_length(result->'events')=0 AND result#>>'{series,0,unresolved_periods}'='1',result);
 result:=lts_projection_private_v412.calculate(p,history,
  jsonb_build_array((slot-'verified_budget_scopes')||'{"authoritative":true}'),'2021-01-15');
 PERFORM qa_v412.assert('closed statements keep the official amount before budget composition',
  jsonb_array_length(result->'events')=0
  AND (result#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=200,result);
END $tests$;
