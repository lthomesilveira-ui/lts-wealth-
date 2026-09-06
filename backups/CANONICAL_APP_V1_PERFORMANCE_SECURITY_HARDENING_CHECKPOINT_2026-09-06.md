# LTS Wealth — Canonical App v1 performance + security hardening checkpoint — 06/09/2026

## Purpose
Immutable checkpoint after improving real authenticated read performance and reducing unnecessary direct database/API exposure without changing financial facts, classifications, valuation inputs, planning rules, documentary evidence or the canonical frontend. `index.html` remains protected and authenticated physical-iPhone E2E is not claimed.

## Source / deployment state before integration
- Canonical frontend remains `canonical-app.html`; no wrapper/iframe architecture reintroduced.
- Main performance source commit: `f673f63616b6af439bcf0de3bc09f98979a5f41e` — cached reconciled wealth in Patrimônio reader.
- Security source commit before this checkpoint: `d414e01060dfe09f46e76e4b4fb113ae2de124ed` — `supabase/canonical_security_surface_hardening_2026_09_06.sql`.
- Security branch is a clean fast-forward from `f673f636...`; pre-checkpoint compare to main was one added SQL file only.
- Public `index.html` was not modified.

## Patrimônio performance
Authenticated `lts_browser_wealth_detail_v1()` previously took approximately **4.0 s** because it recomputed the full wealth executive report even when the reconciled wealth payload already existed in `lts_product_read_cache`.

After `canonical_wealth_detail_cached_wealth_2026_09_06`:
- measured authenticated read: approximately **241.7 ms**;
- cached wealth is used only when `reconciliation_version = wealth-summary-current-effective-v1`;
- fallback recomputation remains for missing/stale reconciliation;
- `cached_equals_live_v5 = true` after the change;
- wealth detail version remains `wealth-detail-v2-rsu-financing-cipo-corrected`;
- current distribution still has 4 rows.

No arithmetic changed. Current canonical financial invariants remain bank R$15.794,43; D0 R$42.929,50; vested D+3 R$12.909,65; through D+3 R$71.633,58; FGTS R$22.432,31; assets central R$5.464.065,89; known debt R$1.894.371,38; net worth central R$3.569.694,51.

Other measured readers were already adequate and were not modified merely for activity: Product ~125 ms; Cartões ~92 ms; Documentos ~20 ms; Despesas ~16 ms.

## Security hardening migration
Supabase migration `canonical_security_surface_hardening_2026_09_06` applied successfully.

The package intentionally changes only permissions/RLS/view execution semantics:
- enabled RLS on `lts_flow_event_operation`, `lts_flow_mutation_audit`, `lts_category_catalog`;
- removed direct PUBLIC/anon/authenticated table privileges from those internal tables;
- converted `lts_expense_analytics_candidate`, `lts_expense_realized`, `lts_expense_analytics_candidate_fast_v1` to `security_invoker=true` and removed direct browser access;
- fixed `lts_browser_enrich_flow_bank_gross_v1(jsonb)` search path to `pg_catalog, public` and removed direct browser execution;
- preserved `lts_browser_expense_context_nature_v1(date,date)` as authenticated-only compatibility for the historical public fallback;
- removed browser execution from a set of internal/QA/arbitrary-user functions while preserving the intentional authenticated `lts_browser_*` wrappers.

Post-migration permission checks confirm:
- the three internal tables have RLS enabled and no direct anon/auth SELECT;
- the three expense views are invoker-safe and have no direct anon/auth SELECT;
- internal functions sampled (`lts_daily_flow_fix86_v14`, `lts_updates_fix86plus_v11`, `lts_refresh_dashboard_cockpit_v2`) are not executable by anon/authenticated;
- the flow enrichment helper has fixed search path and no direct browser execution;
- the compatibility expense browser RPC remains anon-blocked/authenticated-enabled.

## Post-hardening authenticated compatibility
Inside authenticated transaction, all canonical/fallback readers returned successfully:
- Product: `lts-product-fix86-v36`;
- Dashboard: `dashboard-cockpit-v2-documentary-fgts-no-projection`;
- Despesas canonical: `expense-context-lens-v1`;
- Despesas fallback compatibility: `expense-context-nature-matrix-v1`;
- Patrimônio: `wealth-detail-v2-rsu-financing-cipo-corrected`;
- Cartões: `card-history-coverage-summary-v1`;
- Documentos: `document-lifecycle-v2-change-summary`;
- Mastercard transaction search: 239 results;
- historical public fallback Flow v3: 30 current/future days returned for the tested range.

## Regression evidence after hardening
- `lts_fix86_legacy_guardrails_qa_v4`: **10/10 PASS**.
- `lts_liquidity_refresh_v2_transactional_qa_v1`: **8/8 PASS**.
- `lts_browser_liquidity_movement_contract_qa_v1`: **17/17 PASS**.
- `lts_document_lifecycle_qa_v1`: **17/17 PASS**.
- `lts_document_association_qa_v1`: **5/5 PASS**.
- `lts_document_outcome_state_qa_v1`: **4/4 PASS**.
- `lts_document_outcome_browser_contract_qa_v1`: **4/4 PASS**.

## Security advisor interpretation
After the migration, the targeted critical findings disappeared: no remaining advisor ERROR for the three expense SECURITY DEFINER views, no RLS-disabled errors for the targeted internal tables, and no mutable-search-path warning for the flow enrichment helper.

Remaining advisor items are not to be blindly “zeroed”:
- many `rls_enabled_no_policy` INFO items are intentional internal tables with browser grants already removed;
- authenticated SECURITY DEFINER warnings remain for deliberate browser API wrappers; those wrappers are the public RPC boundary and call user-scoping assertions, so revoking them would break the product rather than improve it;
- Supabase Auth leaked-password protection remains disabled at project configuration level and is not claimed as fixed by SQL;
- performance advisor also reports `health_*` objects in the same Supabase project; LTS Health is out of scope for this Wealth hardening and was not modified.

## Product gaps preserved truthfully
- user-facing natural-liquidity control is still not exposed in `canonical-app.html`, although options/preview/apply/refresh backend contract is proven 17/17 and transactional write QA is rollback-clean;
- current liquidity options are 3 active bank accounts and 1 documented cash investment (`Cofrinho Itaú`, D+0); no account/asset/value may be guessed;
- Dashboard wealth history has no reconciled time series and remains unavailable rather than fabricated;
- the only positive operational entry inspected for Sep/2026 was a R$1.846,08 Organon PIX; it is not labeled as income because salary/reimbursement/other economic nature is not evidenced;
- physical-iPhone authenticated visual/data E2E remains pending and unclaimed;
- classification remains human-only where evidence is insufficient;
- documentary/RSU/CIPÓ/Volvo/Open Finance blockers remain unchanged.

## Promotion / user action
No public-root promotion is authorized or performed. The fixed homologation remains the testing surface. No user action is required to preserve this checkpoint; continue autonomous product work until a genuine decision or physical-device final gate is required.
