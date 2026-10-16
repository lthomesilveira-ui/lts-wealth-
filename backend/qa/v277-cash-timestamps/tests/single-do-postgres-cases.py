#!/usr/bin/env python3
"""Prepare synthetic single-statement tests. No database connections."""
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
apply=(tmp/'installer/apply-single-do.sql').read_text()
rollback=(tmp/'installer/rollback-single-do.sql').read_text()
marker=' -- DDL_COMPLETE_POSTCHECK_FOLLOWS'
assert apply.count(marker)==1
failed=apply.replace(marker," RAISE EXCEPTION 'SYNTHETIC_POST_DDL_FAILURE';\n"+marker)
(tmp/'single-do-fail-after-ddl.sql').write_text(failed)
(tmp/'single-do-wrapped-apply.sql').write_text('BEGIN;\n'+apply+"\nINSERT INTO wealth_test.synthetic_migration_journal VALUES('wrapped_apply');\nCOMMIT;\n")
(tmp/'single-do-wrapped-rollback.sql').write_text('BEGIN;\n'+rollback+"\nINSERT INTO wealth_test.synthetic_migration_journal VALUES('wrapped_rollback');\nCOMMIT;\n")
(tmp/'single-do-wrapped-failure.sql').write_text("BEGIN;\nINSERT INTO wealth_test.synthetic_migration_journal VALUES('must_rollback');\n"+failed+'\nCOMMIT;\n')
# The private post-lease is not needed: derive candidate canonical MD5 from source.
import hashlib
expected=hashlib.md5((root/'candidate/lts_browser_cash_today_v178.sql').read_text()[:-1].encode()).hexdigest()
assert apply.count(expected)==1
(tmp/'single-do-postcheck-mismatch.sql').write_text(apply.replace(expected,'0'*32))
(tmp/'hold-advisory-lock.sql').write_text("BEGIN;\nSELECT pg_advisory_xact_lock(hashtextextended('wealth_cash178_bank_positions_v1',0));\n"+f'\\! touch "{tmp}/lock-held"\n'+"SELECT pg_sleep(3);\nCOMMIT;\n")
