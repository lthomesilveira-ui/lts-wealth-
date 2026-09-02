# LTS Wealth — Open Finance Architecture

Status: architecture / implementation preparation. No bank consent, production provider account, paid plan, token or credential has been created by this document.

## Product objective

Make manual bank statements and card invoices the exception rather than the normal operating model. Open Finance data must feed the same reconciliation/audit model already used by LTS Wealth, never create a second financial truth.

Target institutions: Itaú, Bradesco and C6. Target resources: accounts/balances, bank transactions, credit cards/invoices when the provider/institution exposes them, and investments where useful.

## Non-negotiable rules

1. Provider data lands in staging first. It never writes directly into canonical Flow, Despesas or card facts.
2. Every provider record has immutable provider identity + raw hash + normalized identity.
3. Exact duplicates are suppressed; likely matches are linked for review; only a safe promotion contract may create/replace canonical facts.
4. Card purchases and card-bill payment remain different economic layers. A purchase is consumption; bill payment is cash settlement and must not double count Despesas.
5. A documented/manual value already in LTS is not silently overwritten. New Open Finance evidence reconciles against it and records the winner/evidence hierarchy.
6. Historical evidence is append-only/auditable. Corrections suppress/replace; they do not erase the source history.
7. The browser never receives provider API secrets, bank credentials or refresh tokens.
8. LTS database stores provider references and consent metadata only. Secrets/tokens belong in server-side secret storage/environment variables.
9. Connection freshness and failures must surface in Atualizações.
10. Manual PDF/CSV upload remains a fallback and documentary source even after Open Finance is active.

## Provider-neutral data flow

`provider -> server connector -> lts_open_finance_staging -> normalize -> dedupe -> match -> reconcile -> promote -> canonical LTS read models`

Promotion states:
- `received`: provider object persisted privately.
- `normalized`: common LTS fields extracted.
- `matched_exact`: exact canonical/documentary fact found; no duplicate write.
- `matched_candidate`: one or more likely candidates; user/system review required.
- `new_safe`: no conflict and safe promotion rule exists.
- `promoted`: canonical fact created/replaced with audit link.
- `blocked`: ambiguity, unsupported semantics or financial-rule question.

## Connector contract

Every provider adapter must implement equivalent server-side operations:
- `listInstitutions()`
- `createConsentSession()`
- `getConnectionStatus()`
- `syncAccounts()`
- `syncTransactions()`
- `syncCreditCards()` when available
- `syncInvestments()` when available
- `handleWebhook()` when available
- `revokeConnection()`

The rest of LTS only consumes normalized staging records and never imports a vendor SDK directly into financial logic.

## Current provider research — 28 Aug 2026

### Pluggy — preferred proof-of-concept candidate

Why it currently ranks first for this personal LTS use case:
- Pluggy states a unified API for 130+ financial institutions and explicitly includes balances, statements, cards and investments.
- Its Open Finance institution coverage currently marks Bradesco and C6 Bank available for Accounts, Transactions, Credit Cards, Investments and Investment Transactions. Itaú is also listed in its Open Finance coverage.
- Connector/API architecture exposes current connector capability dynamically; LTS should therefore query capability rather than hard-code it.
- Sandbox is available before a production decision.

Important limitation: institution/Open Finance support does not mean every issuer exposes card installments or transaction metadata identically. LTS must retain its own invoice/detail reconciliation and treat missing installment detail as incomplete evidence, not zero.

Commercial pricing and personal-use options can change and must be rechecked before activation. Any paid plan or real bank consent requires an explicit user decision.

### Belvo — technically credible alternative

- Free sandbox/testing environment is available.
- Current Brazilian Launch pricing is listed at R$ 6,000/month; Growth is custom.
- Strong candidate for a commercial/production comparison, but materially more expensive than is justified for a single-user proof of concept unless requirements change.

### Klavi — keep as comparison candidate

- Documentation lists Itaú, Bradesco and C6 among participating institutions.
- Keep behind the same adapter contract until pricing, exact credit-card resources, refresh behavior and production terms are verified.

## Architecture recommendation

Phase A — now, no bank consent required:
1. Create provider-neutral private tables and status read model.
2. Implement normalization/deduplication contracts against fixtures/sandbox payloads.
3. Reuse LTS reconciliation semantics and financial gates.
4. Add health/status checks to Atualizações.

Phase B — later, requires user consent but no change in financial rules:
1. Use one provider sandbox/low-cost personal route if still available and technically sufficient.
2. Connect one institution first.
3. Run read-only shadow sync: compare provider data to existing LTS, promote nothing automatically.
4. Measure coverage, lag, duplicates, card detail and failure modes.

Phase C — only after evidence and explicit cost/contract decision:
1. Enable safe automatic promotion for exact, non-conflicting bank facts.
2. Keep ambiguous items in Atualizações.
3. Add periodic/webhook sync and freshness SLAs.
4. Expand to all target institutions.

## Security model

- No banking usernames/passwords in Supabase tables.
- No provider API keys/tokens in frontend JavaScript or public repository.
- Provider API keys and refresh credentials only in server-side secrets.
- Public-schema Open Finance tables have RLS enabled and no direct `anon`/`authenticated` table privileges.
- Browser status is exposed only through an authenticated function that asserts canonical user identity.
- Webhook ingestion must authenticate provider signature/secret server-side and be idempotent by provider event/record id.
- Staging payloads may contain sensitive financial data and are therefore private; only normalized/status summaries are exposed to the UI.

## Reconciliation identity strategy

Bank transaction candidate identity:
`institution + account + posting_date + signed_amount + normalized_description + provider_transaction_id`

Card purchase candidate identity:
`issuer + card/invoice identity + purchase_date + amount + merchant + installment position when available`

Card cycle candidate identity:
`billing account/card group + reference month + due date + amount`

Never use amount alone as an identity or classification signal.

## Atualizações integration

The Central should eventually show:
- Connected institution and consent status.
- Last successful account/transaction/card sync.
- New facts matched exactly.
- Conflicts/ambiguities requiring a decision.
- Missing resource coverage, e.g. account available but card detail not returned.
- Consent expiration/reconnection needed.
- Manual upload fallback action.

## Release gates before automatic promotion

1. No canonical change before staging/reconciliation.
2. Duplicate fixture test = zero duplicated economic effect.
3. Existing documentary bank anchors remain exact.
4. Card bill payment remains excluded from expense duplication.
5. Re-running the same provider sync is idempotent.
6. Provider correction/reversal preserves audit history.
7. Connection loss cannot zero balances or delete historical facts.
8. Core financial regression and projection bridge remain green.
9. Real authenticated visual E2E remains a separate release gate and cannot be claimed from backend tests.

## Sources reviewed

- Pluggy official site and API/coverage documentation, accessed 28 Aug 2026.
- Belvo official Brazilian plans/pricing page, accessed 28 Aug 2026.
- Klavi participant-institution documentation, reviewed during provider comparison.

Provider capability/pricing is time-sensitive and must be revalidated immediately before production activation.