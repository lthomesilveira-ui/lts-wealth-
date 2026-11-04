"""Construct expectations from explicit reviewed decisions, never from either resolver."""
import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).parent
VERSION = 'temporal_date_overlay_pg17_v1'
KEYS = ('owner','institution','account','bill_id')

def k(b): return {f:b[f] for f in KEYS}
def save(name, data): (ROOT/name).write_text(json.dumps(data,indent=2,ensure_ascii=True)+'\n')
base = json.loads((ROOT/'baseline-28.json').read_text())
inputs, expected, catalog = [], [], []

def add(name, p, codes, overlays=None, findings=(), batch='valid', origin='regression'):
    p = deepcopy(p); overlays = overlays or {}
    rows = deepcopy(p.get('obligations',[])); decisions=[]
    if batch == 'valid':
        assert len(codes)==len(rows)
        for i,(o,code) in enumerate(zip(rows,codes)):
            old=p['obligations'][i]
            if code=='overlay_applied':
                b=p['bills'][overlays[i]]
                o.update(due=b['due'],provenance='issuer_invoice',source_updated=b['source_updated'],bill_key=k(b),due_basis='issuer_exact_cycle')
            decisions.append(dict(event_id=old['event_id'],code=code,changed_due=o.get('due')!=old.get('due')))
    fs=[]
    for target,code in findings:
        row=p['bills'][target] if isinstance(target,int) else target
        fs.append(dict(key=k(row),code=code))
    fs=sorted(fs,key=lambda f:tuple(f['key'][x] for x in KEYS)+(f['code'],))
    out=dict(version=VERSION,batch_state=batch,obligations=rows,decisions=decisions,source_findings=fs)
    inputs.append(dict(case_id=name,input=p));expected.append(dict(case_id=name,result=out))
    catalog.append(dict(case_id=name,origin=origin,obligations=len(rows) if isinstance(rows,list) else 0,invoices=len(p.get('bills',[])) if isinstance(p.get('bills',[]),list) else 0,expected_changed_dates=sum(d['changed_due'] for d in decisions),expected_batch=batch))
    return p,out

success={'future_revision','past_due_revision','cross_month','cross_year','newer_estimate_asof','old_source_late_receipt','identical_duplicates','older_tombstone','two_bill_ids_same_account_same_due_month'}
blocked={'protected_october':'protected_cycle_preserved','paid':'fulfilled_or_unknown_status_preserved','closed':'fulfilled_or_unknown_status_preserved','null_status':'fulfilled_or_unknown_status_preserved','linked_payment':'fulfilled_or_unknown_status_preserved','document_conflict':'documentary_conflict_requires_reconciliation','null_due':'missing_or_invalid_invoice_due','amount_change':'amount_change_outside_date_only_scope','newer_snapshot':'older_issuer_revision_preserved','same_timestamp_snapshot':'equal_revision_conflict','naive_snapshot_time':'unknown_snapshot_recency','two_bill_ids_claim_one_obligation':'multiple_bills_for_one_obligation'}
sources={'unknown_source_time':'unknown_source_recency','equal_revision_conflict':'conflicting_latest_revision','no_binding':'missing_or_ambiguous_cycle_binding','deleted_source':'latest_source_deleted_preserved','newer_tombstone':'latest_source_deleted_preserved','same_version_tombstone_conflict':'conflicting_latest_revision','naive_source_time':'unknown_source_recency'}
for name in base['cases']:
    ids=([f'same-month-event-{n}' for n in (1,2)] if name=='two_bill_ids_same_account_same_due_month' else ['double-claim'] if name=='two_bill_ids_claim_one_obligation' else ['event-'+name])
    obs=[o for o in base['obligations'] if o['event_id'] in ids];accounts={o['account'] for o in obs}
    p={x:base[x] for x in ('today','protected_through')}
    p.update(obligations=obs,bills=[b for b in base['bills'] if b['account'] in accounts],bindings=[b for b in base['bindings'] if b['event_id'] in ids])
    codes=['overlay_applied' if name in success else blocked.get(name,'no_eligible_invoice')]*len(obs)
    add(name,p,codes,{i:i for i in range(len(obs))} if name in success else {},[(0,sources[name])] if name in sources else [],origin='baseline_28')
# Baseline due results remain exactly the 29 previously reviewed expected rows.
assert [{'event_id':o['event_id'],'due':o['due']} for e in expected for o in e['result']['obligations']]==base['expected']
assert sum(x['expected_changed_dates'] for x in catalog)==10

seed=deepcopy(inputs[0]['input'])
def fixture(): return deepcopy(seed)
def one(name,mutate,code='no_eligible_invoice',fs=(),overlay=False,batch='valid'):
    p=fixture();mutate(p)
    return add(name,p,[code],{0:0} if overlay else {},fs,batch)

one('official_snapshot_without_bill_identity',lambda p:p['obligations'][0].update(provenance='issuer_invoice',source_updated='2035-11-01T12:00:00+00:00'), 'missing_snapshot_bill_identity')
one('deleted_null_is_unknown',lambda p:p['bills'][0].update(deleted=None),fs=[(0,'unknown_source_state')])
one('deleted_missing_is_unknown',lambda p:p['bills'][0].pop('deleted'),fs=[(0,'unknown_source_state')])
one('malformed_source_timestamp',lambda p:p['bills'][0].update(source_updated='2035-02-30T12:00:00Z'),fs=[(0,'unknown_source_recency')])
one('invalid_source_offset',lambda p:p['bills'][0].update(source_updated='2035-11-02T12:00:00+01:60'),fs=[(0,'unknown_source_recency')])
one('invalid_due_calendar',lambda p:p['bills'][0].update(due='2035-02-30'),'missing_or_invalid_invoice_due')
one('received_time_is_not_parsed_or_used',lambda p:p['bills'][0].update(received_at='not-a-timestamp'),'overlay_applied',overlay=True)
for shape,value in [('null',None),('scalar',42),('object',{}),('invalid_element',[None])]:
    one('payment_ids_'+shape,lambda p,v=value:p['obligations'][0].update(payment_ids=v),batch='invalid_obligation_input')
one('duplicate_event_id',lambda p:p['obligations'].append(deepcopy(p['obligations'][0])),batch='duplicate_event_id')
one('source_identity_null',lambda p:p['bills'][0].update(account=None),batch='invalid_source_identity')
one('noncanonical_reference_month',lambda p:p['obligations'][0].update(reference_month='2035-10-15'),batch='invalid_obligation_input')
one('noncanonical_protected_cutoff',lambda p:p.update(protected_through='2035-10-15'),batch='invalid_envelope')
one('binding_wrong_shape',lambda p:p['bindings'][0].update(reference_month='2035-11-15'),batch='invalid_binding_input')
one('duplicate_identical_binding',lambda p:p['bindings'].append(deepcopy(p['bindings'][0])),'overlay_applied',overlay=True)
one('forbidden_due_month_binding',lambda p:p['bindings'][0].update(method='month_of_due_date'),fs=[(0,'binding_identity_mismatch')])
one('cancelled_preserved',lambda p:p['obligations'][0].update(status='cancelled'),'fulfilled_or_unknown_status_preserved')
for field in ('owner','institution','account','cycle_id'):
    one('binding_mismatch_'+field,lambda p,f=field:p['bindings'][0].update({f:'other-'+f}),fs=[(0,'missing_or_ambiguous_cycle_binding' if field in ('owner','institution','account') else 'binding_identity_mismatch')])

for label,source_mode in [('deleted','deleted'),('unknown','unknown'),('absent','absent'),('ambiguous','ambiguous')]:
    p=fixture();second=deepcopy(p['bills'][0]);second['bill_id']='competing-bill';link=deepcopy(p['bindings'][0]);link['bill_id']=second['bill_id'];p['bindings'].append(link)
    fs=[]
    if source_mode!='absent':
        p['bills'].append(second)
        if source_mode=='deleted': second['deleted']=True;fs=[(1,'latest_source_deleted_preserved')]
        if source_mode=='unknown': second['source_updated']=None;fs=[(1,'unknown_source_recency')]
        if source_mode=='ambiguous':
            other=deepcopy(p['obligations'][0]);other['event_id']='other-event';p['obligations'].append(other)
            ambiguous=deepcopy(link);ambiguous['event_id']='other-event';p['bindings'].append(ambiguous)
            fs=[(1,'missing_or_ambiguous_cycle_binding')]
    add('competing_claim_'+label,p,['multiple_bills_for_one_obligation']+(['no_eligible_invoice'] if label=='ambiguous' else []),findings=fs)

p=fixture();other=deepcopy(p['obligations'][0]);other['event_id']='other-event';p['obligations'].append(other)
l=deepcopy(p['bindings'][0]);l['event_id']='other-event';p['bindings'].append(l)
add('one_bill_two_obligations',p,['no_eligible_invoice']*2,findings=[(0,'missing_or_ambiguous_cycle_binding')])
# Same local BillID in different identity domains must remain separate.
for scope in ('account','institution','owner'):
    p=fixture();o=deepcopy(p['obligations'][0]);b=deepcopy(p['bills'][0]);l=deepcopy(p['bindings'][0])
    o['event_id']='other-event';l['event_id']=o['event_id']
    for row in (o,b,l): row[scope]='other-'+scope
    b['due']='2035-11-22';p['obligations'].append(o);p['bills'].append(b);p['bindings'].append(l)
    add('same_bill_id_distinct_'+scope,p,['overlay_applied']*2,{0:0,1:1})

p=fixture();p['obligations'][0]['audit_payload']={'purchase':[{'id':'purchase-1','amount':'100.00','date':'2035-10-08','splits':[{'part':1,'ref':None}]}],'payments':[{'id':'historical-payment','amount':'50.00','paid_at':'2035-10-12T15:00:00Z'}],'unknown_field':[True,None,{'nested':'keep'}]}
p,out=add('deep_payload_overlay',p,['overlay_applied'],{0:0})
repeat=deepcopy(p);repeat['obligations']=deepcopy(out['obligations']);add('idempotent_repeat',repeat,['overlay_applied'],{0:0})
for mode in ('deleted','conflict','absent'):
    p=deepcopy(repeat);p['obligations'][0].update(reference_month='2035-10-01',cycle_id='protected-cycle');p['bindings'][0].update(reference_month='2035-10-01',cycle_id='protected-cycle')
    if mode=='deleted': p['bills'][0].update(deleted=True,source_updated='2035-11-03T12:00:00+00:00');fs=[(0,'latest_source_deleted_preserved')]
    elif mode=='conflict': b=deepcopy(p['bills'][0]);b['due']='2035-12-03';p['bills'].append(b);fs=[(0,'conflicting_latest_revision')]
    else: fs=[(p['obligations'][0]['bill_key'],'previous_source_missing_preserved')];p['bills']=[]
    add('protected_deep_'+mode,p,['protected_cycle_preserved'],findings=fs)

p=deepcopy(repeat);p['bills']=[];add('previous_source_absent',p,['no_eligible_invoice'],findings=[(p['obligations'][0]['bill_key'],'previous_source_missing_preserved')])
p=fixture();p['bills'][0]['source_updated']='2035-11-02T09:00:00-03:00';b=deepcopy(p['bills'][0]);b['source_updated']='2035-11-02T12:00:00+00:00';p['bills'].append(b);add('equal_instants_different_offsets',p,['overlay_applied'],{0:0})
one('nonfinite_source_amount',lambda p:p['bills'][0].update(amount='NaN'),fs=[(0,'invalid_source_fields')])
one('numeric_source_amount_not_canonical',lambda p:p['bills'][0].update(amount=100),fs=[(0,'invalid_source_fields')])
one('nonfinite_obligation_amount',lambda p:p['obligations'][0].update(amount='Infinity'),batch='invalid_obligation_input')
# Malformed collection envelopes fail closed without throwing or disappearing rows.
for collection in ('obligations','bills','bindings'):
    for mode in ('missing','null','object'):
        p=fixture()
        if mode=='missing': p.pop(collection)
        else: p[collection]=None if mode=='null' else {}
        add('envelope_'+collection+'_'+mode,p,[],batch='invalid_envelope')
for field,code in [('family','invalid_source_fields'),('amount','invalid_source_fields'),('due','missing_or_invalid_invoice_due')]:
    p=fixture();p['bills'][0][field]={'invalid':'object'}
    add('source_object_'+field,p,[code if field=='due' else 'no_eligible_invoice'],findings=[] if field=='due' else [(0,code)])
one('old_due_null_enters_dated_bucket',lambda p:p['obligations'][0].update(due=None),'overlay_applied',overlay=True)
p=fixture();p['bindings'][0]['opaque']=True;l=deepcopy(p['bindings'][0]);l['opaque']=1;p['bindings'].append(l)
add('binding_boolean_is_not_number',p,['no_eligible_invoice'],findings=[(0,'missing_or_ambiguous_cycle_binding')])
p=fixture();p['bills'][0]['closing_date']=1;b=deepcopy(p['bills'][0]);b['closing_date']=1.0;p['bills'].append(b)
add('invalid_closing_numeric_equivalence',p,['no_eligible_invoice'],findings=[(0,'invalid_source_fields')])
# Combined baseline checks no cross-case collapsing; uses explicit baseline results.
combined={x:deepcopy(base[x]) for x in ('today','protected_through','obligations','bills','bindings')}
base_outputs=deepcopy(expected[:28]);inputs.append({'case_id':'baseline_28_combined','input':combined})
expected.append({'case_id':'baseline_28_combined','result':{'version':VERSION,'batch_state':'valid','obligations':[o for c in base_outputs for o in c['result']['obligations']],'decisions':[d for c in base_outputs for d in c['result']['decisions']],'source_findings':sorted([f for c in base_outputs for f in c['result']['source_findings']],key=lambda f:tuple(f['key'][x] for x in KEYS)+(f['code'],))}})
catalog.append({'case_id':'baseline_28_combined','origin':'aggregate_regression','obligations':29,'invoices':37,'expected_changed_dates':10,'expected_batch':'valid'})
save('inputs.json',inputs);save('expected.json',expected);save('case-catalog.json',catalog)
print(json.dumps({'cases':len(inputs),'baseline_cases':28,'baseline_obligations':29,'baseline_invoice_rows':37,'baseline_changed_dates':10,'sql_executed':False}))
