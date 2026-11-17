"""Defer the foreground review rebuild while the existing worker owns it."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
TARGET='lts_product_refresh_private_v415.expense_review_pending_v450(uuid,date,date)'
BEFORE='2d41fa5eab16fe79d727c184de79021d'
NEEDLE=' source_guard:=lts_product_refresh_private_v415.review_guard_v450(p_user_id);'
REPLACEMENT=""" -- The existing worker warms this snapshot after marking its own request ready.
 -- Do not compete with that worker or certify an old/empty review meanwhile.
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue q
  WHERE q.user_id=p_user_id AND q.state IN('pending','running')
  AND q.request_version>q.completed_version) THEN
  RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='Expense review is waiting for the existing product refresh';
 END IF;
"""+NEEDLE


def definition(name):
    return (ROOT/name).read_text().rstrip().removesuffix(';')+'\n'


def digest(text):
    return hashlib.md5(text.encode()).hexdigest()


def build():
    before=definition('review-original.sql')
    assert digest(before)==BEFORE and before.count(NEEDLE)==1
    after=before.replace(NEEDLE,REPLACEMENT)
    after_hash=digest(after)
    (ROOT/'review-after.sql').write_text(after.rstrip()+';\n')
    for name,expected,desired,old,new in [
        ('install.sql',BEFORE,after_hash,NEEDLE,REPLACEMENT),
        ('rollback.sql',after_hash,BEFORE,REPLACEMENT,NEEDLE),
    ]:
        (ROOT/name).write_text(f"""-- Return the existing supported not-ready state; never a false empty result.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure:='{TARGET}'::regprocedure; d text; attrs jsonb;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='{expected}' THEN
  IF (length(d)-length(replace(d,$needle${old}$needle$,'')))/length($needle${old}$needle$)<>1
  THEN RAISE EXCEPTION 'V457_REVIEW_READ_SHAPE_CHANGED'; END IF;
  EXECUTE replace(d,$needle${old}$needle$,$replacement${new}$replacement$);
 ELSIF md5(d)<>'{desired}' THEN RAISE EXCEPTION 'V457_PREDECESSOR_CHANGED'; END IF;
 IF md5(pg_get_functiondef(target))<>'{desired}'
 OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V457_FUNCTION_CONTRACT_CHANGED'; END IF;
END $patch$;
COMMIT;
""")
    (ROOT/'manifest.json').write_text(json.dumps({
        'target':TARGET,'predecessor_md5':BEFORE,'installed_md5':after_hash,
        'financial_source_writes':False,'new_jobs':False,'frontend_changes':False,
        'not_ready_sqlstate':'55000',
        'preserved':['every source guard and digest','complete reader when ready',
                     'row values, nulls and duplicates','owner/day/range isolation',
                     'worker warm after its ready update','permissions and function configuration']
    },indent=2)+'\n')


if __name__=='__main__':
    build()
