"""Use a verified financial epoch, falling back to semantic rows on trigger drift."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = 'lts_product_refresh_private_v415.card_source_key(uuid)'
CONSUMER = 'public.lts_c6_completeness_state_v269(uuid)'
PROFILE = 'lts_product_refresh_private_v415.review_profile_v450()'
OLD = {SOURCE:'634d70ed1d1a21967b9358ffc2bd6e6e', CONSUMER:'64ba10c612e4641199ee10de7490ffba', PROFILE:'43ff6694dea1f02138fe570eaff6aaec'}
NEEDLE = "coalesce((SELECT string_agg((to_jsonb(s)-ARRAY['sync_run_id','last_seen_at','updated_at'])::text,'' ORDER BY s.id)\n   FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id),'')"
REPLACEMENT = "CASE WHEN current_setting('session_replication_role')='origin'\n   AND md5(pg_get_functiondef('public.lts_v246_invalidate_finance_cache()'::regprocedure))='99f49c4f11e130d6cab4196173f41ec0'\n   AND (SELECT md5(string_agg(t.tgname::text||t.tgenabled::text||pg_get_triggerdef(t.oid),'|' ORDER BY t.tgname))\n    FROM pg_trigger t WHERE t.tgrelid='public.lts_open_finance_staging'::regclass AND NOT t.tgisinternal)='3a4e2f69a3c7ae6d2564028a67121893'\n   THEN 'v462-guarded-staging-epoch:'||p_user_id::text\n   ELSE coalesce((SELECT string_agg((to_jsonb(s)-ARRAY['sync_run_id','last_seen_at','updated_at'])::text,'' ORDER BY s.id)\n   FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id),'') END"
OLD_COMMENT = '-- Keep every semantic source field, including receipt and deletion evidence.\n -- Match V246: sync_run_id, last_seen_at and updated_at are bookkeeping only.'
NEW_COMMENT = '-- The exact enabled statement triggers cover every semantic staging change.\n -- Unknown/disabled trigger contracts fall back to the complete semantic rows.'

def definition(name): return (ROOT/name).read_text().rstrip().removesuffix(';')+'\n'
def md5(s): return hashlib.md5(s.encode()).hexdigest()

def patch_target(signature,before,after):
    return f""" target:='{signature}'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{md5(before)}' THEN EXECUTE $definition${after.rstrip()}$definition$;
 ELSIF md5(d)<>'{md5(after)}' THEN RAISE EXCEPTION 'V462_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'{md5(after)}' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V462_FUNCTION_CONTRACT_CHANGED';END IF;
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
        " IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'V462_WORKER_ACTIVE';END IF;\n",
        " FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V462_WORKER_LOCK_BUSY';END IF;END LOOP;\n"]
        for sig in (SOURCE,CONSUMER,PROFILE):
            parts.append(patch_target(sig,after[sig],original[sig]) if reverse else patch_target(sig,original[sig],after[sig]))
        parts.append('END $patch$;\nCOMMIT;\n')
        (ROOT/filename).write_text(''.join(parts))
    (ROOT/'manifest.json').write_text(json.dumps({'functions':{sig:{'before':OLD[sig],'after':md5(after[sig])} for sig in after},
      'excluded_bookkeeping_fields':['sync_run_id','last_seen_at','updated_at'], 'profile_pins_updated':2,'epoch_trigger_md5':'99f49c4f11e130d6cab4196173f41ec0','staging_triggers_md5':'3a4e2f69a3c7ae6d2564028a67121893','unknown_trigger_contract':'full_semantic_row_fallback',
      'other_profile_changes':False,'financial_writes':False,'permissions_changed':False,'timeouts_changed':False},indent=2)+'\n')

if __name__=='__main__': build()
