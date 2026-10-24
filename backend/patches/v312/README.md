# Complete card classification review

The effective-expense queue excluded older bank observations already covered by
the accounting history. Its zero count did not mean every received purchase had
an individual classification. V312 exposes those pending source observations in
Ações and includes the additional, deduplicated count in the navigation. Search,
pagination and the shared category catalog support reviewing the complete set.
Classifying a source does not create another expense or change an invoice total.

Suggestions reuse the existing evidence engine and current confirmed source
decisions. A later correction is used on subsequent reads. Conflicting historical
categories remain unresolved. Limited, recognized bank merchant-category codes
can suggest a business activity when the history is insufficient. Generic
marketplaces and payment intermediaries need purchase context; funding operations
do not receive a restaurant or store category from their MCC. A proposal never
assigns a beneficiary, property or recurring status and never saves itself.
Every proposal needs a source-specific confirmation. Categories use the active
shared catalog and its existing creation flow.

The owner-bound reader and writer are the only new client RPCs. The writer checks
the exact active source, expected raw hash, positive purchase status, canonical
category and optional explicit beneficiary before calling the existing audited
classification writer. Replays do not write a second audit entry; conflicting
stale decisions require a refresh. Helpers remain invokers with empty search
paths and no anonymous or authenticated grants. Read failures preserve the last
count with a visible freshness warning rather than reporting zero.

`backend/qa/lts_v312_ci.py` runs the real suggestion engine and existing audited
writer with bounded synthetic records on PostgreSQL 17. It checks historical
coverage, confirmation/correction learning, non-writing suggestions, ownership,
source hashes, invalid writes, replay and unchanged source/financial fingerprints.
The resulting payloads drive actual V312 assets at desktop, 390px and 360px widths,
including search, native selection preservation and read failure. These fixtures
do not certify a production browser session, physical device or full restore.

Deployment is additive: apply `card_review.sql`, then publish the new V312 release.
Published V309 and all protected releases stay byte-identical. No private financial
records, owner identifiers or production payloads belong in this public repository.
