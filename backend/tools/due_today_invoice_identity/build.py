"""Keep one canonical identity across the due-today flow and pending-review lanes."""
import hashlib,json,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('due_invoice_base',ROOT.parent/'due_today_invoice'/'build.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
OLD=" pending_predictions:=public.lts_pending_projections_v233(u);"
NEW=OLD+"""
 -- The exact unpaid invoice already retained above is the same forecast,
 -- not another cash movement in the pending-review presentation lane.
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions
 FROM jsonb_array_elements(pending_predictions) x
 WHERE NOT (x->>'source'='card_invoice'
  AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(recent) kept
   WHERE kept->>'source'='card_invoice'
    AND coalesce((kept->>'unposted_current_projection')::boolean,false)
    AND kept->>'source_ref'=x->>'source_ref'
    AND kept->>'account'=x->>'account'
    AND kept->>'event_date'=x->>'event_date'
    AND (kept->>'signed_amount')::numeric=(x->>'signed_amount')::numeric));"""
TARGETS=base.TARGETS
md5=base.md5

def before(target):return base.patch((base.ROOT/target['file']).read_text(),target['array'])
def patch(text):
 assert text.count(OLD)==1
 return text.replace(OLD,NEW)
def lifecycle(reverse=False):
 checks=[];changes=[]
 for target in TARGETS:
  original=before(target);replacement=patch(original)
  old,new=(replacement,original) if reverse else (original,replacement)
  signature=target['signature'];old_hash,new_hash=md5(old),md5(new)
  checks.append(f""" p:='{signature}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner)
 INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN('{old_hash}','{new_hash}') OR actual_acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}'
 OR actual_owner<>'postgres' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo','statement_timeout=18s']
 OR actual_definer IS DISTINCT FROM {'true' if not target['array'] else 'false'} THEN
  RAISE EXCEPTION 'due-today identity reader changed concurrently: %',p;
 END IF;""")
  a,b=(NEW,OLD) if reverse else (OLD,NEW)
  changes.append(f""" p:='{signature}'::regprocedure;
 IF md5(pg_get_functiondef(p))='{old_hash}' THEN
  next_sql:=replace(pg_get_functiondef(p),{base.dollar(a,'identity_old')},{base.dollar(b,'identity_new')});
  IF md5(next_sql)<>'{new_hash}' THEN RAISE EXCEPTION 'identity patch reconstruction differs';END IF;
  EXECUTE next_sql;
  IF md5(pg_get_functiondef(p))<>'{new_hash}' THEN RAISE EXCEPTION 'identity installed definition differs';END IF;
 END IF;""")
 return """BEGIN;
SET LOCAL lock_timeout='2s';
DO $due_today_identity$
DECLARE p regprocedure;actual_hash text;actual_acl text;actual_config text[];actual_definer boolean;actual_owner text;next_sql text;
BEGIN
"""+'\n'.join(checks+changes)+"\nEND $due_today_identity$;\nCOMMIT;\n"
if __name__=='__main__':
 manifest=[{'signature':t['signature'],'before':md5(before(t)),'after':md5(patch(before(t))),'source_writes':False,'security_changed':False} for t in TARGETS]
 (ROOT/'install.sql').write_text(lifecycle());(ROOT/'rollback.sql').write_text(lifecycle(True))
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps(manifest))
