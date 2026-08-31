# LTS Wealth — WIP35 v146 Homologation Exposure Checkpoint

Checkpoint date: 2026-08-31

## Purpose
Record the controlled fixed-homologation switch from v145 to v146 after the v146 navigation/Patrimônio correction passed branch and integrated-main gates. This checkpoint does not authorize public `index.html` promotion, does not change financial rules/data/writers, and does not claim authenticated visual E2E.

## Release state before this exposure
- `main` integrated SHA: `a2bfb254144efccb3da52d8e8fdc15a5c4182235`.
- Public fallback remains WIP35-v136, protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation still resolved v145 before this exposure commit.
- Promotion status was and remains `not_promoted`.

## v146 evidence before exposure
- Exact product SHA: `bef91e27927dc8b73f89239568dd0ae81cd68707`.
- Branch run `33443494728`: SUCCESS; artifact `9777202035`.
- Pre-integration checkpoint: `backups/WIP35_V146_PREINTEGRATION_CHECKPOINT_2026-08-31.md`.
- Pre-integration/integrated commit: `a2bfb254144efccb3da52d8e8fdc15a5c4182235`.
- Integrated-main v146 run `33444432578`: SUCCESS.
- Integrated-main Pages `33444431699`: SUCCESS.
- Integrated v146 run reran inherited parser/static, v142 browser and v143 runtime/navigation gates, then passed the v146 classification + repeated-navigation smoke.
- Repeated-navigation coverage: 10 cycles × 7 destinations × desktop/mobile = **140 physical Playwright clicks**, including `Cartões` → `Patrimônio` in every cycle.

## Regression and correction
The reproduced hang occurred when a physical navigation click moved from `Cartões` to `Patrimônio`. The final cause was inherited v142 wealth-loader completion/retry behavior: after v146 redirected Patrimônio ownership to v143 and retired the redundant legacy loader, a stale loader completion could still invoke `render()` and re-enter Patrimônio, sustaining an effective retry/render loop.

v146 suppresses that stale completion render after retirement, keeps stable nav nodes, and coalesces navigation state/render work outside the synchronous click path. No financial rule, amount, classification, backend writer or economic effect changed.

## Exposure change
This exposure commit switches `homologacao-current.json` to:
- version `v146`;
- path `wip35-v146-candidate.html`;
- candidate head `bef91e27927dc8b73f89239568dd0ae81cd68707`;
- public fallback `index.html`;
- promotion status `not_promoted`.

v145 remains the immediately prior homologation rollback reference. Public `index.html` is not changed by this exposure.

## Required exact exposure-SHA evidence
Before telling the user to access the fixed homologation URL, require all of:
1. v146 navigation/classification workflow SUCCESS;
2. legacy `candidate-smoke` SUCCESS — this exposure changes `homologacao-current.json`, so the legacy workflow path filter must trigger;
3. Pages SUCCESS;
4. public `index.html` blob still exactly `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`;
5. manifest resolves v146 / `wip35-v146-candidate.html` / candidate `bef91e279…` / `not_promoted`.

Only after those gates are green may the user be told `Pode acessar agora`.

## First material homologation focus
- Navigate repeatedly among all main tabs and specifically `Cartões` → `Patrimônio`.
- Confirm Dashboard title/subtitle remain stable with no flicker.
- Confirm Atualizações remains classification-first, with suggestion, research/history evidence, confidence, dropdown and save actions intact.
- Confirm no large blank region or duplicate evidence panel returns.

## Open blockers carried forward
- Real authenticated visual E2E remains pending/unclaimed.
- Guided document association and improved PDF/image interpretation with manual review.
- Authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`.
- Authenticated natural-liquidity save→refresh→visible result and append-only cancellation/reversal semantics.
- Mastercard/Visa historical documentary gaps; never infer missing purchase detail.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps; no fabricated post-2029 TR.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend/credential without explicit user decision.
- Human classification where evidence remains ambiguous.
- Public `index.html` promotion only after explicit user approval.
