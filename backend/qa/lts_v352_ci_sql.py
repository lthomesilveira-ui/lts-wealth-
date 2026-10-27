"""Execute the actual wealth reader and documentary-only activation on synthetic data."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[2]
print(r'''
BEGIN;
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth TO authenticated;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT current_setting('request.jwt.claim.sub',true)::uuid$$;
CREATE FUNCTION public.lts_browser_assert_user_v1()RETURNS uuid LANGUAGE plpgsql STABLE AS $$BEGIN IF auth.uid()IS NULL THEN RAISE EXCEPTION 'authentication required';END IF;RETURN auth.uid();END$$;
CREATE FUNCTION public.lts_card_read_start_v269(uuid)RETURNS text LANGUAGE sql AS $$SELECT 'synthetic-revision'$$;
CREATE FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $3$$;
CREATE FUNCTION public.lts_browser_wealth_detail_v4()RETURNS jsonb LANGUAGE sql AS $$SELECT '{"rsu_summary":{"available_total_brl":3,"future_considered_total_brl":100},"wealth":{"summary":{"assets_central":1000,"net_worth_low":800,"net_worth_central":900,"net_worth_high":1000,"known_debt_total":100,"restricted_contingency":0},"liquidity":{"d0":10},"assets":{"cipo_396":{"market_central":500}},"distribution":[]},"morgan_statement":{"as_of":"2020-01-01","gross_total_brl":103},"current_awards":{"as_of":"2020-01-01","brokerage_available":3},"rsu":{"future_schedule":[{"quantity":34}]},"wealth_v167":{"assets_central_including_pensions":1000,"net_worth_central_including_pensions":900},"financing":{"summary":{"commitments":[]},"documentary":{}},"cipo_detail":{}}'::jsonb$$;
CREATE FUNCTION public.lts_liquidity_adjustments_v242(uuid,date)RETURNS jsonb LANGUAGE sql AS $$SELECT '{"brokerage_settled_withdrawals":0}'::jsonb$$;
CREATE FUNCTION public.lts_browser_cash_today_v242()RETURNS jsonb LANGUAGE sql AS $$SELECT '{"d0":10,"cash":100,"fgts":0,"brokerage_available":3,"available_total":113}'::jsonb$$;
CREATE TABLE public.lts_brokerage_position_snapshots(id uuid,user_id uuid,as_of_date date,total_gross_brl numeric);
INSERT INTO public.lts_brokerage_position_snapshots VALUES('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','2020-01-01',103);
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
''')
print((R/'backend/qa/fixtures/v352_wealth_reader.sql').read_text()+';')
print('CREATE TEMP TABLE before_wealth AS SELECT public.lts_browser_wealth_detail_v242() j;')
print((R/'backend/patches/v352/brokerage_reference.sql').read_text())
print(r'''
DO $$BEGIN IF public.lts_browser_wealth_detail_v242()-'brokerage_reference'IS DISTINCT FROM(SELECT b.j FROM before_wealth b)THEN RAISE EXCEPTION 'Existing financial reader changed';END IF;END$$;
SELECT set_config('lts.v352_owner','00000000-0000-4000-8000-000000000001',true);
''')
manifest={'institution':'Morgan Stanley','received_on':'2020-02-01','position_as_of':None,'total_gross_brl':1000,'available_total_brl':.03,'unavailable_total_brl':999.97,'source_file':'Synthetic.png','source_sha256':'a'*64,'metadata':{'reference_only':True,'position_date_status':'not_visible','quantities':{'regular_rsu_total':34,'regular_rsu_available':0,'cash_rsu_total':8,'cash_rsu_available':0},'available_components':{'long_share_holdings_brl':.02},'unavailable_components':{'regular_rsu_brl':None,'cash_rsu_brl':None}}}
print("SELECT set_config('lts.v352_manifest',$m$"+json.dumps(manifest)+"$m$,true);")
activate=(R/'backend/patches/v352/activate_brokerage_reference.sql').read_text()
print('CREATE TEMP TABLE v352_batch(sql text);INSERT INTO v352_batch VALUES($qa$'+activate+'$qa$);')
print(r'''
CREATE TEMP TABLE v352_cases(name text,mutation text);
INSERT INTO v352_cases VALUES
 ('invented position date',$q$SELECT set_config('lts.v352_manifest',jsonb_set(current_setting('lts.v352_manifest')::jsonb,'{position_as_of}','"2020-02-01"')::text,true)$q$),
 ('invented RSU value',$q$SELECT set_config('lts.v352_manifest',jsonb_set(current_setting('lts.v352_manifest')::jsonb,'{metadata,unavailable_components,regular_rsu_brl}','999.97')::text,true)$q$),
 ('invented Cash RSU value',$q$SELECT set_config('lts.v352_manifest',jsonb_set(current_setting('lts.v352_manifest')::jsonb,'{metadata,unavailable_components,cash_rsu_brl}','0')::text,true)$q$),
 ('wrong total',$q$SELECT set_config('lts.v352_manifest',jsonb_set(current_setting('lts.v352_manifest')::jsonb,'{total_gross_brl}','1001')::text,true)$q$),
 ('wrong owner',$q$SELECT set_config('lts.v352_owner','00000000-0000-4000-8000-000000000002',true)$q$);
DO $test$DECLARE x record;m text;BEGIN FOR x IN SELECT *FROM v352_cases LOOP BEGIN
 EXECUTE x.mutation;m:=NULL;BEGIN EXECUTE(SELECT sql FROM v352_batch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS DISTINCT FROM 'V352_INVALID_DOCUMENTARY_REFERENCE'THEN RAISE EXCEPTION 'Invalid source accepted: % / %',x.name,m;END IF;
 RAISE EXCEPTION USING ERRCODE='V3520',MESSAGE='rollback mutation';EXCEPTION WHEN SQLSTATE 'V3520'THEN NULL;END;END LOOP;END$test$;
''')
print(activate)
print(r'''
DO $test$DECLARE m text;j jsonb;BEGIN
 j:=public.lts_browser_wealth_detail_v242();
 IF j#>'{brokerage_reference,position_as_of}'IS DISTINCT FROM 'null'::jsonb OR j#>>'{brokerage_reference,included_in_current_liquidity}'IS DISTINCT FROM 'false'
 OR j-'brokerage_reference'IS DISTINCT FROM(SELECT b.j FROM before_wealth b)THEN RAISE EXCEPTION 'Reference polluted dated position or liquidity';END IF;
 BEGIN EXECUTE(SELECT sql FROM v352_batch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS DISTINCT FROM 'V352_ALREADY_RECORDED_REVIEW_REQUIRED'THEN RAISE EXCEPTION 'Duplicate reference accepted';END IF;
 IF has_function_privilege('authenticated','public.lts_brokerage_reference_v352(uuid)','EXECUTE')OR has_function_privilege('anon','public.lts_brokerage_reference_v352(uuid)','EXECUTE')OR has_table_privilege('authenticated','public.lts_brokerage_reference_v352','INSERT')THEN RAISE EXCEPTION 'Reference privilege leak';END IF;
END$test$;
SET ROLE authenticated;
DO $$BEGIN IF(SELECT count(*)FROM public.lts_brokerage_reference_v352)<>1 THEN RAISE EXCEPTION 'Owner reference hidden';END IF;END$$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
SET ROLE authenticated;
DO $$BEGIN IF EXISTS(SELECT 1 FROM public.lts_brokerage_reference_v352)THEN RAISE EXCEPTION 'Cross-owner RLS leak';END IF;END$$;
RESET ROLE;
DO $$BEGIN IF public.lts_browser_wealth_detail_v242()->'brokerage_reference'IS DISTINCT FROM 'null'::jsonb THEN RAISE EXCEPTION 'Cross-owner RPC leak';END IF;END$$;
SELECT jsonb_build_object('pass',true,'version',352,'rejection_cases',(SELECT count(*)FROM v352_cases),'dated_position_and_liquidity_preserved',true,'unknown_date_and_components_preserved',true,'cross_owner_rls_and_rpc_isolated',true,'duplicate_rejected',true);
ROLLBACK;
''')
