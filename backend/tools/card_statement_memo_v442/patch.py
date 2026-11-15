"""Reuse exact validated card-cycle output only within one statement/input state."""
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
DECL="DECLARE result jsonb; c6_contract_uncertain boolean; c6_unresolved jsonb; c6_document_ambiguous jsonb;"
END="RETURN public.lts_card_settlement_overlay_v290(p_user_id,public.lts_card_due_overlay_v290(p_user_id,public.lts_card_forecast_overlay_v311(p_user_id,result)));"
PREFIX="""
 -- V442: transaction-local reuse, bound to statement, snapshot, identity and sources.
 memo_v442 jsonb; memo_key_v442 text;
"""
ENTRY="""
 memo_key_v442:=encode(sha256(convert_to(jsonb_build_array(
  p_user_id,current_user,auth.uid(),pg_backend_pid(),statement_timestamp(),
  pg_current_snapshot()::text,current_date,
  (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  lts_product_refresh_private_v415.card_source_key(p_user_id)
 )::text,'UTF8')),'hex');
 BEGIN
  memo_v442:=nullif(current_setting('lts.card_cycles_memo_v442',true),'')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN memo_v442:=NULL;
 END;
 IF memo_v442->>'key'=memo_key_v442
  AND jsonb_typeof(memo_v442->'payload')='object'
  AND memo_v442->>'digest'=encode(sha256(convert_to((memo_v442->'payload')::text,'UTF8')),'hex') THEN
  RETURN memo_v442->'payload';
 END IF;
"""
TAIL="""result:=public.lts_card_settlement_overlay_v290(p_user_id,public.lts_card_due_overlay_v290(p_user_id,public.lts_card_forecast_overlay_v311(p_user_id,result)));
 PERFORM set_config('lts.card_cycles_memo_v442',jsonb_build_object(
  'key',memo_key_v442,'payload',result,
  'digest',encode(sha256(convert_to(result::text,'UTF8')),'hex'))::text,true);
 RETURN result;"""
def patch(source):
 assert source.count(DECL)==1 and source.count(END)==1 and 'memo_v442' not in source
 result=source.replace(DECL,DECL+PREFIX).replace('BEGIN\n','BEGIN\n'+ENTRY,1).replace(END,TAIL)
 restored=result.replace(DECL+PREFIX,DECL).replace('BEGIN\n'+ENTRY,'BEGIN\n',1).replace(TAIL,END)
 assert restored==source,'The complete original financial body must be retained'
 return result
if __name__=='__main__':
 source=(ROOT/'backend/patches/v442/card_cycles_before.sql').read_text()
 expected='b0e83aa15da6ae111484c05c56e0c60e'
 assert hashlib.md5(source.encode()).hexdigest()==expected
 candidate=patch(source)
 (ROOT/'backend/patches/v442/card_cycles_candidate.sql').write_text(candidate)
 sql="""-- V442 changes no financial calculation, grants, timeout or persistent cache.
DO $migration$
DECLARE original text;candidate text;attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT original,attributes
 FROM pg_proc p WHERE p.oid='public.lts_card_cycles_v226(uuid)'::regprocedure;
 IF md5(original)='%s' THEN RETURN;END IF;
 IF md5(original)<>'%s' THEN RAISE EXCEPTION 'V442 predecessor changed; review before applying';END IF;
 candidate:=$candidate$%s$candidate$;
 EXECUTE candidate;
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='public.lts_card_cycles_v226(uuid)'::regprocedure)
  OR md5(pg_get_functiondef('public.lts_card_cycles_v226(uuid)'::regprocedure))<>'%s' THEN
  RAISE EXCEPTION 'V442 attributes or financial body changed unexpectedly';END IF;
END $migration$;
"""%(hashlib.md5(candidate.encode()).hexdigest(),expected,candidate,hashlib.md5(candidate.encode()).hexdigest())
 (ROOT/'backend/patches/v442/install.sql').write_text(sql)
 print({'predecessor_md5':expected,'candidate_md5':hashlib.md5(candidate.encode()).hexdigest()})
