# LTS Wealth — Canonical Delivery Master Plan

Last refreshed: 2026-09-07
Active implementation branch: `canonical-v157plus-product-recovery` (aligned with `canonical-app-v1` and `main` at the exposed V157+ baseline)

Purpose: this is the execution-order view of the LTS Wealth backlog. It does not replace documentary evidence or immutable checkpoints. `PROJECT_MASTER_BACKLOG.md` remains the complete persistent dependency list. This file makes the remaining work explicit so product delivery does not get lost behind release mechanics.

## Definition of DONE for the app
The LTS Wealth app is not considered delivered until all P0 items below are complete together in one canonical application:
- one canonical frontend, not a wrapper/iframe chain over historical releases;
- Dashboard visually aligned with the approved official reference;
- real authenticated financial data rendered without fabricated values or false zeros;
- desktop and mobile responsive layouts designed intentionally, not desktop squeezed into mobile;
- six working product routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações;
- authentication/session state works in the same application;
- no sustained freeze, route trap, clipping or hidden historical UI;
- deterministic desktop + WebKit gates pass before real-device homologation;
- physical-iPhone material homologation is not claimed until actually evidenced.

## P0 — Deliver the canonical app
### P0.1 Canonical shell / architecture
- [x] Replace the v150/v151/v156/v160 wrapper/frame chain with one canonical app shell.
- [x] Connect directly to the existing authenticated data/RPC layer.
- [x] Preserve backend, financial rules, history, classification rules and documentary evidence.
- [x] Remove historical release branding/UI from the primary product surface.
- [x] Add explicit loading, unauthenticated, error and data-ready states.

### P0.2 Dashboard — approved visual contract
- [~] Build the Dashboard directly against the approved 1312×1199 official reference; functional hierarchy is gated and presentation parity remains P0.
- [~] Desktop: dark left rail + light dense executive canvas + compact spacing; continue visual convergence.
- [x] Mobile: purpose-built responsive hierarchy; no squeezed desktop canvas.
- [x] Five primary KPIs: Dinheiro em contas; Contas + curto prazo; RSUs vested; FGTS; Despesas (mês).
- [x] Real values only; missing evidence stays unavailable, never false R$0,00.
- [~] Dense executive sections: functional surfaces exist; continue reference-level chart/detail fidelity.
- [ ] Expense/category drill-down from Dashboard where evidence exists.
- [x] First cash-negative date and management/action date displayed separately when different.
- [x] FGTS rule preserved: R$22.432,31 at 21/08/2026, restricted ~D+30, never D+3, no future accrual projection.

### P0.3 Navigation / responsive product
- [x] One router owned by the canonical app.
- [x] All six routes work physically on desktop and mobile.
- [x] Mobile nav shows all six destinations with no clipping/overflow.
- [ ] Route state survives refresh/session restoration appropriately.
- [x] No iframe navigation races or hidden historical route owners.

### P0.4 Authentication + real data
- [x] Canonical app owns login/session presentation.
- [x] Same authenticated session feeds Dashboard and all modules.
- [x] Direct read paths for cockpit, flow, expenses, wealth, cards, updates/search.
- [x] No synthetic financial data for visual QA outside explicit fixtures.
- [x] Error state must be visible and diagnosable instead of silently showing dashes.

### P0.5 Product-level QA before asking the user
- [ ] Desktop visual parity gate against approved reference hierarchy/density.
- [x] Mobile WebKit gate for layout, scrolling, route fit and event-loop responsiveness.
- [x] Six-route physical navigation regression.
- [x] No-horizontal-overflow and no-sustained-DOM-churn checks.
- [x] Auth-truth / missing-data truth checks.
- [x] Fixed homologation points to the exact green canonical V157+ candidate; public promotion remains separate and unauthorized.

## P1 — Core functional modules in the canonical app
### P1.1 Fluxo Diário
- [x] Canonical UI for Itaú, Bradesco, C6 and Consolidado.
- [x] Preserve Saldo anterior | Entradas | Saídas | Saldo final hierarchy.
- [x] Facts > projections; scenarios never facts; stale anchors cannot reanchor.
- [x] Card invoices do not duplicate underlying expenses.
- [x] Bank↔liquidity-asset transfers have consolidated economic effect zero.
- [x] Historical bank is never inferred without evidence.

### P1.2 Despesas
- [x] Bring the existing R$8.623.752,53 invariant and 3.860/3.860 analytical cache into the canonical UI.
- [x] Nature and context/person/cost center remain separate dimensions.
- [x] Current year, 12 months, since 2023 and since 2013 views where evidence exists.
- [ ] Improve density, ranking and management-useful insights.
- [ ] Reduce `A classificar` only through evidence.
- [ ] Explain each item/context instead of presenting opaque totals.

### P1.3 Patrimônio
- [x] Canonical wealth summary and drilldowns.
- [x] RSU vested position and sale history with future awards excluded before vest/settlement.
- [x] FGTS temporal positions kept distinct.
- [x] CIPÓ 396 rich drilldown preserved without invented assumptions.
- [x] Volvo financing represented exactly once economically.

### P1.4 Cartões
- [x] Canonical card view using certified detail where available and aggregate fallback only where necessary.
- [x] No duplicate spend via invoice + underlying transactions.
- [x] Explicitly label incomplete documentary months rather than filling patterns.

### P1.5 Atualizações / Inputs
- [x] Compact prioritized checklist with no large blank gaps.
- [x] Evidence-backed category/context suggestions consistently throughout the list.
- [x] Explain why user input is needed where ambiguity remains.
- [x] Keep text-entry preview; never auto-post without explicit approval.
- [x] Date/value/account-or-card validation before approval.

## P2 — Search, classification, documents and write lifecycles
### P2.1 Transaction search
- [x] Finish server-side incremental search through `lts_browser_transactions_v1`.
- [x] Search while typing across supported history from 10/10/2013 plus future existing launches.
- [x] Read-only results with total count.
- [x] Excel-compatible CSV export preserving available date, description, account, direction, amount, category, counterparty, cost center and source/reference.
- [x] Existing evidence: Mastercard returns 239 rows spanning 01/11/2013 to 12/04/2028.

### P2.2 Classification lifecycle
- [ ] Real authenticated save → refresh → resolved disappearance / retry / `O que mudou`.
- [ ] Evidence hierarchy stays: user-confirmed rule > exact/consistent LTS history > public merchant research > manual review.
- [ ] Marketplaces/intermediaries never determine purchase purpose alone.

### P2.3 Documents / interpretation
- [ ] Real authenticated PDF/image interpret → review.
- [ ] Bank statement association: institution/account + competence.
- [ ] Card statement association: card + competence.
- [ ] Financing association: commitment + exact as-of.
- [ ] Filename never determines financial facts.
- [ ] Upload alone never posts financial data.

### P2.4 Natural liquidity input / reversals
- [ ] Real authenticated save → refresh → visible result.
- [ ] Preserve parser for 5 mil / R$5.000 / 5000 / 3k / R$1.250,50.
- [ ] Never guess account/asset.
- [ ] Preview both legs, before/after and economic effect R$0 before confirmation.
- [ ] Define append-only auditable cancellation/reversal semantics before enabling reversal UI.

## P3 — Planning, reconciliation and documentary gaps
### P3.1 Planning / FGTS
- [~] Recalculate planning bridge under no-future-FGTS-accrual rule.
- [ ] Revalidate first-negative date versus management/action date and display both when different.
- [ ] Historical R$3.700/month FGTS projections remain historical only.

### P3.2 Cards historical recovery
- [~] Continue Mastercard/Visa documentary recovery only from evidence.
- [ ] Mastercard 2023 category matrix remains absent despite 12 ledger-only payments / R$496.689,05.
- [ ] Incomplete Mastercard 2022/2024/2025 months remain open.
- [ ] C6 Aug/2024 explicit R$66,70 gap remains visible.

### P3.3 CIPÓ 396
- [ ] Itaú consortium delta R$303,60.
- [ ] R$6.654,50 remains arithmetic-only from R$6.502,70 + R$151,80 on different dates.
- [ ] Condominium formula/cutoff source absent.
- [ ] Raw gap R$1.780.358.
- [ ] Dedup gap R$1.312.268.
- [ ] Duplicate excess through Jul/2026 R$3.531,70.
- [ ] No fabricated post-2029 TR.
- [ ] Market-minus-cost is not automatically taxable/net gain.

### P3.4 RSU / Volvo
- [ ] R$578,68 historical RSU sale difference remains unexplained/unitemized.
- [ ] Volvo exact trim/version and km required before valuation refinement.

### P3.5 Historical continuity
- [~] Audit open dependencies back to project start 07/07/2026 so no prior improvement disappears.

## P4 — Open Finance
Open Finance is still part of the product roadmap. It was not cancelled; work was interrupted by the unresolved app/frontend delivery problem.

### P4.1 What is already done
- [x] Provider-neutral private architecture QA 14/14.
- [x] No real consent, token or provider commitment has been made.

### P4.2 What still has to be done before choosing a provider
- [~] Obtain written pricing for viable providers.
- [~] Obtain support model and SLA.
- [~] Confirm product-by-bank coverage for Itaú, Bradesco and C6.
- [ ] Confirm the exact data scope needed: accounts, transactions, balances, cards/invoices and investments where available.
- [ ] Compare refresh cadence, historical depth, webhook/event support, consent renewal, error handling and sandbox quality.
- [ ] Produce a provider comparison with cost/coverage/operational tradeoffs.

### P4.3 Decision that genuinely belongs to the user
- [ ] Provider/commercial spend decision after evidence is assembled.
- [ ] Consent authorization when a provider is selected.
- [ ] No credentials, commercial commitment or spend before explicit approval.

### P4.4 Integration after provider decision
- [ ] Consent/onboarding flow inside canonical app.
- [ ] Normalize bank/account/card identities against LTS entities.
- [ ] Import balances/transactions read-only first.
- [ ] Reconciliation layer before allowing any automated mutation.
- [ ] Refresh/health/status view in Atualizações.
- [ ] Audit trail and disconnect/revoke handling.
- [ ] Keep existing manual/documentary ingestion as fallback.

## P5 — Production readiness / promotion
- [ ] Performance work after correctness/parity, not before.
- [ ] Backup/restore and traceability regression on canonical app.
- [ ] Real authenticated physical-iPhone material homologation.
- [ ] Real authenticated desktop material homologation as needed.
- [ ] Public `index.html` promotion only after explicit user authorization.
- [ ] Preserve fixed homologation/public links.

## Execution order from now
1. P0 canonical app + Dashboard + real data + navigation + mobile/desktop QA.
2. P1 all six modules inside the same canonical app.
3. P2 search/classification/documents/write lifecycles.
4. P3 planning/reconciliation/documentary gaps, with documentary work continuing in parallel where safe.
5. P4 Open Finance provider evidence and integration path; provider/consent/spend waits for explicit user decision.
6. P5 production hardening and explicit promotion.

## Current user action
NONE. Continue autonomous work until a real financial/classification/provider/consent decision is necessary or a materially testable canonical app is ready.
