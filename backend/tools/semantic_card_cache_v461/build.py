"""Preserve prepared cards across sync bookkeeping; guard all semantic source data."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = 'lts_product_refresh_private_v415.card_source_key(uuid)'
CONSUMER = 'public.lts_c6_completeness_state_v269(uuid)'
PROFILE = 'lts_product_refresh_private_v415.review_profile_v450()'
OLD = {SOURCE:'5fc273e25705711595caa96fee9f691d', CONSUMER:'d0e199988d394dd3e875f8c059933fe7', PROFILE:'307c43cfe2b9ecc89f60eb95b6c77c45'}
NEEDLE = 'jsonb_build_array(s.id,s.sync_run_id,s.last_seen_at,s.updated_at)::text'
REPLACEMENT = "(to_jsonb(s)-ARRAY['sync_run_id','last_seen_at','updated_at'])::text"
OLD_COMMENT = '-- Financial inputs in every bank are guarded by the existing epoch triggers.\n -- Include receipt-only fields explicitly: V246 deliberately ignores these.'
NEW_COMMENT = '-- Keep every semantic source field, including receipt and deletion evidence.\n -- Match V246: sync_run_id, last_seen_at and updated_at are bookkeeping only.'

def definition(name): return (ROOT/name).read_text().rstrip().removesuffix(';')+'\n'
def md5(s): return hashlib.md5(s.encode()).hexdigest()

def patch_target(signature,before,after):
    return f""" target:='{signature}'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{md5(before)}' THEN EXECUTE $definition${after.rstrip()}$definition$;
 ELSIF md5(d)<>'{md5(after)}' THEN RAISE EXCEPTION 'V461_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'{md5(after)}' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V461_FUNCTION_CONTRACT_CHANGED';END IF;
"""

def build():
    original = {SOURCE:definition('source-original.sql'),CONSUMER:definition('consumer-original.sql'),PROFILE:definition('profile-original.sql')}
    assert all(md5(text)==OLD[sig] for sig,text in original.items())
    after = {}
    for sig in (SOURCE,CONSUMER):
        text=original[sig]
        assert text.count(NEEDLE)==1 and text.count(OLD_COMMENT)==1
        after[sig]=text.replace(NEEDLE,REPLACEMENT).replace(OLD_COMMENT,NEW_COMMENT)
    profile=original[PROFILE]
    manifest=json.loads(profile.split('$manifest$')[1])
    for sig in (SOURCE,CONSUMER):
        assert sum(p['signature']==sig and p['md5']==OLD[sig] for p in manifest['producers'])==1
        assert profile.count(OLD[sig])==1
        profile=profile.replace(OLD[sig],md5(after[sig]))
    after[PROFILE]=profile
    for sig,name in [(SOURCE,'source'),(CONSUMER,'consumer'),(PROFILE,'profile')]:
        (ROOT/(name+'-after.sql')).write_text(after[sig].rstrip()+';\n')
    for filename,reverse in [('install.sql',False),('rollback.sql',True)]:
        parts=["BEGIN;\nSET LOCAL lock_timeout='2s';\nSET LOCAL statement_timeout='10s';\nDO $patch$\nDECLARE target regprocedure; d text; attrs jsonb; u uuid;\nBEGIN\n",
        " IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'V461_WORKER_ACTIVE';END IF;\n",
        " FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V461_WORKER_LOCK_BUSY';END IF;END LOOP;\n"]
        for sig in (SOURCE,CONSUMER,PROFILE):
            parts.append(patch_target(sig,after[sig],original[sig]) if reverse else patch_target(sig,original[sig],after[sig]))
        parts.append('END $patch$;\nCOMMIT;\n')
        (ROOT/filename).write_text(''.join(parts))
    (ROOT/'manifest.json').write_text(json.dumps({'functions':{sig:{'before':OLD[sig],'after':md5(after[sig])} for sig in after},
      'excluded_bookkeeping_fields':['sync_run_id','last_seen_at','updated_at'], 'profile_pins_updated':2,
      'other_profile_changes':False,'financial_writes':False,'permissions_changed':False,'timeouts_changed':False},indent=2)+'\n')

if __name__=='__main__': build()
