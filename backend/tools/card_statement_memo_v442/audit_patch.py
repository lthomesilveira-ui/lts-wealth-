"""Publish the exact full audit in the existing guarded worker transaction."""
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
DECL='DECLARE projection_full_v438 jsonb;'
CALC='  -- Protect publication, briefly, against a concurrent committed source epoch.'
PUT="  UPDATE lts_product_refresh_private_v415.queue SET state='ready',completed_version=ver,"
COMPUTE="""  -- Complete the same calendar audit once, off the browser's 8s request path.
  audit_guard_v442:=lts_product_refresh_private_v415.audit_guard_v442(u);
  audit_v442:=public.lts_recurring_future_gap_audit_v6(u,current_date,lts_projection_private_v412.horizon_end(current_date));
  IF jsonb_typeof(audit_v442->'horizon_checks') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION USING ERRCODE='P0416',MESSAGE='Calendar audit unavailable';
  END IF;
"""
PUBLISH="""  IF audit_guard_v442 IS DISTINCT FROM lts_product_refresh_private_v415.audit_guard_v442(u) THEN
   RAISE EXCEPTION USING ERRCODE='P0415',MESSAGE='Calendar audit sources changed';
  END IF;
  UPDATE public.lts_product_read_cache SET payload=jsonb_set(payload,'{recurring_audit_v442}',jsonb_build_object(
   'guard',audit_guard_v442,'request_version',ver::text,'payload',audit_v442,
   'digest',encode(sha256(convert_to(audit_v442::text,'UTF8')),'hex')),true) WHERE user_id=u;
"""
def patch(s):
 for a in [DECL,CALC,PUT]:assert s.count(a)==1,a
 assert 'audit_v442' not in s
 r=s.replace(DECL,'DECLARE audit_v442 jsonb; audit_guard_v442 jsonb; projection_full_v438 jsonb;').replace(CALC,COMPUTE+CALC).replace(PUT,PUBLISH+PUT)
 assert r.replace('DECLARE audit_v442 jsonb; audit_guard_v442 jsonb; projection_full_v438 jsonb;',DECL).replace(COMPUTE+CALC,CALC).replace(PUBLISH+PUT,PUT)==s
 return r
if __name__=='__main__':
 p=ROOT/'backend/patches/v442';s=(p/'worker_before.sql').read_text();before=hashlib.md5(s.encode()).hexdigest();assert before=='1a40c6d25b2a31928ee0725799c6c3be'
 r=patch(s);after=hashlib.md5(r.encode()).hexdigest();(p/'worker_candidate.sql').write_text(r)
 cache=(p/'audit_cache.sql').read_text()
 wrapper=(p/'audit_wrapper_before.sql').read_text();assert hashlib.md5(wrapper.encode()).hexdigest()=='87aaedf6b08e79e16d9dd7fb2c26c5d0'
 body=cache.split('DECLARE u uuid:=',1)[1].split('$fn$;',1)[0];body='\nDECLARE u uuid:='+body
 (p/'audit_install.sql').write_text("DO $migration$ DECLARE s text;a jsonb;b jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='lts_product_refresh_private_v415.run_claimed()'::regprocedure;IF md5(s) NOT IN('"+before+"','"+after+"') THEN RAISE EXCEPTION 'V442 worker predecessor changed';END IF;SELECT to_jsonb(p)-'prosrc'-'prolang' INTO STRICT b FROM pg_proc p WHERE p.oid='public.lts_browser_recurring_future_gap_audit_v5(date,date)'::regprocedure;IF md5(pg_get_functiondef('public.lts_browser_recurring_future_gap_audit_v5(date,date)'::regprocedure))<>'87aaedf6b08e79e16d9dd7fb2c26c5d0' AND (SELECT prosrc FROM pg_proc WHERE oid='public.lts_browser_recurring_future_gap_audit_v5(date,date)'::regprocedure) IS DISTINCT FROM $body$"+body+"$body$ THEN RAISE EXCEPTION 'V442 audit wrapper predecessor changed';END IF;"+"\nEXECUTE $cache$"+cache+"$cache$;\nEXECUTE $worker$"+r+"$worker$;\nIF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='lts_product_refresh_private_v415.run_claimed()'::regprocedure) OR b IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'-'prolang' FROM pg_proc p WHERE p.oid='public.lts_browser_recurring_future_gap_audit_v5(date,date)'::regprocedure) THEN RAISE EXCEPTION 'V442 worker or audit permissions changed';END IF;END $migration$;\n")
 (p/'audit_rollback.sql').write_text("DO $rollback$ BEGIN IF md5(pg_get_functiondef('lts_product_refresh_private_v415.run_claimed()'::regprocedure))<>'"+after+"' THEN RAISE EXCEPTION 'V442 worker changed since installation';END IF;EXECUTE $worker$"+s+"$worker$;EXECUTE $wrapper$"+wrapper+"$wrapper$;END $rollback$;\n")
 print({'predecessor_md5':before,'candidate_md5':after})
