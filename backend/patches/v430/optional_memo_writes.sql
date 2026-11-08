-- A derived memo is optional. Its writer must not delay an already computed
-- financial result behind an unrelated transaction. Source reads still fail
-- closed and retain their original fingerprints, deadlines and five-minute TTL.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';

CREATE SCHEMA IF NOT EXISTS lts_read_private_v430;
REVOKE ALL ON SCHEMA lts_read_private_v430 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_read_private_v430 TO service_role;

CREATE OR REPLACE FUNCTION lts_read_private_v430.try_cache_put(
 p_user_id uuid,p_kind text,p_as_of date,p_from date,p_to date,
 p_payload jsonb,p_fingerprint text)
RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $function$
DECLARE previous_lock_timeout text;
BEGIN
 IF current_setting('transaction_read_only')::boolean THEN RETURN false; END IF;
 IF NOT pg_try_advisory_xact_lock(hashtextextended(concat_ws('|',
  'lts:optional-memo-v430',p_user_id::text,p_kind,p_as_of::text,p_from::text,p_to::text),430))
 THEN RETURN false; END IF;
 previous_lock_timeout:=current_setting('lock_timeout');
 BEGIN
  IF previous_lock_timeout::interval=interval '0'
   OR previous_lock_timeout::interval>interval '100 milliseconds' THEN
   PERFORM set_config('lock_timeout','100ms',true);
  END IF;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,p_kind,p_as_of,p_from,p_to,p_payload,p_fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE
   SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  PERFORM set_config('lock_timeout',previous_lock_timeout,true);
 EXCEPTION WHEN read_only_sql_transaction OR lock_not_available OR deadlock_detected THEN
  -- The failed subtransaction has rolled back both the optional write and
  -- its local setting. Do not turn a cache collision into missing cash data.
  RETURN false;
 END;
 RETURN true;
END $function$;
REVOKE ALL ON FUNCTION lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text) TO service_role;

-- The source-specific guarded replacements are appended below.
DO $patch$
DECLARE target regprocedure:='public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='53c7e49fadd8c56f9ddb5d797513f360' THEN
  IF (length(d)-length(replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
    VALUES(p_user_id,'corrected_cash_v1_v268',current_date,cache_from,cache_to,memo,fingerprint,clock_timestamp())
    ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE
    SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,'')))/length($needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
    VALUES(p_user_id,'corrected_cash_v1_v268',current_date,cache_from,cache_to,memo,fingerprint,clock_timestamp())
    ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE
    SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$)<>1
  THEN RAISE EXCEPTION 'V430_MEMO_WRITE_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
    VALUES(p_user_id,'corrected_cash_v1_v268',current_date,cache_from,cache_to,memo,fingerprint,clock_timestamp())
    ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE
    SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,$replacement$PERFORM lts_read_private_v430.try_cache_put(p_user_id,'corrected_cash_v1_v268',current_date,cache_from,cache_to,memo,fingerprint); /* optional_memo_v430 */$replacement$);
 ELSIF md5(d)<>'dd65d959b134f4937b7bb3e66fc1cdc6' THEN RAISE EXCEPTION 'V430_PREDECESSOR_CHANGED: %',target; END IF;
 IF md5(pg_get_functiondef(target))<>'dd65d959b134f4937b7bb3e66fc1cdc6'
  OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V430_FUNCTION_CONTRACT_CHANGED: %',target; END IF;
END $patch$;

DO $patch$
DECLARE target regprocedure:='public.lts_card_invoice_amounts_v230(uuid)'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='b377df3872ef719f955d21542c3f12c9' THEN
  IF (length(d)-length(replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_card_invoice_amounts_v230_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,'')))/length($needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_card_invoice_amounts_v230_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$)<>1
  THEN RAISE EXCEPTION 'V430_MEMO_WRITE_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_card_invoice_amounts_v230_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,$replacement$PERFORM lts_read_private_v430.try_cache_put(p_user_id,'lts_card_invoice_amounts_v230_v243',current_date,current_date,current_date,memo,fingerprint); /* optional_memo_v430 */$replacement$);
 ELSIF md5(d)<>'5edc57b30e5d6b8a52d632efa08ec498' THEN RAISE EXCEPTION 'V430_PREDECESSOR_CHANGED: %',target; END IF;
 IF md5(pg_get_functiondef(target))<>'5edc57b30e5d6b8a52d632efa08ec498'
  OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V430_FUNCTION_CONTRACT_CHANGED: %',target; END IF;
END $patch$;

DO $patch$
DECLARE target regprocedure:='public.lts_payroll_bank_matches_v231(uuid)'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='35faccf3d787112de3f5203577ae408d' THEN
  IF (length(d)-length(replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_payroll_bank_matches_v231_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,'')))/length($needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_payroll_bank_matches_v231_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$)<>1
  THEN RAISE EXCEPTION 'V430_MEMO_WRITE_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle$INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'lts_payroll_bank_matches_v231_v243',current_date,current_date,current_date,memo,fingerprint,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;$needle$,$replacement$PERFORM lts_read_private_v430.try_cache_put(p_user_id,'lts_payroll_bank_matches_v231_v243',current_date,current_date,current_date,memo,fingerprint); /* optional_memo_v430 */$replacement$);
 ELSIF md5(d)<>'3b3d5eaf223fb089c627216199965af3' THEN RAISE EXCEPTION 'V430_PREDECESSOR_CHANGED: %',target; END IF;
 IF md5(pg_get_functiondef(target))<>'3b3d5eaf223fb089c627216199965af3'
  OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V430_FUNCTION_CONTRACT_CHANGED: %',target; END IF;
END $patch$;

COMMIT;
