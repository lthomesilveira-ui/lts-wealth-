BEGIN;
SET LOCAL statement_timeout='55s';SET LOCAL jit=off;SET LOCAL TimeZone='America/Sao_Paulo';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
DO $probe$
DECLARE j jsonb; days jsonb; r jsonb; c jsonb; cash jsonb; a jsonb; b jsonb; checks integer:=0;
BEGIN
 j:=public.lts_browser_flow_v242('2026-01-01','2027-12-31');
 IF j->>'ok'<>'true' THEN RAISE EXCEPTION 'flow not ready';END IF;
 days:=coalesce(j#>'{flow,historical,days}','[]')||coalesce(j#>'{flow,current_future,days}','[]');
 IF jsonb_array_length(days)<>730 OR (SELECT count(DISTINCT x->>'date') FROM jsonb_array_elements(days)x)<>730
 OR (SELECT min(x->>'date') FROM jsonb_array_elements(days)x)<>'2026-01-01'
 OR (SELECT max(x->>'date') FROM jsonb_array_elements(days)x)<>'2027-12-31'
 THEN RAISE EXCEPTION '2026/2027 daily coverage broken';END IF;
 checks:=checks+1;
 IF (SELECT count(*) FROM jsonb_array_elements(days)x WHERE x->>'date' BETWEEN '2027-01-01' AND '2027-12-31')<>365
 THEN RAISE EXCEPTION '2027 days missing';END IF;
 FOR r IN SELECT x FROM jsonb_array_elements(days)x WHERE x->>'date'>='2027-01-01' LOOP
  c:=r->'fix86_columns';
  IF EXISTS(SELECT 1 FROM unnest(ARRAY['saldo_anterior','entradas','saidas','saldo_final','liq_d0_1','rsus_vested','fgts','saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts'])k WHERE c->>k IS NULL)
  THEN RAISE EXCEPTION 'liquidity column missing on %',r->>'date';END IF;
  IF abs((c->>'saldo_final')::numeric-(c->>'saldo_anterior')::numeric-(c->>'entradas')::numeric+(c->>'saidas')::numeric)>=.005
  THEN RAISE EXCEPTION 'daily cash arithmetic failed on %',r->>'date';END IF;
 END LOOP;
 checks:=checks+1;
 cash:=public.lts_browser_cash_today_v242();
 SELECT x->'fix86_columns' INTO STRICT c FROM jsonb_array_elements(days)x WHERE x->>'date'=current_date::text;
 IF (cash->>'cash') IS NULL OR abs((c->>'saldo_final')::numeric-(cash->>'cash')::numeric)>=.005
 THEN RAISE EXCEPTION 'current Flow/cash position parity failed';END IF;
 checks:=checks+1;
 a:=public.lts_browser_wealth_detail_v242();b:=public.lts_browser_wealth_detail_v242();
 a:=jsonb_set(a,'{current_liquidity}',(a->'current_liquidity')-'computed_at');
 b:=jsonb_set(b,'{current_liquidity}',(b->'current_liquidity')-'computed_at');
 IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'wealth facts changed on consecutive reads';END IF;
 checks:=checks+1;
 PERFORM set_config('lts.v266_product_probe',jsonb_build_object('pass',true,'checks',checks,
 'daily_rows',730,'year_2027_rows',365,'daily_arithmetic',true,'current_cash_parity',true,
 'wealth_facts_equal',true,'excluded_metadata','current_liquidity.computed_at only','mutations','rolled_back')::text,true);
END; $probe$;
SELECT current_setting('lts.v266_product_probe')::jsonb receipt;
ROLLBACK;