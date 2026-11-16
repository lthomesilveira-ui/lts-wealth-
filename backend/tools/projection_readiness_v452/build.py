"""Guarded lifecycle for complete projection readiness; no financial source writes."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
CACHE='lts_product_refresh_private_v415.cache_info(uuid)'
STATUS='public.lts_browser_product_refresh_status_v415()'
HELPER='lts_product_refresh_private_v415.projection_current_v452(uuid)'
def read(n):return (ROOT/n).read_text()
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def once(s,a,b):assert s.count(a)==1;return s.replace(a,b)
def cache():return once(read('cache-info-original.sql'),'AND lts_product_refresh_private_v415.card_state_cached(p_user_id) IS NOT NULL,','AND lts_product_refresh_private_v415.card_state_cached(p_user_id) IS NOT NULL\n   AND lts_product_refresh_private_v415.projection_current_v452(p_user_id),')
def status():
 s=once(read('status-original.sql'),' STABLE SECURITY DEFINER',' SECURITY DEFINER')
 s=once(s,'DECLARE u uuid:=public.lts_browser_assert_user_v1();','DECLARE u uuid:=public.lts_browser_assert_user_v1(); refresh jsonb;')
 return once(s," RETURN jsonb_build_object('ok',true,'refresh',lts_product_refresh_private_v415.status(u));",''' refresh:=lts_product_refresh_private_v415.status(u);
 -- A refreshed card view must not certify an obsolete projection snapshot.
 -- Join the existing queue only when no version is already pending/running.
 -- enqueue(false) rechecks under its existing row lock and never starts a worker.
 IF refresh->>'required'='true' AND refresh->>'state'='pending'
  AND refresh->>'request_version'=refresh->>'completed_version' THEN
  refresh:=lts_product_refresh_private_v415.enqueue(u,'cache_read',false);
 END IF;
 RETURN jsonb_build_object('ok',true,'refresh',refresh);''')
FUNCTIONS=[(CACHE,'cache-info-original.sql',cache),(STATUS,'status-original.sql',status)]
CFG='ARRAY[\'search_path=""\',\'TimeZone=America/Sao_Paulo\']'
def lifecycle(reverse=False):
 checks=[];changes=[]
 for sig,name,fn in FUNCTIONS:
  old,new=read(name),fn();a,b=(new,old) if reverse else (old,new)
  acl='{postgres=X/postgres,service_role=X/postgres'+(',authenticated=X/postgres' if sig==STATUS else '')+'}'
  checks.append(f'''SELECT md5(pg_get_functiondef(oid)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid='{sig}'::regprocedure;
 IF h NOT IN('{md5(a)}','{md5(b)}') OR acl IS DISTINCT FROM '{acl}' OR cfg IS DISTINCT FROM {CFG} OR NOT definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Projection readiness changed concurrently: {sig}';END IF;''')
  changes.append(f"IF md5(pg_get_functiondef('{sig}'::regprocedure))='{md5(a)}' THEN EXECUTE $replace${b}$replace$;END IF;\nIF md5(pg_get_functiondef('{sig}'::regprocedure))<>'{md5(b)}' THEN RAISE EXCEPTION 'Projection readiness reconstruction differs';END IF;")
 helper=read('projection-guard.sql')
 checks.append(f'''IF to_regprocedure('{HELPER}') IS NOT NULL THEN
 SELECT md5(pg_get_functiondef(oid)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO h,acl,cfg,definer,owner FROM pg_proc WHERE oid='{HELPER}'::regprocedure;
 IF h<>'{md5(helper)}' OR acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR cfg IS DISTINCT FROM {CFG} OR definer OR owner<>'postgres' THEN RAISE EXCEPTION 'Projection helper changed concurrently';END IF;END IF;''')
 for sig,name in [('lts_product_refresh_private_v415.enqueue(uuid,text,boolean)','enqueue-original.sql'),('lts_product_refresh_private_v415.status(uuid)','private-status-original.sql')]:
  checks.append(f"IF md5(pg_get_functiondef('{sig}'::regprocedure))<>'{md5(read(name))}' THEN RAISE EXCEPTION 'Existing refresh queue changed concurrently';END IF;")
 before='' if reverse else f"IF to_regprocedure('{HELPER}') IS NULL THEN EXECUTE $replace${helper}$replace$;ALTER FUNCTION {HELPER} OWNER TO postgres;REVOKE ALL ON FUNCTION {HELPER} FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION {HELPER} TO service_role;END IF;\n"
 after=f"DROP FUNCTION IF EXISTS {HELPER};\n" if reverse else ''
 return "BEGIN;\nSET LOCAL lock_timeout='2s';\nDO $guard$ DECLARE h text;acl text;cfg text[];definer boolean;owner text;BEGIN\n"+'\n'.join(checks)+'\nEND $guard$;\nDO $change$ BEGIN\n'+before+'\n'.join(changes)+'\n'+after+'END $change$;\nCOMMIT;\n'
if __name__=='__main__':
 for name,s in [('cache-info-after.sql',cache()),('status-after.sql',status()),('install.sql',lifecycle()),('rollback.sql',lifecycle(True))]:(ROOT/name).write_text(s)
 (ROOT/'manifest.json').write_text(json.dumps({'scope':'Projection readiness and the existing queue only','financial_sources_changed':False,'new_worker_created':False,'definitions':{sig:{'before':md5(read(name)),'after':md5(fn())} for sig,name,fn in FUNCTIONS},'helper':md5(read('projection-guard.sql'))},indent=2)+'\n')
 print(json.dumps({'pass':True,'scope':'projection_readiness_v452'}))
