# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current release baseline — v155 — 04/09/2026
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation manifest points to **v155** through `wip35-v155-candidate.html`.
- v155 integrated baseline: `3f54c4df145d4ec81a9b61513a9fecd28f93f3ef`.
- Controlled exposure commit: `5a8f43cefdacf5eb4a2817dfedd8dbcd58a57f47`.
- `promotion_status:not_promoted`; public root promotion is NOT AUTHORIZED / NOT DONE.
- Authenticated visual/data E2E: PENDING / NOT CLAIMED.
- Pre-exposure immutable evidence: `backups/WIP35_V155_FUNCTIONAL_RECOVERY_CHECKPOINT_2026-09-04.md`.
- Exposure evidence: `backups/WIP35_V155_HOMOLOGATION_EXPOSURE_CHECKPOINT_2026-09-04.md`.

## Why v154 was rejected
- Its visual direction was materially closer to the official reference, but real iPhone homologation exposed functional defects.
- Route controls were not reliably functional.
- Nullable financial fields were converted with `Number(null) === 0`, creating false zeros in D+3 / monthly expenses / action-count presentation.
- The prior visual fixture gate was therefore insufficient as product-readiness evidence.

## v155 correction contract
- Reuses the v154 official-reference shell; no architecture restart.
- Null-safe financial display: missing values remain missing, never fabricated as R$0,00.
- D+3 can recover only from already-evidenced eligible components `bank_cash + d0 + d3_vested` where explicit D+3 is null/zero and component evidence is identifiable/nonzero; FGTS is never included.
- Monthly spend missing → `—` + explicit unavailable-data message.
- Action count may fall back to existing `top_actions` evidence when `actionable_count` is absent/zero but actions exist.
- Navigation retries nested application readiness for all six established routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- No new financial writer was added.

## Exact release evidence
- Branch functional gate `33928444995`: SUCCESS; desktop 1312×1199 + mobile 390×844; physical all-six-route click sequence; false-zero guard; D+3 component-recovery guard; no page-level horizontal overflow.
- Branch artifact `9957671192`; digest `sha256:144662d3e31ac02d983ab24f507c8b3c4c9f9c731e31f534a77c5a150e531248`.
- Same branch run included a no-fixture boot/navigation smoke; CI was unauthenticated and had no usable financial read model, so this is not authenticated E2E.
- Exact-main v155 functional gate `33928619024`: SUCCESS.
- Integration Pages `33928618809`: SUCCESS.
- Exact exposure v155 functional gate `33929115651`: SUCCESS.
- Exact exposure Pages `33929115081`: SUCCESS.

## Current material user gate — v155
1. Open the fixed homologation URL on iPhone and allow the Dashboard to settle.
2. Confirm the interface remains in the official-reference visual language and is not an old v151/v152/v153 layout.
3. Physically navigate Dashboard → Fluxo Diário → Despesas → Patrimônio → Cartões → Atualizações → Dashboard; no dead buttons or route trap.
4. Check `Disponível D+3`: it must show an evidenced value when available; if unavailable it must not fabricate R$0,00. FGTS must never be included in D+3.
5. Check `Despesas (mês)`: an unavailable monthly read must show unavailable/`—`, not a false R$0,00.
6. Check `Ações pendentes`: the headline and updates-in-queue evidence must not contradict each other through a false zero.
7. Inspect mobile viewport for horizontal page overflow, inaccessible nav controls or large blank-space regression.
8. Do not perform a real financial write merely for QA. Existing review/approval guardrails remain.
9. Public promotion remains a separate explicit authorization and cannot be inferred from homologation approval.

## Current FGTS / planning invariant
- Latest documentary FGTS balance: R$22.432,31 at 21/08/2026.
- Restricted / approximately D+30 contingency; excluded from D+3.
- No future FGTS contributions projected.
- Historical R$3.700/month accrual and dependent R$32.309,05 request-date / worst-case outputs are historical evidence only, not current validated forecast.
- First-negative date and management/action date must be revalidated under the conservative FGTS rule and shown separately if different.

## Open blockers retained
- Material authenticated user homologation of v155.
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
