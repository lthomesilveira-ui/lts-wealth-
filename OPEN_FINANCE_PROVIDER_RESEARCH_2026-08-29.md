# LTS Wealth — Open Finance provider research — 2026-08-29

Status: technical/commercial research only. No provider account, production contract, consent, credential, token or bank connection has been created by this work.

## Evidence refresh — 2026-08-30
- Pluggy remains the strongest first sandbox candidate. Current official Open Finance coverage explicitly includes Itaú, Bradesco and C6 Bank for the principal data products; the public site still states 130+ institutions and a sandbox evaluation before commercial negotiation. Regulated Open Finance connectors are a premium production feature, so price/SLA still require sales confirmation.
- Belvo's current OFDA aggregation matrix explicitly lists Itaú retail/business and Bradesco retail/business with Accounts, Transactions and Credit Card (plus Loans/Savings) and 12 months of historical data. The current aggregation matrix does **not** contain C6. Belvo documentation does expose `c6_retail` in a Brazilian payments/widget context, but that is not sufficient evidence that C6 has equivalent data-aggregation coverage. The C6 aggregation blocker therefore remains open.
- Belvo's official public pricing still lists Launch at **R$6,000/month** and sandbox as free for testing/evaluation.
- Klavi's current Conecte documentation now makes the environments clearer: sandbox is fully simulated; `testing/desenvolvimento` mirrors production, allows real consents/data with a daily consent limit and no billing; production is the live billed environment. No comparable public production price was found in this refresh.
- No ranking change is authorized by research alone. Pluggy remains first technical sandbox candidate; Belvo remains benchmark/economic comparison; Klavi remains alternative pending explicit product×bank coverage and commercial terms.

## Decision frame
The LTS needs a provider that can cover at minimum Itaú, Bradesco and C6 for personal financial data, with account balances, transactions and credit-card data. The integration must preserve LTS reconciliation rules: provider data is documentary input, not permission to invent category, merchant, competence or historical purchase detail.

The existing LTS staging remains provider-neutral. Provider-specific IDs/payloads must be normalized before entering canonical financial logic, and manual statement/card upload remains fallback.

## 1. Pluggy — current technical leader
Evidence reviewed from official Pluggy documentation/changelog and current public site:
- Open Finance institution coverage explicitly lists Itaú, Bradesco and C6 Bank with the principal data products needed by LTS; current coverage tables show all three institutions in the regulated connector set.
- Public site states one API connects to 130+ financial institutions and exposes balances, statements/transactions, cards and investments in a normalized schema.
- Sandbox evaluation is available before a commercial conversation; the public site says it can be tested without meeting, card or waiting, and official sandbox docs expose simulated connection/error/MFA/Open Finance flows.
- Webhooks exist for transaction created/updated/deleted events, reducing the need for blind polling.
- Pluggy has dedicated documentation for credit-card installments and explicitly warns that banks expose installment data inconsistently: some return future installments at once, some month by month, and some only the current installment.
- Changelogs record fixes for transaction/account/card data involving Itaú, Bradesco and C6, showing active maintenance but also proving that connector-quality regressions are a real operational risk.
- C6 operation-type metadata has a documented limitation: transactions may come as `OUTROS`, so LTS cannot rely on provider operationType alone for semantic classification.
- Open Finance operational limits are explicit. Pluggy documents account balance/recent-transaction limits that allow routine automatic synchronization but warns against multiple connections for the same CPF/institution because all consume the same regulated quotas. Historical/non-recent account retrieval is materially more restricted than current balances/transactions.
- Regulated Open Finance connectors are documented as a premium feature that must be enabled for the production plan.

Implication for LTS:
- Best current fit for an initial sandbox proof-of-concept.
- Must ingest idempotently and reconcile provider records against current LTS facts; never overwrite certified history automatically.
- Credit-card installments need LTS-specific normalization + evidence status, not blind trust.
- Webhook events should land in neutral staging first, then pass through reconciliation/invalidation gates.
- LTS should maintain one live provider connection per CPF/institution where practical, rather than recreating connections, to avoid consuming Open Finance operational limits unnecessarily.

Official sources reviewed:
- https://docs.pluggy.ai/docs/open-finance-institutions-coverage
- https://docs.pluggy.ai/docs/open-finance-regulated
- https://docs.pluggy.ai/docs/credit-card-installments
- https://docs.pluggy.ai/docs/rate-limits-of
- https://docs.pluggy.ai/docs/sandbox
- https://www.pluggy.ai/

Commercial status:
- Sandbox is publicly offered and can be evaluated before a sales conversation.
- No official public production price was established in the sources reviewed through 2026-08-30; production pricing/SLA/support still require commercial confirmation.

## 2. Belvo — strong regulated benchmark, high public entry price for this use case
Evidence reviewed from official Belvo documentation/site:
- Brazil OFDA aggregation supports accounts, transactions, balances and credit-card data.
- Current OFDA matrix explicitly lists Itaú retail/business and Bradesco retail/business with Accounts, Transactions and Credit Card, plus Loans/Savings and 12 months of historical data.
- Hosted Widget + consent management + webhooks are documented.
- Retrieval limits/frequencies are documented; repeated link creation should be avoided because Open Finance operational limits apply.
- Current official pricing page lists **Launch at R$6,000/month** and states sandbox access is free for testing/evaluation. Growth is custom-priced.
- The public plan matrix includes standard support and describes premium support/validation/account-management capabilities by plan/service arrangement.
- Current OFDA aggregation matrix does not contain C6. A separate payments/widget API supports `c6_retail`, but that cannot be treated as proof of equivalent C6 account/transaction/card aggregation coverage.

Implication for LTS:
- Technically mature benchmark, particularly for regulated consent/history behavior.
- The published production entry price is significant for a single-user personal treasury system and materially weakens Belvo's current fit unless commercial terms differ for this scope.
- C6 **data aggregation** must be confirmed in writing before Belvo can be considered equivalent to Pluggy for the LTS bank set.

Official sources reviewed:
- https://developers.belvo.com/pt-br/products/aggregation_brazil/aggregation-brazil-institutions
- https://developers.belvo.com/pt-br/developer_resources/resources-available-institutions
- https://developers.belvo.com/pt-br/apis/belvoopenapispec/biometric-pix-widget-access-token-%28brazil%29
- https://belvo.com/pt-br/planos-precos/

## 3. Klavi — credible alternative, commercial/institution-product evidence still weaker
Evidence reviewed from official Klavi documentation/site:
- Conecte is Klavi's Open Finance data-sharing solution with consent, APIs, products and webhooks.
- Environments are now explicit: sandbox is fully mocked; testing/development mirrors production and can use real consents/data with a daily consent-creation limit and no billing; production is the live environment.
- Public material states broad Open Finance interoperability, and Klavi's payments material references more than 200 institutions, but that number should not be treated as a product-by-product data-aggregation guarantee.
- No directly comparable public production price was found in this review.

Open questions before it can outrank Pluggy:
- Confirm explicit Itaú/Bradesco/C6 institution-by-product equivalence for accounts + transactions + credit cards, not just participant/payment reach.
- Obtain production price, support model and SLA in writing.
- Validate card-installment behavior and deletion/update webhook semantics against the same LTS adapter fixtures used for Pluggy.

Official sources reviewed:
- https://docs.klavi.ai/connect
- https://www.klavi.ai/

## Current shortlist conclusion
1. **Pluggy — first sandbox candidate.** Best current combination of explicit bank/product evidence, sandbox accessibility, normalized API/webhooks and technical fit. Production pricing/SLA still needs sales confirmation before any commitment.
2. **Belvo — benchmark, not current economic leader.** Strong regulated product/documentation; public Launch price R$6,000/month and unresolved C6 *aggregation* evidence make it less attractive for the current single-user LTS scope.
3. **Klavi — viable alternative to validate.** Stronger environment story than previously documented, but pricing/SLA and institution-by-product equivalence still require evidence.

This ranking is technical/commercial diligence, not authorization to connect accounts or spend money.

## Recommended next technical step — no user action yet
1. Keep Pluggy as the first sandbox candidate, not a contracted provider.
2. Keep the LTS adapter provider-neutral: institution/account/card/external transaction IDs, source timestamp, provider update timestamp, raw payload fingerprint, deleted/updated state, consent/link reference, evidence level, and ingestion idempotency key.
3. Sandbox-test three fixture classes before any real bank consent: account transaction, credit-card transaction/bill, and installment behavior.
4. Require exact reconciliation/parity gates against LTS before a provider record can affect canonical cashflow or expense analytics.
5. For production shortlist, obtain Pluggy and Klavi written price + support/SLA + explicit Itaú/Bradesco/C6 product matrix; obtain explicit C6 aggregation confirmation from Belvo; compare against Belvo's current public R$6,000/month baseline.
6. Ask the user only when a real account, consent, production credential, paid plan or commercial commitment is required.

## Non-negotiable guardrails
- No provider credential/token in public repo or client HTML.
- No direct provider payload → canonical financial table write without staging/reconciliation.
- Provider category/merchant enrichment is evidence, not truth; existing user-confirmed LTS classifications retain priority.
- Historical certified cycles remain immutable unless new documentary evidence passes exact replacement/parity gates.
- Provider outages/duplicates/deletions must never silently delete LTS history.
