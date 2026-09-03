# WIP35 v150 canonical-docs closure checkpoint — 03/09/2026

## Purpose
This immutable checkpoint closes the documentation drift discovered during the v150 continuity handoff. It does not change product code, financial behavior, fixed-homologation routing, or the protected public fallback. The Git commit that first adds this file is the canonical anchor for this closure checkpoint.

## Audited pre-closure repository state
- `main` before this docs-only closure: `c8bf30f1ffde34dc15f08f71c3b01bf387592372`.
- Active v150 branch head: `25e517a28f900e281966d00a44cba827e49efb85`.
- Fresh `main...v150-expenses-input-dashboard-recomposition` compare showed the branch fully contained in main (`ahead_by=0`, `behind_by=3`) before this closure.
- The three commits after the branch head were the v150 homologation exposure plus two documentation/evidence commits; no divergent v150 product work remained.
- Fresh compare from exposure commit `97fff4d35cc0c3edd24a11b458a1bed7d885ddcb` to pre-closure main showed only `NEXT_HOMOLOGATION_GATE.md` and `backups/WIP35_V150_HOMOLOGATION_EXPOSURE_CHECKPOINT_2026-09-03.md` changed after exposure.

## v150 product / release evidence retained
- Exact green product/gate SHA: `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- Branch workflow `33784295793`: SUCCESS; job `100745221087`; artifact `9904891998`; digest `sha256:3a2550ddc480b17182cedfff16ef49d8756387195509816f163bc5d56145c8ea`.
- Integrated-main baseline `25e517a28f900e281966d00a44cba827e49efb85`; v150 workflow `33785378395` SUCCESS; Pages `33785376825` SUCCESS.
- Controlled exposure commit `97fff4d35cc0c3edd24a11b458a1bed7d885ddcb`.
- Exact exposure v150 workflow `33796998363`: SUCCESS; job `100786998249`; artifact `9909647698`; digest `sha256:735cc4082378302a8b04ad710898a485defe6cf7909f2f9af65e0e292e02d388`.
- Exact exposure candidate-smoke `33796998174`: SUCCESS.
- Exact exposure v148 classification lifecycle `33796998303`: SUCCESS.
- Exact exposure Pages `33796996669`: SUCCESS.
- All nine workflows triggered by the exposure commit reached terminal conclusions without in-progress/null/failure/cancellation at release closure.
- v150 exact smoke covers desktop/mobile Dashboard, Despesas context×nature + drill-down, Atualizações quick tools, reviewed-input route to `Entradas`, read-only Fluxo lookup, version ownership and no forbidden writer RPCs.
- Inherited v146 navigation regression remains 10 × 7 destinations × desktop/mobile = 140 physical Playwright clicks.

## Fixed homologation / public protection
- Fixed URL: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- `homologacao-current.json` points to `v150` / `wip35-v150-candidate.html` / product SHA `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- `promotion_status` remains `not_promoted`.
- Protected public `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public root promotion remains unauthorized/not done.
- Real authenticated visual E2E remains pending/not claimed.

## Canonical docs reconciled by this closure
- `PROJECT_MASTER_BACKLOG.md` now records v150 as integrated/exposed and retains every known open financial, documentary, classification and product dependency.
- `NEXT_HOMOLOGATION_GATE.md` now makes material user homologation of v150 the current release gate and preserves the exact evidence chain.
- `LTS_WEALTH_CONTINUITY_HANDOFF.md` now describes v150 as the current fixed homologation release and carries forward v146/v147/v148/v149 contracts plus all financial invariants/open blockers.
- Historical immutable release checkpoints remain untouched.

## Open backlog deliberately retained
- Material user homologation of v150.
- Real authenticated visual E2E.
- Public promotion only after explicit user approval.
- Real authenticated PDF/image interpretation→review.
- Real authenticated classification save→refresh→resolved disappearance/self-heal/`O que mudou`.
- Natural-liquidity authenticated save→refresh→visible.
- Append-only auditable cancellation/reversal semantics.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary recovery; never fabricate aggregate-only detail.
- All CIPÓ blockers: R$303,60 delta; date/overlap ambiguity; condominium source; raw/dedup gaps; duplicate excess; no fabricated post-2029 TR; no automatic taxable/net-gain conclusion.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/support/SLA/product×bank for Itaú/Bradesco/C6; no consent/spend/credential/provider commitment without explicit user authorization.
- Further performance only after correctness/parity.
- Continued historical pending-item audit back to project start 07/07/2026.
- Preserve balance visual emphasis, compact Atualizações checklist, no large whitespace regression, mobile/desktop usability, fixed links, backup and traceability.

## Financial invariants explicitly unchanged
- Planning management point 08/01/2027; FGTS request-by 09/12/2026; documentary FGTS R$17.509,05; existing accrual R$3.700/month; request-date FGTS R$32.309,05; worst before -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027 under the current model.
- Despesas invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Card certified 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36; C6 Aug/2024 explicit R$66,70 gap.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded; 283-unit sale R$19.673,72 theoretical gross / R$19.095,04 net / R$578,68 unitemized difference.
- FGTS historical R$25.585,03 and current R$17.509,05 remain distinct temporal positions.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031, exactly once economically.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites plus supplemental v143 16/16. These are accumulated suites, not one monolithic gate.
