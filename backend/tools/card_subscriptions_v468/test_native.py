"""Isolated PostgreSQL tests with invented data; psql must be available."""
from pathlib import Path
import json,subprocess
p=Path(__file__).resolve().parent
def sql(s):
 r=subprocess.run(['psql','-X','-q','-v','ON_ERROR_STOP=1','-A','-t'],input=s,text=True,capture_output=True)
 if r.returncode: raise RuntimeError(r.stderr)
 return r.stdout.strip()
def lit(o): return "'"+json.dumps(o,ensure_ascii=False).replace("'","''")+"'::jsonb"
sql("""CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE TABLE public.legacy_namespace(usuario_id uuid,chave text,valor_bruto text,sha256 text,PRIMARY KEY(usuario_id,chave));
CREATE SCHEMA lts_projection_private_v412;
CREATE FUNCTION public.lts_bank_merchant_key_v231(text) RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT regexp_replace(lower($1),'[^a-z0-9]','','g') $f$;
CREATE FUNCTION public.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT CASE WHEN $2='C6' THEN 'c6' WHEN $2='Itaú' THEN 'itau_mastercard' ELSE 'other' END $f$;
CREATE FUNCTION public.lts_card_projection_date_v370(uuid,text,date,date,date) RETURNS date LANGUAGE sql STABLE AS $f$ SELECT $4 $f$;
CREATE FUNCTION public.lts_card_cycles_v226(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $f$ SELECT '{"cards":[]}'::jsonb $f$;
""")
sql((p/'build-before.sql').read_text())
sql("REVOKE ALL ON FUNCTION lts_projection_private_v412.build(uuid,date) FROM PUBLIC;GRANT EXECUTE ON FUNCTION lts_projection_private_v412.build(uuid,date) TO service_role;")
acl_before=sql("SELECT proacl::text FROM pg_proc WHERE oid='lts_projection_private_v412.build(uuid,date)'::regprocedure;")
sql((p/'install.sql').read_text())
assert sql("SELECT proacl::text FROM pg_proc WHERE oid='lts_projection_private_v412.build(uuid,date)'::regprocedure;")==acl_before
assert sql("SELECT md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure));")==json.loads((p/'manifest.json').read_text())['installed_build_md5']
U='10000000-0000-4000-8000-000000000001'
V='20000000-0000-4000-8000-000000000002'
def rule(i='music',amount='12.34',**extra):
 return {'id':i,'description':'Music service','family':'itau_mastercard','account':'Itaú','last4':'4567','amount_brl':amount,'cadence_months':1,'due_day':16,'anchor_cash_month':'2026-12-01','active':True,'amount_selector':'merchant','merchant_keys':['musicservice'],'evidence_ref':'synthetic-owner-approval',**extra}
def plan(rs=None,owner=U):return {'schema':'owner-card-subscriptions-v1','owner_id':owner,'approved_on':'2026-11-17','owner_evidence_ref':'synthetic-owner-approval','rules':rs or [rule()]}
def period(m='2026-12-01',due='2026-12-16',**extra):
 return {'family':'itau_mastercard','cash_month':m,'due_date':due,'trusted':True,'authoritative':False,'items':[],**extra}
def charge(amount='12.34',**extra):
 return {'merchant_key':'musicservice','last4':'4567','amount':amount,'source_id':'synthetic-charge-one','is_payment':False,**extra}
def calc(pl,cal,asof='2026-11-17',end='2027-12-31'):
 return json.loads(sql("SELECT lts_subscription_private_v468.calculate("+lit(pl)+","+lit(cal)+",'"+asof+"'::date,'"+end+"'::date);"))
def reject(pl,cal):
 try:calc(pl,cal)
 except RuntimeError:return
 raise AssertionError('invalid source accepted')
passed=[]
def ok(name):passed.append(name)
x=calc(plan(),[period()]);assert len(x['events'])==1 and x['events'][0]['signed_amount']==-12.34;ok('specific_future_cash_event')
x=calc(plan(),[period(items=[charge()])]);assert not x['events'] and x['series'][0]['preserved_occurrences']==1;ok('already_in_invoice_not_added_again')
x=calc(plan(),[period(items=[charge(),charge('-12.34',source_id='synthetic-refund')])]);assert not x['events'];ok('refund_not_refilled')
x=calc(plan(),[period(authoritative=True)]);assert not x['events'];ok('final_invoice_has_precedence')
x=calc(plan(),[period(items=[charge('17.34')])]);assert not x['events'];ok('known_new_price_kept')
x=calc(plan(),[period(trusted=False)]);assert not x['events'] and x['series'][0]['annual_totals'][0]['budget_total_brl'] is None and x['warnings'];ok('incomplete_is_not_zero')
x=calc(plan(),[period(items=[charge(last4='9999')])]);assert not x['events'] and x['warnings'];ok('different_card_not_silently_assigned')
x=calc(plan(),[period(items=[charge(),charge(source_id='synthetic-charge-two')])]);assert not x['events'] and x['warnings'];ok('ambiguous_charge_count')
reject(plan(),[period(),period()]);ok('duplicate_cash_period_rejected')
reject(plan([rule(),rule('music_other')] ),[period()]);ok('overlapping_rules_rejected')
reject(plan([rule(amount='-2')]),[period()]);ok('invalid_amount_rejected')
reject(plan([rule(cadence_months=2)]),[period()]);ok('unapproved_cadence_rejected')
x=calc(plan([rule(active=False)]),[period()]);assert not x['events'];ok('disabled_not_generated')
x=calc(plan([rule(ends_on='2026-12-31')]),[period(),period('2027-01-01','2027-01-16')]);assert len(x['events'])==1;ok('explicit_end_date')
x=calc(plan([rule(cadence_months=12)]),[period(),period('2027-01-01','2027-01-16'),period('2027-12-01','2027-12-16')]);assert len(x['events'])==2;ok('annual_not_monthly')
x=calc(plan(),[period('2026-11-01','2026-11-16'),period()],asof='2026-12-16');assert not x['events'];ok('no_past_or_today_forecast')
apple=[rule('device_a','7.25',merchant_keys=['devicebill'],amount_selector='exact_amount'),rule('device_b','9.75',merchant_keys=['devicebill'],amount_selector='exact_amount')]
x=calc(plan(apple),[period(items=[charge('7.25',merchant_key='devicebill')])]);assert len(x['events'])==1 and x['events'][0]['signed_amount']==-9.75;ok('separate_merchant_services_counted_once')
x=calc(plan(apple),[period(items=[charge('8.25',merchant_key='devicebill')])]);assert not x['events'] and len(x['warnings'])==2;ok('unknown_device_price_not_added_to_existing_charge')
base={'version':'projection-policy-v412','schema_version':1,'enabled':True,'as_of':'2026-11-17','horizon_end':'2031-12-31','next_review_on':'2027-01-01','history_window':{'from':'2025-01-01','to':'2025-12-31'},'series':[],'warnings':[],'events':[{'source_ref':'original-obligation','signed_amount':-44.21}],'replacement_refs':['original-source'],'card_method':'total_budget_floor','outliers_excluded':False,'missing_months_assumed_zero':False,'financial_sources_modified':False}
sql("INSERT INTO public.legacy_namespace SELECT '"+U+"','lts_owner_card_subscriptions_v468',"+lit(plan())+"::text,encode(sha256(convert_to("+lit(plan())+"::text,'UTF8')),'hex');")
x=json.loads(sql("SELECT lts_subscription_private_v468.append_result('"+V+"','2026-11-17',"+lit(base)+",NULL,'[]');"));assert x==base;ok('other_owner_result_exactly_preserved')
cards={'complete':True,'cards':[{'family':'itau_mastercard','complete':True,'cycles':[]}]}
x=json.loads(sql("SELECT lts_subscription_private_v468.append_result('"+U+"','2026-11-17',"+lit(base)+","+lit(cards)+",'[]');"))
assert x['events'][0]==base['events'][0] and x['replacement_refs']==base['replacement_refs']
assert len(x['events'])==62 and x['financial_sources_modified'] is False
(p.parents[2]/'v468-synthetic-model.json').write_text(json.dumps(x))
ok('adapter_preserves_original_obligation_and_all_base_fields')
badbase=[{'event_date':'2026-12-16','description':'Known card invoice','account':'Itaú','signed_amount':-44.21}]
x=json.loads(sql("SELECT lts_subscription_private_v468.append_result('"+U+"','2026-11-17',"+lit(base)+","+lit(cards)+","+lit(badbase)+");"))
assert x['series'][0]['unresolved_periods']==1 and x['warnings'];ok('unitemized_existing_obligation_not_refilled')
sql("UPDATE public.legacy_namespace SET sha256='not-the-stored-digest';")
try:sql("SELECT lts_subscription_private_v468.owner_plan('"+U+"');")
except RuntimeError:pass
else:raise AssertionError('bad plan digest accepted')
ok('stored_plan_digest_required')
for role in ['anon','authenticated','service_role']:
 assert sql("SELECT has_schema_privilege('"+role+"','lts_subscription_private_v468','USAGE');")=='f'
 assert sql("SELECT has_function_privilege('"+role+"','lts_subscription_private_v468.validate_plan(jsonb)','EXECUTE');")=='f'
ok('no_new_public_or_service_permissions')
print(json.dumps({'pass':True,'cases':passed,'case_count':len(passed),'private_user_data':False,'financial_source_writes':0}))

