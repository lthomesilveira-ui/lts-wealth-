"""Reuse the exact long-range raw engine output in the existing guarded worker."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
NS='lts_product_refresh_private_v415'
FLOW='public.lts_current_flow_v229(uuid,date,date)'
WORKER=NS+'.run_claimed()'
PROFILE=NS+'.review_profile_v450()'
HELPERS=[(NS+'.long_flow_guard_v450(uuid)','guard.sql'),(NS+'.long_flow_raw_v450(uuid,date)','raw.sql')]
def original(name):return (ROOT/name).read_text().rstrip('\n')+'\n'
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def patch(s,old,new):
 assert s.count(old)==1,(old,s.count(old))
 return s.replace(old,new)
def flow():return patch(original('flow-original.sql'),'else public.lts_daily_flow_fix86_v20(p_user_id,current_date,p_to+30) end;',f'else {NS}.long_flow_raw_v450(p_user_id,p_to+30) end;')
WOLD='  result:=public.lts_refresh_product_read_cache_operational_v5(u);'
WNEW=f'''  -- Warm the exact long raw range used by the existing five-year browser
  -- projection, within this same claimed/guarded transaction. No extra job.
  PERFORM {NS}.long_flow_raw_v450(u,lts_projection_private_v412.horizon_end(current_date)+30);
'''+WOLD
def worker():return patch(original('worker-original.sql'),WOLD,WNEW)
def dollar(s,tag):
 assert '$'+tag+'$' not in s
 return '$'+tag+'$'+s+'$'+tag+'$'
def lifecycle(reverse=False):
 targets=[(FLOW,'flow-original.sql',flow(),True),(WORKER,'worker-original.sql',worker(),True)]
 checks=[];changes=[]
 for signature,name,after,definer in targets:
  prior=original(name);a,b=(after,prior) if reverse else (prior,after)
  cfg="ARRAY['search_path=\"\"','TimeZone=America/Sao_Paulo']" if definer else "ARRAY['search_path=\"\"']"
  checks.append(f'''p:='{signature}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h NOT IN('{md5(a)}','{md5(b)}') OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM {cfg} OR definer IS DISTINCT FROM {str(definer).lower()} OR owner<>'postgres' THEN RAISE EXCEPTION 'long flow reader changed concurrently: %',p;END IF;''')
  changes.append(f"IF md5(pg_get_functiondef('{signature}'::regprocedure))='{md5(a)}' THEN EXECUTE {dollar(b,'replacement')};END IF;\nIF md5(pg_get_functiondef('{signature}'::regprocedure))<>'{md5(b)}' THEN RAISE EXCEPTION 'long flow reconstruction differs';END IF;")
 for signature,name in HELPERS:
  checks.append(f'''p:=to_regprocedure('{signature}');IF p IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid=p;
 IF h<>'{md5(original(name))}' OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'long flow helper changed concurrently';END IF;END IF;''')
 result="BEGIN;\nSET LOCAL lock_timeout='2s';\nDO $check$ DECLARE p regprocedure;h text;acl text;cfg text[];definer boolean;owner text;BEGIN\n"+'\n'.join(checks)+'\nEND $check$;\n'
 if not reverse:
  for signature,name in HELPERS:result+=original(name)+f';\nREVOKE ALL ON FUNCTION {signature} FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION {signature} TO service_role;\n'
 result+='DO $install$ BEGIN\n'+'\n'.join(changes)+'\nEND $install$;\nCOMMIT;\n';return result
if __name__=='__main__':
 for n,s in [('flow-after.sql',flow()),('worker-after.sql',worker()),('install.sql',lifecycle()),('rollback.sql',lifecycle(True))]:(ROOT/n).write_text(s)
 manifest=[{'signature':sig,'before':md5(original(name)),'after':md5(after),'security_changed':False,'source_writes':False} for sig,name,after in [(FLOW,'flow-original.sql',flow()),(WORKER,'worker-original.sql',worker())]]
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest))
