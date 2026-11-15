"""Reuse unchanged payroll/history results within one statement; no worker change."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[3];P=ROOT/'backend/patches/v442'
SPECS={
 'payroll':('public.lts_payroll_bank_matches_v231(uuid)','3b3d5eaf223fb089c627216199965af3'," SELECT payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id"," AND c.source_fingerprint=fingerprint AND c.refreshed_at>clock_timestamp()-interval '5 minutes';"),
 'history':('public.lts_historical_effective_cash_v4(uuid,date,date)','558708b14bd9546d7ed88a0618947565'," SELECT payload INTO memo FROM public.lts_v229_read_cache c"," ORDER BY c.to_date-c.from_date,c.refreshed_at DESC LIMIT 1;")}
def patch(s,name):
 _,_,start,end=SPECS[name]
 for v in[start,end,'DECLARE memo jsonb;',' RETURN QUERY SELECT r.']:assert s.count(v)==1,v
 guc='lts.'+name+'_memo_v442';args='p_user_id' if name=='payroll' else 'p_user_id,p_from,p_to'
 entry="""
 memo_key_v442:=encode(sha256(convert_to(jsonb_build_array(%s,current_user,auth.uid(),pg_backend_pid(),statement_timestamp(),pg_current_snapshot()::text,current_date,current_setting('TimeZone'),source_epoch,lts_product_refresh_private_v415.card_source_key(p_user_id))::text,'UTF8')),'hex');
 BEGIN saved_v442:=nullif(current_setting('%s',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN saved_v442:=NULL;END;
 entry_v442:=saved_v442#>ARRAY['entries',memo_key_v442];
 IF saved_v442->>'statement'=statement_timestamp()::text AND jsonb_typeof(entry_v442->'payload')='array'
 AND entry_v442->>'digest'=encode(sha256(convert_to((entry_v442->'payload')::text,'UTF8')),'hex') THEN memo:=entry_v442->'payload';END IF;
 IF memo IS NULL THEN
"""%(args,guc)
 store=""" -- Merge again after the engine: nested reads may have memoized another range.
 BEGIN saved_v442:=nullif(current_setting('%s',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN saved_v442:=NULL;END;
 IF saved_v442->>'statement' IS DISTINCT FROM statement_timestamp()::text OR jsonb_typeof(saved_v442->'entries') IS DISTINCT FROM 'object'
 THEN saved_v442:=jsonb_build_object('statement',statement_timestamp()::text,'entries','{}'::jsonb);END IF;
 IF (SELECT count(*) FROM jsonb_object_keys(saved_v442->'entries'))>=16
 THEN saved_v442:=jsonb_build_object('statement',statement_timestamp()::text,'entries','{}'::jsonb);END IF;
 saved_v442:=jsonb_set(saved_v442,ARRAY['entries',memo_key_v442],jsonb_build_object('payload',memo,'digest',encode(sha256(convert_to(memo::text,'UTF8')),'hex')));
 PERFORM set_config('%s',saved_v442::text,true);
 END IF;
"""%(guc,guc)
 decl='DECLARE saved_v442 jsonb; entry_v442 jsonb; memo_key_v442 text; memo jsonb;'
 r=s.replace('DECLARE memo jsonb;',decl).replace(start,entry+start).replace(' RETURN QUERY SELECT r.',store+' RETURN QUERY SELECT r.')
 restored=r.replace(decl,'DECLARE memo jsonb;').replace(entry+start,start).replace(store+' RETURN QUERY SELECT r.',' RETURN QUERY SELECT r.');assert restored==s
 if name=='history':
  a=""" INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
  VALUES(p_user_id,'historical_cash_v4_v243',current_date,p_from,p_to,memo,'cash-v243:'||source_epoch,clock_timestamp())
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;"""
  b=" PERFORM lts_read_private_v430.try_cache_put(p_user_id,'historical_cash_v4_v243',current_date,p_from,p_to,memo,'cash-v243:'||source_epoch); /* optional_memo_v442 */"
  assert r.count(a)==1;r=r.replace(a,b)
 return r
def build():
 installs=[]
 for name,(signature,expected,_,_)in SPECS.items():
  s=(P/(name+'_before.sql')).read_text();assert hashlib.md5(s.encode()).hexdigest()==expected
  r=patch(s,name);h=hashlib.md5(r.encode()).hexdigest();(P/(name+'_candidate.sql')).write_text(r)
  previous=(P/(name+'_memo_v1.sql')).read_text();previous_hash=hashlib.md5(previous.encode()).hexdigest()
  assert previous_hash=={'payroll':'7b0f4ddd2e6eade1d79261ecfce617ac','history':'8f34e3bcad3c810b6b045b05f7ff52d6'}[name]
  installs.append("DO $guard$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='"+signature+"'::regprocedure;IF md5(s)='"+h+"' THEN RETURN;END IF;IF md5(s) NOT IN('"+expected+"','"+previous_hash+"') THEN RAISE EXCEPTION 'V442 "+name+" predecessor changed';END IF;EXECUTE $candidate$"+r+"$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='"+signature+"'::regprocedure) OR md5(pg_get_functiondef('"+signature+"'::regprocedure))<>'"+h+"' THEN RAISE EXCEPTION 'V442 "+name+" attributes changed';END IF;END $guard$;\n")
  (P/(name+'_rollback.sql')).write_text("DO $rollback$ BEGIN IF md5(pg_get_functiondef('"+signature+"'::regprocedure))<>'"+h+"' THEN RAISE EXCEPTION 'V442 "+name+" changed since installation';END IF;EXECUTE $previous$"+previous+"$previous$;END $rollback$;\n")
  print(name,h)
 (P/'auxiliary_memo_install.sql').write_text('\n'.join(installs))
if __name__=='__main__':build()
