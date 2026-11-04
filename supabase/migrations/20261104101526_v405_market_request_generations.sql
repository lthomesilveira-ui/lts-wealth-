-- V405: pg_net request IDs may be reused after an unclean database restart.
-- Keep every request and quotation; identify each new request by server generation.
-- Apply this file in one transaction. No net extension objects or schedules change.
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $lease$
DECLARE key_definition text; generation_type oid;
BEGIN
 LOCK TABLE public.lts_market_request_v290 IN ACCESS EXCLUSIVE MODE;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_market_request_quotes_v290()'::regprocedure)
    NOT IN ('ccff034ebb69b34de11eed3a2cccc467','b3019cb0f6ec5851a72e522c812f720d') THEN
  RAISE EXCEPTION 'V405 request writer predecessor changed';
 END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.lts_market_collect_quotes_v290()'::regprocedure)
    NOT IN ('bda35a8a992777c26f40eb2fcc4054f5','d15da8ec8caa695232eb370189766e9e') THEN
  RAISE EXCEPTION 'V405 response collector predecessor changed';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_constraint WHERE contype='f'
           AND confrelid='public.lts_market_request_v290'::regclass) THEN
  RAISE EXCEPTION 'V405 request identity has an unexpected foreign-key consumer';
 END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.lts_market_request_v290'::regclass) THEN
  RAISE EXCEPTION 'V405 request table must retain row-level security';
 END IF;
 SELECT pg_get_constraintdef(oid) INTO key_definition FROM pg_constraint
 WHERE conrelid='public.lts_market_request_v290'::regclass AND contype='p';
 SELECT atttypid INTO generation_type FROM pg_attribute
 WHERE attrelid='public.lts_market_request_v290'::regclass
   AND attname='request_generation' AND NOT attisdropped;
 IF generation_type IS NULL THEN
  IF key_definition IS DISTINCT FROM 'PRIMARY KEY (request_id)' THEN
   RAISE EXCEPTION 'V405 original request primary key changed';
  END IF;
  -- The actual server generation of older history was not captured. Do not invent it.
  ALTER TABLE public.lts_market_request_v290 ADD COLUMN request_generation timestamptz
   NOT NULL DEFAULT '-infinity'::timestamptz;
  UPDATE public.lts_market_request_v290 SET request_generation=pg_postmaster_start_time()
   WHERE requested_at>=pg_postmaster_start_time();
  ALTER TABLE public.lts_market_request_v290
   ALTER COLUMN request_generation SET DEFAULT pg_postmaster_start_time(),
   DROP CONSTRAINT lts_market_request_v290_pkey,
   ADD CONSTRAINT lts_market_request_v290_pkey PRIMARY KEY(request_generation,request_id);
 ELSIF generation_type<>'timestamptz'::regtype
       OR key_definition IS DISTINCT FROM 'PRIMARY KEY (request_generation, request_id)' THEN
  RAISE EXCEPTION 'V405 request generation schema changed or partially applied';
 END IF;
END $lease$;

COMMENT ON COLUMN public.lts_market_request_v290.request_generation IS
 'Database postmaster start time captured when the request was enqueued; -infinity means historical generation was not recorded before V405.';

CREATE OR REPLACE FUNCTION public.lts_market_request_quotes_v290()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE quote_symbol text; target text; req bigint; ids jsonb:='[]';
 current_generation timestamptz:=pg_postmaster_start_time(); requested timestamptz;
 day date:=(clock_timestamp() AT TIME ZONE 'America/Sao_Paulo')::date;
BEGIN
 FOREACH quote_symbol IN ARRAY ARRAY['OGN','USD/BRL'] LOOP
  IF EXISTS(SELECT 1 FROM public.lts_market_request_v290 r
            WHERE r.symbol=quote_symbol AND r.request_generation=current_generation
              AND r.processed_at IS NULL AND r.requested_at>clock_timestamp()-interval '3 minutes')
  THEN CONTINUE; END IF;
  target:=CASE WHEN quote_symbol='OGN' THEN 'https://query1.finance.yahoo.com/v8/finance/chart/OGN?interval=1d&range=5d'
  ELSE 'https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoDolarPeriodo(dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)?@dataInicial=%27'
   ||to_char(day-21,'MM-DD-YYYY')||'%27&@dataFinalCotacao=%27'||to_char(day,'MM-DD-YYYY')||'%27&$format=json&$orderby=dataHoraCotacao%20desc&$top=1' END;
  requested:=clock_timestamp();
  req:=net.http_get(url:=target,headers:='{"Accept":"application/json","User-Agent":"LTSWealth/1.0"}'::jsonb,timeout_milliseconds:=12000);
  INSERT INTO public.lts_market_request_v290(request_id,symbol,requested_at,request_generation)
   VALUES(req,quote_symbol,requested,current_generation);
  INSERT INTO public.lts_market_refresh_v290(symbol,last_attempt_at,status)
   VALUES(quote_symbol,requested,'consulting')
   ON CONFLICT(symbol) DO UPDATE SET last_attempt_at=excluded.last_attempt_at,status=excluded.status,error_code=NULL;
  ids:=ids||jsonb_build_array(jsonb_build_object('symbol',quote_symbol,'request_id',req));
 END LOOP;
 RETURN ids;
END $f$;

CREATE OR REPLACE FUNCTION public.lts_market_collect_quotes_v290()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE r record; parsed jsonb; qid bigint; previous_id bigint; previous_time timestamptz; accepted integer:=0;
 changed boolean:=false; err text; body jsonb; current_generation timestamptz:=pg_postmaster_start_time();
BEGIN
 FOR r IN SELECT req.*,res.status_code,res.content,res.timed_out,res.error_msg,res.created response_at
  FROM public.lts_market_request_v290 req
  LEFT JOIN LATERAL(
   SELECT response.* FROM net._http_response response
   WHERE req.request_generation=current_generation AND response.id=req.request_id
     AND response.created>=req.requested_at
   ORDER BY response.created DESC LIMIT 1
  ) res ON true
  WHERE req.processed_at IS NULL AND
   (req.request_generation<>current_generation OR res.id IS NOT NULL
    OR req.requested_at<clock_timestamp()-interval '3 minutes')
  ORDER BY req.requested_at,req.request_generation,req.request_id FOR UPDATE OF req SKIP LOCKED LOOP
  err:=NULL; parsed:=NULL;
  IF r.request_generation<>current_generation THEN err:='request_interrupted_by_restart';
  ELSIF r.status_code IS NULL OR r.timed_out OR r.error_msg IS NOT NULL THEN err:='source_unavailable';
  ELSIF r.status_code<>200 THEN err:='http_'||r.status_code;
  ELSE
   BEGIN body:=r.content::jsonb; parsed:=public.lts_market_parse_v290(r.symbol,body,clock_timestamp());
   EXCEPTION WHEN OTHERS THEN parsed:=NULL; END;
   IF parsed IS NULL THEN err:='invalid_or_undated_quote'; END IF;
  END IF;
  IF err IS NULL THEN
   INSERT INTO public.lts_market_quote_v290(symbol,value,currency,quoted_at,source_name,source_url,market_state,details,received_at)
   VALUES(r.symbol,(parsed->>'value')::numeric,parsed->>'currency',(parsed->>'quoted_at')::timestamptz,
    parsed->>'source_name',parsed->>'source_url',parsed->>'market_state',parsed->'details',clock_timestamp())
   ON CONFLICT(symbol,source_name,quoted_at,value) DO NOTHING;
   SELECT id INTO qid FROM public.lts_market_quote_v290 q WHERE q.symbol=r.symbol
    AND q.source_name=parsed->>'source_name' AND q.quoted_at=(parsed->>'quoted_at')::timestamptz AND q.value=(parsed->>'value')::numeric;
   SELECT h.quote_id,q.quoted_at INTO previous_id,previous_time FROM public.lts_market_head_v290 h
    JOIN public.lts_market_quote_v290 q ON q.id=h.quote_id WHERE h.symbol=r.symbol;
   IF previous_time IS NULL OR (parsed->>'quoted_at')::timestamptz>=previous_time THEN
    INSERT INTO public.lts_market_head_v290(symbol,quote_id) VALUES(r.symbol,qid)
     ON CONFLICT(symbol) DO UPDATE SET quote_id=excluded.quote_id;
    changed:=changed OR qid IS DISTINCT FROM previous_id;
   END IF;
   accepted:=accepted+1;
  END IF;
  UPDATE public.lts_market_request_v290 SET processed_at=clock_timestamp(),error_code=err
   WHERE request_generation=r.request_generation AND request_id=r.request_id;
  -- A late failure of an older attempt must not overwrite a newer in-flight attempt.
  UPDATE public.lts_market_refresh_v290 refresh SET last_response_at=clock_timestamp(),
   status=CASE WHEN err IS NULL THEN 'available' ELSE 'failed' END,error_code=err
   WHERE refresh.symbol=r.symbol AND NOT EXISTS(
    SELECT 1 FROM public.lts_market_request_v290 newer WHERE newer.symbol=r.symbol
     AND (newer.requested_at,newer.request_generation,newer.request_id)>
         (r.requested_at,r.request_generation,r.request_id));
 END LOOP;
 IF changed THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton; END IF;
 RETURN jsonb_build_object('accepted',accepted,'valuation_revision_changed',changed);
END $f$;

REVOKE ALL ON FUNCTION public.lts_market_request_quotes_v290(),public.lts_market_collect_quotes_v290()
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_market_request_quotes_v290(),public.lts_market_collect_quotes_v290()
 TO service_role;
