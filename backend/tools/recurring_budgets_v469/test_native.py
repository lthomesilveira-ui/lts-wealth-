from pathlib import Path
import runpy,json,subprocess
p=Path(__file__).resolve().parent
prior=runpy.run_path(str(p.parent/'card_subscriptions_v468/test_native.py'))
sql=prior['sql'];lit=prior['lit']
sql("""CREATE TABLE public.lts_v178_review_decision(user_id uuid,source_table text,source_ref text,category_label text,beneficiary text);
CREATE TABLE public.lts_open_finance_staging(user_id uuid,resource_type text,currency text,provider_deleted_at timestamptz,normalized_payload jsonb,posting_date date,description_raw text,signed_amount numeric);
CREATE FUNCTION public.lts_v178_norm(text)RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT translate(lower($1),'áàâãéêíóôõúç','aaaaeeiooouc') $f$;
""")
sql((p/'classifier-before.sql').read_text())
before_acl=sql("SELECT proacl::text FROM pg_proc WHERE oid='lts_projection_private_v412.build(uuid,date)'::regprocedure")
sql((p/'install.sql').read_text())
manifest=json.loads((p/'manifest.json').read_text())
assert sql("SELECT md5(pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure))")==manifest['installed_build_md5']
assert sql("SELECT md5(pg_get_functiondef('public.lts_flow_classification_decision_v1(uuid,jsonb)'::regprocedure))")==manifest['installed_classifier_md5']
assert sql("SELECT proacl::text FROM pg_proc WHERE oid='lts_projection_private_v412.build(uuid,date)'::regprocedure")==before_acl
U='30000000-0000-4000-8000-000000000003'
budgets=[{'id':k,'description':'Synthetic recurring '+k,'amount_brl':v,'coverage_months':12,'reference_window':{'from':'2025-01-01','to':'2025-12-31'}} for k,v in [('pharmacy','45.67'),('hair','23.45'),('membership','8.90'),('prime_2990','4.56')]]
plan={'schema':'specific-recurring-plan-v469','owner_id':U,'centralize_card_forecasts':True,'school_start_month':'2026-11-01','budget_start_month':'2026-12-01','budgets':budgets,'school_sources':[{'event_date':'2026-11-30','source_ref':'old-school-one'}],'school_food_brl':'222.22','school_tuition_brl':'1111.11','school_total_brl':'1333.33','school_food_day':28,'school_food_description':'Synthetic school meals','school_tuition_description':'Synthetic school tuition','school_original_description':'Synthetic original school','school_category':'Educação','school_beneficiary':None,'school_account':'Itaú','school_tuition_match':'%SCHOOL BILL%','school_food_match':'%MEALS BILL%','school_known_food_amounts':['222.22']}
base={'enabled':True,'as_of':'2026-11-17','horizon_end':'2027-02-28','events':[{'source_ref':'unrelated-obligation','signed_amount':-17.21},{'source_ref':'projection:v468:spotify:2026-12-16','event_date':'2026-12-16','signed_amount':-12.34,'source':'planning_projection_v412','account':'Itaú'}],'series':[],'warnings':[],'replacement_refs':['unrelated-replacement']}
cal=[{'id':r['id'],'cash_month':m,'known_brl':0,'trusted':True} for r in budgets for m in ['2026-12-01','2027-01-01','2027-02-01']]
def calc(pl=plan,ba=base,ca=None,paid=[],day='2026-11-17'):
 return json.loads(sql('SELECT lts_recurring_private_v469.calculate('+','.join([lit(pl),lit(ba),lit(ca or cal),lit(paid),"'"+day+"'::date"])+');'))
def rows(x,k):return [e for e in x['events'] if e.get('source_ref','').startswith('projection:v469:'+k+':')]
cases=[]
def ok(n):cases.append(n)
x=calc();assert x['events'][0]==base['events'][0];ok('unrelated_original_event_unchanged')
assert rows(x,'sub_spotify')[0]['account']=='Bradesco' and rows(x,'sub_spotify')[0]['event_date']=='2026-12-03';ok('unreceived_subscription_moved_to_target_card')
assert rows(x,'school_food')[0]['event_date']=='2026-11-28' and rows(x,'school_tuition')[0]['event_date']=='2026-12-03';ok('food_this_month_tuition_next_month')
assert rows(x,'school_tuition')[1]['event_date']=='2027-01-06';ok('new_year_holiday_and_weekend_excluded')
assert 'old-school-one' in x['replacement_refs'] and 'unrelated-replacement' in x['replacement_refs'];ok('original_total_replaced_once')
assert len(rows(x,'school_tuition'))==3;ok('school_horizon_not_overrun')
ca=json.loads(json.dumps(cal));ca[0]['known_brl']=30
x=calc(ca=ca);assert rows(x,'pharmacy')[0]['signed_amount']==-15.67;ok('known_pharmacy_installments_subtracted')
ca[0]['known_brl']=100;x=calc(ca=ca);assert len(rows(x,'pharmacy'))==2;ok('known_expense_above_budget_not_reduced')
ca[0]['known_brl']=-10;x=calc(ca=ca);assert rows(x,'pharmacy')[0]['signed_amount']==-45.67;ok('credit_does_not_refill_budget')
ca[0]['trusted']=False;x=calc(ca=ca);assert len(rows(x,'pharmacy'))==2 and x['warnings'];ok('unavailable_coverage_not_zero')
x=calc(paid=[{'id':'school_food','cash_month':'2026-11-01'}]);assert len(rows(x,'school_food'))==3;ok('early_meals_payment_not_repeated')
x=calc(paid=[{'id':'school_tuition','cash_month':'2026-12-01'}]);assert len(rows(x,'school_tuition'))==2;ok('early_tuition_payment_not_repeated')
assert not any('decolar' in e.get('source_ref','') or 'pet' in e.get('source_ref','') or 'therapy' in e.get('source_ref','') for e in x['events']);ok('unapproved_or_ended_spending_not_created')
ca=json.loads(json.dumps(cal));next(v for v in ca if v['id']=='membership' and v['cash_month']=='2026-12-01')['known_brl']='8.90'
x=calc(ca=ca);assert len(rows(x,'membership'))==2;ok('membership_continues_after_known_installments')
try:calc(ca=cal+[cal[0]])
except RuntimeError:pass
else:raise AssertionError('duplicate period accepted')
ok('duplicate_month_rejected')
sql("INSERT INTO public.legacy_namespace VALUES('"+U+"','lts_owner_recurring_plan_v469',"+lit(plan)+"::text,encode(sha256(convert_to("+lit(plan)+"::text,'UTF8')),'hex'));")
cards={'complete':True,'cards':[{'family':'itau_mastercard','cycles':[{'due_date':'2026-12-16','amount':30,'items':[{'description':'Synthetic drug store','category':'Farmácia','amount':30,'source_id':'synthetic-item'}]}]}]}
baseline=[{'event_date':'2026-11-30','source_ref':'old-school-one','account':'Itaú','description':'Synthetic original school','signed_amount':-1333.33},{'event_date':'2026-12-16','source_ref':'synthetic-card-invoice','account':'Itaú','description':'Synthetic Mastercard invoice','signed_amount':-30}]
def append(b=baseline):return json.loads(sql("SELECT lts_recurring_private_v469.append_result('"+U+"','2026-11-17',"+lit(base)+","+lit(cards)+","+lit(b)+");"))
x=append();assert rows(x,'pharmacy')[0]['signed_amount']==-15.67;ok('real_sql_adapter_uses_itemized_known_card_amount')
try:append(b=baseline[1:])
except RuntimeError:pass
else:raise AssertionError('changed school source overwritten')
ok('changed_school_schedule_guard')
e=rows(x,'pharmacy')[0];c=json.loads(sql("SELECT public.lts_flow_classification_decision_v1('"+U+"',"+lit(e)+");"));assert c['category']=='Farmácia' and c['signed_amount']==e['signed_amount'];ok('new_forecasts_have_categories_without_fake_purchases')
e={'source':'other','source_ref':'other','signed_amount':-5};assert json.loads(sql("SELECT public.lts_flow_classification_decision_v1('"+U+"',"+lit(e)+");"))==e;ok('old_classification_path_exactly_preserved')
for role in ['anon','authenticated','service_role']:
 assert sql("SELECT has_schema_privilege('"+role+"','lts_recurring_private_v469','USAGE')")=='f'
ok('no_new_public_role_grants')
print(json.dumps({'pass':True,'case_count':len(cases),'cases':cases,'invented_data_only':True,'financial_source_writes':0}))
