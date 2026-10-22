# V298 — review queue query reuse

A first classification-queue read with disposable read memos unavailable took
10.659 seconds in the administrative profile. Repeated source scans, whole-row
JSON conversions, duplicate category normalization and repeated card-cycle
subqueries consumed most of that time. This package reduces that work while
retaining the existing source evidence and classification rules.

Apply these bounded, idempotent files in one transaction, in this order:

1. `review_source_lookup.sql`: retain strict text identity and all evidence
   masks; add guarded native UUID lookups and restrict expensive row masks to
   every occurrence of the referenced identities, preserving multiplicity.
2. `review_normalization.sql`: reuse identical category normalizations and
   source keys already present in the expense relation.
3. `c6_reuse.sql`: reuse the materialized C6-only calendar and source scope.
4. `workbook_unchanged_row.sql`: return an unchanged composite directly when
   no certified bank overlay or prior overlay flag requires the original path.
5. `card_cycle_reuse.sql`: share byte-identical contract CTEs and document
   matches within one cycle query, preserving the uncertainty predicate.

Installed migration: `20261022111511_lts_review_queue_query_reuse_v298`.
The migration compared every canonical expense row and its multiplicity, and
the complete queue JSON, before committing. Reapplying the package was a no-op.

Private repeatable-read trials also preserved all 13 C6 identities, all 4,821
whole workbook records, the card-cycle JSON except its request clock field,
and a partial-month expense slice. Full-field fingerprints and counts of the
ledger, financial events, bank staging, review decisions and workbook evidence
stayed identical. No financial source, category decision or payment was written.

The unchanged authenticated role and eight-second statement limit passed a
6.751-second cold trial, then 6.817 and 6.655 seconds after installation.
These are observed RPC timings with all owner disposable memo dates and keys
made ineligible in a rolled-back transaction. PostgreSQL shared buffers may be
warm; these measurements do not certify a physical phone or private HTTP session.
Earlier incomplete candidates exceeded eight seconds and were not installed.

Validation is in `backend/qa/lts_v298_*`: full row/queue parity, card readers,
source fingerprints, restoration, and 44 synthetic strict-identity, duplicate,
NULL, month, changed-amount and whole-record cases. The five function identities,
owners, ACLs, invoker/definer status, volatility and configurations stay exact.
The public review RPC, its signature and its timeout configuration are unchanged.
Security advisory counts remain at the pre-existing 106 INFO / 2 path warnings /
152 authenticated definer warnings; this package introduces no new privileges.

The published frontend remains V296. There are no V298 frontend assets, private financial source
files, credentials, transaction details or private test receipts in this package.
Documentary gaps and private-session/device/native-restoration acceptance remain
separate open work. This package does not close the full project backlog.

| Reader | Original definition MD5 | Installed definition MD5 |
| --- | --- | --- |
| Expense source wrapper | e4e25fa5c5ec9c4bd5225aff371f2e4e | 0d845b5e55b0505af153d66adfcd6ea4 |
| Canonical expense baseline | 4b244b0ef223b50268ebc2de48235dd9 | 24c9b55478e02403bdca12003f5f22fe |
| C6 cycle identities | 077677805193b3167ca5041f69863900 | 8bb5a959015e5351c28820a39e987ca7 |
| Workbook bank overlay | a06bbae089c045121ecd9afc588835f6 | e7912321b844aa828da58fc94f00390c |
| Card-cycle reader | e091114f321d7f7fa5d7fdd6a759cd33 | bad00fdc296f78ad36e2cca6ef1ce75d |
