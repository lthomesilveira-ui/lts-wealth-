# LTS Wealth — V166 feedback closure checkpoint

Business date: 16/09/2026.

## Reproducible release identity
- Preserved user-accepted base: V165 product commit `6bcdfb1f78baf944e6f215da045b75ef3244d4de` and candidate `wip35-v165-candidate.html`.
- V165 baseline contract: `backups/V165_USER_ACCEPTED_BASELINE_2026-09-16.md`.
- V166 product head: `117c467a02641c1b7e167493fda6f916e7927e14`.
- V166 candidate: `wip35-v166-candidate.html`.
- Runtime assets: `lts-v166-feedback-closure.js` and `lts-v166-feedback-closure.css`.
- Database migration: `supabase/canonical_v166_feedback_closure_2026_09_16.sql`, applied to project `tadhkamnwtsbdozwkyut`.
- Protected public root: `index.html` SHA-256 `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`; not promoted.

## User feedback closed
- Atualizações count equals the visible action list. Paid September invoice tasks are no longer shown; only current documentary and future-cycle work remains.
- Priority actions either open the matching search or a recurrence proposal based on historical evidence; no proposal writes before explicit confirmation.
- Incremental search works without a date. Results expose edit/open controls after asynchronous loading. Editable projections use the audited writer; protected future sources are routed to the exact Flow year instead of dead-ending.
- Despesas period controls update the period, totals and charts. Cartões is an internal view and lists the invoices available to the reconciled reader.
- Technical coverage copy was replaced by user-facing data-language while classification and documentary coverage remain distinct.
- Dashboard horizon covers the current and following year and expense composition is populated from the authenticated reader.
- Patrimônio shows one CIPÓ asset, restores `Empréstimo pai e mãe`, and exposes the documented CIPÓ purchase/works detail.
- RSU normal remains 100%; Cash RSU remains 70% net after 30% tax reserve. Original dates are immutable; anticipated dates, action price and FX are user-editable audited assumptions.
- Vested shares and brokerage cash are separated. The 18/02/2027 Cash RSU enters projected liquidity on 21/02/2027 (D+3) for the evidenced net amount.

## Real authenticated evidence
- Published browser opened V166 with a real authenticated session and five routes.
- Dashboard, Despesas period switch, Cartões invoices, Patrimônio, CIPÓ detail, family loan, RSU schedule and assumption dialog were inspected without saving test mutations.
- Atualizações returned three `retention` rows and exposed `Editar` plus `Abrir no Fluxo` for every asynchronous result.
- Flow 14/09/2026 reconciled exactly: opening `10,732.19` + entries `4,068.00` - exits `9,828.72` = closing `4,971.47`.

## Automated evidence
- V166 branch workflow `35042586885`: SUCCESS.
- V166 main workflow `35042587776`: SUCCESS.
- Pages workflow `35042586995`: SUCCESS.
- Static gate preserves V165 checkpoint, protected root, append-only actions, private-value exclusion from migration and asynchronous search decoration.

## Remaining human gate
- The user may continue material visual/financial review. New feedback is additive to this checkpoint; V165/V166 must not be reconstructed from chat memory.
- Public-root promotion remains a separate explicit decision.
