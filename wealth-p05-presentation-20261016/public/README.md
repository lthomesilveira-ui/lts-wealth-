# P05 presentation candidate, synthetic-only package

Candidate for review. No database application, release replacement, publication, or authenticated production UI certification.

## Proposal

The current source warning compares the refreshed invoice hash against the original documentary hash. The existing audited private contract now recognizes exact raw invoice content with only root `updatedAt` excluded. Presentation reuses that precise installed predicate and its policy selection, without changing the economic guard.

`build_candidate.py` extracts the predicate from the pinned generic economic guard reference. Its exact SHA-256 is `ae48a8c0dd8b1771090beaad96f4b46fd68c651ebe117682e99ec757b0b1f00b`. Extraction and parity gates prevent a second tolerance definition. Contracts without a policy retain exact hash comparison; unknown policies fail closed. Every other raw key, nested field and array order remains exact.

The private projector validates owner/payment/invoice identities, the exact frozen original P05 link, bank hash/status/account, issuer FULL_PAYMENT evidence, currency/amounts and source dates. The existing presentation reader calls it and returns the ten-field allowlist in `CONTRACT.json`. The original P05 record, historical hash and documents are untouched. No expense/coverage reader or cancelled current-bills reader is called. No manifest or canonical/private evidence reaches the browser.

The UI label says payment was reported in full by the issuer. The note separately labels the issuer's day and the bank debit's posting day. It preserves raw `payment_status`, due dates, cycle and values. Both badge and note use the same validated annotation. Original documentary-only evidence keeps its old presentation; genuinely changed evidence keeps the warning.

## Exact browser base

`releases/v280/lts-v226-card-composition.js` from main `a0181d50c81154f43f753a4f46cfaa18dc346da0`, blob `25472d021a29726fe15427928ce8a91098562614`.

Only the note function and summary label expression change. The source original is pinned and rebuilt deterministically. Generation guards in detail/flow async paths, navigation and all remaining code stay byte-identical. The candidate is stored inside this test package, never at a published release path.

## Tests

Run `python3 run_postgres17.py --allow-fresh-synthetic-postgres17` only with the proposed workflow's fresh loopback PostgreSQL17 service. The runner clears inherited PG configuration, accepts no production URL and requires the dedicated synthetic database/user. All SQL fixtures are fictional. SQL uses temporary objects and ends in ROLLBACK.

The gate contains 174 pure annotation cases, a shared invoice-policy mutation matrix, ten ACL/role-chain checks, and actual presentation-reader integration with synthetic source tables. It checks raw-field additions/removals/mutations, nested updatedAt, unknown policy, only-root-timestamp changes, legacy valid fallback, genuine stale evidence, input/source immutability and cross-owner behavior. Presentation intentionally asserts no consumption coverage. The authenticated entry in the ACL test is a synthetic privilege-chain test double, not live authentication.

Local JavaScript checks execute the exact candidate summary/detail functions: 49 cases plus ten original V272 regression cases. They establish annotation/badge consistency and unchanged financial/source inputs. They are not full-stack or desktop/mobile visual certification.

`postgres17-presentation.proposed.yml` is for the existing draft test PR. It uses a disposable PostgreSQL service and contains no deployment or production secrets.

## Public boundary

Upload only files explicitly named by `PUBLIC_FILES.json`. This directory contains generic code and invented fixtures, not the actual private contract, invoice, documentary sources, timestamp proof or installation receipts. Generated SQL is reproducible inside CI. Do not upload the parent directory or its `private/` directory.

No production migration is included. The rollback-default candidate is for review, not an approved installer. A later installation decision needs fresh function/ACL/source leases, exact rollback and independent approval.
