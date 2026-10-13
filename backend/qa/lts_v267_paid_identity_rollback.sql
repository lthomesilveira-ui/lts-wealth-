BEGIN;
SET LOCAL jit=off;
SET LOCAL statement_timeout='20s';
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL plan_cache_mode='force_custom_plan';
DO $probe$
DECLARE t timestamptz:=clock_timestamp(); u uuid:=public.lts_open_finance_pilot_owner_v1();
 r jsonb; first_value jsonb; i int; equal_results boolean:=true; elapsed_ms numeric;
 original_deleted_at timestamptz; old_payload jsonb; checks integer:=0;
BEGIN
 FOR i IN 1..15 LOOP
  -- Separate expression sites reproduce the cost of repeated dependent readers.
  EXECUTE 'SELECT public.lts_c6_paid_identity_v237($1)' INTO r USING u;
  IF i=1 THEN first_value:=r;
  ELSE equal_results:=equal_results AND r IS NOT DISTINCT FROM first_value; END IF;
 END LOOP;
 elapsed_ms:=round(extract(epoch FROM clock_timestamp()-t)*1000,1);
 IF NOT equal_results OR first_value IS NULL THEN RAISE EXCEPTION 'paid identity positive source changed'; END IF;
 checks:=checks+1;
 IF current_setting('plan_cache_mode')<>'force_custom_plan'
 THEN RAISE EXCEPTION 'caller planning mode leaked'; END IF;
 checks:=checks+1;
 IF public.lts_c6_paid_identity_v237(NULL) IS NOT NULL
 OR public.lts_c6_paid_identity_v237('00000000-0000-0000-0000-000000000001') IS NOT NULL
 THEN RAISE EXCEPTION 'unrelated owner accepted'; END IF;
 checks:=checks+1;
 SELECT provider_deleted_at INTO original_deleted_at FROM public.lts_open_finance_staging
 WHERE id=(first_value->>'invoice_id')::uuid AND user_id=u;
 UPDATE public.lts_open_finance_staging SET provider_deleted_at=clock_timestamp()
 WHERE id=(first_value->>'invoice_id')::uuid AND user_id=u;
 IF public.lts_c6_paid_identity_v237(u) IS NOT NULL
 THEN RAISE EXCEPTION 'prepared query retained a deleted invoice'; END IF;
 UPDATE public.lts_open_finance_staging SET provider_deleted_at=original_deleted_at
 WHERE id=(first_value->>'invoice_id')::uuid AND user_id=u;
 IF public.lts_c6_paid_identity_v237(u) IS DISTINCT FROM first_value
 THEN RAISE EXCEPTION 'restored invoice did not restore the exact identity'; END IF;
 checks:=checks+1;
 SELECT normalized_payload INTO old_payload FROM public.lts_open_finance_staging
 WHERE id=(first_value->>'debit_id')::uuid AND user_id=u;
 UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"')
 WHERE id=(first_value->>'debit_id')::uuid AND user_id=u;
 IF public.lts_c6_paid_identity_v237(u) IS NOT NULL
 THEN RAISE EXCEPTION 'prepared query accepted an unposted debit'; END IF;
 UPDATE public.lts_open_finance_staging SET normalized_payload=old_payload
 WHERE id=(first_value->>'debit_id')::uuid AND user_id=u;
 IF public.lts_c6_paid_identity_v237(u) IS DISTINCT FROM first_value
 THEN RAISE EXCEPTION 'restored posted debit changed the identity'; END IF;
 checks:=checks+1;
 PERFORM set_config('lts.v267_identity_probe',jsonb_build_object('calls',15,'elapsed_ms',elapsed_ms,
  'equal_results',equal_results,'result_md5',md5(first_value::text),'nonnull',true,
  'no_owner_result',true,'foreign_owner_result',true,'caller_plan_mode_restored',true,
  'deleted_invoice_rejected',true,'pending_debit_rejected',true,'checks',checks,
  'source_mutations','rolled_back')::text,true);
END $probe$;
SELECT current_setting('lts.v267_identity_probe')::jsonb receipt;
ROLLBACK;
