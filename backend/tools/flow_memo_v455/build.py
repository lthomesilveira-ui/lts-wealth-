"""Guard the optional flow-key memo write; retain every source-read contract."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TARGET = 'public.lts_flow_read_source_key_v247(uuid)'
HELPER = 'lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)'
BEFORE = 'b65080ab49a211a349b5125aa4c1e48a'
HELPER_HASH = '9c0d1ac15cb98696ef8fc98aca9ef6b6'
NEEDLE = """INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
 VALUES(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key,clock_timestamp())
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;"""
REPLACEMENT = """PERFORM lts_read_private_v430.try_cache_put(p_user_id,'flow_source_key_v243',current_date,current_date,current_date,to_jsonb(key_value),cache_key); /* optional_flow_memo_v455 */"""


def definition(name):
    return (ROOT / name).read_text().rstrip().removesuffix(';') + '\n'


def digest(text):
    return hashlib.md5(text.encode()).hexdigest()


def build():
    original = definition('flow-original.sql')
    helper = definition('helper.sql')
    assert digest(original) == BEFORE
    assert digest(helper) == HELPER_HASH
    assert original.count(NEEDLE) == 1
    after = original.replace(NEEDLE, REPLACEMENT)
    after_hash = digest(after)
    (ROOT / 'flow-after.sql').write_text(after.rstrip() + ';\n')
    for filename, expected, desired, old, new in [
        ('install.sql', BEFORE, after_hash, NEEDLE, REPLACEMENT),
        ('rollback.sql', after_hash, BEFORE, REPLACEMENT, NEEDLE),
    ]:
        script = f"""-- Only a derived cache write changes. No source facts, guards or TTL change.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure:='{TARGET}'::regprocedure; d text; attrs jsonb;
BEGIN
 IF md5(pg_get_functiondef('{HELPER}'::regprocedure))<>'{HELPER_HASH}'
 THEN RAISE EXCEPTION 'V455_OPTIONAL_MEMO_HELPER_CHANGED'; END IF;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{expected}' THEN
  IF (length(d)-length(replace(d,$needle${old}$needle$,'')))/length($needle${old}$needle$)<>1
  THEN RAISE EXCEPTION 'V455_MEMO_WRITE_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle${old}$needle$,$replacement${new}$replacement$);
 ELSIF md5(d)<>'{desired}' THEN RAISE EXCEPTION 'V455_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef(target))<>'{desired}'
 OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V455_FUNCTION_CONTRACT_CHANGED'; END IF;
END $patch$;
COMMIT;
"""
        (ROOT / filename).write_text(script)
    (ROOT / 'manifest.json').write_text(json.dumps({
        'target': TARGET, 'predecessor_md5': BEFORE, 'installed_md5': after_hash,
        'helper': HELPER, 'helper_md5': HELPER_HASH,
        'financial_source_writes': False, 'frontend_changes': False,
        'preserved': ['return value', 'five-minute TTL', 'owner/day/range cache key',
                      'source epoch fence', 'bank freshness', 'scheduled-transfer revision',
                      'source errors', 'function metadata and ACL'],
    }, indent=2) + '\n')


if __name__ == '__main__':
    build()
