# LTS Wealth — Canonical App v1 performance + authenticated lifecycle checkpoint — 06/09/2026

## Purpose
Immutable checkpoint after hardening the recovered canonical baseline for real authenticated usage. This package improves the existing canonical app without changing its frontend architecture, financial facts, classifications, valuation inputs, planning rules or documentary evidence. Public `index.html` remains protected and no physical-iPhone E2E is claimed.

## Source package
Canonical branch source commits before this checkpoint:
- `850ce27a9727d5ebce1f9b259e32f9aa85337c79` — cockpit read path reuses the already-reconciled cached wealth payload and avoids redundant cache writes.
- `39d111e8c4138d030c75a2811cae79884f58d010` — grants authenticated execution only to the existing server-side transaction-search RPC; anonymous/public execution remains revoked.

Supabase migrations applied successfully:
- `canonical_cockpit_cached_wealth_2026_09_06`
- `canonical_transactions_authenticated_acl_2026_09_06`

The canonical frontend itself remains `canonical-app.html`, functional source commit `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`; no wrapper/iframe release line was reintroduced.

## Cockpit performance improvement
Authenticated cockpit timing before this package was approximately **3487.7 ms** in the measured real-data read path because `lts_browser_dashboard_cockpit_v1()` recomputed the full wealth report on every read.

After the cached-wealth optimization, five consecutive authenticated calls measured:
- 20.1 ms
- 3.8 ms
- 3.6 ms
- 3.5 ms
- 3.5 ms

The reader now uses `lts_product_read_cache.payload->wealth_executive` when its `reconciliation_version` is `wealth-summary-current-effective-v1`, falling back to the full wealth computation only when that canonical reconciliation is unavailable/stale.

No arithmetic changed. Post-optimization authenticated values remained exactly:
- bank cash R$15.794,43;
- D0 R$42.929,50;
- vested D+3 R$12.909,65;
- through D+3 R$71.633,58;
- FGTS R$22.432,31;
- request FGTS by 30/11/2026;
- management/action point 30/12/2026;
- first negative/uncovered gap 30/01/2027;
- worst before FGTS -R$25.782,39;
- worst after current documentary FGTS -R$3.350,08;
- assets central R$5.464.065,89;
- known debt R$1.894.371,38;
- net worth central R$3.569.694,51;
- four current distribution rows remain available.

## Regression evidence
After the performance migration:
- `lts_fix86_legacy_guardrails_qa_v4`: **10/10 PASS**.
- `lts_liquidity_refresh_v2_transactional_qa_v1`: **8/8 PASS**.

These preserve historical parity, append-only mutation semantics, scenario/read-only guardrails, stale-anchor protection, liquidity composition, wealth/cockpit parity, Planning Flow v13, future-cache movement semantics, targeted refresh and rollback cleanliness.

## Authenticated route/read audit
The canonical frontend RPC surface was audited against the functions it actually calls. Authenticated execution is present for:
- `lts_browser_product_v1`;
- `lts_browser_dashboard_cockpit_v1`;
- `lts_browser_expense_context_lens_v1`;
- `lts_browser_wealth_detail_v1`;
- `lts_browser_card_history_coverage_v1`;
- `lts_browser_document_lifecycle_v1`;
- `lts_browser_transactions_v1` after the ACL fix;
- `lts_browser_semantic_feedback_v1`.

Authenticated reads returned successfully in one transaction:
- product: OK;
- cockpit: `dashboard-cockpit-v2-documentary-fgts-no-projection`;
- Despesas: `expense-context-lens-v1`;
- Patrimônio: `wealth-detail-v2-rsu-financing-cipo-corrected`;
- Cartões: `card-history-coverage-summary-v1`;
- Documentos: `document-lifecycle-v2-change-summary`.

## Authenticated transaction search proved
Before the ACL fix, an authenticated call to `lts_browser_transactions_v1` failed with `permission denied for function lts_browser_transactions_v1`. The RPC itself was already `SECURITY DEFINER`, called `lts_browser_assert_user_v1()` and filtered rows by the asserted user, so the missing authenticated EXECUTE grant was a real access defect rather than a financial/data-model issue.

After the ACL fix, authenticated search for `Mastercard` returned:
- total: **239** rows;
- first date: **01/11/2013**;
- last date: **12/04/2028**;
- all 239 returned amount fields numeric.

This matches the existing documentary/backend search evidence. Anonymous/public execution remains revoked.

## Authenticated liquidity browser contract proved transactionally
The actual browser RPC chain was exercised inside a deliberate rollback using only existing eligible options returned by the backend:
- active bank account: Itaú;
- documented cash-investment asset: Cofrinho Itaú, D+0;
- QA movement: R$100 application;
- preview version: `liquidity-movement-preview-v2-effective-balance`;
- preview economic effect: R$0;
- bank delta: -R$100;
- asset delta: +R$100;
- authenticated apply: OK;
- targeted refresh: OK;
- browser version: `liquidity-movement-browser-v2-reviewed-effective-refresh`.

Observed before/after inside the QA transaction:
- bank cash R$15.794,43 → R$15.694,43;
- D0 R$42.929,50 → R$43.029,50;
- through-D3 R$71.633,58 → R$71.633,58.

After rollback, the unique QA idempotency key had:
- 0 `lts_liquidity_movement` rows;
- 0 `financial_events` rows.

Therefore the authenticated browser preview→apply→refresh data contract is proven without persisting a financial event. This does **not** claim that a dedicated user-facing liquidity control is already exposed in `canonical-app.html`; that UI wiring remains a separate product task.

## Classification state / why no fake QA decision was made
Current `semantic_review.items` is empty and reports 0 pending groups. `card_classification_review` currently has pending human-review items, but `safe_suggestion_groups` is **0** and all visible suggestions are explicitly marked `suggestion_safe:false` and/or taxonomy/context guarded.

No category was invented or simulated as a user decision just to make a lifecycle test pass. Real authenticated classification save→refresh→resolved remains open until there is a legitimate user-confirmed/safe case.

## What remains open
- authenticated physical-iPhone financial/data E2E remains pending and unclaimed;
- classification save→refresh→resolved when a legitimate decision exists;
- real authenticated PDF/image interpret→review;
- dedicated user-facing natural-liquidity UI wiring, despite its authenticated backend/browser contract now being proven;
- user-facing reversal/undo beyond proven append-only cancel/edit/split semantics;
- expense density/evidence-only classification refinement;
- Mastercard/Visa documentary gaps;
- incomplete RSU settlement evidence;
- CIPÓ documentary/reconciliation gaps;
- Volvo exact trim/version/km before valuation refinement;
- Open Finance provider/commercial/consent decision;
- public root promotion only with explicit user authorization.

## User action
No action required to create this checkpoint. The next material gate is fixed homologation after this source package is integrated to `main`; physical-iPhone validation remains explicitly separate.