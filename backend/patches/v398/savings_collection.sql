-- Public BCB requests contain only dates. No personal information or credentials.
CREATE SCHEMA IF NOT EXISTS lts_savings_private_v398;
REVOKE ALL ON SCHEMA lts_savings_private_v398 FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS lts_savings_private_v398.request (
 request_id bigint PRIMARY KEY,requested_at timestamptz NOT NULL DEFAULT now(),
 processed_at timestamptz,error_code text,accepted_rows integer,
 response_md5 text
);
REVOKE ALL ON lts_savings_private_v398.request FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION lts_savings_private_v398.collect()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $fn$
DECLARE r record;body jsonb;x jsonb;d date;e date;rate numeric;
 accepted integer:=0;changed integer:=0;row_change integer;err text;
BEGIN
 FOR r IN SELECT q.*,h.status_code,h.content,h.timed_out,h.error_msg
  FROM lts_savings_private_v398.request q LEFT JOIN net._http_response h ON h.id=q.request_id
  WHERE q.processed_at IS NULL AND (h.id IS NOT NULL OR q.requested_at<clock_timestamp()-interval '10 minutes')
  ORDER BY q.requested_at FOR UPDATE OF q SKIP LOCKED LOOP
  err:=NULL;accepted:=0;
  IF r.status_code IS NULL OR r.status_code<>200 OR coalesce(r.timed_out,false) OR r.error_msg IS NOT NULL THEN err:='source_unavailable';
  ELSE
   BEGIN
    body:=r.content::jsonb;
    IF jsonb_typeof(body) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid source';END IF;
    -- Validate the whole response before any row is accepted. Day-one periods
    -- are stored once; other anniversary dates are outside this loan's scope.
    FOR x IN SELECT value FROM jsonb_array_elements(body) LOOP
     IF NOT coalesce(x->>'data' ~ '^\d{2}/\d{2}/\d{4}$'
      AND x->>'dataFim' ~ '^\d{2}/\d{2}/\d{4}$'
      AND x->>'valor' ~ '^[0-9]+([.][0-9]+)?$',false) THEN RAISE EXCEPTION 'invalid source row';END IF;
     d:=to_date(x->>'data','DD/MM/YYYY');e:=to_date(x->>'dataFim','DD/MM/YYYY');rate:=(x->>'valor')::numeric;
     IF to_char(d,'DD/MM/YYYY')<>x->>'data' OR to_char(e,'DD/MM/YYYY')<>x->>'dataFim'
      OR rate<0 OR rate>10 OR e<d OR e>d+interval '32 days' THEN RAISE EXCEPTION 'invalid source period';END IF;
    END LOOP;
    IF EXISTS(SELECT 1 FROM jsonb_array_elements(body)x WHERE left(x->>'data',3)='01/' GROUP BY x->>'data' HAVING count(*)>1)
     THEN RAISE EXCEPTION 'duplicate source periods';END IF;
    FOR x IN SELECT value FROM jsonb_array_elements(body) WHERE left(value->>'data',3)='01/' LOOP
     d:=to_date(x->>'data','DD/MM/YYYY');e:=to_date(x->>'dataFim','DD/MM/YYYY');rate:=(x->>'valor')::numeric;
     IF e<>(d+interval '1 month')::date OR d>(clock_timestamp() AT TIME ZONE 'America/Sao_Paulo')::date THEN RAISE EXCEPTION 'future source period';END IF;
     INSERT INTO public.lts_savings_rate_v398(period_start,period_end,rate_pct,source_url)
     VALUES(d,e,rate,'https://api.bcb.gov.br/dados/serie/bcdata.sgs.195/dados')
     ON CONFLICT(period_start) DO UPDATE SET period_end=excluded.period_end,rate_pct=excluded.rate_pct,observed_at=clock_timestamp()
      WHERE (lts_savings_rate_v398.period_end,lts_savings_rate_v398.rate_pct) IS DISTINCT FROM (excluded.period_end,excluded.rate_pct);
     GET DIAGNOSTICS row_change=ROW_COUNT;changed:=changed+row_change;accepted:=accepted+1;
    END LOOP;
   EXCEPTION WHEN OTHERS THEN err:='invalid_savings_response';accepted:=0;END;
  END IF;
  UPDATE lts_savings_private_v398.request SET processed_at=clock_timestamp(),error_code=err,accepted_rows=accepted,
   response_md5=CASE WHEN r.content IS NOT NULL THEN md5(r.content) END WHERE request_id=r.request_id;
 END LOOP;
 IF changed>0 THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;END IF;
 RETURN jsonb_build_object('changed_rows',changed);
END $fn$;
REVOKE ALL ON FUNCTION lts_savings_private_v398.collect() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION lts_savings_private_v398.tick()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=''
AS $fn$
DECLARE start_date date;today date:=(clock_timestamp() AT TIME ZONE 'America/Sao_Paulo')::date;request_id bigint;j jsonb;
BEGIN
 j:=lts_savings_private_v398.collect();
 SELECT min(starts_on) INTO start_date FROM public.lts_family_loan_v398 WHERE active;
 IF start_date IS NULL THEN RETURN j;END IF;
 IF EXISTS(SELECT 1 FROM lts_savings_private_v398.request
  WHERE (processed_at IS NULL AND requested_at>clock_timestamp()-interval '10 minutes')
   OR (error_code IS NULL AND accepted_rows>0 AND requested_at AT TIME ZONE 'America/Sao_Paulo'>=today::timestamp))
 THEN RETURN j;END IF;
 request_id:=net.http_get(url:='https://api.bcb.gov.br/dados/serie/bcdata.sgs.195/dados',
  params:=jsonb_build_object('formato','json','dataInicial',to_char(start_date,'DD/MM/YYYY'),'dataFinal',to_char(today,'DD/MM/YYYY')),
  headers:='{"Accept":"application/json"}',timeout_milliseconds:=15000);
 INSERT INTO lts_savings_private_v398.request(request_id) VALUES(request_id);
 RETURN j||jsonb_build_object('request_queued',true);
END $fn$;
REVOKE ALL ON FUNCTION lts_savings_private_v398.tick() FROM PUBLIC,anon,authenticated;
DO $schedule$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='lts_savings_daily_v398') THEN
  PERFORM cron.schedule('lts_savings_daily_v398','12 * * * *','select lts_savings_private_v398.tick()');
 END IF;
END $schedule$;
