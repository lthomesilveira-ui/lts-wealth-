from pathlib import Path
from copy import deepcopy
import json
root=Path(__file__).parent
orig=json.loads((root/'fixtures-input-synthetic.json').read_text())
u,_,l,b,t,_,asof=orig['base']; c=orig['contract']
l['id']='44444444-4444-4444-8444-444444444444';l['created_at']='2026-10-15T00:00:00+00:00'
c['link_contract']={k:v for k,v in l.items() if k!='created_at'}
b['raw_hash']='invoicehash-refreshed';c['invoice_current_hash']=b['raw_hash']
c['private_test_marker']='NEVER_RETURN_PRIVATE_CONTRACT'
base={'user':u,'link':l,'invoice':b,'payment':t,'contract':c,'as_of':asof}
expected={'status':'identified_in_statement','basis':'reviewed_original_link_and_exact_issuer_refresh','payment_date':'2026-10-14','bank_posting_date':'2026-10-14','bank_posting_status':'POSTED','issuer_payment_date':'2026-10-12','issuer_payment_type':'FULL_PAYMENT','amount':100,'currency':'BRL','cash_effect':'none'}
(root/'synthetic-fixture.json').write_text(json.dumps({'args':base,'expected':expected},indent=2)+'\n')
cases=[('valid refreshed evidence',base,expected)]
def add(label,path,value):
 d=deepcopy(base);o=d
 for x in path[:-1]:o=o[x]
 o[path[-1]]=value;cases.append((label,d,None))
add('owner mismatch',['user'],'99999999-9999-4999-8999-999999999999')
for section in ['link','invoice','payment','contract']:
 add(section+' owner mismatch',[section,'user_id'],'99999999-9999-4999-8999-999999999999')
add('contract revoked',['contract','active'],False)
add('link revoked',['link','active'],False)
add('frozen original hash cannot be overwritten',['link','invoice_raw_hash'],'new-hash')
add('documentary sources cannot be overwritten',['link','documentary_sources'],[{},{} ,{}])
add('contract original link mismatch',['contract','link_contract','expected_amount'],99)
add('current invoice hash changed',['invoice','raw_hash'],'third-hash')
add('bank hash changed',['payment','raw_hash'],'third-hash')
for field in ['institution_code','provider_record_id','provider_account_ref','currency','resource_type','id']:
 for source in ['invoice','payment']:add(source+' '+field+' changed',[source,field],'different')
for source in ['invoice','payment']:
 add(source+' deleted',[source,'provider_deleted_at'],'2026-10-15T00:00:00Z')
 add(source+' signed amount mismatch',[source,'signed_amount'],99)
add('bank date changed',['payment','posting_date'],'2026-10-13')
add('bank pending normalized',['payment','normalized_payload','status'],'PENDING')
add('bank pending raw',['payment','raw_payload','status'],'PENDING')
add('wrong bank account type',['payment','normalized_payload','account_type'],'CREDIT_CARD')
add('due date changed',['invoice','normalized_payload','due_date'],'2026-10-13')
add('closing date changed',['invoice','normalized_payload','closing_date'],'2026-10-04')
add('issuer payload changed',['invoice','raw_payload','payments'],[])
add('contract invoice target mismatch',['contract','invoice_id'],'99999999-9999-4999-8999-999999999999')
add('contract payment target mismatch',['contract','payment_id'],'99999999-9999-4999-8999-999999999999')
add('contract amount mismatch',['contract','amount'],99)
add('as of precedes bank posting',['as_of'],'2026-10-13')
add('missing contract',['contract'],None)
add('empty issuer array',['contract','issuer_payments'],[])
add('issuer array wrong shape',['contract','issuer_payments'],{})
# Change both issuer copies, preserving equality, to exercise semantic guards.
for field,value in [('amount',99),('valueType','PARTIAL_PAYMENT'),('paymentMode','OTHER'),('currencyCode','USD'),('paymentDate','2026-10-16T00:00:00Z'),('paymentDate','2026-10-05T00:00:00Z'),('paymentDate','2026-02-30T00:00:00Z'),('paymentDate','<img>'),('paymentDate','2026-10-12T25:00:00Z')]:
 d=deepcopy(base)
 for p in [d['contract']['issuer_payments'],d['invoice']['raw_payload']['payments']]:p[0][field]=value
 cases.append(('issuer '+field+' rejected '+str(value),d,None))
# Created-at is explicitly excluded from the original audited identity lease.
d=deepcopy(base);d['link']['created_at']='2030-01-01T00:00:00Z';cases.append(('created_at immaterial',d,expected))

# The new policy shares the exact installed predicate. All data below is invented.
def canonical(args):
 d=deepcopy(args)
 if not isinstance(d.get('contract'),dict): return d
 raw=d['invoice'].get('raw_payload')
 if not isinstance(raw,dict): return d
 raw.update({'id':'synthetic-bill-id','totalAmount':100,'totalAmountCurrencyCode':'BRL','dueDate':'2026-10-12T00:00:00Z','billClosingDate':'2026-10-05T00:00:00Z','createdAt':'2026-10-06T12:00:00Z','updatedAt':'2026-10-16T12:00:00Z','minimumPaymentAmount':10,'allowsInstallments':True,'financeCharges':[], 'unknownProviderObject':{'updatedAt':'nested-must-stay-exact','value':None,'array':[{'key':'A'},{'key':'B'}]}})
 d['contract']['invoice_evidence_policy']='raw_except_updatedAt_v1'
 d['contract']['invoice_canonical_payload']={k:deepcopy(v) for k,v in raw.items() if k!='updatedAt'}
 return d
canonical_base=canonical(base)
# Apply every legacy mutation to the canonical baseline rather than recomputing
# a canonical contract from the mutated invoice.
legacy_cases=list(cases)
def diffs(original,changed,path=()):
 if isinstance(original,dict) and isinstance(changed,dict):
  out=[]
  for k in original.keys()|changed.keys():
   if k not in changed: out.append((path+(k,),None,True))
   elif k not in original: out.append((path+(k,),changed[k],False))
   else: out.extend(diffs(original[k],changed[k],path+(k,)))
  return out
 return [] if original==changed else [(path,changed,False)]
def setpath(data,path,value,remove=False):
 o=data
 for k in path[:-1]:o=o[k]
 if remove:del o[path[-1]]
 else:o[path[-1]]=deepcopy(value)
for label,args,exp in legacy_cases:
 d=deepcopy(canonical_base)
 for path,value,remove in diffs(base,args):setpath(d,path,value,remove)
 cases.append(('canonical / '+label,d,expected if label=='current invoice hash changed' else exp))
# Root timestamp is the only excluded field; equality remains JSONB equality.
for label,value in [('future root timestamp','2027-01-01T18:22:00Z'),('changed root timestamp','2026-10-16T13:00:00.111Z')]:
 d=deepcopy(canonical_base);d['invoice']['raw_payload']['updatedAt']=value;d['invoice']['raw_hash']='changed-fingerprint';cases.append((label,d,expected))
for value in [None,1,{},'bad','2026-10-16']:
 d=deepcopy(canonical_base);d['invoice']['raw_payload']['updatedAt']=value;cases.append(('invalid updatedAt '+str(value),d,None))
for value in ['unknown_v2','',False]:
 d=deepcopy(canonical_base);d['contract']['invoice_evidence_policy']=value;cases.append(('unknown policy '+str(value),d,None))
for key in ['updatedAt']:
 d=deepcopy(canonical_base);del d['invoice']['raw_payload'][key];cases.append(('missing required root timestamp',d,None))
for value in [None,[],{},'bad']:
 d=deepcopy(canonical_base);d['contract']['invoice_canonical_payload']=value;cases.append(('canonical malformed '+str(value),d,None))
# Mutate/remove every node except root updatedAt, including unknown/nested data.
def paths(value,path=()):
 result=[]
 if isinstance(value,dict):
  for key,item in value.items():
   if path==() and key=='updatedAt':continue
   result.append(path+(key,));result.extend(paths(item,path+(key,)))
 elif isinstance(value,list):
  for index,item in enumerate(value):result.append(path+(index,));result.extend(paths(item,path+(index,)))
 return result
for path in paths(canonical_base['invoice']['raw_payload']):
 for remove in [False,True]:
  d=deepcopy(canonical_base);setpath(d['invoice']['raw_payload'],path,'MUTATED_SYNTHETIC',remove);cases.append(('raw '+('remove' if remove else 'mutate')+' '+'.'.join(map(str,path)),d,None))
d=deepcopy(canonical_base);d['invoice']['raw_payload']['newUnknownField']='not reviewed';cases.append(('new unknown root field',d,None))
d=deepcopy(canonical_base);d['invoice']['raw_payload']['unknownProviderObject']['array'].reverse();cases.append(('array order exact',d,None))
d=deepcopy(canonical_base);d['invoice']['raw_payload']=dict(reversed(list(d['invoice']['raw_payload'].items())));cases.append(('object key order ignored',d,expected))
# Use the canonical policy for the actual presentation-reader integration.
b=canonical_base['invoice'];c=canonical_base['contract']
(root/'synthetic-fixture.json').write_text(json.dumps({'args':canonical_base,'expected':expected},indent=2)+'\n')
q=lambda x:"'"+json.dumps(x,separators=(',',':'),ensure_ascii=False).replace("'","''")+"'::jsonb"
local=lambda s:'\n'.join(x for x in s.replace('public.','pg_temp.').splitlines() if not x.startswith(('REVOKE ','GRANT ')))
pure=local((root/'payment-refresh-annotation.sql').read_text())
s='''-- SYNTHETIC ONLY. Exact candidate code; no production relations or readers.\nBEGIN;\nSET LOCAL statement_timeout='15s';\nSET LOCAL TIME ZONE 'America/Sao_Paulo';\nDO $safety$ BEGIN IF current_database()<>'lts_p05_synthetic' OR current_user<>'lts_p05_synthetic' OR current_setting('server_version_num')::int/10000<>17 OR EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','v','m','f')) THEN RAISE EXCEPTION 'fresh synthetic PostgreSQL17 required'; END IF; END $safety$;\n'''+pure+'''
CREATE TEMP TABLE annotation_cases(label text,args jsonb,expected jsonb);
'''
s+='INSERT INTO pg_temp.annotation_cases VALUES\n'+',\n'.join("('"+name.replace("'","''")+"',"+q(args)+','+q(exp)+')' for name,args,exp in cases)+';\n'
s+='''DO $tests$ DECLARE c record;r jsonb; BEGIN
 FOR c IN SELECT * FROM pg_temp.annotation_cases LOOP
 r:=pg_temp.lts_card_payment_refresh_annotation_v273((c.args->>'user')::uuid,c.args->'link',c.args->'invoice',c.args->'payment',c.args->'contract',(c.args->>'as_of')::date);
 IF r IS DISTINCT FROM nullif(c.expected,'null'::jsonb) THEN RAISE EXCEPTION 'FAIL: %',c.label; END IF;
 END LOOP;
END $tests$;
SELECT jsonb_build_object('stage','pure','cases',count(*),'passed',count(*)) FROM pg_temp.annotation_cases;
'''
original=(root/'original-presentation-helper.sql').read_text()
ddl=original[original.index('CREATE TABLE'):original.index('CREATE FUNCTION')].replace('CREATE TABLE','CREATE TEMP TABLE',1)
s+=local(ddl)+'\n'
s+='''CREATE TEMP TABLE lts_open_finance_staging(id uuid,user_id uuid,resource_type text,provider_deleted_at timestamptz,institution_code text,provider_record_id text,provider_account_ref text,currency text,signed_amount numeric,normalized_payload jsonb,raw_payload jsonb,posting_date date,raw_hash text);
CREATE TEMP TABLE lts_card_settlement_expense_contract_v273(user_id uuid,payment_source_id uuid,revision text,payload jsonb,active boolean,PRIMARY KEY(user_id,payment_source_id));
'''
s+='INSERT INTO pg_temp.lts_open_finance_staging SELECT * FROM jsonb_populate_record(NULL::pg_temp.lts_open_finance_staging,'+q(b)+');\n'
s+='INSERT INTO pg_temp.lts_open_finance_staging SELECT * FROM jsonb_populate_record(NULL::pg_temp.lts_open_finance_staging,'+q(t)+');\n'
s+='INSERT INTO pg_temp.lts_card_documentary_payment_link_v272 SELECT * FROM jsonb_populate_record(NULL::pg_temp.lts_card_documentary_payment_link_v272,'+q(l)+');\n'
s+='INSERT INTO pg_temp.lts_card_settlement_expense_contract_v273 VALUES(\''+u+"','"+t['id']+"','synthetic',"+q(c)+',true);\n'
s+=local((root/'documentary-payment-presentation.sql').read_text())+'\n'
payload={'complete':True,'cards':[{'family':'synthetic','cycles':[{'invoice_source_id':b['id'],'amount':100,'month':'2026-10-01','due_date':'2026-10-12','payment_status':'payment_not_reported','items':[{'amount':60},{'amount':40}]}]},{'family':'unrelated','cycles':[{'amount':30,'due_date':'2026-11-20','payment_status':'payment_not_reported'}]}]}
s+='''DO $integration$ DECLARE p jsonb:='''+q(payload)+''';r jsonb;initial jsonb; BEGIN
 SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(x)) FROM pg_temp.lts_open_finance_staging x),(SELECT jsonb_agg(to_jsonb(x)) FROM pg_temp.lts_card_documentary_payment_link_v272 x),(SELECT jsonb_agg(to_jsonb(x)) FROM pg_temp.lts_card_settlement_expense_contract_v273 x)) INTO initial;
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('''+"'"+u+"'"+''',p);
 IF r#>'{cards,0,cycles,0,documentary_payment_evidence}' IS DISTINCT FROM '''+q(expected)+''' THEN RAISE EXCEPTION 'refreshed projection mismatch'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'financial/source payload changed'; END IF;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('''+"'"+u+"'"+''',r) IS DISTINCT FROM r THEN RAISE EXCEPTION 'projection not idempotent'; END IF;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('99999999-9999-4999-8999-999999999999',r) IS DISTINCT FROM p THEN RAISE EXCEPTION 'cross-owner annotation leak'; END IF;
 IF r::text LIKE '%NEVER_RETURN_PRIVATE_CONTRACT%' OR r::text LIKE '%manifest%' OR r::text LIKE '%raw_hash%' OR r::text LIKE '%documentary_sources%' THEN RAISE EXCEPTION 'private contract leaked'; END IF;
 IF jsonb_build_array((SELECT jsonb_agg(to_jsonb(x)) FROM pg_temp.lts_open_finance_staging x),(SELECT jsonb_agg(to_jsonb(x)) FROM pg_temp.lts_card_documentary_payment_link_v272 x),(SELECT jsonb_agg(to_jsonb(x)) FROM pg_temp.lts_card_settlement_expense_contract_v273 x)) IS DISTINCT FROM initial THEN RAISE EXCEPTION 'source or P05 mutated'; END IF;
 UPDATE pg_temp.lts_open_finance_staging SET raw_hash='changed-again',raw_payload=jsonb_set(raw_payload,'{updatedAt}',to_jsonb('2027-01-01T00:00:00Z'::text)) WHERE resource_type='invoice';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('11111111-1111-4111-8111-111111111111',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,basis}' IS DISTINCT FROM 'reviewed_original_link_and_exact_issuer_refresh' THEN RAISE EXCEPTION 'timestamp-only refresh lost annotation'; END IF;
 UPDATE pg_temp.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{totalAmount}','101'::jsonb) WHERE resource_type='invoice';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('''+"'"+u+"'"+''',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'unreviewed refresh accepted'; END IF;
 UPDATE pg_temp.lts_open_finance_staging SET raw_hash='invoicehash' WHERE resource_type='invoice';
 UPDATE pg_temp.lts_card_settlement_expense_contract_v273 SET active=false;
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('''+"'"+u+"'"+''',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,basis}' IS DISTINCT FROM 'reviewed_documentary_alias_and_posted_bank_transaction' THEN RAISE EXCEPTION 'original documentary path lost'; END IF;
 UPDATE pg_temp.lts_card_documentary_payment_link_v272 SET active=false;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('''+"'"+u+"'"+''',r) IS DISTINCT FROM p THEN RAISE EXCEPTION 'inactive annotation retained'; END IF;
END $integration$;
SELECT jsonb_build_object('stage','integration','passed',true);
ROLLBACK;
'''
(root/'synthetic-presentation-test.sql').write_text(s)
(root/'test-cases.json').write_text(json.dumps({'pure_sql_cases':len(cases),'case_names':[x[0] for x in cases],'executed':False},indent=2)+'\n')
print('Prepared',len(cases),'pure SQL cases plus reader integration (not executed).')
