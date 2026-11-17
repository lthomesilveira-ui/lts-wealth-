from pathlib import Path
import runpy,json
p=Path(__file__).resolve().parent
prior=runpy.run_path(str(p.parent/'recurring_budgets_v469/test_native.py'))
sql=prior['sql'];lit=prior['lit'];U=prior['U'];base=prior['base'];oldplan=prior['plan'];cards=prior['cards'];baseline=prior['baseline']
before=sql("SELECT proacl::text FROM pg_proc WHERE oid='lts_projection_private_v412.build(uuid,date)'::regprocedure")
sql((p/'install.sql').read_text())
manifest=json.loads((p/'manifest.json').read_text())
assert sql("SELECT md5(pg_get_functiondef('lts_recurring_private_v469.append_result(uuid,date,jsonb,jsonb,jsonb)'::regprocedure))")==manifest['adapter_after_md5']
assert sql("SELECT proacl::text FROM pg_proc WHERE oid='lts_projection_private_v412.build(uuid,date)'::regprocedure")==before
plan={'schema':'owner-budgets-v470','owner_id':U,'starts_on':'2026-12-01','budgets':[
 {'id':'owner_food','description':'Synthetic food budget','category':'Meals','categories':['Meals'],'amount_brl':'51.23'},
 {'id':'owner_clothing','description':'Synthetic clothing budget','category':'Clothing','categories':['Clothing','Child Clothing'],'amount_brl':'81.23'},
 {'id':'owner_legacy','description':'Synthetic direct commitment','category':'Insurance','source_refs':['known-direct'],'amount_brl':'13.45'}],
 'suppressions':[{'source_ref':'remove-future','event_date':'2026-12-01','description':'Synthetic cancelled class','account':'Itaú','signed_amount':-67.89}]}
ba={'as_of':'2026-11-17','horizon_end':'2027-02-28','events':[{'source_ref':'unrelated','signed_amount':-9.87}],'replacement_refs':[],'series':[],'warnings':[]}
cal=[{'id':r['id'],'cash_month':m,'known_brl':0,'trusted':True}for r in plan['budgets']for m in ['2026-12-01','2027-01-01','2027-02-01']]
def calc(pl=plan,ca=None):return json.loads(sql('SELECT lts_budget_private_v470.calculate('+','.join([lit(pl),lit(ba),lit(cal if ca is None else ca),"'2026-11-17'::date"])+');'))
def rows(x,k):return [e for e in x['events']if e.get('source_ref','').startswith('projection:v469:'+k+':')]
cases=[]
def ok(n):cases.append(n)
x=calc();assert len(x['events'])==10 and x['events'][0]==ba['events'][0];ok('unrelated_forecasts_retained')
assert all(e['account']=='Bradesco' and e['event_date'].endswith('-03')for e in x['events'][1:]);ok('owner_provisions_use_one_card_cash_date')
ca=json.loads(json.dumps(cal));ca[0]['known_brl']=40;x=calc(ca=ca);assert rows(x,'owner_food')[0]['signed_amount']==-11.23;ok('only_remainder_added')
ca[0]['known_brl']=80;x=calc(ca=ca);assert len(rows(x,'owner_food'))==2;ok('known_above_budget_preserved')
ca[0]['known_brl']=-40;x=calc(ca=ca);assert rows(x,'owner_food')[0]['signed_amount']==-51.23;ok('refund_not_new_budget')
ca[0]['trusted']=False;x=calc(ca=ca);assert len(rows(x,'owner_food'))==2 and x['warnings'];ok('missing_coverage_not_zero')
assert 'remove-future'in x['replacement_refs'];ok('future_class_suppressed_without_deleting_source')
try:calc(ca=cal+[cal[0]])
except RuntimeError:pass
else:raise AssertionError('duplicate calendar allowed')
ok('duplicate_period_rejected')
raw=lit(plan)+'::text';sql("INSERT INTO public.legacy_namespace VALUES('"+U+"','lts_owner_budgets_v470',"+raw+",encode(sha256(convert_to("+raw+",'UTF8')),'hex'));")
cs={'complete':True,'cards':[{'family':'itau_mastercard','cycles':[{'due_date':'2026-12-16','amount':150,'items':[
 {'description':'Synthetic food','category':'Meals','amount':30,'source_id':'one'},
 {'description':'Synthetic child clothing','category':'Child Clothing','amount':120,'source_id':'two'},
 {'description':'Synthetic refund','category':'Meals','amount':-5,'source_id':'refund'}]}]}]}
bl=baseline[:1]+[{'source_ref':'invoice','event_date':'2026-12-16','account':'Itaú','description':'Synthetic Mastercard invoice','signed_amount':-150},
 {'source_ref':'known-direct','event_date':'2026-12-20','account':'Itaú','description':'Synthetic direct insurance','signed_amount':-13.45},plan['suppressions'][0],
 {'source_ref':'positive-return','event_date':'2026-12-20','account':'Itaú','description':'Synthetic refund','signed_amount':99}]
def append(c=cs,b=bl):return json.loads(sql("SELECT lts_recurring_private_v469.append_result('"+U+"','2026-11-17',"+lit(base)+","+lit(c)+","+lit(b)+");"))
x=append();assert rows(x,'owner_food')[0]['signed_amount']==-21.23;ok('native_card_amount_subtracted_once')
assert len(rows(x,'owner_clothing'))==2;ok('family_clothing_existing_installments_not_duplicated')
assert len(rows(x,'owner_legacy'))==2;ok('direct_cash_commitment_subtracted')
try:append(b=bl[:-2]+bl[-1:])
except RuntimeError:pass
else:raise AssertionError('changed cancellation source allowed')
ok('cancellation_source_guard')
c=json.loads(json.dumps(cs));c['complete']=False;x=append(c=c);assert not rows(x,'owner_food');ok('incomplete_card_source_not_zero')
c=json.loads(json.dumps(cs));c['cards'][0]['cycles'][0]['amount']=155;x=append(c=c);assert len(rows(x,'owner_food'))==2;ok('invoice_coverage_mismatch_warns')
x=append();e=rows(x,'owner_food')[0];y=json.loads(sql("SELECT public.lts_flow_classification_decision_v1('"+U+"',"+lit(e)+");"));assert y['category']=='Meals'and y['signed_amount']==e['signed_amount'];ok('new_owner_forecasts_classified')
assert not any('unapproved'in e.get('source_ref','')for e in x['events']);ok('no_unrequested_series')
for role in ['anon','authenticated','service_role']:assert sql("SELECT has_schema_privilege('"+role+"','lts_budget_private_v470','USAGE')")=='f'
ok('private_schema_roles_unchanged')
print(json.dumps({'pass':True,'case_count':len(cases),'cases':cases,'invented_data_only':True,'financial_source_writes':0}))
