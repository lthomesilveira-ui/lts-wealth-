# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current release baseline — v158 corrected — 05/09/2026
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation manifest points to **v158** through `wip35-v158-candidate.html`.
- Source branch remains `v158-native-core-auth-mobile-recovery`; branch staged head `ecc7feb534921a93ac54064cd7e743d841a2486c` and was not force-moved.
- Corrected candidate head on `main`: `86171f5748e706d7dd9c5abdd6ac7b55b5444294`.
- Manifest refresh commit: `05ea21cabcf6078e050e3e532877204450476a6c`.
- `promotion_status:not_promoted`; public root promotion is NOT AUTHORIZED / NOT DONE.
- Authenticated visual/data E2E: PENDING / NOT CLAIMED.
- Immutable evidence baseline: `backups/WIP35_V158_NATIVE_CORE_AUTH_MOBILE_RECOVERY_CHECKPOINT_2026-09-05.md`; corrected-target addendum must remain preserved in subsequent checkpointing.

## Why the first v158 exposure was invalid
- The first v158 candidate incorrectly loaded `index.html?v158-native-core`.
- Public `index.html` is intentionally the protected WIP35-v136 fallback, so the homologation URL could be on v158 while its embedded product visibly rendered v136.
- The user's observation that the v158 link opened v136 was therefore correct and exposed a release-wiring defect, not a cache assumption.
- The first attempted correction to `wip35-v151-candidate.html` still failed CI because the gate inspected only the first wrapper document while the real app is nested deeper in the existing same-origin core chain.

## Corrected v158 contract
- `wip35-v158-candidate.html` no longer targets public `index.html`.
- It loads the existing evidence-bearing product core chain through `wip35-v151-candidate.html?v158-native-core`.
- The v158 layer recursively follows the bounded same-origin iframe chain to find the actual login/app document; it does not synthesize financial KPI values.
- If the active browser context is unauthenticated, the real login state must surface; if authenticated, the real app/data layer owns financial state.
- Mobile adaptation remains limited to the six established routes in one fixed row: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- No `document.write`, permanent `setInterval` or `MutationObserver`; bounded retry burst only.
- Public `index.html` remains unchanged.

## Exact corrected release evidence
- Superseded shallow-inspection run `33974643243`: FAILURE; this failure was diagnostic and is not hidden.
- Corrected nested-core WebKit/Chromium run `33974901298`: **SUCCESS** on exact candidate head `86171f5748e706d7dd9c5abdd6ac7b55b5444294`.
- WebKit iPhone-equivalent truthfulness gate: SUCCESS.
- Chromium desktop native-core smoke: SUCCESS.
- Exact GitHub Pages deployment `33974901021`: **SUCCESS** on the same head `86171f5748e706d7dd9c5abdd6ac7b55b5444294`.
- `homologacao-current.json` now uses corrected candidate head `86171f5748e706d7dd9c5abdd6ac7b55b5444294` and still points to `wip35-v158-candidate.html`.
- CI remains unauthenticated. These gates do not prove the user's authenticated financial session and must not be represented as authenticated E2E.

## Current material user gate — v158 corrected
1. Open the fixed homologation URL on the real iPhone.
2. It must no longer render the protected v136 public fallback as the v158 content.
3. If that browser context has no active LTS session, the native/core login should be visible; authenticate normally in that context if prompted.
4. After authentication, real product data must load from the existing core chain.
5. Physically navigate Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard; no clipped route, dead control or route trap.
6. Confirm there is no overlapping text regression like the v157 `Despesas (mês)` card.
7. Do not perform a financial write merely for QA.
8. Public promotion remains a separate explicit authorization and cannot be inferred from homologation approval.

## Current FGTS / planning invariant
- Latest documentary FGTS balance: R$22.432,31 at 21/08/2026.
- Restricted / approximately D+30 contingency; excluded from D+3.
- No future FGTS contributions projected.
- Historical R$3.700/month accrual and dependent R$32.309,05 request-date / worst-case outputs are historical evidence only, not current validated forecast.
- First-negative date and management/action date must be revalidated under the conservative FGTS rule and shown separately if different.

## Open blockers retained
- Material authenticated physical-iPhone homologation of corrected v158.
- Real authenticated visual/data E2E.
- Real authenticated classification save→refresh/resolved disappearance/self-heal/`O que mudou`.
- Real authenticated PDF/image interpretation→review.
- Authenticated natural-liquidity save→refresh→visible result.
- Append-only auditable cancellation/reversal semantics.
- Server-side transaction search completion, total and Excel-compatible CSV export.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary gaps; never pattern-fill.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps and duplicate excess; no fabricated post-2029 TR or automatic taxable/net-gain conclusion.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend/credential/provider commitment without explicit user decision.
- Continue historical pending-item audit back to 07/07/2026.
- Public promotion only after explicit user approval.
