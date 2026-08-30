# LTS Wealth — Open Finance provider research — 2026-08-29

Status: technical/commercial research only. No provider account, production contract, consent, credential, token or bank connection has been created by this work.

## Decision frame
The LTS needs a provider that can cover at minimum Itaú, Bradesco and C6 for personal financial data, with account balances, transactions and credit-card data. The integration must preserve LTS reconciliation rules: provider data is documentary input, not permission to invent category, merchant, competence or historical purchase detail.

The existing LTS staging remains provider-neutral. Provider-specific IDs/payloads must be normalized before entering canonical financial logic, and manual statement/card upload remains fallback.

## 1. Pluggy — current technical leader
Evidence reviewed from official Pluggy documentation/changelog and current public site:
- Open Finance institution coverage reviewed previously lists Itaú, Bradesco and C6 Bank with Accounts, Transactions and Credit Cards supported.
- Public site states one API connects to 130+ financial institutions and exposes balances, statements/transactions, cards and investments in a normalized schema.
- Sandbox evaluation is available before a commercial conversation; the current public site says it can be tested without meeting, card or waiting, and official sandbox docs expose simulated connection/error/MFA/Open Finance flows.
- Webhooks exist for transaction created/updated/deleted events, reducing the need for blind polling.
- Pluggy has dedicated documentation for credit-card installments and explicitly warns that banks expose installment data inconsistently: some return future installments at once, some month by month, and some only the current installment.
- 2026 changelogs record fixes for transaction/account/card data involving Itaú, Bradesco and C6, showing active maintenance but also proving that connector-quality regressions are a real operational risk.
- C6 operation-type metadata has a documented limitation: transactions may come as `OUTROS`, so LTS cannot rely on provider operationType alone for semantic classification.
- Open Finance operational limits are explicit. Pluggy documents, for example, account balance/recent-transaction limits that allow routine automatic synchronization but warns against multiple connections for the same CPF/institution because all consume the same regulated quotas. Historical/non-recent account retrieval is materially more restricted than current balances/transactions.

Implication for LTS:
- Best current fit for an initial sandbox proof-of-concept.
- Must ingest idempotently and reconcile provider records against current LTS facts; never overwrite certified history automatically.
- Credit-card installments need LTS-specific normalization + evidence status, not blind trust.
- Webhook events should land in neutral staging first, then pass through reconciliation/invalidation gates.
- LTS should maintain one live provider connection per CPF/institution where practical, rather than recreating connections, to avoid consuming Open Finance operational limits unnecessarily.

Official sources reviewed:
- https://docs.pluggy.ai/docs/open-finance-institutions-coverage
- https://docs.pluggy.ai/docs/credit-card-installments
- https://docs.pluggy.ai/docs/rate-limits-of
- https://docs.pluggy.ai/docs/sandbox
- https://docs.pluggy.ai/changelog/atualiza%C3%A7%C3%B5es-de-produto-maio2026
- https://docs.pluggy.ai/changelog/atualiza%C3%A7%C3%B5es-de-produto-mar%C3%A7o2026
- https://docs.pluggy.ai/changelog/atualiza%C3%A7%C3%B5es-de-produto-fevereiro-2026
- https://www.pluggy.ai/

Commercial status:
- Sandbox is publicly offered and can be evaluated before a sales conversation.
- No official public production price was established in the sources reviewed on 2026-08-29; production pricing/SLA/support still require commercial confirmation.

## 2. Belvo — strong regulated benchmark, high public entry price for this use case
Evidence reviewed from official Belvo documentation/site:
- Brazil OFDA aggregation supports accounts, transactions, balances and credit-card data.
- On initial consent/link creation, Belvo documents recovery of prior history for account/owner/transactions/card-bill information; earlier review found 12-month history for the relevant products/institutions.
- Itaú retail/business and Bradesco retail/business are explicitly documented with relevant data products in the institution matrix reviewed previously.
- Hosted Widget + consent management + webhooks are documented.
- Retrieval limits/frequencies are documented; repeated link creation should be avoided because Open Finance operational limits apply.
- Current official pricing page (checked 2026-08-29) lists **Launch at R$6,000/month** and states sandbox access is free for testing/evaluation. Growth is custom-priced.
- The public plan matrix includes standard support and describes premium support/validation/account-management capabilities by plan/service arrangement.
- In the institution list reviewed on 2026-08-29, an explicit C6 entry was not found. This remains a blocking commercial/technical confirmation before Belvo could be considered equivalent to Pluggy for the LTS bank set.

Implication for LTS:
- Technically mature benchmark, particularly for regulated consent/history behavior.
- The published production entry price is significant for a single-user personal treasury system and materially weakens Belvo's current fit unless commercial terms differ for this scope.
- C6 coverage must be confirmed before a real shortlist decision.

Official sources reviewed:
- https://developers.belvo.com/pt-br/products/aggregation_brazil/aggregation-brazil-introduction
- https://developers.belvo.com/pt-br/developer_resources/resources-available-institutions
- https://developers.belvo.com/pt-br/products/aggregation_brazil/aggregation-brazil-data-retrieval-limits
- https://developers.belvo.com/pt-br/products/aggregation_brazil/aggregation-brazil-integration-widget
- https://belvo.com/pt-br/planos-precos/

## 3. Klavi — credible alternative, commercial/institution-product evidence still weaker
Evidence reviewed from official Klavi documentation/site:
- Participant-institutions page reviewed previously lists Itaú, Bradesco and C6 Bank.
- Product overview includes checking accounts, savings, credit-card statements/limits/transactions, credit products and categorized credit-card outputs.
- Klavi publishes Open Finance operational limits and maximum expected data-delay ranges by product. Its documentation shows that credit-card limits/current transactions can be refreshed much more frequently than invoice/identification endpoints, and that account balances/transactions are subject to regulated monthly quotas.
- Public pages emphasize a single integration and broad institution interoperability, but no directly comparable public production price was found in this review.

Open questions before it can outrank Pluggy:
- Confirm explicit Itaú/Bradesco/C6 institution-by-product equivalence for accounts + transactions + credit cards, not just participant presence.
- Obtain production price, support model and SLA in writing.
- Validate card-installment behavior and deletion/update webhook semantics against the same LTS adapter fixtures used for Pluggy.

Official sources reviewed:
- https://docs.klavi.ai/connect/participant-institutions
- https://docs.klavi.ai/connect/overview
- https://docs.klavi.ai/connect/rate-limits-and-throughput
- https://www.klavi.ai/

## Current shortlist conclusion
1. **Pluggy — first sandbox candidate.** Best current combination of explicit bank/product evidence, sandbox accessibility, normalized API/webhooks and technical fit. Production pricing/SLA still needs sales confirmation before any commitment.
2. **Belvo — benchmark, not current economic leader.** Strong regulated product/documentation; public Launch price R$6,000/month and unresolved explicit C6 evidence make it less attractive for the current single-user LTS scope.
3. **Klavi — viable alternative to validate.** Broad participant/product claims and documented operational limits, but pricing/SLA and institution-by-product equivalence require stronger evidence.

This ranking is technical/commercial diligence, not authorization to connect accounts or spend money.

## Recommended next technical step — no user action yet
1. Keep Pluggy as the first sandbox candidate, not a contracted provider.
2. Keep the LTS adapter provider-neutral: institution/account/card/external transaction IDs, source timestamp, provider update timestamp, raw payload fingerprint, deleted/updated state, consent/link reference, evidence level, and ingestion idempotency key.
3. Sandbox-test three fixture classes before any real bank consent: account transaction, credit-card transaction/bill, and installment behavior.
4. Require exact reconciliation/parity gates against LTS before a provider record can affect canonical cashflow or expense analytics.
5. For production shortlist, obtain Pluggy and Klavi written price + support/SLA + explicit Itaú/Bradesco/C6 product matrix; compare against Belvo's current public R$6,000/month baseline.
6. Ask the user only when a real account, consent, production credential, paid plan or commercial commitment is required.

## Non-negotiable guardrails
- No provider credential/token in public repo or client HTML.
- No direct provider payload → canonical financial table write without staging/reconciliation.
- Provider category/merchant enrichment is evidence, not truth; existing user-confirmed LTS classifications retain priority.
- Historical certified cycles remain immutable unless new documentary evidence passes exact replacement/parity gates.
- Provider outages/duplicates/deletions must never silently delete LTS history.
