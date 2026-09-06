# LTS Wealth — Canonical App v1 recovery baseline checkpoint — 06/09/2026

## Purpose
Immutable recovery checkpoint proving a minimum usable canonical baseline after the user requested restoration of at least the functionality already validated. This checkpoint does not promote the protected public root and does not claim physical-iPhone authenticated E2E.

## Product baseline preserved
- Canonical frontend remains `canonical-app.html`; no wrapper/iframe release chain was reintroduced.
- Functional frontend source remains commit `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`, 79,339 bytes, SHA-256 `2ce0e6e92575c8ca11bc8178f54bc13a6b6c8bf05b0b75bc9b05046c1c1638f8`.
- Fixed homologation remains `canonical-v1` through `canonical-app.html` with `promotion_status:not_promoted`.
- Existing deterministic frontend gate `34003647351` remains the browser evidence for Chromium desktop 1312×1199 and WebKit mobile 390×844: five KPIs, all six physical routes, Fluxo account switching, Despesas dual lens/drilldown, Patrimônio, Cartões, Atualizações search/CSV/classification/documents, no iframe, no horizontal overflow, mobile navigation fit and truthful unauthenticated login.
- Public `index.html` remains protected and unchanged.

## Recovery read-model package applied
Supabase migrations applied successfully:
- `canonical_read_model_reconciliation_2026_09_06`
- `canonical_recovery_qa_alignment_2026_09_06`

GitHub source commits on `canonical-app-v1` before this checkpoint:
- `fee0438de1a46a61fbc284497f5cd54deb711769` — canonical wealth and bank-flow read-model reconciliation.
- `3498d668649b26ebfcf10833263623f5e2dac0b3` — QA expectation aligned to the already-current documentary-FGTS cockpit v2 contract; no financial/product logic changed.

## Current authenticated read evidence
Authenticated browser-RPC path was exercised transactionally with rollback and returned the current canonical contract:
- bank cash R$15.794,43;
- D0 R$42.929,50;
- vested D+3 R$12.909,65;
- liquidity through D+3 R$71.633,58;
- documentary FGTS R$22.432,31;
- FGTS request-by 30/11/2026;
- management/action point 30/12/2026;
- first uncovered/negative gap 30/01/2027;
- worst before FGTS -R$25.782,39;
- worst after current documentary FGTS -R$3.350,08;
- future FGTS accrual remains disabled.

## Patrimony reconciliation proved
The current wealth read model now uses current effective positions rather than summing superseded snapshots as simultaneous positions.

Validated output:
- assets central R$5.464.065,89;
- known debt R$1.894.371,38;
- net worth central R$3.569.694,51;
- net worth low R$2.944.694,51;
- net worth high R$4.199.694,51;
- restricted contingency R$22.432,31;
- future awards excluded R$1.717.810,87;
- distribution sum equals assets central exactly: difference R$0,00;
- net worth + debt equals assets exactly: difference R$0,00.

Distribution exposed to the canonical browser read:
- Liquidez até D+3 R$71.633,58;
- FGTS R$22.432,31;
- CIPÓ 396 central model input R$5.200.000,00;
- Volvo XC40 central model input R$170.000,00.

Brokerage cash R$2.862,67 remains `available_unclassified` and is not added to D0/D3 by this reconciliation. No new valuation, classification or financial assumption was introduced.

## Fluxo Diário recovery proved
Gross bank entries/exits are enriched from the existing canonical flow events for Itaú, Bradesco and C6.

Reconciliation result:
- 129 day×account rows checked;
- 0 mismatches;
- maximum absolute difference R$0,00;
- 15 rows with activity;
- `entries - exits = net` exactly for every checked bank/day row.

## Regression evidence
Post-migration tests:
- `lts_fix86_legacy_guardrails_qa_v4`: 10/10 PASS.
- `lts_liquidity_refresh_v2_transactional_qa_v1`: 8/8 PASS after correcting only its stale expected cockpit version string from v1 to the already-current `dashboard-cockpit-v2-documentary-fgts-no-projection`.
- Liquidity transactional QA proves Flow composition, through-D3 neutrality, Wealth parity, Cockpit parity, Planning Flow v13, future cache movement semantics, refresh contract and rollback cleanliness.
- Authenticated browser product/cockpit reads return the reconciled current values and 43 flow days; browser read test was wrapped in a rollback.

## What this checkpoint means
The project is not at zero. The canonical minimum functional baseline is preserved and its real-data read contract has been reconciled. The recovery work did not rebuild the product from scratch, did not reintroduce historical wrappers and did not modify source financial facts.

## Still open / not claimed
All pre-existing open dependencies remain open, including:
- authenticated physical-iPhone financial/data E2E;
- real authenticated classification save→refresh lifecycle;
- real authenticated PDF/image interpretation→review;
- authenticated natural-liquidity save→refresh→visible;
- user-facing append-only reversal/undo contract;
- evidence-only expense/classification refinement;
- Mastercard/Visa documentary gaps;
- incomplete RSU trade settlement evidence;
- CIPÓ documentary/reconciliation gaps;
- Volvo exact trim/version/km before valuation refinement;
- Open Finance provider/commercial/consent decision;
- full historical dependency audit back to 07/07/2026;
- public `index.html` promotion only with explicit user authorization.

## User action now
NONE for the recovery baseline. Continue autonomous hardening/evolution; physical-iPhone validation remains a later final material gate and must not be claimed until actually executed.
