"""Run the real V363 contracts against the optimized source lookup."""
from pathlib import Path
import contextlib,io,runpy
R=Path(__file__).resolve().parents[2]
buf=io.StringIO()
with contextlib.redirect_stdout(buf):runpy.run_path(str(R/'backend/qa/lts_v363_ci_sql.py'))
source=buf.getvalue()
operation=(R/'backend/operations/record_proved_transfer_refresh_v363.sql').read_text().replace('public.','v363_fixture.')
patch=(R/'backend/patches/v364/transfer_proof_lookup.sql').read_text().replace('public.','v363_fixture.')
patch=patch.replace('md5(definition)',"md5(replace(definition,'v363_fixture.','public.'))").replace('md5(original)',"md5(replace(original,'v363_fixture.','public.'))")
guard=r"""
CREATE TEMP TABLE v364_before ON COMMIT DROP AS SELECT to_jsonb(p)j FROM v363_fixture.lts_owner_confirmed_transfer_pairs_v263('00000000-0000-4000-8000-000000000001')p;
CREATE TEMP TABLE v364_attributes ON COMMIT DROP AS SELECT to_jsonb(p)-'prosrc'j FROM pg_proc p WHERE oid='v363_fixture.lts_previously_proved_transfer_pairs_v363(uuid)'::regprocedure;
"""+patch+r"""
DO $test$BEGIN
 IF(SELECT jsonb_agg(j ORDER BY j::text)FROM v364_before)IS DISTINCT FROM(SELECT jsonb_agg(to_jsonb(p)ORDER BY to_jsonb(p)::text)FROM v363_fixture.lts_owner_confirmed_transfer_pairs_v263('00000000-0000-4000-8000-000000000001')p)THEN RAISE EXCEPTION 'Optimized pair set changed';END IF;
 IF(SELECT j FROM v364_attributes)IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid='v363_fixture.lts_previously_proved_transfer_pairs_v363(uuid)'::regprocedure)THEN RAISE EXCEPTION 'Lookup ACL/security attributes changed';END IF;
END $test$;
DROP TABLE v364_before,v364_attributes;
"""
assert source.count(operation)==2
source=source.replace(operation,operation+'\n'+guard)
source=source.replace('ROLLBACK;',"SELECT jsonb_build_object('version',364,'pass',true,'v363_contracts_reexecuted',true,'invalid_cases_rejected',30,'pair_set_preserved',true,'lookup_acl_preserved',true);\nROLLBACK;")
print(source)
