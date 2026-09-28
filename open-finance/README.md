# Pluggy → LTS: isolated Itaú shadow ingestion

This adapter reads an existing **MeuPluggy proxy Item**. It does not create a consent, connect a bank, refresh a proxy Item, submit payments, or promote records to canonical finance. No product UI or existing reader is replaced.

## Entry points and deployment

- SQL: `supabase/open_finance_itau_shadow.sql`, applied as `open_finance_itau_shadow_v1`.
- Edge Function: `lts-open-finance-itau`, with **verify_jwt=true**.
- Core and handler are dependency-free ES modules, shared by Node tests and the Deno runtime.
- Tests: `node --test open-finance/tests/*.test.mjs`.
- Database tests: `open-finance/tests/database-rollback.sql`. Run under an authorized administrator; all fixtures roll back.
- CI: `.github/workflows/open-finance-shadow.yml`.

The pilot's owner is resolved from the existing `usuario` and active `lts_allowed_users` owner rows. More than one owner fails closed. User calls must validate against Supabase Auth and match that owner. Service calls require the server's service credential or a private, expiring, single-use job issued through an administrator-only RPC. An anon key alone is rejected. Existing RLS and table ACLs remain unchanged.

## Server secrets

Set `PLUGGY_CLIENT_ID` and `PLUGGY_CLIENT_SECRET` **only in Supabase Edge Function Secrets**. Use the credentials of the application containing the already-linked proxy. Never put either value in HTML, SQL, Git, documentation, issue bodies or chat. API keys from `POST /auth` live only in memory. The code never logs request bodies or provider errors.

Optional `PLUGGY_ITAU_ITEM_ID` holds the existing **proxy** ID, not the original bank Item. It is useful when the team's opt-in Item listing is unavailable or multiple Items exist. Retrieve the ID from the existing application's connection details. Do not create another connection to obtain an ID.

## Authorized operations

POST a JSON object with `action`:

| Action | Result |
| --- | --- |
| `status` | Credential-presence booleans and latest shadow report; no credential values. |
| `discover` | Retrieve a known existing proxy or discover exactly one MeuPluggy Item. No database binding or bank writes. |
| `sync` | Verify the Item/institution, register a run, ingest, reconcile and finish. |
| `report` | Paginated normalized observations and reconciliation (`run_id` optional, `offset` integer, page size 200). Raw payloads remain private in the database. |

An administrator can invoke `lts_open_finance_enqueue_itau_v1(endpoint, public_anon_jwt, action)` through the trusted database connection. The existing `pg_net` dispatches the request; only a random token's hash is retained, and the token is never returned. Inspect the returned `http_request_id` in `net._http_response`. Do not copy service credentials into SQL. This is an explicit one-shot operation; no scheduler or webhook was activated.

## Data and idempotency

Existing tables `lts_open_finance_connection`, `lts_open_finance_sync_run`, `lts_open_finance_staging` are reused. New `lts_open_finance_observation` preserves each run's raw and normalized observations, reconciliation evidence and inserted/updated/unchanged/stale outcome. `lts_open_finance_job` handles private one-shot execution.

- Stable identity: user + provider + resource type + proxy Item ID + provider resource ID.
- Raw JSON is hashed with stable object-key ordering. Identical replay keeps one current staging record; another run receives a separate audit observation.
- Same-batch retry is idempotent. A changed payload using the same run/record identity fails closed.
- Provider corrections retain previous raw observations. Older explicitly timestamped revisions cannot replace newer staging records.
- Missing records never imply deletion. This pilot does not implement deletion webhooks.
- One active sync per connection. An abandoned run is marked failed after its ten-minute lease; a later retry can proceed.
- A moving provider snapshot, incomplete pagination, missing source window or unknown data semantics cannot silently become a complete success.
- **Every staged record remains promotion-blocked.** No canonical writer is reachable from the adapter.

## Coverage and financial meaning

| Product | Endpoint | Interpretation |
| --- | --- | --- |
| Accounts, balances, cards | `GET /accounts?itemId=…` | Separate bank balance and credit-card debt/used-limit meaning. Never treat credit limit as cash. |
| Bank/card transactions | `GET /v2/transactions?accountId=…` | Follow the complete returned cursor. Bank signed cash and card balance signs are separate. Preserve pending status, installment and bill identifiers. |
| Bills | `GET /bills?accountId=…` | Keep due date, total, payments and finance charges. Do not infer bank settlement or create a second cash event. |
| Investments | `GET /investments?itemId=…` | `balance` = net valuation; `amount` = gross; `amountWithdrawal` = withdrawal availability; `date` = position date. Null, zero and missing remain distinct. |
| Loans/financing | `GET /loans?itemId=…` | Keep loan kind and outstanding balance separately from original principal. |

Product coverage distinguishes available, empty and unavailable; unavailable never means zero. Snapshot metadata retains the Item's enabled products and freshness. No intelligence/paid enrichment endpoint is used. The documented investment schema does not establish a D+0/D+1 liquidity field; any returned `liquidity` value remains uninterpreted and the raw payload is preserved. Maturity and grace dates are not converted into liquidity assumptions.

Transaction timestamps are interpreted in America/Sao_Paulo per the current Pluggy documentation; original timestamp and provider civil date are retained, and day shifts are flagged. Bill due dates remain civil dates. These differences must be checked against real statements before promotion is ever considered.

## Reconciliation

The source reader reads existing account positions, historical/operational cash readers, card instruments/purchases/invoices, asset positions and debt positions, in bounded complete date windows. It writes none of those sources.

- `exact`: stable documentary/provider identity, date, currency and amount agree.
- `candidate`: plausible identity or a position with different/unknown dates needs review.
- `new`: not found in the consulted LTS sources. This does **not** mean safe to promote.
- `conflict`: ambiguous candidates, divergent same-date values, incomplete provider semantics or many-to-one collisions.

Existing LTS evidence may itself be incomplete. This adapter does not certify all historical balances or reopen unrelated audits. An instrument name or equal value alone is insufficient for an exact match. The report includes candidate references, amounts, dates, comparison deltas and reasons; differences are never corrected automatically.

## Validation and continuation

The implementation has passed local synthetic adapter/handler tests, transaction-rolled-back database tests and a deployed authenticated status check. A deployed sync without provider secrets correctly stops before ingestion. **This is not evidence of a real Pluggy sync.** Production data coverage, real Item binding, real replay idempotency and reconciliation must be validated after the authorized operator configures the provider credentials.

Keep the project private checkpoint authoritative for deployment version, test receipts, credential-presence status and remaining gates. Do not claim this feature technically integrated until a real successful sync, populated staging, nonduplicating replay, complete coverage report and actual reconciliation exist.

## Official documentation verified 2026-09-24

- https://docs.pluggy.ai/en/docs/authentication
- https://meu.pluggy.ai/api-guide
- https://docs.pluggy.ai/en/docs/connections/item
- https://docs.pluggy.ai/en/reference/items/items-list-by-cursor
- https://docs.pluggy.ai/en/reference/transaction/transactions-list-by-cursor
- https://docs.pluggy.ai/en/docs/products/accounts
- https://docs.pluggy.ai/en/docs/products/credit-card-bills
- https://docs.pluggy.ai/en/docs/products/investments
- https://docs.pluggy.ai/en/docs/products/loans
- https://supabase.com/docs/guides/functions/secrets
- https://supabase.com/docs/guides/functions/auth-headers
