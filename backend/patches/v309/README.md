# Dated contract readers

The contract reader previously retained the document's full remaining schedule
after some due dates and independently validated payments had passed. The wealth
response also carried older compatibility summaries beside the canonical fields.

`contract_read_state.sql` derives future installments, individually identified
payments and past installments without a payment identity. It reuses the existing
bank validator, rejects ambiguous identities, and keeps the source schedule and
dated debt stock intact. A scheduled due date never proves payment or delinquency.
Payroll withholding remains separate from bank debits.

`apply_contract_views.sql` installs three private invoker helpers and wraps the
three leased readers. Before/after definition hashes guard against drift. Existing
reader OIDs, ownership, ACLs, configuration and definer attributes must remain
exact. Replaying this patch is checked to be definition-identical. No source
table is updated and no balance is inferred from a payment's full amount.

Regenerate the patch only from explicitly reviewed definitions supplied on stdin:

```sh
python3 backend/tools/build_contract_patch_v309.py < private-definitions.json
```

The PostgreSQL 17 workflow uses a synthetic schema and the actual bank validator;
the unrelated partial-obligation validator is explicitly doubled false. It
checks dated positions, owner partitioning, four contract schedules, 21 rejected
payment proofs, unchanged reader attributes, exact replay, and drift rollback.
The browser workflow loads the immutable release stack with synthetic API data
at desktop, 390 px and 360 px sizes. These checks do not certify a production
signed-in HTTP session, a physical device or a full database/storage restore.
