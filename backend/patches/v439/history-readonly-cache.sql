DO $guard$ BEGIN
 IF md5(pg_get_functiondef('public.lts_flow_history_read_v229(date,date)'::regprocedure)) <> '80565507ae298d785afd0bfcf4056791' THEN
 RAISE EXCEPTION 'history reader changed; review required'; END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.lts_flow_history_read_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; hf date; ht date; source_key text;
BEGIN
 source_key:=public.lts_flow_read_source_key_v247(u);
 SELECT payload INTO j FROM public.lts_v229_read_cache WHERE user_id=u AND kind='history' AND payload->>'source_revision'='correlated-cash-v247' AND payload->>'source_fingerprint'=source_key AND as_of=current_date AND from_date<=p_from AND to_date>=p_to ORDER BY refreshed_at DESC LIMIT 1;
 IF j IS NULL THEN
  hf:=p_from;ht:=p_to;
  j:=(public.lts_browser_flow_v12(hf,ht)->'flow')||jsonb_build_object('source_revision','correlated-cash-v247','source_fingerprint',source_key);
  IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload) VALUES(u,'history',current_date,hf,ht,j)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=now();
 -- A cache write is optional: preserve the computed result on contention.
 EXCEPTION WHEN read_only_sql_transaction OR lock_not_available THEN NULL;
 END;
 END IF;
 END IF;
 RETURN j||jsonb_build_object('from',p_from,'to',p_to,'historical',(j->'historical')||jsonb_build_object(
  'days',coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(j#>'{historical,days}') x WHERE (x->>'date')::date BETWEEN p_from AND p_to),'[]'),
  'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date') FROM jsonb_array_elements(j#>'{historical,events}') x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]')));
END $function$

