CREATE OR REPLACE FUNCTION public.lts_payroll_bank_matches_v231(p_user_id uuid)
 RETURNS TABLE(projection_ref text, projection_date date, projection_amount numeric, staging_id uuid, actual_date date, actual_amount numeric, bank text)
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
#variable_conflict use_column
DECLARE memo jsonb; source_epoch bigint; fingerprint text;
BEGIN
 IF p_user_id IS NULL THEN RETURN QUERY SELECT * FROM public.lts_payroll_bank_matches_v231_engine_v243(p_user_id); RETURN;END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='source-v243:'||source_epoch;
 SELECT payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id
 AND c.kind='lts_payroll_bank_matches_v231_v243' AND c.as_of=current_date AND c.from_date=current_date AND c.to_date=current_date
 AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO memo FROM public.lts_payroll_bank_matches_v231_engine_v243(p_user_id) r;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
  IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 PERFORM lts_read_private_v430.try_cache_put(p_user_id,'lts_payroll_bank_matches_v231_v243',current_date,current_date,current_date,memo,fingerprint); /* optional_memo_v430 */
 EXCEPTION WHEN read_only_sql_transaction THEN NULL;
 END;
 END IF;
  END IF;
 END IF;
 RETURN QUERY SELECT r.projection_ref,r.projection_date,r.projection_amount,r.staging_id,r.actual_date,r.actual_amount,r.bank FROM jsonb_array_elements(memo) WITH ORDINALITY a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) r(projection_ref text, projection_date date, projection_amount numeric, staging_id uuid, actual_date date, actual_amount numeric, bank text) ORDER BY a.ord;
END $function$
