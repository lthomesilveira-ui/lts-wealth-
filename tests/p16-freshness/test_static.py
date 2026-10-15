from pathlib import Path
import re
p=Path(__file__).parent
old=(p/'baseline.sql').read_text();new=(p/'candidate.sql').read_text();expr=(p/'timestamp-expression.sql').read_text()
addition="\n        'provider_item_updated_at',"+expr+","
assert new.replace(addition,'',1)==old
assert new.count(addition)==1
assert expr.count('::pg_catalog.timestamptz')==2
assert "pg_catalog.pg_input_is_valid" in expr and "'pg_catalog.timestamptz'" in expr
assert 'r.user_id=v_uid and r.connection_id=c.id' in expr
assert "r.status='success' and r.finished_at=c.last_success_at" in expr
assert 'r.match_count=1' in expr
assert expr.replace('public.lts_open_finance_sync_run','adjusted').replace('r.user_id=v_uid','r.user_id=c.user_id') in (p/'fixtures.sql').read_text()
for s in (old,new):
 assert 'GRANT ' not in s and 'ALTER ' not in s and 'SECURITY DEFINER' in s
print('PASS exact additive contract; qualified casts; same owner/connection/success/receipt; duplicate-null; fixture expression parity')
