# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a new public candidate. This file is operational and must stay aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current public baseline
- WIP35-v136 remains the canonical public fallback.
- Do not publish a microbuild.
- Real authenticated visual E2E remains pending/unclaimed.

## Current data-recovery position — 2026-08-29
- Historical expense total: R$ 8,623,752.53 invariant.
- Certified historical category-allocation cycles: 34.
- Historical effective rows through 2026-08-29: 3,767.
- Rows with recovered category detail: 3,449.
- Remaining card aggregate fallback rows: 318, totaling R$ 2,714,803.16.
- Mastercard Itaú 2025 certified: Mar, Apr, May, Jun, Aug, Nov.
- Mastercard Itaú 2025 candidate only: Jan, Feb, Jul, Oct.
- Mastercard Itaú 2025 blocked: Sep, Dec.
- Mastercard Itaú 2024 pending ledger identities: Jan/1829/R$53,652.87; Feb/1871/R$58,667.61; Apr/1966/R$47,802.70; Jun/2061/R$48,393.80; Jul/2104/R$51,947.18; Nov/2281/R$45,259.24.

## Minimum package before next user look
1. Data/history: materially reduce historical card aggregate fallback using only documentary exact closures. Do not require all 318 rows to be eliminated; blocked evidence gaps remain explicit.
2. Despesas UX: next candidate must visibly improve navigation/drilldown, not just backend coverage. Prefer direct interaction from executive category/rank/trend into evidence-backed transaction detail where merchant evidence exists, while retaining category-only drilldown where merchant detail does not exist.
3. Atualizações UX: make checklist lifecycle explicit: received → interpreted → reconciled → decision needed → resolved; resolved items must leave the active worklist reliably.
4. Actionability: empty states and decision states in the touched modules must tell the user what can be done next, without technical diagnostics in the primary reading layer.
5. Regression: expense v9/v10, core financial regression, projection bridge and operational health must be green after the material package.
6. Candidate QA: parser and smoke must be green before publication; prior public v136 stays fallback on failure.
7. Visual QA: do not claim authenticated visual E2E unless actually performed. If not available, disclose it as pending when asking the user to inspect.

## Current readiness assessment
- Backend/history: advanced but still in progress; 34 exact certified cycles.
- Despesas visible package: not yet material enough beyond v136 for user review.
- Atualizações lifecycle package: still open.
- Regression safety: currently green after the latest historical recovery batch.
- Publish readiness: NOT YET. Continue internal work.

## Trigger to ask user to look again
Ask the user to inspect only when all of the following are true:
- at least one visible Despesas interaction improvement is implemented and internally checked;
- Atualizações active checklist/lifecycle is materially clearer or another equally material visible package is completed;
- latest financial gates are green;
- candidate parser/smoke is green;
- public fallback behavior is preserved.

Historical recovery should continue in parallel but unresolved documentary gaps alone must not indefinitely block a useful visual candidate, provided they are explicitly disclosed and no inference is introduced.
