# Documentary incoming purposes

Backend data continuation of V296; no published application asset is changed.
The generic operation classifies only manifest-pinned incoming ledger records
whose purpose is explicit in the original source. The private manifest records
the exact source hash, description, date, account, amount and canonical category.
No bank-name rule, beneficiary, property or new cash entry is inferred.

Salary subtypes keep their original descriptions. Loans, asset sales, FGTS and
own-account receipts retain their existing report treatment. Missing investment
principal/yield detail and ambiguous names remain unresolved. A descriptive
category is not evidence that a payment, investment balance or transfer pair has
been reconciled.

Before applying, run the operation twice in one rolled-back transaction and run
the negative QA. The operation compares every canonical expense, all historical
cash fields except category, incoming identities and non-target decisions, and
the full source fingerprints including the original ledger. It verifies the
expected queue reduction and actual source-key invalidation. Originals and the
documentary manifest are retained in one idempotent private audit record.

No schema, function, public API signature, permission or timeout is modified.
Run real report reads before and after, then preserve their results separately
from synthetic UI or physical-device acceptance. Keep private source identities
and workbook contents out of Git.
