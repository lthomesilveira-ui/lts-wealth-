# WIP35 v155 homologation exposure checkpoint — 04/09/2026

## Scope
- v155 functional recovery integrated to `main` without force and exposed only on the fixed homologation channel.
- Public `index.html` remains unchanged; public promotion remains unauthorized/not done.
- Candidate: `wip35-v155-candidate.html`; runtime: `wip35-v155-runtime.js`.

## Rejected predecessor
- v154 visual language was retained, but v154 itself is rejected for product readiness after real iPhone testing exposed unreliable navigation and false-zero financial display.
- Root causes and pre-integration correction evidence are preserved in `backups/WIP35_V155_FUNCTIONAL_RECOVERY_CHECKPOINT_2026-09-04.md`.

## Integration / exposure
- Integrated v155 baseline: `3f54c4df145d4ec81a9b61513a9fecd28f93f3ef`.
- Controlled exposure commit: `5a8f43cefdacf5eb4a2817dfedd8dbcd58a57f47`.
- `homologacao-current.json` points to version `v155`, path `wip35-v155-candidate.html`, with `promotion_status:not_promoted`.

## Evidence
- Branch gate `33928444995`: SUCCESS; deterministic desktop/mobile physical clicks over all six routes; false-zero guard; D+3 component-recovery guard; no page-level horizontal overflow.
- Branch artifact `9957671192`; digest `sha256:144662d3e31ac02d983ab24f507c8b3c4c9f9c731e31f534a77c5a150e531248`.
- Exact-main gate `33928619024`: SUCCESS.
- Integration Pages `33928618809`: SUCCESS.
- Exact exposure gate `33929115651`: SUCCESS.
- Exact exposure Pages `33929115081`: SUCCESS.
- No authenticated financial-data E2E is claimed. The no-fixture CI smoke had no authenticated user session and no usable financial read model.

## v155 correction contract
- Missing/null financial fields are not converted to false zero.
- D+3 display recovery is limited to already-evidenced eligible bank cash + D0 + vested D+3 components; FGTS excluded.
- Missing monthly spend shows unavailable/`—`, never fabricated R$0,00.
- Action-count display can fall back to existing top-action evidence when the headline count is missing/zero but actions exist.
- Navigation retries readiness across Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações.
- No new financial/backend writer was introduced.

## Financial guardrails
- FGTS latest documentary position remains R$22.432,31 at 21/08/2026; restricted/approximately D+30; excluded from D+3.
- No future FGTS contributions/accrual projected.
- Old R$3.700/month FGTS accrual and dependent projections are historical-only until the Planning bridge is recalculated.
- Facts remain above projections; scenarios never become facts.

## Release status
- v155 is ready for material authenticated user homologation on the fixed homologation URL.
- Public promotion is not authorized and has not occurred.
- Real authenticated visual/data E2E remains pending/unclaimed.
