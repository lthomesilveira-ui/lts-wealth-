BEGIN;
SET LOCAL statement_timeout='55s';
SET LOCAL jit=off;
SET LOCAL TimeZone='America/Sao_Paulo';
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
DO $probe$
DECLARE t timestamptz; first_ms numeric; repeat_ms numeric; j jsonb; k jsonb;
BEGIN
 t:=clock_timestamp(); j:=public.lts_browser_wealth_detail_v242(); first_ms:=extract(epoch FROM clock_timestamp()-t)*1000;
 t:=clock_timestamp(); k:=public.lts_browser_wealth_detail_v242(); repeat_ms:=extract(epoch FROM clock_timestamp()-t)*1000;
 PERFORM set_config('lts.v266_performance',jsonb_build_object('reader','wealth',
 'cold_ms',round(first_ms,1),'repeat_ms',round(repeat_ms,1),
 'same_response',j=k,'keys',(SELECT jsonb_agg(x) FROM jsonb_object_keys(j)x),
 'row_count',CASE WHEN jsonb_typeof(j->'rows')='array' THEN jsonb_array_length(j->'rows') END,
 'source_mutations','none','cache_mutations','rolled_back')::text,true);
END; $probe$;
SELECT current_setting('lts.v266_performance')::jsonb receipt;
ROLLBACK;
