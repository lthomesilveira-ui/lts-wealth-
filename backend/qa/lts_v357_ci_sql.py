"""Execute source-leased current reader bodies; synthetic owners and debt sources."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[2]
def sql(p):return (R/p).read_text()
print(sql('backend/qa/fixtures/v357_dependencies.sql'))
print(r'''
CREATE TABLE public.qa_debt_sources(user_id uuid PRIMARY KEY,summary jsonb,wealth jsonb);
CREATE FUNCTION public.lts_card_cycles_presentation_v355(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT'{}'::jsonb$$;
CREATE FUNCTION public.lts_card_operating_overlay_v355(jsonb,jsonb,date)RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_product_card_operating_overlay_v355(jsonb,jsonb,date)RETURNS jsonb LANGUAGE sql AS $$SELECT $1$$;
CREATE FUNCTION public.lts_commitments_summary_v1(uuid,date)RETURNS jsonb LANGUAGE sql AS $$SELECT summary||jsonb_build_object('as_of',$2)FROM public.qa_debt_sources WHERE user_id=$1$$;
CREATE FUNCTION public.lts_browser_wealth_detail_v4()RETURNS jsonb LANGUAGE sql AS $$SELECT wealth||jsonb_build_object('financing',jsonb_build_object('summary',public.lts_commitments_summary_v1(user_id,current_date)))FROM public.qa_debt_sources WHERE user_id=public.lts_browser_assert_user_v1()$$;
CREATE FUNCTION public.lts_liquidity_adjustments_v242(uuid,date)RETURNS jsonb LANGUAGE sql AS $$SELECT'{"brokerage_settled_withdrawals":0}'::jsonb$$;
CREATE FUNCTION public.lts_browser_cash_today_v242()RETURNS jsonb LANGUAGE sql AS $$SELECT'{"cash":1000,"d0":200,"fgts":500,"brokerage_available":300,"available_total":1500}'::jsonb$$;
CREATE FUNCTION public.lts_brokerage_reference_v352(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT'{}'::jsonb$$;
''')
for name in ['lts_browser_product_v1','lts_browser_dashboard_cockpit_v1','lts_browser_wealth_detail_v242']:
    print(sql(f'backend/qa/fixtures/v357_{name}_original.sql')+';')
summary=dict(version='commitments-summary-v2-documentary',as_of='2026-10-27',commitments=[
 dict(id='cipo_396',current_documentary_debt_balance=900,current_debt_as_of='2026-09-02',documentary_source_label='Synthetic dated source',remaining_scheduled_outflow_current_terms=130),
 dict(id='volvo',remaining_scheduled_outflow=580,confirmed_paid_installments=2,remaining_events=58),
 dict(id='coopharma',current_documentary_debt_balance=None,remaining_economic_outflow=270),
 dict(id='pai_mae',remaining_scheduled_outflow=50)])
wealth=dict(wealth=dict(reconciliation_version='wealth-summary-current-effective-v240',summary=dict(assets_central=4000,known_debt_total=1000,net_worth_central=3000,net_worth_low=2800,net_worth_high=3200,restricted_contingency=500),
 liquidity=dict(bank_cash=1000,d0=200,d3=300,fgts_contingency=500),distribution=[],
 assets=dict(cipo_396=dict(market_central=2000,documentary_debt=900),volvo_xc40=dict(market_low=400,market_central=500,market_high=600,documented_financed_balance=100,equity_low=300,equity_central=400,equity_high=500,future_schedule_total=580))),
 rsu_summary=dict(available_total_brl=300),wealth_v167=dict(assets_central_including_pensions=4500,net_worth_central_including_pensions=3500),
 cipo_detail={},untouched_history=[dict(category='Original',amount=-15,source_ref='synthetic-row')])
for n in [1,2]:
    s=json.loads(json.dumps(summary))
    if n==2:s['commitments'][0]['current_documentary_debt_balance']=4321
    print(f"INSERT INTO public.qa_debt_sources VALUES('00000000-0000-4000-8000-{n:012d}',$fixture${json.dumps(s)}$fixture$,$fixture${json.dumps(wealth)}$fixture$);")
print(r'''
INSERT INTO public.lts_product_read_cache
SELECT user_id,'lts-product-fix86-v36',jsonb_build_object('wealth_executive',wealth->'wealth','untouched_history',wealth->'untouched_history',
'updates',jsonb_build_object('freshness',jsonb_build_object('today',current_date),'document_change_summary_version','document-change-summary-v1'),
'dashboard_cockpit',jsonb_build_object('wealth',wealth#>'{wealth,summary}','cards','{}'::jsonb,'work','{}'::jsonb)),
current_date::timestamptz,'synthetic'FROM public.qa_debt_sources;
INSERT INTO public.lts_dashboard_cockpit_cache SELECT user_id,current_date,refreshed_at,payload->'dashboard_cockpit'FROM public.lts_product_read_cache;
SELECT set_config('lts.qa_owner','00000000-0000-4000-8000-000000000001',true);
CREATE TEMP TABLE v357_before(kind text,j jsonb);
INSERT INTO v357_before VALUES('product',public.lts_browser_product_v1()),('cockpit',public.lts_browser_dashboard_cockpit_v1()),('wealth',public.lts_browser_wealth_detail_v242()),('source',(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id)FROM public.qa_debt_sources x));
''')
print(sql('backend/patches/v357/dated_debt_projection.sql'))
patch=sql('backend/patches/v357/readers.sql');print(patch)
print("CREATE TEMP TABLE v357_patch(sql text);INSERT INTO v357_patch VALUES($fixture$"+patch+"$fixture$);")
print(r'''
CREATE TEMP TABLE v357_after(kind text,j jsonb);
INSERT INTO v357_after VALUES('product',public.lts_browser_product_v1()),('cockpit',public.lts_browser_dashboard_cockpit_v1()),('wealth',public.lts_browser_wealth_detail_v242());
DO $test$DECLARE p jsonb;c jsonb;w jsonb;m text;BEGIN
 SELECT j->'mvp'INTO p FROM v357_after WHERE kind='product';SELECT j INTO c FROM v357_after WHERE kind='cockpit';SELECT j INTO w FROM v357_after WHERE kind='wealth';
 IF p#>'{wealth_executive,debt_coverage}'IS DISTINCT FROM w#>'{wealth,debt_coverage}'
 OR c#>'{wealth,debt_coverage}'IS DISTINCT FROM w#>'{wealth,debt_coverage}'
 OR p#>'{dashboard_cockpit,wealth,debt_coverage}'IS DISTINCT FROM w#>'{wealth,debt_coverage}'
 OR w#>>'{wealth,debt_coverage,documented_count}'<>'1'
 OR w#>>'{wealth,debt_coverage,missing_count}'<>'3'
 OR w#>>'{wealth,summary,known_debt_total}'<>'900'
 OR p#>>'{wealth_executive,summary,net_worth_central}'IS NOT NULL
 OR c#>>'{wealth,net_worth_central}'IS NOT NULL
 OR w#>>'{wealth_v167,net_worth_central_including_pensions}'IS NOT NULL
 OR w#>>'{wealth,assets,volvo_xc40,equity_central}'IS NOT NULL
 OR w#>>'{wealth,assets,volvo_xc40,documented_financed_balance}'<>'100'
 OR w#>>'{wealth,assets,volvo_xc40,future_schedule_total}'<>'580'
 THEN RAISE EXCEPTION 'Current consumers disagree, initial debt reused, or unknown balance turned zero';END IF;
 IF(SELECT j FROM v357_before WHERE kind='source')IS DISTINCT FROM(SELECT jsonb_agg(to_jsonb(x)ORDER BY user_id)FROM public.qa_debt_sources x)
 THEN RAISE EXCEPTION 'Debt source changed';END IF;
 PERFORM set_config('lts.qa_owner','00000000-0000-4000-8000-000000000002',true);
 IF public.lts_browser_product_v1()#>>'{mvp,wealth_executive,summary,known_debt_total}'<>'4321'
 OR public.lts_browser_wealth_detail_v242()#>>'{wealth,summary,known_debt_total}'<>'4321'
 OR public.lts_browser_dashboard_cockpit_v1()#>>'{wealth,known_debt_total}'<>'4321'
 THEN RAISE EXCEPTION 'Owners not isolated';END IF;
 PERFORM set_config('lts.qa_owner','00000000-0000-4000-8000-000000000001',true);
 BEGIN EXECUTE(SELECT sql FROM v357_patch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m NOT LIKE'V357_SOURCE_CHANGED:%'THEN RAISE EXCEPTION 'Replay lease failed';END IF;
 EXECUTE'SET LOCAL ROLE authenticated';
 BEGIN PERFORM public.lts_debt_evidence_read_v357('00000000-0000-4000-8000-000000000002',current_date);RAISE EXCEPTION 'Helper exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 EXECUTE'RESET ROLE';
END $test$;
CREATE TEMP TABLE v357_complete(j jsonb);
INSERT INTO v357_complete SELECT s||jsonb_build_object('commitments',(SELECT jsonb_agg(c||jsonb_build_object('current_documentary_debt_balance',0,'current_debt_as_of',current_date))FROM jsonb_array_elements(s->'commitments')c))FROM(SELECT public.lts_commitments_summary_v1('00000000-0000-4000-8000-000000000001',current_date)s)x;
CREATE TEMP TABLE v357_cases(name text,path text[],value jsonb);
INSERT INTO v357_cases VALUES('source version','{version}','"wrong"'),('source date','{as_of}','"2020-01-01"'),('missing source array','{commitments}','null'),
('missing amount','{commitments,0,current_documentary_debt_balance}','null'),('typed string amount','{commitments,0,current_documentary_debt_balance}','"900"'),
('negative amount','{commitments,0,current_documentary_debt_balance}','-1'),('not a number','{commitments,0,current_documentary_debt_balance}','"NaN"'),
('missing date','{commitments,0,current_debt_as_of}','null'),('invalid date','{commitments,0,current_debt_as_of}','"2026-02-30"'),
('future date','{commitments,0,current_debt_as_of}',to_jsonb((current_date+1)::text));
DO $test$DECLARE b jsonb;v jsonb;r record;BEGIN
 SELECT j INTO b FROM v357_complete;
 v:=public.lts_debt_evidence_projection_v357(b,current_date);
 IF v->>'complete'<>'true'OR v->>'documented_count'<>'4'OR v->>'total_debt'<>'0' THEN RAISE EXCEPTION 'Documented zero not accepted';END IF;
 FOR r IN SELECT*FROM v357_cases LOOP
  v:=public.lts_debt_evidence_projection_v357(jsonb_set(b,r.path,r.value,true),current_date);
  IF v->>'complete'<>'false'OR v->>'total_debt'IS NOT NULL THEN RAISE EXCEPTION 'Invalid evidence accepted: %',r.name;END IF;
 END LOOP;
 v:=public.lts_debt_evidence_projection_v357(jsonb_set(b,'{commitments}',(b->'commitments')||jsonb_build_array(b#>'{commitments,0}')),current_date);
 IF v->>'complete'<>'false'OR v#>>'{positions,0,status}'<>'ambiguous_commitment'THEN RAISE EXCEPTION 'Duplicate accepted';END IF;
 v:=public.lts_debt_evidence_projection_v357(jsonb_set(b,'{commitments}',(b->'commitments')||'[{"id":"additional_contract"}]'::jsonb),current_date);
 IF v->>'complete'<>'false'OR v->>'additional_unmodelled_commitments'<>'1'THEN RAISE EXCEPTION 'Additional liability ignored';END IF;
END $test$;
SELECT jsonb_build_object('pass',true,'version',357,'invalid_evidence_cases',(SELECT count(*)+2 FROM v357_cases),'owner_isolation',true,'private_helpers',true,'source_preserved',true,
'before_readers',(SELECT jsonb_object_agg(kind,j)FROM v357_before WHERE kind<>'source'),
'after_readers',(SELECT jsonb_object_agg(kind,j)FROM v357_after));
ROLLBACK;
''')
