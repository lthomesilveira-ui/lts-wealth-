-- Synthetic documentary price timelines. Never uses owner data or billing facts.
DO $tests$
DECLARE p jsonb;r jsonb;j jsonb;bad jsonb;
BEGIN
 p:=qa_v412.policy('fixed','{"amount_brl":120,"amount_changes":[{"effective_on":"2021-02-10","amount_brl":135,"source_ref":"synthetic-notice-a"},{"effective_on":"2021-04-01","amount_brl":110,"source_ref":"synthetic-notice-b"}]}');
 r:=p#>'{rules,0}';
 PERFORM qa_v412.assert('dated price preserves old amount before effective date',
  lts_projection_private_v412.fixed_amount(r,'2021-02-09')=120);
 PERFORM qa_v412.assert('dated price applies on the effective date',
  lts_projection_private_v412.fixed_amount(r,'2021-02-10')=135);
 PERFORM qa_v412.assert('later documented price may decrease without compounding',
  lts_projection_private_v412.fixed_amount(r,'2021-04-01')=110
  AND lts_projection_private_v412.fixed_amount(r,'2025-12-31')=110);
 j:=lts_projection_private_v412.calculate(p,'[]',jsonb_build_array(
  qa_v412.slot('{"event_date":"2021-01-15"}'),qa_v412.slot(),
  qa_v412.slot('{"event_date":"2021-04-15"}')),'2021-01-01');
 PERFORM qa_v412.assert('price timeline changes amounts and keeps monthly dates',
  j#>>'{events,0,event_date}'='2021-01-15' AND(j#>>'{events,0,signed_amount}')::numeric=-120
  AND j#>>'{events,1,event_date}'='2021-02-15' AND(j#>>'{events,1,signed_amount}')::numeric=-135
  AND j#>>'{events,2,event_date}'='2021-04-15' AND(j#>>'{events,2,signed_amount}')::numeric=-110,j);
 PERFORM qa_v412.assert('dated event carries applicable documentary reference',
  j#>'{events,1,source_refs}' ? 'synthetic-notice-a'
  AND j#>'{events,2,source_refs}' ? 'synthetic-notice-b',j);
 PERFORM qa_v412.assert('reference amount follows as-of rather than future price',
  (j#>>'{series,0,reference_amount_brl}')::numeric=120,j);
 j:=lts_projection_private_v412.calculate(p,'[]',jsonb_build_array(qa_v412.slot()),'2021-02-11');
 PERFORM qa_v412.assert('as-of reference advances only after price effective date',
  (j#>>'{series,0,reference_amount_brl}')::numeric=135,j);
 j:=lts_projection_private_v412.calculate(p,'[]',jsonb_build_array(
  qa_v412.slot('{"cancelled":true}'),
  qa_v412.slot('{"event_date":"2021-03-15","authoritative":true,"known_amount_brl":99}'),
  qa_v412.slot('{"event_date":"2021-04-15","known_amount_brl":88}')),'2021-01-01');
 PERFORM qa_v412.assert('price change preserves cancellation documentary and existing precedence',
  jsonb_array_length(j->'events')=0 AND(j#>>'{series,0,preserved_occurrences}')::int=3,j);
 PERFORM qa_v412.set_policy(p);
 PERFORM qa_v412.assert('owner accepts validated fixed timeline',
  lts_projection_private_v412.owner_policy(qa_v412.owner()) IS NOT NULL);
 FOR bad IN SELECT value FROM jsonb_array_elements('[null,{},[{"effective_on":"2021-02-30","amount_brl":135,"source_ref":"s"}],[{"effective_on":"2021-02-10","amount_brl":0,"source_ref":"s"}],[{"effective_on":"2021-02-10","amount_brl":135.001,"source_ref":"s"}],[{"effective_on":"2021-02-10","amount_brl":135}],[{"effective_on":"2020-11-01","amount_brl":135,"source_ref":"s"}],[{"effective_on":"2021-02-10","amount_brl":135,"source_ref":"s"},{"effective_on":"2021-02-10","amount_brl":140,"source_ref":"s"}],[{"effective_on":"2021-03-10","amount_brl":135,"source_ref":"s"},{"effective_on":"2021-02-10","amount_brl":140,"source_ref":"s"}]]') LOOP
  PERFORM qa_v412.expect_error('invalid timeline rejected: '||bad::text,format(
   'SELECT lts_projection_private_v412.fixed_amount(%L::jsonb,%L::date)',jsonb_set(r,'{amount_changes}',bad),'2021-01-01'));
 END LOOP;
 PERFORM qa_v412.set_policy(jsonb_set(p,'{rules,0,method}','"repeat_calendar"'));
 PERFORM qa_v412.expect_error('price timeline rejected on non-fixed method',
  'SELECT lts_projection_private_v412.owner_policy(qa_v412.owner())');
 PERFORM qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":120}'));
 PERFORM qa_v412.assert('fixed rule without timeline remains compatible',
  lts_projection_private_v412.fixed_amount(qa_v412.policy('fixed','{"amount_brl":120}')#>'{rules,0}','2021-02-10')=120);
END $tests$;
