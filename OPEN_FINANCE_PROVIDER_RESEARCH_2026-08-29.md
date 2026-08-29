# LTS Wealth — Open Finance provider research — 2026-08-29

Status: technical research only. No provider account, production contract, consent, credential, token or bank connection has been created by this work.

## Decision frame
The LTS needs a provider that can cover at minimum Itaú, Bradesco and C6 for personal financial data, with account balances, transactions and credit-card data. The integration must preserve LTS reconciliation rules: provider data is documentary input, not permission to invent category, merchant, competence or historical purchase detail.

The existing LTS staging remains provider-neutral. Provider-specific IDs/payloads must be normalized before entering canonical financial logic, and manual statement/card upload remains fallback.

## 1. Pluggy — current technical leader
Evidence reviewed from official Pluggy documentation/changelog:
- Open Finance institution coverage lists Itaú, Bradesco and C6 Bank with Accounts, Transactions and Credit Cards supported.
- Pluggy offers sandbox evaluation before a commercial conversation.
- Data connectors expose balances, statements/transactions, cards and investments in a normalized API.
- Webhooks exist for transaction created/updated/deleted events, reducing the need for blind polling.
- Pluggy has dedicated documentation for credit-card installments and explicitly warns that banks expose installment data inconsistently: some return future installments at once, some month by month, and some only the current installment.
- 2026 changelogs record fixes for transaction/account/card data involving Itaú, Bradesco and C6, showing active maintenance but also proving that connector-quality regressions are a real operational risk.
- C6 operation-type metadata has a documented limitation: transactions may come as `OUTROS`, so LTS cannot rely on provider operationType alone for semantic classification.

Implication for LTS:
- Best current fit for an initial sandbox proof-of-concept.
- Must ingest idempotently and reconcile provider records against current LTS facts; never overwrite certified history automatically.
- Credit-card installments need LTS-specific normalization + evidence status, not blind trust.
- Webhook events should land in neutral staging first, then pass through reconciliation/invalidation gates.

Official sources:
- https://docs.pluggy.ai/docs/open-finance-institutions-coverage
- https://docs.pluggy.ai/docs/credit-card-installments
- https://docs.pluggy.ai/changelog/atualiza%C3%A7%C3%B5es-de-produto-maio2026
- https://docs.pluggy.ai/changelog/atualiza%C3%A7%C3%B5es-de-produto-mar%C3%A7o2026
- https://docs.pluggy.ai/changelog/atualiza%C3%A7%C3%B5es-de-produto-fevereiro-2026
- https://www.pluggy.ai/

Commercial status:
- Sandbox is publicly offered.
- Production price was not established from the official sources reviewed here; commercial confirmation remains required before any production decision.

## 2. Belvo — strong regulated benchmark
Evidence reviewed from official Belvo documentation:
- Brazil OFDA aggregation supports accounts, transactions, balances and credit-card data.
- On initial consent/link creation, Belvo documents recovery of the prior 12 months for account/owner/transactions/card-bill information.
- Itaú retail/business and Bradesco retail/business are explicitly listed with checking account, credit card, loans and savings support and 12 months historical data.
- Hosted Widget + consent management + webhooks are documented.
- Retrieval limits/frequencies are explicitly documented; repeated link creation consumes Open Finance operational limits and should be avoided.
- Published Launch plan is R$6,000/month; sandbox is free for test/evaluation.
- In the institution list reviewed on 2026-08-29, an explicit C6 entry was not found. This must be resolved directly with Belvo before considering it equivalent to Pluggy for the LTS bank set.

Implication for LTS:
- Technically mature benchmark, particularly for regulated consent/history behavior.
- Current published production entry price is significant for a single-user personal treasury system.
- C6 coverage must be confirmed before a real shortlist decision.

Official sources:
- https://developers.belvo.com/pt-br/products/aggregation_brazil/aggregation-brazil-introduction
- https://developers.belvo.com/pt-br/developer_resources/resources-available-institutions
- https://developers.belvo.com/pt-br/products/aggregation_brazil/aggregation-brazil-data-retrieval-limits
- https://developers.belvo.com/pt-br/products/aggregation_brazil/aggregation-brazil-integration-widget
- https://belvo.com/pt-br/planos-precos/

## 3. Klavi — credible alternative, institution-level validation still needed
Evidence reviewed from official Klavi documentation:
- Participant-institutions page lists Itaú, Bradesco and C6 Bank.
- Product overview includes checking accounts, savings, credit card statements/limits/transactions, credit products and categorized credit-card outputs.

Open question:
- The reviewed documentation establishes supported participants and product families but did not provide enough institution-by-product evidence in this pass to assert the same explicit Itaú/Bradesco/C6 card coverage contract as Pluggy.

Official sources:
- https://docs.klavi.ai/connect/participant-institutions
- https://docs.klavi.ai/connect/overview

## Recommended next technical step — no user action yet
1. Keep Pluggy as the first sandbox candidate, not a contracted provider.
2. Build the LTS adapter contract provider-neutral first: institution/account/card/external transaction IDs, source timestamp, provider update timestamp, raw payload fingerprint, deleted/updated state, consent/link reference, evidence level, and ingestion idempotency key.
3. Sandbox-test three fixtures/classes before any real bank consent: account transaction, credit-card transaction/bill, and installment behavior.
4. Require explicit parity/reconciliation gates against LTS before a provider record can affect canonical cashflow or expense analytics.
5. Ask the user only when a real consent/production account/commercial commitment is required.

## Non-negotiable guardrails
- No provider credential/token in public repo or client HTML.
- No direct provider payload → canonical financial table write without staging/reconciliation.
- Provider category/merchant enrichment is evidence, not truth; existing user-confirmed LTS classifications retain priority.
- Historical certified cycles remain immutable unless new documentary evidence passes exact replacement/parity gates.
- Provider outages/duplicates/deletions must never silently delete LTS history.
