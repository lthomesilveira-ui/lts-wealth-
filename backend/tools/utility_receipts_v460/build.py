"""Add a guarded, read-only identity for an already retired paid utility forecast."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
SOURCE='public.lts_recurring_receipt_identities_v303(uuid,date)'
PROFILE='lts_product_refresh_private_v415.review_profile_v450()'
HELPER='lts_receipt_private_v460.utility_receipts(uuid,date)'
OLD_SOURCE='fbb5db9c22d8b9e8de6137ea3ebd37d1'
OLD_PROFILE='219dba6201aa21e8603b9959b7c7c32d'
NEEDLE=', candidates AS (SELECT * FROM payroll UNION ALL SELECT * FROM cards UNION ALL SELECT * FROM aeternum)'
REPLACEMENT=', utilities AS MATERIALIZED (SELECT * FROM lts_receipt_private_v460.utility_receipts(p_user_id,p_as_of))'+NEEDLE[:-1]+' UNION ALL SELECT * FROM utilities)'

def definition(name):return (ROOT/name).read_text().rstrip().removesuffix(';')+'\n'
def md5(s):return hashlib.md5(s.encode()).hexdigest()

def patch_target(signature,before,after):
    return f""" target:='{signature}'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{md5(before)}' THEN EXECUTE $definition${after.rstrip()}$definition$;
 ELSIF md5(d)<>'{md5(after)}' THEN RAISE EXCEPTION 'V460_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'{md5(after)}' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V460_FUNCTION_CONTRACT_CHANGED';END IF;
"""

def build():
    source=definition('source-original.sql');profile=definition('profile-original.sql');helper=definition('helper.sql')
    assert md5(source)==OLD_SOURCE and md5(profile)==OLD_PROFILE
    assert source.count(NEEDLE)==1
    after=source.replace(NEEDLE,REPLACEMENT)
    old_manifest=profile.split('$manifest$')[1]
    manifest=json.loads(old_manifest)
    assert not any(x['signature'] in (SOURCE,HELPER) for x in manifest['producers'])
    manifest['producers'] += [{'signature':SOURCE,'md5':md5(after)},{'signature':HELPER,'md5':md5(helper)}]
    after_profile=profile.replace(old_manifest,json.dumps(manifest,ensure_ascii=False,indent=2))
    (ROOT/'source-after.sql').write_text(after.rstrip()+';\n')
    (ROOT/'profile-after.sql').write_text(after_profile.rstrip()+';\n')
    for filename,reverse in [('install.sql',False),('rollback.sql',True)]:
        parts=["BEGIN;\nSET LOCAL lock_timeout='2s';\nSET LOCAL statement_timeout='10s';\nDO $patch$\nDECLARE target regprocedure; d text; attrs jsonb; u uuid;\nBEGIN\n",
        " IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'V460_WORKER_ACTIVE';END IF;\n",
        " FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V460_WORKER_LOCK_BUSY';END IF;END LOOP;\n"]
        if reverse:
            parts.append(" IF EXISTS(SELECT 1 FROM public.projecao_op WHERE dados->>'status'='ativa' AND dados#>>'{reconciliation,basis}'='posted_unique_utility_receiver_plus_prior_owner_classification') THEN RAISE EXCEPTION 'V460_UTILITY_RECEIPTS_IN_USE';END IF;\n")
        else:
            parts.append(f""" IF to_regnamespace('lts_receipt_private_v460') IS NULL THEN
  EXECUTE 'CREATE SCHEMA lts_receipt_private_v460';
 ELSIF to_regprocedure('{HELPER}') IS NULL THEN RAISE EXCEPTION 'V460_UNRECOGNIZED_SCHEMA';END IF;
 IF EXISTS(SELECT 1 FROM pg_class WHERE relnamespace='lts_receipt_private_v460'::regnamespace)
 OR EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace='lts_receipt_private_v460'::regnamespace AND oid<>coalesce(to_regprocedure('{HELPER}'),0))
 THEN RAISE EXCEPTION 'V460_UNRECOGNIZED_SCHEMA';END IF;
 target:=to_regprocedure('{HELPER}');
 IF target IS NOT NULL THEN
  IF md5(pg_get_functiondef(target))<>'{md5(helper)}' THEN RAISE EXCEPTION 'V460_HELPER_DRIFT';END IF;
 END IF;
 EXECUTE $helper${helper.rstrip()}$helper$;
 REVOKE ALL ON SCHEMA lts_receipt_private_v460 FROM PUBLIC,anon,authenticated;
 REVOKE ALL ON FUNCTION {HELPER} FROM PUBLIC,anon,authenticated;
 IF md5(pg_get_functiondef('{HELPER}'::regprocedure))<>'{md5(helper)}'
 OR (SELECT prosecdef OR provolatile<>'s' FROM pg_proc WHERE oid='{HELPER}'::regprocedure)
 OR has_schema_privilege('anon','lts_receipt_private_v460','USAGE') OR has_schema_privilege('authenticated','lts_receipt_private_v460','USAGE')
 OR has_function_privilege('anon','{HELPER}','EXECUTE') OR has_function_privilege('authenticated','{HELPER}','EXECUTE')
 THEN RAISE EXCEPTION 'V460_PRIVATE_HELPER_CONTRACT';END IF;
""")
        for sig,old,new in [(SOURCE,source,after),(PROFILE,profile,after_profile)]:
            parts.append(patch_target(sig,new,old) if reverse else patch_target(sig,old,new))
        parts.append('END $patch$;\nCOMMIT;\n')
        (ROOT/filename).write_text(''.join(parts))
    (ROOT/'manifest.json').write_text(json.dumps({'source':SOURCE,'source_before_md5':OLD_SOURCE,'source_after_md5':md5(after),
     'profile_before_md5':OLD_PROFILE,'profile_after_md5':md5(after_profile),'helper':HELPER,'helper_md5':md5(helper),
     'existing_profile_entries_changed':0,'new_closed_profile_producers':2,'financial_writes':False,
     'new_public_permissions':False,'timeouts_changed':False,'helper_security':'invoker/private/read-only'},indent=2)+'\n')

if __name__=='__main__':build()
