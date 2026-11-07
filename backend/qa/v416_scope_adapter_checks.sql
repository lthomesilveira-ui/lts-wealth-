DO $tests$
DECLARE p jsonb;r jsonb;fact jsonb;rows jsonb;result jsonb;slot jsonb;cards jsonb;history jsonb;a jsonb;
BEGIN
 r:='{"series_key":"synthetic","card_family":"test","source_kind":"card_invoice","method":"history_total_budget","history_window_months":3,"card_budget_mode":"scoped","budget_definition":{"decision_ref":"synthetic-explicit-approval","source_accounts":["Test card"],"excluded_categories":["Past event"],"allowances":[{"id":"care","descriptions":["Test clinic"],"legacy_through":"2020-12-31","beneficiary":"Person A","amount_brl":80,"funded_by_series":"synthetic"}]}}';
 p:=qa_v412.policy('history_total_budget',r);
 r:=p->'rules'->0;
 fact:='[{"series_key":"synthetic","month":"2020-12-01","amount_brl":200,"coverage":"complete","source_refs":["statement"]}]';
 rows:='[{"row_key":"a","source_ref":"a","account_source":"Test card","competence_month":"2020-12-01","coverage_mode":"card_detail_structured","amount":100,"category":"General","description":"Food"},{"row_key":"b","source_ref":"b","account_source":"Test card","competence_month":"2020-12-01","coverage_mode":"card_detail_structured","amount":60,"category":"Past event","description":"Past event"},{"row_key":"c","source_ref":"c","account_source":"Test card","competence_month":"2020-12-01","coverage_mode":"card_detail_structured","amount":40,"category":"Care","description":"Test clinic"}]';
 result:=lts_projection_private_v412.scope_history_v416(p,fact,rows,'2021-01-15');
 PERFORM qa_v412.assert('scope history reconciles statement before deducting explicit exceptions',
  (result#>>'{0,amount_brl}')::numeric=100 AND result#>>'{0,coverage}'='complete' AND (result#>>'{0,gross_invoice_brl}')::numeric=200,result);
 result:=lts_projection_private_v412.scope_history_v416(p,fact,rows-2,'2021-01-15');
 PERFORM qa_v412.assert('incomplete expense detail cannot certify a reduced mean',result#>>'{0,coverage}'='observed',result);
 result:=lts_projection_private_v412.scope_history_v416(p,fact,rows||jsonb_build_array(rows->0),'2021-01-15');
 PERFORM qa_v412.assert('duplicate detail identity invalidates mean',result#>>'{0,coverage}'='observed',result);
 PERFORM qa_v412.assert('old clinic installment consumes no new allowance',
  lts_projection_private_v412.scope_match_v416('{"category":"Care","description":"Test clinic","purchase_date":"2020-10-01"}',r,false)='excluded');
 PERFORM qa_v412.assert('new documented owner purchase consumes its allowance',
  lts_projection_private_v412.scope_match_v416('{"category":"Care","description":"Test clinic","purchase_date":"2021-01-01","beneficiary":"Person A"}',r,false)='care');
 PERFORM qa_v412.assert('other beneficiary is not assigned the new allowance',
  lts_projection_private_v412.scope_match_v416('{"category":"Care","description":"Test clinic","purchase_date":"2021-01-01","beneficiary":"Person B"}',r,false)='excluded');
 PERFORM qa_v412.assert('unknown beneficiary is not inferred from merchant',
  lts_projection_private_v412.scope_match_v416('{"category":"Care","description":"Test clinic","purchase_date":"2021-01-01"}',r,false)='unresolved');
 PERFORM qa_v412.assert('unknown purchase date cannot consume new allowance',
  lts_projection_private_v412.scope_match_v416('{"category":"Person A — Care","description":"Test clinic"}',r,false)='unresolved');
 slot:=qa_v412.slot('{"event_date":"2021-02-15","known_amount_brl":100}');
 cards:='{"cards":[{"family":"test","cycles":[{"due_date":"2021-02-15","amount":100,"items":[{"source_id":"ordinary","amount":20,"description":"Food","category":"General"},{"source_id":"old","amount":80,"description":"Test clinic","category":"Care","purchase_date":"2020-10-01"}]}]}]}';
 result:=lts_projection_private_v412.scope_slots_v416(p,jsonb_build_array(slot),cards);
 PERFORM qa_v412.assert('existing exceptional installments remain but do not absorb new spending',
  (result#>>'{0,known_amount_brl}')::numeric=100 AND (result#>>'{0,verified_budget_scopes,0,consumed_brl}')::numeric=20
  AND (result#>>'{0,verified_budget_scopes,1,target_brl}')::numeric=80
  AND (result#>>'{0,verified_budget_scopes,1,consumed_brl}')::numeric=0,result);
 history:='[{"series_key":"synthetic","month":"2020-10-01","amount_brl":100,"coverage":"complete"},{"series_key":"synthetic","month":"2020-11-01","amount_brl":100,"coverage":"complete"},{"series_key":"synthetic","month":"2020-12-01","amount_brl":100,"coverage":"complete"}]';
 result:=lts_projection_private_v412.calculate(p,history,result,'2021-01-15');
 PERFORM qa_v412.assert('integrated floor replaces old mean and adds only uncovered allowance',
  (result#>>'{events,0,signed_amount}')::numeric=-160 AND (result#>>'{events,0,budget_total_brl}')::numeric=260
  AND (result#>>'{series,0,reference_amount_brl}')::numeric=180,result);
 result:=lts_projection_private_v412.scope_slots_v416(p,jsonb_build_array(slot),jsonb_set(cards,'{cards,0,cycles,0,amount}','101'));
 PERFORM qa_v412.assert('statement detail mismatch does not create speculative supplement',result#>>'{0,known_complete}'='false',result);
 result:=lts_projection_private_v412.scope_slots_v416(p,jsonb_build_array(slot||'{"legacy_estimate_brl":100}'),'{"cards":[]}');
 PERFORM qa_v412.assert('identified legacy generic budget remains an ordinary floor',
  (result#>>'{0,verified_budget_scopes,0,consumed_brl}')::numeric=100,result);
 result:=lts_projection_private_v412.scope_slots_v416(p,jsonb_build_array(slot),'{"cards":[]}');
 PERFORM qa_v412.assert('undocumented baseline cannot be assigned by amount alone',result#>>'{0,known_complete}'='false',result);
 result:=lts_projection_private_v412.scope_slots_v416(p,jsonb_build_array(slot||'{"authoritative":true}'),'{"cards":[]}');
 PERFORM qa_v412.assert('closed invoice survives missing analytical detail unchanged',result->0=(slot||'{"authoritative":true}'::jsonb),result);
 result:=lts_projection_private_v412.scope_slots_v416(p,jsonb_build_array(qa_v412.slot('{"event_date":"2026-12-15","known_amount_brl":0}')),'{"cards":[]}');
 result:=lts_projection_private_v412.calculate(p,history,result,'2021-01-15');
 PERFORM qa_v412.assert('five-year future after installments end retains only recurring budgets',
  (result#>>'{events,0,signed_amount}')::numeric=-180 AND result->>'horizon_end'='2026-12-31',result);
 a:='{"series":[{"series_key":"synthetic","coverage_months":3,"sum_brl":300,"mean_brl":100,"window_from":"2020-09-01","window_to":"2020-11-30","source_refs":["old"],"scope_digest":"different"}]}';
 result:=lts_projection_private_v412.calculate(p||jsonb_build_object('_history_reference',a),history-2,'[]','2021-01-15');
 PERFORM qa_v412.assert('scope revision rejects incompatible fallback',result#>>'{series,0,reference_amount_brl}' IS NULL,result);
END $tests$;
