DO $test$
DECLARE
 a date:='2028-04-04'; rule jsonb:='{"id":"service","series_key":"service","starts_on":"2028-04-01","account":"Example bank","source_description":"Monthly service","description":"Monthly service","source_prefix":"projection:fixture:service:","due_day":8,"early_days":7,"prices":[{"from":"2028-04-01","amount":40}]}';
 policy jsonb:=jsonb_build_object('bank_commitments',jsonb_build_array(rule)); unrelated jsonb:='{"description":"Other movement"}';
 base jsonb:=jsonb_build_object('horizon_end','2028-06-30','events',jsonb_build_array(unrelated),'replacement_refs','[]'::jsonb);
 receipt jsonb:='[{"bill":"service","receipt":"receipt-1","paid_on":"2028-04-05"}]';
 legacy jsonb:='[{"source":"legacy_fix86","source_ref":"fixture:legacy:1","signed_amount":-32,"description":"Monthly service","account":"Example bank","event_date":"2028-04-08"}]';
 rc jsonb; other_result jsonb; sample jsonb; cards jsonb; series jsonb; card_rule jsonb;
 stats jsonb:='{"direction":"expense","method":"history_total_budget"}'; flags jsonb:='{"skip_unconfirmed_current_expense_estimates":true}';
BEGIN
 rc:=lts_recurring_private_v469.bank_commitments_v479(base,'[]','[]',a,policy);
 ASSERT jsonb_array_length(rc->'events')=4 AND rc#>'{events,0}'=unrelated;
 ASSERT rc#>>'{events,1,event_date}'='2028-04-08' AND (rc#>>'{events,1,signed_amount}')::numeric=-40;
 ASSERT lts_recurring_private_v469.bank_commitments_v479(rc,'[]','[]',a,policy)=rc;
 other_result:=lts_recurring_private_v469.bank_commitments_v479(rc,legacy,receipt,'2028-04-06',policy);
 ASSERT jsonb_array_length(other_result->'events')=3 AND other_result->'replacement_refs'='["fixture:legacy:1"]'::jsonb;
 ASSERT lts_recurring_private_v469.bank_commitments_v479(other_result,legacy,receipt,'2028-04-06',policy)=other_result;
 rc:=lts_recurring_private_v469.bank_commitments_v479(base,legacy,'[]','2028-05-02',policy);
 ASSERT rc#>>'{events,1,event_date}'='2028-05-03' AND rc#>>'{events,1,original_date}'='2028-04-08'
  AND (rc#>>'{events,1,signed_amount}')::numeric=-32 AND rc#>>'{events,1,confidence}'='confirmed_recurring_overdue';
 ASSERT rc#>>'{events,2,event_date}'='2028-05-08';
 rc:=lts_recurring_private_v469.bank_commitments_v479(rc,legacy,'[{"bill":"service","receipt":"single","paid_on":"2028-05-02"},{"bill":"service","receipt":"single","paid_on":"2028-05-02"}]','2028-05-03',policy);
 ASSERT jsonb_array_length(rc->'events')=3 AND rc#>>'{events,1,event_date}'='2028-05-08';
 rc:=lts_recurring_private_v469.bank_commitments_v479(base,legacy,'[]',a,policy);
 ASSERT jsonb_array_length(rc->'events')=3 AND rc->'replacement_refs'='[]'::jsonb;
 ASSERT lts_recurring_private_v469.skip_current_estimate_v479(flags,stats,'2028-04-30',a);
 ASSERT NOT lts_recurring_private_v469.skip_current_estimate_v479(flags,stats,'2028-05-01',a);
 ASSERT NOT lts_recurring_private_v469.skip_current_estimate_v479(flags,stats||'{"occurrence_confirmed":true}','2028-04-30',a);
 ASSERT NOT lts_recurring_private_v469.skip_current_estimate_v479(flags,stats||'{"method":"inflated_calendar"}','2028-04-30',a);
 ASSERT NOT lts_recurring_private_v469.skip_current_estimate_v479(flags,stats||'{"method":"fixed"}','2028-04-30',a);
 ASSERT NOT lts_recurring_private_v469.skip_current_estimate_v479(flags,stats||'{"direction":"income"}','2028-04-30',a);
 ASSERT NOT lts_recurring_private_v469.skip_current_estimate_v479('{}',stats,'2028-04-30',a);

 card_rule:='{"id":"contract","series":"recurring_contract","family":"issuer_test","account":"Example bank","last4":"1234","merchant_pattern":"TEST CONTRACT","starts_on":"2028-04-01","due_day":16,"description":"Monthly contract","category":"Subscription"}';
 policy:=jsonb_build_object('card_commitments',jsonb_build_array(card_rule));
 series:='[{"series_key":"recurring_contract","reference_amount_brl":75,"coverage":[],"warnings":[]}]';
 cards:='{"complete":true,"cards":[{"family":"issuer_test","cycles":[{"due_date":"2028-04-17","items":[{"source_id":"a","description":"TEST CONTRACT","last4":"1234","amount":72},{"source_id":"b","description":"Other vendor","last4":"1234","amount":75}]},{"due_date":"2028-05-16","items":[{"source_id":"c","description":"TEST CONTRACT","last4":"5678","amount":75}]}]}]}';
 base:=base||jsonb_build_object('series',series);
 rc:=lts_recurring_private_v469.card_commitments_v479(base,cards,a,policy);
 ASSERT jsonb_array_length(rc->'events')=2 AND rc#>'{events,0}'=unrelated;
 ASSERT rc#>>'{events,1,account}'='Example bank' AND rc#>>'{events,1,event_date}'='2028-05-16';
 ASSERT (rc#>>'{series,0,coverage,0,known_brl}')::numeric=72 AND (rc#>>'{series,0,coverage,0,additional_brl}')::numeric=0;
 ASSERT (rc#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=147;
 ASSERT lts_recurring_private_v469.card_commitments_v479(rc,cards,a,policy)=rc;
 rc:=lts_recurring_private_v469.card_commitments_v479(base,jsonb_set(cards,'{cards,0,cycles,1,basis}','"open_finance_invoice_v263"'),a,policy);
 ASSERT jsonb_array_length(rc->'events')=1;
 rc:=lts_recurring_private_v469.card_commitments_v479(base,jsonb_set(cards,'{complete}','false'),a,policy);
 ASSERT jsonb_array_length(rc->'events')=1 AND rc#>>'{series,0,coverage,1,status}'='requires_review';
END $test$;
