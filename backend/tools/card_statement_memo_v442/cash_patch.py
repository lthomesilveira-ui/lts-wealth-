"""Reuse the original corrected cash result inside one statement; preserve slicing."""
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
DECL='DECLARE memo jsonb; source_epoch bigint; fingerprint text; cache_from date; cache_to date;'
READ=' SELECT c.payload INTO memo FROM public.lts_v229_read_cache c WHERE c.user_id=p_user_id'
READ_END=' ORDER BY c.to_date-c.from_date,c.refreshed_at DESC LIMIT 1;'
RETURN=' RETURN QUERY SELECT r.event_date,r.account,r.description,r.signed_amount,r.source,r.source_ref,r.confidence,r.account_assignment,r.legacy_index,r.original_date,r.displaced'
PREFIX='\n statement_memo_v442 jsonb; statement_key_v442 text;'
ENTRY="""
 statement_key_v442:=encode(sha256(convert_to(jsonb_build_array(
  p_user_id,current_user,auth.uid(),pg_backend_pid(),statement_timestamp(),
  pg_current_snapshot()::text,current_date,current_setting('TimeZone'),source_epoch,
  lts_product_refresh_private_v415.card_source_key(p_user_id)
 )::text,'UTF8')),'hex');
 BEGIN
  statement_memo_v442:=nullif(current_setting('lts.cash_base_memo_v442',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN statement_memo_v442:=NULL;
 END;
 IF statement_memo_v442->>'key'=statement_key_v442
  AND jsonb_typeof(statement_memo_v442->'payload')='array'
  AND statement_memo_v442->>'from'~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND statement_memo_v442->>'to'~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND statement_memo_v442->>'from'<=cache_from::text AND statement_memo_v442->>'to'>=cache_to::text
  AND statement_memo_v442->>'digest'=encode(sha256(convert_to((statement_memo_v442->'payload')::text,'UTF8')),'hex') THEN
  memo:=statement_memo_v442->'payload';
 END IF;
 IF memo IS NULL THEN
"""
STORE=""" PERFORM set_config('lts.cash_base_memo_v442',jsonb_build_object(
  'key',statement_key_v442,'from',cache_from,'to',cache_to,'payload',memo,
  'digest',encode(sha256(convert_to(memo::text,'UTF8')),'hex'))::text,true);
"""
def patch(s):
 for marker in [DECL,READ,READ_END,RETURN]:assert s.count(marker)==1,marker
 assert 'statement_memo_v442' not in s
 r=s.replace(DECL,DECL+PREFIX).replace(READ,ENTRY+READ).replace(RETURN,STORE+' END IF;\n'+RETURN)
 assert r.replace(DECL+PREFIX,DECL).replace(ENTRY+READ,READ).replace(STORE+' END IF;\n'+RETURN,RETURN)==s
 return r
if __name__=='__main__':
 p=ROOT/'backend/patches/v442';s=(p/'cash_base_before.sql').read_text();expected=hashlib.md5(s.encode()).hexdigest();assert expected=='dd65d959b134f4937b7bb3e66fc1cdc6'
 r=patch(s);h=hashlib.md5(r.encode()).hexdigest();(p/'cash_base_candidate.sql').write_text(r)
 previous=(p/'cash_base_memo_v1.sql').read_text();previous_hash=hashlib.md5(previous.encode()).hexdigest();assert previous_hash=='74d485e5ce27f02705136e95dd5fe576'
 (p/'cash_install.sql').write_text("DO $migration$ DECLARE original text;attributes jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT original,attributes FROM pg_proc p WHERE p.oid='public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure;IF md5(original)='"+h+"' THEN RETURN;END IF;IF md5(original) NOT IN('"+expected+"','"+previous_hash+"') THEN RAISE EXCEPTION 'V442 cash predecessor changed';END IF;EXECUTE $candidate$"+r+"$candidate$;IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure) OR md5(pg_get_functiondef('public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure))<>'"+h+"' THEN RAISE EXCEPTION 'V442 cash contract changed';END IF;END $migration$;\n")
 (p/'cash_rollback.sql').write_text("DO $rollback$ BEGIN IF md5(pg_get_functiondef('public.lts_corrected_cashflow_fix86_v1(uuid,date,date)'::regprocedure))<>'"+h+"' THEN RAISE EXCEPTION 'V442 cash changed since installation';END IF;EXECUTE $previous$"+previous+"$previous$;END $rollback$;\n")
 print({'predecessor_md5':expected,'candidate_md5':h})
