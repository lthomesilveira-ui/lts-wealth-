# LTS Wealth — Canonical App v1 liquidity user-surface refresh v5 checkpoint — 06/09/2026

## Purpose
Immutable evidence after reducing the authenticated bank↔D0 liquidity-movement confirmation path from approximately 13.2 seconds to approximately 1.4 seconds while preserving the audited economic contract and the protected canonical frontend baseline.

## Scope
- Supabase runtime promoted to `lts_refresh_after_liquidity_movement_v5`.
- Browser writer remains `lts_browser_apply_liquidity_movement_v1`, now returning `liquidity-movement-browser-v4-user-surface-refresh`.
- Source files on `canonical-app-v1`:
  - `supabase/canonical_liquidity_incremental_refresh_2026_09_06.sql` — Flow v13 incremental foundation / v4 fallback.
  - `supabase/canonical_liquidity_user_surface_refresh_v5_2026_09_06.sql` — final v5 user-surface refresh, bidirectional QA and browser contract.
- No `canonical-app.html` change in this checkpoint.
- No `index.html` change or public-root promotion.

## Economic contract preserved
A reviewed bank↔cash-investment movement:
- requires explicit account, asset, date and positive amount;
- preview is required before the browser writer;
- application and redemption use equal-and-opposite bank and asset legs;
- economic effect is exactly R$0;
- movement is excluded from income/expense;
- browser path supports today/future movements only;
- repeated idempotency keys cannot double-apply the cache delta;
- stale/missing canonical cache automatically falls back to the previously proven full refresh path.

Current canonical financial invariants remain unchanged after rollback-clean QA:
- bank cash R$15.794,43;
- D0 R$42.929,50;
- vested D+3 R$12.909,65;
- through D+3 R$71.633,58;
- documentary FGTS R$22.432,31 at 21/08/2026, restricted / approximately D+30 and no future-accrual estimate.

## Performance progression
Measured on the same production Supabase project with deliberate rollback QA:
- original apply + all-surface refresh: approximately 13.2 s;
- Flow-v13 incremental v4: approximately 4.5–4.6 s;
- user-surface v5: approximately 1.4 s.

Latest bidirectional QA measurements:
- application: approximately 1.44 s / 5 of 5 PASS;
- redemption: approximately 1.41 s / 5 of 5 PASS.

Authenticated browser-wrapper transaction returned:
- `browser_version=liquidity-movement-browser-v4-user-surface-refresh`;
- `refresh_version=liquidity-movement-refresh-v5-user-surface`;
- `surface_fast_path=true`;
- refresh elapsed approximately 1.38 s;
- bank delta -R$100 / D0 asset delta +R$100 for the rollback application case;
- `economic_effect_brl=0`.
The transaction was rolled back. Post-check confirmed zero QA movement rows and zero QA financial-event rows.

## Why v5 is safe
Internal bank↔D0 transfer changes composition but not economic liquidity. v5 therefore:
- incrementally patches the audited 730-day Flow v13 cache;
- produces the same Flow day/event representation as a full Flow v13 recomputation;
- patches the 43-day product Flow slice;
- updates reconciled Wealth bank/D0 composition;
- refreshes the executive cockpit;
- reuses the already-audited Planning / Planning ladder / Planning executive / Dashboard economic projections because total liquidity is invariant.

A diagnostic initially found one non-financial mismatch: incremental event `confidence=user_reviewed` versus full Flow v13 `documented_current_internal_transfer`. The incremental event metadata was aligned to the full engine before promotion. After alignment, entire Flow days and events compare equal.

## Exact QA after v5 promotion
- `lts_fix86_legacy_guardrails_qa_v4`: 10/10 PASS.
- `lts_liquidity_refresh_v2_transactional_qa_v1`: 8/8 PASS; prior full path retained as regression/fallback proof.
- `lts_liquidity_user_surface_refresh_qa_v1`: 10/10 PASS across application + redemption; full Flow, economic-layer preservation, Wealth, cockpit and rollback-clean checks.
- `lts_browser_liquidity_movement_contract_qa_v1`: 19/19 PASS; authenticated-only browser wrappers, anon blocked, internal arbitrary-user functions blocked, idempotency guard present.
- `lts_document_lifecycle_qa_v1`: 17/17 PASS.
- `lts_document_association_qa_v1`: 5/5 PASS.
- `lts_document_outcome_state_qa_v1`: 4/4 PASS.
- `lts_document_outcome_browser_contract_qa_v1`: 4/4 PASS.

## Product status / next gate
Backend is ready for the canonical Atualizações UI to expose:
`Aplicar ou resgatar → conta → cash-investment asset → valor/data → preview das duas pernas → confirmação explícita → refresh`.

The UI is NOT claimed in this checkpoint. The current canonical frontend remains the previously gated single-app baseline. Physical authenticated iPhone E2E remains pending and unclaimed. User-facing undo/reversal remains disabled until a separate append-only reversal contract is explicitly implemented and gated.

## Open dependencies preserved
No documentary or financial blocker was closed by this performance package. Mastercard/Visa evidence gaps, RSU sale documentary detail, CIPÓ unresolved deltas/source gaps, Volvo exact trim/km, classification decisions requiring human evidence and Open Finance provider/commercial/consent decisions remain open exactly as before.
