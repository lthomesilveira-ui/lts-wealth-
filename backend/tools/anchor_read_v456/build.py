"""Avoid a write lock when the canonical liquidity anchor is already current."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TARGET = 'public.lts_apply_current_liquidity_anchor_v1(uuid)'
BEFORE = '9c49edc420a9661d2dfe5bef45db9371'
LOCKED = 'select * into c from public.lts_product_read_cache where user_id=p_user_id for update;'
UNLOCKED = 'select * into c from public.lts_product_read_cache where user_id=p_user_id;'
CHECK = """ if not found then raise exception 'product cache unavailable'; end if;
 k:=public.lts_dashboard_source_key_v240(p_user_id);
 cached_key:=public.lts_dashboard_payload_key_v240(c.payload);
 if c.payload#>>'{canonical_summary,source_key}'=k and c.payload#>>'{canonical_summary,payload_key}'=cached_key then
  return jsonb_build_object('ok',true,'version','canonical-cache-v240','cache_hit',true);
 end if;"""
NEEDLE = ' ' + LOCKED + '\n' + CHECK
REPLACEMENT = (' ' + UNLOCKED + '\n' + CHECK +
               '\n -- A cache hit is read-only. Only a real rebuild takes the original lock;\n'
               ' -- recheck after acquiring it because another writer may have finished.\n ' + LOCKED + '\n' + CHECK)


def definition(name):
    return (ROOT / name).read_text().rstrip().removesuffix(';') + '\n'


def digest(text):
    return hashlib.md5(text.encode()).hexdigest()


def build():
    before = definition('anchor-original.sql')
    assert digest(before) == BEFORE
    assert before.count(NEEDLE) == 1
    after = before.replace(NEEDLE, REPLACEMENT)
    after_hash = digest(after)
    (ROOT / 'anchor-after.sql').write_text(after.rstrip() + ';\n')
    for name, expected, desired, old, new in [
        ('install.sql', BEFORE, after_hash, NEEDLE, REPLACEMENT),
        ('rollback.sql', after_hash, BEFORE, REPLACEMENT, NEEDLE),
    ]:
        (ROOT / name).write_text(f"""-- Avoid a row lock only for a fully validated canonical cache hit.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure:='{TARGET}'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{expected}' THEN
  IF (length(d)-length(replace(d,$needle${old}$needle$,'')))/length($needle${old}$needle$)<>1
  THEN RAISE EXCEPTION 'V456_ANCHOR_READ_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle${old}$needle$,$replacement${new}$replacement$);
 ELSIF md5(d)<>'{desired}' THEN RAISE EXCEPTION 'V456_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef(target))<>'{desired}'
 OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V456_FUNCTION_CONTRACT_CHANGED'; END IF;
END $patch$;
COMMIT;
""")
    (ROOT / 'manifest.json').write_text(json.dumps({
        'target':TARGET, 'predecessor_md5':BEFORE,'installed_md5':after_hash,
        'financial_source_writes':False,'frontend_changes':False,
        'preserved':['source and payload fingerprints','complete rebuild on a miss',
                     'write lock and post-lock recheck on a miss','return values',
                     'unavailable-source errors','permissions and function configuration']
    },indent=2)+'\n')


if __name__ == '__main__':
    build()
