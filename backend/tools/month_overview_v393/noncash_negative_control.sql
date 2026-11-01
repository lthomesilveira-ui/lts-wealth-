-- Reproduce the new reader's regression before the additive V394 correction.
DO $test$
DECLARE f jsonb;e jsonb;j jsonb;
BEGIN
 SELECT payload INTO f FROM qa.flow WHERE user_id='00000000-0000-4000-8000-000000000001';
 SELECT jsonb_agg(to_jsonb(x)) INTO e FROM qa.expense x WHERE user_id='00000000-0000-4000-8000-000000000001';
 j:=lts_month_private_v393.build(f,e,'2026-11-01','2026-11-30','2026-11-01');
 ASSERT (j#>>'{cash,total,payments}')::numeric=570;
 ASSERT (j#>>'{cash,unconfirmed,payments}')::numeric=70;
 RAISE NOTICE 'V393 payroll withholding double-count negative control reproduced';
END $test$;
