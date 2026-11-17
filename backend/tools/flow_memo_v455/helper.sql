CREATE OR REPLACE FUNCTION lts_read_private_v430.try_cache_put(p_user_id uuid, p_kind text, p_as_of date, p_from date, p_to date, p_payload jsonb, p_fingerprint text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
