#!/usr/bin/env python3
"""Exact V438 builder/worker in disposable PG17; source inputs are synthetic."""
from pathlib import Path
import importlib.util

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('memo_fixture',Path(__file__).with_name('test_sql.py'))
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)

def compose():
    migrations=list((ROOT/'supabase/migrations').glob('*_v438_guarded_projection_read.sql'));assert len(migrations)==1
    parts=[fixture.compose(),"""
CREATE SCHEMA qa_v438;
ALTER TABLE public.lts_product_read_cache ADD COLUMN payload jsonb;
CREATE TABLE lts_product_refresh_private_v415.queue(
 user_id uuid PRIMARY KEY,state text,claim_token uuid,claimed_version bigint,claimed_epoch bigint,
 request_version bigint,completed_version bigint,attempts int DEFAULT 1,invalidate_caches boolean DEFAULT false,
 completed_at timestamptz,next_attempt_at timestamptz,lease_expires_at timestamptz,last_error_code text);
CREATE FUNCTION lts_product_refresh_private_v415.allowed_owner(uuid)RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION lts_product_refresh_private_v415.cache_info(uuid)RETURNS jsonb LANGUAGE sql AS $$
 SELECT '{"available":true,"current":true}'::jsonb
$$;
CREATE FUNCTION public.lts_refresh_product_read_cache_v2(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT '{"ok":true}'::jsonb$$;
CREATE FUNCTION public.lts_refresh_product_read_cache_operational_v5(p_user uuid)RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 PERFORM lts_projection_private_v412.build(p_user,current_date);
 CASE current_setting('qa.v438_mode',true)
 WHEN 'epoch' THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;
 WHEN 'receipt' THEN INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
  VALUES(current_date+1,'Itaú','synthetic',-9,'document','new-synthetic-receipt','confirmed');
 WHEN 'damaged' THEN PERFORM set_config('lts.projection_memo_v437',jsonb_set(
  current_setting('lts.projection_memo_v437')::jsonb,'{digest}','"wrong"')::text,true);
 WHEN 'missing' THEN PERFORM set_config('lts.projection_memo_v437','',true);
 ELSE NULL;
 END CASE;
 RETURN '{"ok":true}'::jsonb;
END$$;
CREATE FUNCTION public.lts_c6_completeness_state_v269(p_user uuid)RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('complete',true,'source_revision',lts_product_refresh_private_v415.card_source_key(p_user))
$$;
""",(ROOT/'backend/qa/fixtures/v438/worker_before.sql').read_text(),"""
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.run_claimed() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_product_refresh_private_v415.run_claimed() TO service_role;
CREATE TABLE qa_v438.attributes AS SELECT p.oid,to_jsonb(p)-'prosrc' attrs FROM pg_proc p
 WHERE p.oid IN('lts_projection_private_v412.build(uuid,date)'::regprocedure,
  'lts_product_refresh_private_v415.run_claimed()'::regprocedure);
""",migrations[0].read_text(),"""
SELECT qa_v412.assert('V438 preserves all builder and worker catalog attributes',
 (SELECT bool_and(a.attrs=to_jsonb(p)-'prosrc') FROM qa_v438.attributes a JOIN pg_proc p ON p.oid=a.oid));
""",migrations[0].read_text(),"""
CREATE FUNCTION qa_v438.policy(p_owner uuid)RETURNS jsonb LANGUAGE sql SET TimeZone='America/Sao_Paulo' AS $$
 SELECT lts_projection_private_v412.owner_policy(p_owner)||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_owner))
$$;
CREATE FUNCTION qa_v438.cached(p_owner uuid,p_date date DEFAULT current_date)RETURNS jsonb LANGUAGE sql AS $$
 SELECT lts_projection_private_v412.read_build_cache_v438(p_owner,p_date,qa_v438.policy(p_owner))
$$;
CREATE FUNCTION qa_v438.publish(p_owner uuid,p_mode text DEFAULT '')RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE ver bigint;token uuid:=gen_random_uuid();epoch_now bigint;
BEGIN
 INSERT INTO lts_product_refresh_private_v415.queue(user_id,request_version,attempts)
 VALUES(p_owner,0,1) ON CONFLICT(user_id) DO NOTHING;
 SELECT epoch INTO epoch_now FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 UPDATE lts_product_refresh_private_v415.queue SET request_version=request_version+1,completed_version=NULL,
  state='running',claim_token=token,claimed_version=request_version+1,claimed_epoch=epoch_now,
  attempts=1,last_error_code=NULL WHERE user_id=p_owner RETURNING request_version INTO ver;
 PERFORM set_config('qa.v438_mode',p_mode,true);
 PERFORM set_config('lts.product_refresh_claim',jsonb_build_object('user_id',p_owner,'token',token,'version',ver,'epoch',epoch_now)::text,false);
 RETURN lts_product_refresh_private_v415.run_claimed();
END$$;
DO $checks$
DECLARE u uuid:=qa_v412.owner();a jsonb;b jsonb;r jsonb;h text;n int;prior jsonb;old_epoch bigint;
BEGIN
 INSERT INTO public.lts_product_read_cache(user_id,payload)VALUES(u,'{"fixture":true}')
 ON CONFLICT DO NOTHING;
 PERFORM qa_v412.assert('missing publication is a cache miss',qa_v438.cached(u) IS NULL);
 h:=qa_v412.financial_hash();
 r:=qa_v438.publish(u);
 PERFORM qa_v412.assert('worker publishes full memo atomically with ready state',r->>'published'='true'
  AND (SELECT state='ready' AND request_version=completed_version FROM lts_product_refresh_private_v415.queue WHERE user_id=u));
 a:=qa_v438.cached(u);
 b:=lts_projection_private_v412.build_before_v437(u,current_date);
 PERFORM qa_v412.assert('published full projection equals unchanged original builder',a=b AND a IS NOT NULL,
  jsonb_build_object('cache_null',a IS NULL,'queue',(SELECT to_jsonb(q) FROM lts_product_refresh_private_v415.queue q WHERE user_id=u),
   'meta',(SELECT (payload->'projection_build_v438')-'payload' FROM public.lts_product_read_cache WHERE user_id=u),
   'policy_fp',md5(qa_v438.policy(u)::text),'source_key',lts_product_refresh_private_v415.card_source_key(u)));
 n:=qa_v437.computations();
 b:=lts_projection_private_v412.build(u,current_date);
 PERFORM qa_v412.assert('normal read reuses published result without calculation',b=a AND qa_v437.computations()=n);
 PERFORM qa_v412.assert('publication and reuse do not change financial inputs',h=qa_v412.financial_hash());
 PERFORM qa_v412.assert('other owner never receives published projection',qa_v438.cached(qa_v412.owner(2)) IS NULL);
 PERFORM qa_v412.assert('another as-of date cannot receive current projection',qa_v438.cached(u,current_date-1) IS NULL);
 UPDATE lts_product_refresh_private_v415.queue SET state='pending' WHERE user_id=u;
 PERFORM qa_v412.assert('pending update cannot serve old projection',qa_v438.cached(u) IS NULL);
 UPDATE lts_product_refresh_private_v415.queue SET state='ready',completed_version=request_version-1 WHERE user_id=u;
 PERFORM qa_v412.assert('superseded version cannot serve old projection',qa_v438.cached(u) IS NULL);
 UPDATE lts_product_refresh_private_v415.queue SET completed_version=request_version WHERE user_id=u;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;
 PERFORM qa_v412.assert('epoch change rejects published projection immediately',qa_v438.cached(u) IS NULL);
 r:=qa_v438.publish(u);
 INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES(current_date+2,'Itaú','synthetic',-3,'document','receipt-without-epoch','confirmed');
 PERFORM qa_v412.assert('receipt-only change rejects published projection',qa_v438.cached(u) IS NULL);
 r:=qa_v438.publish(u);
 PERFORM qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":333,"due_day":15}'));
 PERFORM qa_v412.assert('policy change rejects published projection without epoch change',qa_v438.cached(u) IS NULL);
 r:=qa_v438.publish(u);
 PERFORM qa_v412.set_reference(jsonb_set(qa_v412.reference(),'{revision}','8'));
 PERFORM qa_v412.assert('reference change rejects published projection without epoch change',qa_v438.cached(u) IS NULL);
 r:=qa_v438.publish(u);
 UPDATE public.lts_product_read_cache SET payload=jsonb_set(payload,'{projection_build_v438,digest}','"wrong"') WHERE user_id=u;
 PERFORM qa_v412.assert('damaged published memo is rejected',qa_v438.cached(u) IS NULL);
 r:=qa_v438.publish(u,'missing');
 PERFORM qa_v412.assert('worker rebuilds a missing full memo before publication',r->>'published'='true' AND qa_v438.cached(u) IS NOT NULL);
 SELECT payload INTO prior FROM public.lts_product_read_cache WHERE user_id=u;
 h:=qa_v412.financial_hash();
 r:=qa_v438.publish(u,'epoch');
 PERFORM qa_v412.assert('epoch mismatch rolls back publication and all source changes',r->>'error_code'='refresh_superseded'
  AND prior=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=u) AND h=qa_v412.financial_hash());
 r:=qa_v438.publish(u,'receipt');
 PERFORM qa_v412.assert('receipt mismatch rolls back publication independently of epoch',r->>'error_code'='refresh_superseded'
  AND prior=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=u) AND h=qa_v412.financial_hash());
 r:=qa_v438.publish(u,'damaged');
 PERFORM qa_v412.assert('damaged worker memo cannot publish ready state',r->>'error_code'='refresh_contract_invalid'
  AND prior=(SELECT payload FROM public.lts_product_read_cache WHERE user_id=u));
 r:=qa_v438.publish(u);
 PERFORM qa_v412.assert('valid retry publishes an exact current projection',r->>'published'='true'
  AND qa_v438.cached(u)=lts_projection_private_v412.build_before_v437(u,current_date));
END$checks$;
SELECT qa_v412.assert('new private cache helper is not browser-executable',
 NOT has_function_privilege('anon','lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)','EXECUTE')
 AND NOT has_function_privilege('authenticated','lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)','EXECUTE'));
SELECT jsonb_build_object('pass',bool_and(pass),'checks',count(*),'runtime',version(),
 'scope','Synthetic exact builder and worker; no real session, device, restore or physical-I/O certification',
 'cases',jsonb_agg(name ORDER BY name))FROM qa_v412.results;
"""]
    return '\n'.join(parts)

if __name__=='__main__':print(compose())
