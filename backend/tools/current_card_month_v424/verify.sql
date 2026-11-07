-- Disposable PG17 only. Values and identities below are invented.
DO $tests$
DECLARE p jsonb; q jsonb; history jsonb; slots jsonb; a jsonb; b jsonb; s jsonb; financial_before text;
 dt date; due date; nxt date;
BEGIN
 financial_before:=qa_v412.financial_hash();
 p:=qa_v412.policy('history_total_budget','{"source_kind":"card_invoice","history_window_months":3}');
 q:=p||'{"current_month_card_budget":"known_only"}';
 SELECT jsonb_agg(jsonb_build_object('series_key','synthetic','month',make_date(2020,n,1),
  'amount_brl',100,'coverage','complete','source_refs',jsonb_build_array('invented-'||n)))
 INTO history FROM generate_series(10,12)n;
 slots:=jsonb_build_array(qa_v412.slot('{"event_date":"2021-01-20","known_amount_brl":20}'),
  qa_v412.slot('{"event_date":"2021-02-20","known_amount_brl":30}'));
 a:=lts_projection_private_v412.calculate(p,history,slots,'2021-01-15');
 b:=lts_projection_private_v412.calculate(q,history,slots,'2021-01-15');
 PERFORM qa_v412.assert('v424 opt-in leaves previous rule available',jsonb_array_length(a->'events')=2,a);
 PERFORM qa_v412.assert('v424 removes only current month supplement',jsonb_array_length(b->'events')=1
  AND b#>>'{events,0,event_date}'='2021-02-20' AND (b#>>'{events,0,signed_amount}')::numeric=-70,b);
 PERFORM qa_v412.assert('v424 future event byte identical',b#>'{events,0}'=a#>'{events,1}');
 PERFORM qa_v412.assert('v424 annual totals include known current obligations',
  (b#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=120
  AND (b#>>'{series,0,annual_totals,0,additional_brl}')::numeric=70,b);
 PERFORM qa_v412.assert('v424 history reference unchanged',b#>'{series,0,reference_amount_brl}'=a#>'{series,0,reference_amount_brl}'
  AND b->'replacement_refs'=a->'replacement_refs');
 FOR s IN SELECT value FROM jsonb_array_elements('[{"authoritative":true},{"cancelled":true},{"known_complete":false},{"known_amount_brl":null}]') LOOP
  a:=lts_projection_private_v412.calculate(p,history,jsonb_build_array((slots->0)||s),'2021-01-15');
  b:=lts_projection_private_v412.calculate(q,history,jsonb_build_array((slots->0)||s),'2021-01-15');
  PERFORM qa_v412.assert('v424 preserve guard '||s::text,a=b,b);
 END LOOP;
 b:=lts_projection_private_v412.calculate(q,'[]',jsonb_build_array(slots->0),'2021-01-15');
 PERFORM qa_v412.assert('v424 known current amount does not require a historic mean',
  jsonb_array_length(b->'events')=0 AND (b#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=20
  AND b#>>'{series,0,reference_amount_brl}' IS NULL,b);
 b:=lts_projection_private_v412.calculate(q,history,jsonb_build_array(jsonb_set(slots->0,'{known_amount_brl}','200')),'2021-01-15');
 PERFORM qa_v412.assert('v424 above-budget known obligations never reduced',
  jsonb_array_length(b->'events')=0 AND (b#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=200,b);
 p:=jsonb_set(p,'{rules,0,card_budget_mode}','"scoped"');q:=p||'{"current_month_card_budget":"known_only"}';
 s:=qa_v412.slot('{"event_date":"2021-01-20","known_amount_brl":200,"verified_budget_scopes":[{"scope":"general","consumed_brl":20},{"scope":"new_spending","target_brl":80,"consumed_brl":15}]}');
 slots:=jsonb_build_array(s,jsonb_set(s,'{event_date}','"2021-02-20"'));
 a:=lts_projection_private_v412.calculate(p,history,slots,'2021-01-15');
 b:=lts_projection_private_v412.calculate(q,history,slots,'2021-01-15');
 PERFORM qa_v412.assert('v424 current month skips all allowance and general supplements',
  jsonb_array_length(b->'events')=1 AND b#>'{events,0}'=a#>'{events,1}'
  AND (b#>>'{events,0,signed_amount}')::numeric=-145,b);
 PERFORM qa_v412.assert('v424 legacy installments remain in known amount',
  (b#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=545,b);
 p:=qa_v412.policy('history_total_budget','{"source_kind":"direct_cash"}');q:=p||'{"current_month_card_budget":"known_only"}';
 SELECT jsonb_agg(jsonb_build_object('series_key','synthetic','month',make_date(2020,n,1),
  'amount_brl',100,'coverage','complete')) INTO history FROM generate_series(1,12)n;
 slots:=jsonb_build_array(qa_v412.slot('{"event_date":"2021-01-20","known_amount_brl":20}'));
 PERFORM qa_v412.assert('v424 noncard recurring estimates unchanged',
  lts_projection_private_v412.calculate(p,history,slots,'2021-01-15')=
  lts_projection_private_v412.calculate(q,history,slots,'2021-01-15'));
 p:=qa_v412.policy('fixed','{"amount_brl":50}');q:=p||'{"current_month_card_budget":"known_only"}';
 PERFORM qa_v412.assert('v424 fixed recurring amounts unchanged',
  lts_projection_private_v412.calculate(p,history,slots,'2021-01-15')=
  lts_projection_private_v412.calculate(q,history,slots,'2021-01-15'));
 p:=qa_v412.policy('history_total_budget','{"source_kind":"card_invoice","history_window_months":3}');
 q:=p||'{"current_month_card_budget":"known_only"}';
 FOREACH dt IN ARRAY ARRAY[date'2021-01-15',date'2021-12-01',date'2024-02-01',date'2024-02-28',date'2027-01-01'] LOOP
  due:=(date_trunc('month',dt::timestamp)+interval'1 month'-interval'1 day')::date;
  nxt:=(date_trunc('month',dt::timestamp)+interval'1 month'+interval'9 days')::date;
  SELECT jsonb_agg(jsonb_build_object('series_key','synthetic','month',m::date,
   'amount_brl',100,'coverage','complete')) INTO history FROM generate_series(
    date_trunc('month',dt::timestamp)-interval'3 months',date_trunc('month',dt::timestamp)-interval'1 month',interval'1 month')m;
  slots:=jsonb_build_array(qa_v412.slot(jsonb_build_object('event_date',due,'known_amount_brl',20)),
   qa_v412.slot(jsonb_build_object('event_date',nxt,'known_amount_brl',30)));
  b:=lts_projection_private_v412.calculate(q,history,slots,dt);
  PERFORM qa_v412.assert('v424 month and year rollover '||dt,
   jsonb_array_length(b->'events')=1 AND b#>>'{events,0,event_date}'=nxt::text
   AND (b#>>'{events,0,signed_amount}')::numeric=-70,b);
  b:=lts_projection_private_v412.calculate(q,history,slots,date_trunc('month',nxt::timestamp)::date);
  PERFORM qa_v412.assert('v424 next month automatically becomes known only '||dt,
   jsonb_array_length(b->'events')=0,b);
 END LOOP;
 PERFORM qa_v412.assert('v424 calculation writes no financial source',qa_v412.financial_hash()=financial_before);
 PERFORM qa_v412.expect_error('v424 invalid opt-in is rejected',
  format('SELECT lts_projection_private_v412.calculate(%L::jsonb,%L::jsonb,%L::jsonb,%L::date)',
   (p||'{"current_month_card_budget":"unknown"}')::text,history::text,slots::text,'2027-01-01'));
 PERFORM qa_v412.expect_error('v424 null opt-in is rejected',
  format('SELECT lts_projection_private_v412.calculate(%L::jsonb,%L::jsonb,%L::jsonb,%L::date)',
   (p||'{"current_month_card_budget":null}')::text,history::text,slots::text,'2027-01-01'));
END $tests$;
