DO $test$
DECLARE x record;n int;i int;
BEGIN
 SELECT * INTO x FROM public.lts_card_projection_rows_v290(qa.owner(1)) WHERE card_name ILIKE '%PRIME%';
 ASSERT FOUND AND x.user_id=qa.owner(1) AND x.card_name='VISA INFINITE PRIME' AND x.amount=12.34;
 ASSERT x.due_date=qa.month()+19 AND x.status='projected' AND x.source='received_card_composition_v290';
 SELECT count(*) INTO n FROM public.lts_card_projection_rows_v290(qa.owner(1)) WHERE card_name ILIKE '%PRIME%';ASSERT n=1;
 FOREACH i IN ARRAY ARRAY[2,3,4,5,6,8,9,10] LOOP
  ASSERT NOT EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290(qa.owner(i)) WHERE card_name ILIKE '%PRIME%'),format('Rejected case %s',i);
 END LOOP;
 SELECT * INTO x FROM public.lts_card_projection_rows_v290(qa.owner(7)) WHERE card_name ILIKE '%PRIME%';
 ASSERT FOUND AND x.card_name='Stored PRIME' AND x.amount=12.34;
 ASSERT EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290(qa.owner(1)) WHERE card_name='Itaú MASTER' AND amount=23.45);
 ASSERT EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290(qa.owner(1)) WHERE card_name='Bradesco AETERNUM' AND amount=34.56);
 ASSERT NOT EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290(NULL));
 ASSERT (SELECT count(*) FROM public.card_invoices)=3;
 ASSERT (SELECT count(*) FROM public.lts_open_finance_staging)=20;
 ASSERT (SELECT count(*) FROM qa.rows)=13;
 RAISE NOTICE 'V395 actual SQL passed: Prime once, same owner/account/bank, projected only, official precedence, rejected mismatches and unchanged other families';
END $test$;
BEGIN READ ONLY;
SELECT count(*)>=1 AS read_only_reader_pass FROM public.lts_card_projection_rows_v290(qa.owner(1));
COMMIT;
