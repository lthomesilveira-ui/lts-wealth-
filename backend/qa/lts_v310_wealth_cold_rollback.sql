-- Real native reader, existing authenticated role, private memos cold.
-- Only memo metadata changes, all rolled back. No financial source DML.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL statement_timeout='8s';
SET LOCAL lock_timeout='2s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text
 FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
UPDATE public.lts_v229_read_cache SET source_fingerprint='v310-cold-rollback',refreshed_at='2000-01-01'
 WHERE user_id=public.lts_open_finance_pilot_owner_v1();
SET LOCAL ROLE authenticated;
DO $cold$ DECLARE t timestamptz:=clock_timestamp();j jsonb;ms numeric;BEGIN
 j:=public.lts_browser_wealth_detail_v242();ms:=1000*extract(epoch FROM(clock_timestamp()-t));
 PERFORM set_config('lts.v310.cold_payload',j::text,true);
 PERFORM set_config('lts.v310.cold_ms',ms::text,true);
END $cold$;
DO $warm$ DECLARE t timestamptz:=clock_timestamp();j jsonb;b jsonb;ms numeric;BEGIN
 j:=public.lts_browser_wealth_detail_v242();ms:=1000*extract(epoch FROM(clock_timestamp()-t));
 b:=current_setting('lts.v310.cold_payload')::jsonb;
 IF (j#-'{current_liquidity,computed_at}') IS DISTINCT FROM(b#-'{current_liquidity,computed_at}')
 THEN RAISE EXCEPTION 'Wealth financial payload differs between cold and repeat';END IF;
 PERFORM set_config('lts.v310.receipt',jsonb_build_object('status','PASS','role','authenticated',
  'cold_ms',current_setting('lts.v310.cold_ms')::numeric,'repeat_ms',ms,
  'private_memos_cold',true,'per_call_timeout','8s','complete_financial_payload_equal',true,
  'checksum_excluding_computed_at',md5((j#-'{current_liquidity,computed_at}')::text),
  'source_dml',false,'transaction','ROLLBACK','verified_at',clock_timestamp())::text,true);
END $warm$;
RESET ROLE;
SELECT current_setting('lts.v310.receipt')::jsonb receipt;
ROLLBACK;
