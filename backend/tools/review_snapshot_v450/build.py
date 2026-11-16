"""Reuse exact pending-review rows behind a complete, fail-closed source guard."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
NS='lts_product_refresh_private_v415'
QUEUE='public.lts_browser_expense_review_queue_v229(date,date,integer,integer,text)'
WORKER=NS+'.run_claimed()'
OLD='from public.lts_v229_review_rows(v_uid,p_from,p_to) r'
NEW='from '+NS+'.expense_review_pending_v450(v_uid,p_from,p_to) r'
WOLD='  succeeded:=true;'
WNEW="""  -- Warm after all product and queue publication writes, in the same claim.
  -- No extra job, altered classification, browser identity or financial write.
  PERFORM 1 FROM lts_product_refresh_private_v415.expense_review_pending_v450(u,date '2013-10-10',current_date);
"""+WOLD
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def get_original(name):return (ROOT/name).read_text().rstrip('\n')+'\n'
def dollar(s,tag):
 assert '$'+tag+'$' not in s
 return '$'+tag+'$'+s+'$'+tag+'$'
def patch(s,old,new):
 assert s.count(old)==1
 return s.replace(old,new)
def helpers():
 profile=(ROOT/'source-profile.json').read_text();columns=(ROOT/'row-columns.txt').read_text().strip()
 sql=f"""CREATE OR REPLACE FUNCTION {NS}.review_profile_v450() RETURNS jsonb
 LANGUAGE sql IMMUTABLE SET search_path='' AS $profile$ SELECT {dollar(profile,'manifest')}::jsonb $profile$;
CREATE OR REPLACE FUNCTION {NS}.review_guard_v450(p_user_id uuid) RETURNS jsonb
 LANGUAGE plpgsql SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $guard$
DECLARE profile jsonb:={NS}.review_profile_v450(); item jsonb; actual text; primary_hashes jsonb:='{{}}'; rel regclass; owner_column text;
BEGIN
 -- Unknown producer, view or invalidation rules disable reuse, including new
 -- dependencies. They never convert unavailable information into an empty list.
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'producers') LOOP
  SELECT md5(pg_get_functiondef(to_regprocedure(item->>'signature'))) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'views') LOOP
  SELECT md5(pg_get_viewdef(to_regclass(item->>'signature'),true)) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'epoch_tables') LOOP
  SELECT md5(string_agg(t.tgname::text||t.tgenabled::text||pg_get_triggerdef(t.oid),'|' ORDER BY t.tgname)) INTO actual
   FROM pg_trigger t WHERE t.tgrelid=to_regclass(item->>'signature') AND NOT t.tgisinternal;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'tables') LOOP
  -- Relations and owner-column names come only from the pinned private profile.
  rel:=to_regclass(format('%I.%I',item->>'schema',item->>'name'));owner_column:=item->>'owner';
  IF rel IS NULL THEN RETURN NULL;END IF;
  EXECUTE format('WITH row_hashes AS MATERIALIZED (SELECT md5(to_jsonb(s)::text) h FROM %s s%s) SELECT md5(coalesce(string_agg(h,'''' ORDER BY h),'''')) FROM row_hashes',
   rel,CASE WHEN owner_column IS NULL THEN '' ELSE format(' WHERE %I=$1',owner_column) END) INTO actual USING p_user_id;
  primary_hashes:=primary_hashes||jsonb_build_object(item->>'schema'||'.'||(item->>'name'),actual);
 END LOOP;
 RETURN jsonb_build_object('owner',p_user_id,'as_of',current_date,
  'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  'card_source_key',{NS}.card_source_key(p_user_id),'primary_hashes',primary_hashes,'profile',md5(profile::text));
END $guard$;
CREATE OR REPLACE FUNCTION {NS}.expense_review_pending_v450(p_user_id uuid,p_from date,p_to date)
 RETURNS TABLE({columns}) LANGUAGE plpgsql SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $pending$
DECLARE source_guard jsonb; final_guard jsonb; fingerprint text; stored jsonb; result jsonb; old_lock text;
BEGIN
 IF p_user_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid review range';END IF;
 source_guard:={NS}.review_guard_v450(p_user_id);
 IF source_guard IS NULL THEN
  RETURN QUERY SELECT r.* FROM public.lts_v229_review_rows(p_user_id,p_from,p_to) r WHERE r.identity_status='pending';RETURN;
 END IF;
 fingerprint:='expense-review-v450:'||md5(source_guard::text);
 SELECT c.payload INTO stored FROM public.lts_v229_read_cache c
 WHERE c.user_id=p_user_id AND c.kind='expense_review_pending_v450' AND c.as_of=current_date
 AND c.from_date=p_from AND c.to_date=p_to AND c.source_fingerprint=fingerprint;
 IF FOUND AND stored->'guard'=source_guard AND jsonb_typeof(stored->'rows')='array'
 AND stored->>'digest'=md5((stored->'rows')::text) THEN result:=stored->'rows';
 ELSE
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) INTO result
   FROM public.lts_v229_review_rows(p_user_id,p_from,p_to) r WHERE r.identity_status='pending';
  final_guard:={NS}.review_guard_v450(p_user_id);
  IF final_guard IS DISTINCT FROM source_guard THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Review sources changed during read';END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN
   old_lock:=current_setting('lock_timeout');
   BEGIN
    IF old_lock::interval=interval '0' OR old_lock::interval>interval '100 milliseconds' THEN PERFORM set_config('lock_timeout','100ms',true);END IF;
    INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
    VALUES(p_user_id,'expense_review_pending_v450',current_date,p_from,p_to,
     jsonb_build_object('guard',source_guard,'rows',result,'digest',md5(result::text)),clock_timestamp(),fingerprint)
    ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
    PERFORM set_config('lock_timeout',old_lock,true);
   EXCEPTION WHEN lock_not_available OR read_only_sql_transaction THEN NULL;END;
  END IF;
 END IF;
 -- Recheck even cache hits; no crossing to a changed owner/day/source revision.
 IF {NS}.review_guard_v450(p_user_id) IS DISTINCT FROM source_guard THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Review sources changed during read';END IF;
 RETURN QUERY SELECT r.* FROM jsonb_to_recordset(result) AS r({columns});
END $pending$;
"""
 for signature in [NS+'.review_profile_v450()',NS+'.review_guard_v450(uuid)',NS+'.expense_review_pending_v450(uuid,date,date)']:
  sql+=f'REVOKE ALL ON FUNCTION {signature} FROM PUBLIC,anon,authenticated;\nGRANT EXECUTE ON FUNCTION {signature} TO service_role;\n'
 return sql
def lifecycle(reverse=False):
 targets=[(QUEUE,get_original('queue-original.sql'),OLD,NEW,'{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}'),
          (WORKER,get_original('worker-original.sql'),WOLD,WNEW,'{postgres=X/postgres,service_role=X/postgres}')]
 checks=[];changes=[]
 for signature,original,a,b,acl in targets:
  replacement=patch(original,a,b);before,after=(replacement,original) if reverse else (original,replacement)
  checks.append(f"""p:='{signature}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN ('{md5(before)}','{md5(after)}') OR actual_acl IS DISTINCT FROM '{acl}' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo'] OR NOT actual_definer OR actual_owner<>'postgres' THEN RAISE EXCEPTION 'review reader changed concurrently: %',p;END IF;""")
  x,y=(b,a) if reverse else (a,b)
  changes.append(f"""p:='{signature}'::regprocedure;
 IF md5(pg_get_functiondef(p))='{md5(before)}' THEN next_sql:=replace(pg_get_functiondef(p),{dollar(x,'old_part')},{dollar(y,'new_part')});
 IF md5(next_sql)<>'{md5(after)}' THEN RAISE EXCEPTION 'review patch reconstruction differs';END IF;EXECUTE next_sql;
 IF md5(pg_get_functiondef(p))<>'{md5(after)}' THEN RAISE EXCEPTION 'review installed definition differs';END IF;END IF;""")
 body='BEGIN;\nSET LOCAL lock_timeout=\'2s\';\nDO $checks$ DECLARE p regprocedure;actual_hash text;actual_acl text;actual_config text[];actual_definer boolean;actual_owner text;next_sql text;BEGIN\n'+'\n'.join(checks)+'\nEND $checks$;\n'
 if not reverse:
  helper_checks=[]
  for name,tag,config in [('review_profile_v450()','profile',['search_path=""']),('review_guard_v450(uuid)','guard',['search_path=""','TimeZone=America/Sao_Paulo']),('expense_review_pending_v450(uuid,date,date)','pending',['search_path=""','TimeZone=America/Sao_Paulo'])]:
   source=re.search(r'AS \$'+tag+r'\$([\s\S]*?)\$'+tag+r'\$',helpers()).group(1)
   cfg='ARRAY['+','.join("'"+x+"'" for x in config)+']'
   helper_checks.append(f"""p:=to_regprocedure('{NS}.{name}');IF p IS NOT NULL THEN
    SELECT md5(prosrc),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner) INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
    IF actual_hash<>'{md5(source)}' OR actual_acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}' OR actual_config IS DISTINCT FROM {cfg} OR actual_definer OR actual_owner<>'postgres' THEN RAISE EXCEPTION 'review helper changed concurrently: %',p;END IF;END IF;""")
  body+='DO $helpers$ DECLARE p regprocedure;actual_hash text;actual_acl text;actual_config text[];actual_definer boolean;actual_owner text;BEGIN\n'+'\n'.join(helper_checks)+'\nEND $helpers$;\n'
 if not reverse:body+=helpers()
 body+='DO $changes$ DECLARE p regprocedure;next_sql text;BEGIN\n'+'\n'.join(changes)+'\nEND $changes$;\nCOMMIT;\n'
 return body
if __name__=='__main__':
 for file,text in [('install.sql',lifecycle()),('rollback.sql',lifecycle(True)),('helpers.sql',helpers())]:(ROOT/file).write_text(text)
 manifest=[{'signature':s,'before':md5(get_original(f)),'after':md5(patch(get_original(f),a,b)),'source_writes':False,'security_changed':False} for s,f,a,b in [(QUEUE,'queue-original.sql',OLD,NEW),(WORKER,'worker-original.sql',WOLD,WNEW)]]
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest))
