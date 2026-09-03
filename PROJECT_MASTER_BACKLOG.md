# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and checkpoints. Never remove an open financial, documentary, classification or product dependency during compaction.

## P0 — v150 recomposição Dashboard / Despesas / input — 03/09/2026
- [x] Dashboard recomposed around `Disponível realizável até D+3`; bank cash, D0 and vested D+3 remain separated.
- [x] FGTS remains restricted/not immediate cash and appears only as an additional D+30 contingency layer.
- [x] Redundant top-level Planejamento navigation hidden; detailed liquidity remains inside Dashboard.
- [x] Despesas separates nature from context/person and distinguishes documentary gap, system-investigation and classification/context pending states without fabricating detail.
- [x] Expense drilldown and Fluxo query remain read-only in the v150 journey.
- [x] Reviewed-input shortcut routes to existing `Entradas` preview UI, prefills `.phrase`, adds no writer and requires explicit approval before the pre-existing writer can execute.
- [x] Exact green product/gate SHA `a67ba2d9c8fb770a463397349c67e654fe2e781f`; workflow `33784295793` SUCCESS; job `100745221087` SUCCESS; artifact `9904891998`; digest `sha256:3a2550ddc480b17182cedfff16ef49d8756387195509816f163bc5d56145c8ea`.
- [x] Same run passed architecture/static, button contracts, parser, v146 140-click navigation regression, v147 guided association, v148 classification lifecycle, v149 interpretation review and v150 desktop/mobile smoke.
- [x] Immutable pre-integration checkpoint: `backups/WIP35_V150_PREINTEGRATION_CHECKPOINT_2026-09-03.md`.
- [~] Safe `main` integration, exact integrated-main gates, Pages verification and controlled fixed-homologation exposure to v150 are the current release sequence.
- [ ] Real authenticated visual E2E remains pending/unclaimed.
- [ ] Public root promotion remains blocked pending explicit user approval.

## P0 — v149 revisão de interpretação documental — 02/09/2026
- [x] Added read-only PDF/image interpretation review on top of v147 explicit association.
- [x] Structured extraction stays evidence; user-provided association stays explicit and separate.
- [x] Missing required association remains visible/manual; filename never infers account/card/competence/date/amount.
- [x] No RPC financial writer, reconciliation, classification inference or balance effect.
- [x] Preserved v148 classification lifecycle while retiring its competing observer under v149.
- [x] First v149 gate caught a self-triggering version-label `MutationObserver` loop; fixed by idempotent stamping before release evidence.
- [x] Exact green product/gate SHA `050ca36dd14d4ffdbaa27dbfdfc579ddbfe54331`; workflow `33692647025` SUCCESS; artifact `9870669700`; digest `sha256:e470c3d9c46feb622b42371606cb11d0712ba057c6a4668ce2419e1b533d26ff`.
- [x] Integrated into `main` by normal fast-forward with `force=false`; exact integrated-main SHA `797bcc458dc4fe4fd9ac7cce4722d61238e542a0`.
- [x] Integrated-main workflow `33693382626` SUCCESS; job `100456903413` SUCCESS; artifact `9870938762`; digest `sha256:401ebbd1c788a0d8731439864d09a49061f911a2836d9f07c64d41fbc9fbbcba`; Pages `33693381251` SUCCESS.
- [x] Immutable integrated checkpoint: `backups/WIP35_V149_INTEGRATED_MAIN_CHECKPOINT_2026-09-02.md`.
- [ ] Real authenticated PDF/image interpret→review remains pending; never claim synthetic smoke as authenticated E2E.

## P0 — v146 Atualizações/navigation stability — 31/08/2026
- [x] Reproduced a real navigation hang under repeated physical Playwright clicks: transition `Cartões` → `Patrimônio` could stall before the click action returned.
- [x] Preserved v144 Atualizações classification/evidence UX and v145 Dashboard stability; no financial rule, value, classification, backend writer or economic effect changed.
- [x] v146 owns a stable seven-item navigation DOM without node recreation and coalesces navigation work outside the physical click path.
- [x] Root cause isolated to inherited v142 wealth-loader completion/retry behavior: stale completion could call `render()` after v146 had retired legacy wealth loading/ownership, reopening an effective render/retry loop exactly when `Patrimônio` became active.
- [x] Final guard suppresses stale v142 wealth-loader completion render once the legacy loader/owner is retired by v146; active Patrimônio renderer remains v143.
- [x] Exact candidate SHA `bef91e27927dc8b73f89239568dd0ae81cd68707`.
- [x] Branch gate `33443494728` SUCCESS on that exact SHA; artifact `9777202035`.
- [x] Gate reran v146 architecture/static checks, inherited button census, v142 parser/browser smoke, v143 runtime/navigation smoke and v146 classification + repeated-navigation smoke.
- [x] Repeated-navigation smoke exercises 10 cycles × 7 destinations × desktop/mobile = **140 physical clicks**, including `Cartões` → `Patrimônio` on every cycle.
- [x] Classification contract remains manual where required: GULA GULA MORUMBI shows `Restaurantes` suggestion/evidence/confidence but no auto-confirmation; intermediators remain unresolved without purpose evidence.
- [x] Pre-integration freeze commit `a2bfb254144efccb3da52d8e8fdc15a5c4182235`; checkpoint `backups/WIP35_V146_PREINTEGRATION_CHECKPOINT_2026-08-31.md`.
- [x] Integrated into `main` by normal fast-forward with `force=false`; no divergent work overwritten.
- [x] Integrated-main v146 run `33444432578` SUCCESS on `a2bfb254…`, including inherited v142/v143 gates and all 140 clicks.
- [x] Integrated-main Pages `33444431699` SUCCESS.
- [x] Public `index.html` remains protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Open financial / documentary / classification / product dependencies — retain
- [ ] Material user homologation of the next fixed candidate after controlled exposure.
- [ ] Real authenticated classification save→refresh/resolved disappearance/self-heal/`O que mudou`.
- [ ] Real authenticated PDF/image interpretation→review.
- [ ] Authenticated natural-liquidity save→refresh→visible result.
- [ ] Append-only auditable cancellation/reversal semantics; no destructive financial behavior by assumption.
- [ ] Expense density/insight refinement and evidence-only reduction of `A classificar`.
- [ ] Mastercard/Visa documentary gaps; never pattern-fill or infer purchase detail.
- [ ] CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps and duplicate excess; no fabricated post-2029 TR and no automatic taxable/net-gain conclusion.
- [ ] Volvo exact trim/km before valuation refinement.
- [ ] Open Finance pricing/SLA/product×bank coverage; no consent/spend/credential/provider commitment without explicit user decision.
- [ ] Real authenticated visual E2E.
- [ ] Public promotion only after explicit user approval.