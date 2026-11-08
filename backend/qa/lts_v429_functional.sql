\ir lts_v429_setup.sql
\ir ../patches/v429/canonical_cycle_settlement.sql
\ir ../patches/v429/canonical_cycle_settlement.sql

DO $test$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';p jsonb;r jsonb;before_hash text;after_hash text;
BEGIN
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>2
 THEN RAISE EXCEPTION 'V429 cache epoch changed on replay'; END IF;
 IF NOT public.lts_card_invoice_settled_v290(u,'c6-main','2026-11-01','2026-11-05',100)
 THEN RAISE EXCEPTION 'V429 exact C6 confirmation rejected'; END IF;
 IF NOT public.lts_card_invoice_settled_v290(u,'itau-main','2026-11-01','2026-11-10',50)
 THEN RAISE EXCEPTION 'V429 exact other-bank confirmation rejected'; END IF;
 IF public.lts_card_invoice_settled_v290(u,'c6-main','2026-11-01','2026-11-05',101)
  OR public.lts_card_invoice_settled_v290(u,'c6-main','2026-11-01','2026-11-06',100)
  OR public.lts_card_invoice_settled_v290(u,'c6-main','2026-12-01','2026-12-05',70)
  OR public.lts_card_invoice_settled_v290(u,'dup-main','2026-11-01','2026-11-15',30)
  OR public.lts_card_invoice_settled_v290('00000000-0000-4000-8000-000000000002','c6-main','2026-11-01','2026-11-05',100)
 THEN RAISE EXCEPTION 'V429 changed, duplicate or foreign evidence accepted'; END IF;

 p:='{"version":"card-cycles-v226","complete":true,"cards":[{"family":"c6","name":"synthetic-c6","complete":true,"cycles":[{"month":"2026-10-01","due_date":"2026-10-05","amount":80,"invoice_source_id":"30000000-0000-4000-8000-000000000001","payment_status":"unconfirmed"},{"month":"2026-11-01","due_date":"2026-11-05","amount":100,"payment_status":null},{"month":"2026-12-01","due_date":"2026-12-05","amount":70,"payment_status":"unconfirmed"}]},{"family":"prime","name":"synthetic-prime","complete":true,"cycles":[{"month":"2026-11-01","due_date":"2026-11-12","amount":40}]},{"family":"dup","name":"synthetic-dup","complete":true,"cycles":[{"month":"2026-11-01","due_date":"2026-11-15","amount":30}]}]}'::jsonb;
 r:=public.lts_card_settlement_overlay_v290(u,p);
 IF r#>>'{cards,0,cycles,0,settlement_basis}' IS DISTINCT FROM 'reviewed_c6_other_payment_and_exact_posted_checking_debit'
 THEN RAISE EXCEPTION 'V429 prior reviewed-link path regressed'; END IF;
 IF r#>>'{cards,0,cycles,1,settlement_basis}' IS DISTINCT FROM 'exact_card_cycle_fact_confirmation_v429'
  OR r#>'{cards,0,cycles,1,settlement_confirmed}' IS DISTINCT FROM 'true'::jsonb
  OR r#>>'{cards,0,cycles,1,payment_status}' IS DISTINCT FROM 'paid'
 THEN RAISE EXCEPTION 'V429 exact cycle not settled'; END IF;
 IF r#>'{cards,0,cycles,2}' IS DISTINCT FROM p#>'{cards,0,cycles,2}'
  OR r#>'{cards,1,cycles,0}' IS DISTINCT FROM p#>'{cards,1,cycles,0}'
  OR r#>'{cards,2,cycles,0}' IS DISTINCT FROM p#>'{cards,2,cycles,0}'
 THEN RAISE EXCEPTION 'V429 unmatched or ambiguous cycle changed'; END IF;

 SELECT hash INTO before_hash FROM v429_sources_before;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]')) INTO after_hash FROM(
  SELECT 'invoice' kind,to_jsonb(i) row FROM public.card_invoices i
  UNION ALL SELECT 'fact',to_jsonb(f) FROM public.lts_fact_confirmation f
  UNION ALL SELECT 'link',to_jsonb(l) FROM public.lts_card_documentary_payment_link_v272 l
  UNION ALL SELECT 'contract',to_jsonb(c) FROM public.lts_card_settlement_expense_contract_v273 c
  UNION ALL SELECT 'staging',to_jsonb(s) FROM public.lts_open_finance_staging s
 )x;
 IF before_hash IS DISTINCT FROM after_hash THEN RAISE EXCEPTION 'V429 source tables changed'; END IF;
 IF EXISTS(SELECT 1 FROM v429_attrs_before b JOIN pg_proc p ON p.oid=b.oid WHERE b.attrs IS DISTINCT FROM to_jsonb(p)-'prosrc')
 THEN RAISE EXCEPTION 'V429 function attributes changed'; END IF;
END
$test$;

\ir ../patches/v355/canonical_card_obligations.sql
DO $consumer$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';p jsonb;r jsonb;o jsonb;
BEGIN
 p:='{"version":"card-cycles-v226","complete":true,"cards":[{"family":"c6","name":"synthetic-c6","complete":true,"cycles":[{"month":"2026-11-01","due_date":"2026-11-05","amount":100,"payment_status":null},{"month":"2026-12-01","due_date":"2026-12-05","amount":70,"payment_status":"unconfirmed"}]}]}'::jsonb;
 r:=public.lts_card_settlement_overlay_v290(u,p);
 o:=public.lts_card_obligations_v355(r,'2026-11-08');
 IF jsonb_array_length(o->'canonical_paid_cycles')<>1
  OR o#>>'{canonical_paid_cycles,0,reference_month}' IS DISTINCT FROM '2026-11-01'
  OR o#>>'{next_due,reference_month}' IS DISTINCT FROM '2026-12-01'
  OR jsonb_array_length(o->'closed_or_due')<>0
 THEN RAISE EXCEPTION 'V429 canonical obligations still expose settled cycle'; END IF;
END
$consumer$;

SELECT jsonb_build_object('pass',true,'exact_confirmations',2,'reviewed_link_preserved',true,
 'ambiguity_rejected',true,'foreign_owner_rejected',true,'consumer_advanced',true,
 'source_writes',0,'replay_passed',true,'private_data_used',false);
