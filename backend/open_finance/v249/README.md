# V249 card normalization and complete staged snapshots

This dependency-free module is based on the retrieved deployed reader core.
It does not install a migration, invoke a bank connector or alter production.

Normalizer changes are confined to credit-card semantic layer and card-identity provenance:
- Exact `PAGAMENTO_FATURA` is statement payment evidence; generic `PAGAMENTO`
  is consumption. Refunds and cashback remain consumption adjustments, not income.
- Transaction `creditCardMetadata.cardNumber` supplies the last four when valid.
  The account number and its last four remain separate. Invalid supplied metadata
  is unresolved, not silently replaced with the account card.
- Conflicting payment direction is reported for review, never force-corrected.
- Amount/sign, currency, source IDs, raw hash/payload, dates, installments and
  official-effect=false are preserved. Pending records stay pending.
- Card normalization carries an explicit revision, so deployment can be verified
  from newly ingested records without altering the original raw hash.

The guarded SQL patch brings the C6/Bradesco batch writer to the same complete
snapshot behavior as the existing Itaú writer. Previously a conflict updated raw
and normalized payloads but retained old amount, date, provider timestamp and
match status. All three writers now keep those columns together, reject older
provider updates, reject changed retries within one run, and re-normalize
unchanged raw records in a new run. Observation history remains immutable;
canonical financial events are not promoted, deleted or changed by this patch.

Primary references checked 2026-10-05/06:
https://docs.pluggy.ai/en/docs/products/transactions
https://docs.pluggy.ai/pt/reference/transaction/transactions-retrieve
https://www.postgresql.org/docs/current/sql-insert.html

Run synthetic QA: `node --test backend/qa/lts_v249_card_normalization.test.mjs`.
Private replay must also compare baseline/candidate on original owner exports.
Do not publish financial examples, owner/provider UUIDs or private replay hashes.

Validation: 16 synthetic normalizer tests, independent original-source replay
for three banks, and live transactional staging/card-consumer rollback PASS.
The rollback proof covers retries, unchanged-raw revision, pending-to-posted
value/date/match changes, stale rejection, signed refunds and no promotion.
Function definitions/ACLs are restored and all fixtures absent after the probe.
An initial probe syntax error was rolled back and corrected before the PASS.

Build the operator-only rollback probe with
`node backend/qa/lts_v249_transactional_probe.mjs` from the repository root.
It emits migration JSON. Only an RLS-protected, access-revoked private validation
receipt persists; all candidate DDL and source fixtures are subtransactional.

Deployment requires an exact deployed-source lease and successful CI. Productive
three-bank syncs and actual staging/expense/projection acceptance must then be
verified separately. Synthetic state transitions are not owner financial audits.
No observations may be overwritten or consumption auto-promoted on classification
alone. The legacy pending financial-event reconciler is outside this patch; its
refund/missing-record policies need separate review and must not be invoked here.
Deployment must retain the deployed entrypoint, handler, custom authentication and
other unchanged dependencies; this module alone is not a complete deploy bundle.
Frozen V245 UI is unchanged. V247 performance work is separate.
