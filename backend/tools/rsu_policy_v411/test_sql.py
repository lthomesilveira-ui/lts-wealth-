"""Emit a complete disposable PostgreSQL17 integration test; no production inputs."""
from pathlib import Path
import json
from setup import build as fixture
from build_migration import build as migration

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent

def build():
    patch=migration()
    specs=json.loads((ROOT/'backend/patches/v411/consumer_manifest.json').read_text())
    signatures=','.join("('"+s['signature']+"')" for s in specs)
    guard='\n'.join("SELECT qa_assert_v411('exact predecessor: "+s['signature']+"',md5(pg_get_functiondef('"+s['signature']+"'::regprocedure))='"+s['before_md5']+"');" for s in specs)
    attributes="""
CREATE TABLE qa_consumer_attributes_v411 AS
 SELECT p.oid,to_jsonb(p)-'prosrc' attributes FROM pg_proc p
 WHERE p.oid IN(SELECT sig::regprocedure FROM(VALUES %s)s(sig));
"""%signatures
    rollback="""
SELECT qa_assert_v411('migration transaction rolls back completely',
 to_regprocedure('public.lts_browser_rsu_policy_v411()') IS NULL
 AND md5(pg_get_viewdef('public.lts_future_liquidity_effective_v290'::regclass,true))='58b622a70fdb6522ae0c9b9dde9342f5'
 AND(SELECT epoch=10 FROM lts_read_cache_epoch_v242 WHERE singleton)
 AND(SELECT count(*)=2 FROM lts_product_read_cache));
"""
    cache="""
SELECT qa_assert_v411('cache epoch advances exactly once including replay',
 (SELECT epoch=11 FROM lts_read_cache_epoch_v242 WHERE singleton));
SELECT qa_assert_v411('only configured owner derived caches invalidated',
 (SELECT count(*)=1 AND min(user_id::text)='00000000-0000-4000-8000-000000000002' FROM lts_product_read_cache)
 AND(SELECT count(*)=1 AND min(user_id::text)='00000000-0000-4000-8000-000000000002' FROM lts_dashboard_cockpit_cache)
 AND(SELECT count(*)=1 AND min(user_id::text)='00000000-0000-4000-8000-000000000002' FROM lts_flow_future_read_cache)
 AND(SELECT count(*)=1 AND min(user_id::text)='00000000-0000-4000-8000-000000000002' FROM lts_flow_future_read_cache_v2)
 AND(SELECT count(*)=1 AND min(user_id::text)='00000000-0000-4000-8000-000000000002' FROM lts_v229_read_cache));
SELECT qa_assert_v411('all consumer identity ACL owner and configuration preserved',
 (SELECT bool_and(a.attributes=to_jsonb(p)-'prosrc') FROM qa_consumer_attributes_v411 a JOIN pg_proc p ON p.oid=a.oid));
"""
    drift="""
DO $qa_drift$
DECLARE blocked boolean:=false;d text;
BEGIN
 BEGIN
  d:=pg_get_functiondef('public.lts_daily_flow_fix86_v19(uuid,date,date)'::regprocedure);
  EXECUTE replace(d,'begin','begin -- synthetic unexpected predecessor');
  BEGIN EXECUTE $migration$MIGRATION$migration$;
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'V411 consumer drift:%' THEN blocked:=true;ELSE RAISE;END IF;END;
  RAISE SQLSTATE 'P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 PERFORM qa_assert_v411('consumer drift aborts without partial installation',blocked);
 blocked:=false;
 BEGIN
  d:=pg_get_functiondef('lts_award_private.net_value_v411(uuid,text,numeric,numeric)'::regprocedure);
  EXECUTE replace(d,'Componente de RSU sem valor bruto válido.','Synthetic changed message.');
  BEGIN EXECUTE $migration$MIGRATION$migration$;
  EXCEPTION WHEN raise_exception THEN IF SQLERRM LIKE 'V411 core definition drift:%' THEN blocked:=true;ELSE RAISE;END IF;END;
  RAISE SQLSTATE 'P9999';
 EXCEPTION WHEN SQLSTATE 'P9999' THEN NULL;END;
 PERFORM qa_assert_v411('core drift aborts before installation',blocked);
END $qa_drift$;
""".replace('MIGRATION',patch)
    report="""
SELECT jsonb_build_object('pass',bool_and(passed),'checks',count(*),'postgres_version',version(),
 'cache_epoch',(SELECT epoch FROM lts_read_cache_epoch_v242 WHERE singleton),
 'results',jsonb_agg(to_jsonb(q)ORDER BY name)) FROM qa_checks_v411 q;
"""
    return '\n'.join(['BEGIN;',fixture(),guard,attributes,'COMMIT;','BEGIN;',patch,'ROLLBACK;',rollback,
      'BEGIN;',patch,'COMMIT;','BEGIN;',patch,'COMMIT;',cache,
      (HERE/'verify.sql').read_text(),drift,cache,report])

if __name__=='__main__':print(build())
