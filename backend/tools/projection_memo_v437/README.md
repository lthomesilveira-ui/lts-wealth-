# Statement projection reuse

V437 avoids rebuilding the same projection during nested recurrence reads. It
retains the exact builder, calculation, ordering, access rules and worker summary
hook. The optional memo is transaction-local and checked against owner, date,
database role, backend, statement timestamp, snapshot, source epoch, policy,
history reference and the existing independent receipt fingerprint. It is never
stored in a table or returned as application metadata.

The migration verifies the exact predecessor, preserves every catalog attribute
except the function body, and accepts an exact replay. A malformed or damaged
optional memo falls back to the calculation. No timeout or schedule is enlarged.

```sh
python3 backend/tools/projection_memo_v437/test_v438_sql.py > /tmp/v437.sql
createdb v437_memo
psql -X -d v437_memo -v ON_ERROR_STOP=1 -At -f /tmp/v437.sql
```

The disposable PostgreSQL tests use the existing normalized projection fixtures,
the reviewed full predecessor and the exact migration. They verify output parity,
calculation reuse, date and owner isolation, invalidation after source/policy/
reference changes, the worker summary hook, read-only behavior, transaction
cleanup, replay and unchanged access. They do not certify a real second user,
physical device, restore acceptance or physical disk I/O. Private production
comparison and timing evidence remains outside the public repository.

V438 adds reuse across requests without another scheduled job or another
calculation. The existing guarded refresh publishes the full result it already
calculated, together with its source guards and content digest. Normal reads use
it only for the same owner and current date, a completed current queue version,
the same source epoch, receipt fingerprint and full policy/reference fingerprint.
An absent or outdated publication falls back to the existing calculation.

The exact worker tests also verify atomic publication, independent receipt-only
and epoch guards, rollback of unsuccessful publications, damaged memo rejection,
recovery of missing full results and unchanged function access. The new private
reader is not executable by browser roles. Old sources and all financial rows
are preserved.
