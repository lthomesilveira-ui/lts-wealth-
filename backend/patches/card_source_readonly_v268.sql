-- On a cold read-only call, compute the same result without memo writes.
BEGIN;
DO $lease$ BEGIN IF md5(pg_get_functiondef('public.lts_card_source_rows_v226(uuid)'::regprocedure))<>'ff5621b6abec5edfb72a2eea02d61b6e' THEN RAISE EXCEPTION 'Card source reader changed; inspect before applying'; END IF; END $lease$;
CREATE OR REPLACE FUNCTION public.lts_card_source_rows_v226(p_user_id uuid)
 RETURNS TABLE(source_id uuid, bank text, family text, card_name text, last4 text, billing_last4 text, posting_date date, purchase_date date, reference_month date, due_date date, provider_status text, amount numeric, description text, category text, category_basis text, installment_number integer, total_installments integer, is_payment boolean, bill_id text, observed_at timestamp with time zone)
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET jit TO 'off'
AS $function$
DECLARE cache_epoch bigint; after_epoch bigint; memo jsonb; attempt integer; source_key text; cache_hit boolean;
BEGIN
 IF p_user_id IS NULL THEN RETURN; END IF;
 FOR attempt IN 1..2 LOOP
  SELECT epoch INTO cache_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
  IF cache_epoch IS NULL THEN RAISE EXCEPTION 'read source revision unavailable'; END IF;
  source_key:='v262:card-source:'||cache_epoch::text||':'||current_date::text;
  SELECT c.payload INTO memo FROM public.lts_v229_read_cache c
  WHERE c.user_id=p_user_id AND c.kind='card_source_v262' AND c.as_of=current_date
   AND c.from_date=current_date AND c.to_date=current_date AND c.source_fingerprint=source_key;
  cache_hit:=FOUND;
  IF NOT cache_hit THEN
   SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) INTO memo
   FROM public.lts_card_source_rows_pre_v262(p_user_id) r;
  END IF;
  SELECT epoch INTO after_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
  IF after_epoch=cache_epoch THEN
   IF NOT cache_hit AND NOT current_setting('transaction_read_only')::boolean THEN
   DELETE FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id AND c.kind='card_source_v262' AND c.as_of<>current_date;
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
   VALUES(p_user_id,'card_source_v262',current_date,current_date,current_date,memo,clock_timestamp(),source_key)
   ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
    payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
   END IF;
   RETURN QUERY
   SELECT r.source_id,r.bank,r.family,r.card_name,r.last4,r.billing_last4,r.posting_date,r.purchase_date,r.reference_month,r.due_date,r.provider_status,r.amount,r.description,r.category,r.category_basis,r.installment_number,r.total_installments,r.is_payment,r.bill_id,CASE WHEN r.provider_status='DOCUMENTED' THEN r.observed_at ELSE coalesce(s.last_seen_at,r.observed_at) END
   FROM jsonb_to_recordset(memo) AS r(source_id uuid,bank text,family text,card_name text,last4 text,billing_last4 text,posting_date date,purchase_date date,reference_month date,due_date date,provider_status text,amount numeric,description text,category text,category_basis text,installment_number integer,total_installments integer,is_payment boolean,bill_id text,observed_at timestamp with time zone)
   LEFT JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id AND s.id=r.source_id
    AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL;
   RETURN;
  END IF;
  memo:=NULL;
 END LOOP;
 RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='card source changed during read';
END $function$
;
COMMIT;

