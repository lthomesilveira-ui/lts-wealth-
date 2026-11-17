"""Add a payment channel to the existing, reconciled expense presentation."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
SPECS={
 'scope':'public.lts_expense_scope_v353(jsonb,jsonb,text,jsonb)',
 'presentation':'public.lts_expense_presentation_v353(uuid,date,date,jsonb)',
 'detail':'public.lts_browser_expense_detail_v353(date,date,jsonb,integer,integer,text)',
 'taxonomy':'public.lts_expense_taxonomy_v353(text,text,text)',
 'report':'public.lts_browser_expenses_v229(date,date)',
 'profile':'lts_product_refresh_private_v415.review_profile_v450()'}
EXPECTED={'scope':'fa7b6cb4a3173bbe927ceece060002ad','presentation':'ac2b6ab32167cce65809b20e0550cbf0','detail':'50c40fde481733d256566166dff4d7cb','taxonomy':'5679e50ce6dc0fe2486977754effccd7','profile':'25952f79bf0f8216a651aff7ce239923'}
CARD="(coalesce(r->>'source_table','') LIKE '%card%' OR coalesce(r->>'coverage_mode','') LIKE 'card_%')"
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def definition(name):return (ROOT/name).read_text().rstrip().removesuffix(';')+'\n'
def once(s,a,b):
 assert s.count(a)==1,(a[:90],s.count(a))
 return s.replace(a,b)
def patch(sig,before,after):
 return f""" target:='{sig}'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{md5(before)}' THEN EXECUTE $definition${after.rstrip()}$definition$;
 ELSIF md5(d)<>'{md5(after)}' THEN RAISE EXCEPTION 'V464_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'{md5(after)}' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V464_FUNCTION_CONTRACT_CHANGED';END IF;
"""
def build():
 old={k:definition(k+'-original.sql') for k in SPECS}
 assert all(md5(old[k])==h for k,h in EXPECTED.items())
 new=dict(old)
 new['scope']=once(old['scope']," (nullif(s->>'macrogroup','')IS NULL", " (nullif(s->>'payment','')IS NULL OR s->>'payment'='card'AND "+CARD+" OR s->>'payment'='account'AND NOT "+CARD+")AND\n (nullif(s->>'macrogroup','')IS NULL")
 new['presentation']=once(old['presentation'],"(taxonomy->>'is_tax')::boolean is_tax,sum(greatest(amount,0))gross", "(taxonomy->>'is_tax')::boolean is_tax,CASE WHEN coalesce(row_payload->>'source_table','') LIKE '%card%' OR coalesce(row_payload->>'coverage_mode','') LIKE 'card_%' THEN 'card' ELSE 'account' END payment,sum(greatest(amount,0))gross")
 new['presentation']=once(new['presentation'],'FROM filtered GROUP BY 1,2,3,4,5,6,7)x)', 'FROM filtered GROUP BY 1,2,3,4,5,6,7,8)x)')
 new['detail']=once(old['detail'],"'center_cost','sign','view']", "'center_cost','sign','view','payment']")
 new['detail']=once(new['detail'],"OR coalesce(p_scope->>'view','type')NOT IN", "OR coalesce(p_scope->>'payment','')NOT IN('','card','account')OR coalesce(p_scope->>'view','type')NOT IN")
 new['taxonomy']=once(old['taxonomy'],"macro:='Vida pessoal e familiar';g:='Presentes e contribuições'", "macro:='Presentes e contribuições';g:='Presentes e contribuições'")
 new['taxonomy']=once(new['taxonomy'],"macro:='Vida pessoal e familiar';g:='Tipo de gasto não detalhado';cat:='Despesas pessoais sem tipo informado'", "macro:=coalesce(cat,'Outras despesas');g:=macro")
 new['report']=once(old['report'],"fingerprint:='expenses-v353:'", "fingerprint:='expenses-v464:'")
 profile=json.loads(old['profile'].split('$manifest$')[1])
 assert not any(p['signature'] in list(SPECS.values())[:-1] for p in profile['producers'])
 for k,sig in SPECS.items():
  if k!='profile':profile['producers'].append({'signature':sig,'md5':md5(new[k])})
 new['profile']=old['profile'].replace(old['profile'].split('$manifest$')[1],json.dumps(profile,ensure_ascii=False,indent=2))
 for k in SPECS:(ROOT/(k+'-after.sql')).write_text(new[k].rstrip()+';\n')
 for filename,reverse in [('install.sql',False),('rollback.sql',True)]:
  parts=["BEGIN;\nSET LOCAL lock_timeout='2s';\nSET LOCAL statement_timeout='10s';\nDO $patch$\nDECLARE target regprocedure;d text;attrs jsonb;u uuid;\nBEGIN\n",
   " IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'V464_WORKER_ACTIVE';END IF;\n",
   " FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V464_WORKER_LOCK_BUSY';END IF;END LOOP;\n"]
  for k,sig in SPECS.items():parts.append(patch(sig,new[k],old[k]) if reverse else patch(sig,old[k],new[k]))
  parts.append('END $patch$;\nCOMMIT;\n');(ROOT/filename).write_text(''.join(parts))
 (ROOT/'manifest.json').write_text(json.dumps({'functions':{sig:{'before':md5(old[k]),'after':md5(new[k])}for k,sig in SPECS.items()},'new_profile_producers':5,'existing_profile_entries_changed':0,'financial_writes':False,'permissions_changed':False,'timeouts_changed':False,'classification_source_rows_changed':False,'payment_definition':'same source_table/coverage_mode predicate as the existing expense summary','old_report_cache_reused':False},indent=2)+'\n')
if __name__=='__main__':build()
