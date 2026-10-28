CREATE OR REPLACE FUNCTION public.lts_card_invoice_amounts_v230(p_user_id uuid)
 RETURNS TABLE(user_id uuid, card_name text, reference_month date, due_date date, status text, amount numeric, source text)
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
#variable_conflict use_column
DECLARE memo jsonb; source_epoch bigint; fingerprint text;
BEGIN
 IF p_user_id IS NULL THEN RETURN QUERY SELECT * FROM public.lts_card_invoice_amounts_v230_engine_v243(p_user_id); RETURN;END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='source-v243:'||source_epoch;
 SELECT payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id
 AND c.kind='lts_card_invoice_amounts_v230_v243' AND c.as_of=current_date AND c.from_date=current_date AND c.to_date=current_date
 AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes';
 IF memo IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO memo FROM public.lts_card_invoice_amounts_v230_engine_v243(p_user_id) r;
  IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
   RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
  END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
  IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_card_invoice_amounts_v230_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
 EXCEPTION WHEN read_only_sql_transaction THEN NULL;
 END;
 END IF;
  END IF;
 END IF;
 RETURN QUERY WITH current_projection AS MATERIALIZED(SELECT * FROM public.lts_card_projection_rows_v290(p_user_id)),
 base AS(SELECT r.*,a.ord FROM jsonb_array_elements(memo) WITH ORDINALITY a(j,ord)
 CROSS JOIN LATERAL jsonb_to_record(a.j) r(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text))
 SELECT b.user_id,b.card_name,b.reference_month,b.due_date,CASE WHEN b.status IN('open','projected') AND public.lts_card_invoice_settled_v290(p_user_id,b.card_name,b.reference_month,b.due_date,b.amount) THEN 'paid' ELSE b.status END,b.amount,b.source FROM base b
 WHERE NOT EXISTS(SELECT 1 FROM current_projection p WHERE p.reference_month=b.reference_month
 AND public.lts_card_family_v226(p.card_name,p.card_name)=public.lts_card_family_v226(b.card_name,b.card_name))
 UNION ALL SELECT * FROM current_projection;
END $function$
