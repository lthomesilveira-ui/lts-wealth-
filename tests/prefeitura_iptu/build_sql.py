#!/usr/bin/env python3
"""Render only. Never executes SQL, connects, publishes, or flips release gates."""
import argparse,hashlib,json,re
from pathlib import Path
HERE=Path(__file__).resolve().parent
J=lambda x:json.dumps(x,ensure_ascii=False,separators=(',',':'))
L=lambda x:"'"+str(x).replace("'","''")+"'"
GATES=['identity_authorization_verified','fresh_full_preimages_verified','account_mapping_verified','schema_dependencies_reviewed','consumer_integration_verified','postgres17_passed','independent_review_passed','serialized_no_ddl_window','exact_candidate_authorized']
def catalog_sql(config):
 return (HERE/'catalog-query.sql').read_text().rstrip().replace('__TABLES__',','.join(L(t) for t in config['tables'])).replace('__FUNCTIONS_JSON__',J(config['functions']).replace("'","''"))
def render(c,action):
 assert action in ['apply','rollback']
 q=catalog_sql(c['catalog_config'])
 guard="""IF c->'ready' IS DISTINCT FROM 'true'::jsonb OR c->'gates' IS DISTINCT FROM '%s'::jsonb
 OR current_setting('transaction_isolation') IS DISTINCT FROM 'read committed'
 OR current_setting('TimeZone') IS DISTINCT FROM 'UTC'
 OR coalesce(c->>'original_event_md5','') !~ '^[0-9a-f]{32}$'
 OR jsonb_typeof(c->'original_event') IS DISTINCT FROM 'object'
 OR jsonb_typeof(c->'catalog') IS DISTINCT FROM 'object'
 OR jsonb_array_length(c->'protected_events')<>2 OR jsonb_array_length(c->'protected_sources')<>3
 OR c->'expected_epoch_delta' IS DISTINCT FROM '3'::jsonb
THEN RAISE EXCEPTION 'release gates incomplete or contract missing'; END IF;"""%J(dict.fromkeys(GATES,True))
 t=(HERE/'templates'/f'{action}.sql').read_text()
 for key,file in [('__COMMON__','common.sql'),('__POST_GUARDS__','post-guards.sql'),('__VALIDATE_POSTIMAGE__','validate-postimage.sql')]:t=t.replace(key,(HERE/'templates'/file).read_text())
 t=t.replace('__CATALOG_QUERY__',q).replace('__RELEASE_GUARD__',guard).replace('__CONTRACT__',J(c))
 readback="SELECT current_setting('wealth.iptu_outcome',true) AS outcome, (SELECT to_jsonb(e) FROM public.financial_events e WHERE e.id="+L(c['target_id'])+"::uuid) AS event, (SELECT jsonb_agg(to_jsonb(a) ORDER BY a.id) FROM public.lts_access_audit a WHERE a.meta->>'operation_id'="+L(c['operation_id'])+" OR a.meta->>'rollback_of'="+L(c['operation_id'])+") AS receipts, (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) AS epoch;"
 t=t.replace('__RECEIPT_READBACK__',readback)
 assert not re.search(r'__[A-Z_]+__',t)
 return t
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--contract',type=Path,default=HERE/'CONTRACT.json');p.add_argument('--out',type=Path,default=HERE);a=p.parse_args();c=json.loads(a.contract.read_text());a.out.mkdir(parents=True,exist_ok=True)
 for action in ['apply','rollback']:(a.out/f'{action}-candidate.sql').write_text(render(c,action))
 print(J(dict(ready=c['ready'],sql_executed=False,files={action:hashlib.sha256((a.out/f'{action}-candidate.sql').read_bytes()).hexdigest() for action in ['apply','rollback']})))
