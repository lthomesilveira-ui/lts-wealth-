# V249 normalization candidate — NOT DEPLOYED

This dependency-free module is based on the retrieved deployed reader core.
It does not install a migration, invoke a bank connector or alter production.

Changes are confined to credit-card semantic layer and card-identity provenance:
- Exact `PAGAMENTO_FATURA` is statement payment evidence; generic `PAGAMENTO`
  is consumption. Refunds and cashback remain consumption adjustments, not income.
- Transaction `creditCardMetadata.cardNumber` supplies the last four when valid.
  The account number and its last four remain separate. Invalid supplied metadata
  is unresolved, not silently replaced with the account card.
- Conflicting payment direction is reported for review, never force-corrected.
- Amount/sign, currency, source IDs, raw hash/payload, dates, installments and
  official-effect=false are preserved. Pending records stay pending.

Primary references checked 2026-10-05:
https://docs.pluggy.ai/en/docs/products/transactions
https://docs.pluggy.ai/pt/reference/transaction/transactions-retrieve

Run synthetic QA: `node --test backend/qa/lts_v249_card_normalization.test.mjs`.
Private replay must also compare baseline/candidate on original owner exports.
Do not publish financial examples, owner/provider UUIDs or private replay hashes.

Release gates remain pending: writable production service, exact deployed-source
lease, downstream staging/reconciliation/expense/projection regression, pending
expense lifecycle and all three banks' successful syncs. Do not overwrite old
observations or auto-promote consumption just because this classification changes.
Deployment must retain the deployed entrypoint, handler, custom authentication and
other unchanged dependencies; this module alone is not a complete deploy bundle.
Do not alter frozen V245 UI or apply the unrelated V247 candidate before its QA.
