# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-09-04 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before every repository write.

## Conduct
- Preserve every open financial, documentary, classification, reconciliation and product dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, recurrence, reconciliation, valuation, tax or economic-effect rules.
- Ask the user only when a real financial/classification/documentary decision is required; otherwise advance autonomously.
- Test before user homologation; do not delegate basic QA.
- Never claim authenticated visual/data E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Never force branch divergence; use normal fast-forward/merge only after fresh compare.
- Preserve historical evidence back to 2013 where supported.

## Fixed links / access
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Supabase project: `tadhkamnwtsbdozwkyut`.
- Public fallback remains WIP35-v136; protected `index.html` blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized/not done.

## Current release — v155 fixed homologation
- v154 visual direction is preserved, but v154 itself is rejected because real iPhone homologation found dead/unreliable navigation and false-zero financial display.
- v155 source branch: `v155-real-data-navigation-fix`.
- Integrated product SHA before exposure: `3f54c4df145d4ec81a9b61513a9fecd28f93f3ef`.
- Candidate: `wip35-v155-candidate.html`; runtime: `wip35-v155-runtime.js`.
- Controlled fixed-homologation exposure: `5a8f43cefdacf5eb4a2817dfedd8dbcd58a57f47`.
- `homologacao-current.json` points to v155 and `promotion_status:not_promoted`.
- Exact-main v155 gate `33928619024`: SUCCESS.
- Integration Pages `33928618809`: SUCCESS.
- Exact exposure v155 gate `33929115651`: SUCCESS.
- Exact exposure Pages `33929115081`: SUCCESS.
- Authenticated real-data E2E remains pending/not claimed.

## v155 functional contract
- Reuses v154 official-reference visual shell directly; no architecture restart and no extra wrapper iframe.
- Null-safe numeric parsing: null/undefined/empty remain missing.
- D+3 read recovery may sum only already-evidenced eligible components `bank_cash + d0 + d3_vested` when explicit D+3 is null/zero and component sum is identifiable/nonzero. FGTS is excluded.
- Missing monthly expenses render `—` and an explicit unavailable-data message; never fabricated R$0,00.
- Action count may use existing `top_actions` evidence when `actionable_count` is missing/zero but actions exist.
- Six-route navigation is captured and retried until the nested app is ready: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- Client normalization is display/read recovery only; no financial/backend writer added.

## Deterministic evidence / limits
- Branch gate `33928444995`: SUCCESS; desktop 1312×1199 + mobile 390×844; all six routes physically clicked; false-zero and D+3 recovery guards pass; no page-level horizontal overflow.
- Artifact `9957671192`, digest `sha256:144662d3e31ac02d983ab24f507c8b3c4c9f9c731e31f534a77c5a150e531248`.
- A no-fixture boot/navigation smoke also passed but CI had no authenticated user session and no usable financial read model. Do not reinterpret that as authenticated financial correctness.

## Official visual contract
- Original Dashboard source: 1312×1199; SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`.
- v155 retains the dark desktop rail, light executive canvas, five-KPI first row, dense multi-row executive cockpit, compact cards and persistent mobile navigation from v154.
- Visual reference defines hierarchy/density/language, not financial values.

## Current financial/product invariants
### Dashboard / Planning / FGTS
- Primary liquidity is available realizable through D+3; bank cash, D0 and vested RSU D+3 remain separated.
- FGTS exact documentary balance: R$22.432,31 at 21/08/2026; restricted/approximately D+30; never D+3.
- No future FGTS deposits/accrual are projected.
- Historical R$17.509,05 + R$3.700/month and dependent R$32.309,05 request-date / old worst-case figures are historical model evidence only, not current validated forecast.
- Revalidate first-negative and management/action dates under the current conservative rule and display them separately when different.
- Future RSUs remain excluded until vest/settlement.

### Despesas
- Invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Nature and context/person/cost center are distinct dimensions.
- Periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- Context→nature and nature→context drilldowns are read-only and show detail only where evidence exists.
- Evidence hierarchy: explicit user rule → exact/consistent LTS history → public merchant research → manual review.
- Marketplaces/intermediaries stay manual where purchase purpose is unproven.

### Atualizações / search / documents
- Atualizações is a compact action center/checklist; avoid large blank whitespace and buried actions.
- `Lançamento por texto` routes to existing `Entradas` preview; no automatic posting; explicit approval remains required.
- Server-side transaction search through `lts_browser_transactions_v1` remains in progress: incremental typing, supported history from 10/10/2013 + future existing launches, total, read-only results, Excel-compatible CSV export.
- Backend evidence for `Mastercard`: 239 rows from 01/11/2013 to 12/04/2028.
- Explicit document association and review contracts remain; filename never infers account/card/competence/date/value and upload alone never posts financial facts.
- Real authenticated PDF/image interpret→review remains pending.

### Fluxo Diário / liquidity input
- Mandatory Itaú, Bradesco, C6 and Consolidado; preserve history from 2013 where supported.
- `Saldo anterior | Entradas | Saídas | Saldo final`; facts > projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed own forecast.
- Bank↔liquidity-asset transfer consolidated economic effect zero.
- Natural input parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`; never guess account/asset; preview before explicit confirmation.
- Authenticated save→refresh→visible and append-only reversal semantics remain open.

### Cards / RSU / CIPÓ / Volvo
- Cards certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- Mastercard/Visa incomplete historical months remain documentary-recovery work; never pattern-fill.
- RSU vested 459.483 units / R$32.772,30 / D+3; 283-unit sale net R$19.095,04; R$578,68 difference remains unexplained/unitemized.
- CIPÓ unresolved: consortium R$303,60 delta; different-date arithmetic R$6.654,50 = R$6.502,70 + R$151,80; condominium source absent; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70. Never fabricate post-2029 TR or automatically treat market-minus-cost as taxable/net gain.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031 exactly once economically; exact trim/km remains open before valuation refinement.

### Open Finance / QA
- Provider-neutral private architecture QA 14/14; no real consent/token/provider.
- Need written pricing/support/SLA/product×bank for Itaú/Bradesco/C6; no provider commitment without explicit user decision.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites + supplemental v143 16/16.
- v146 navigation regression remains 140 physical Playwright clicks; v155 adds its own six-route desktop/mobile functional gate.

## Open backlog that must always remain visible
- Material authenticated user homologation of current v155 fixed candidate.
- Real authenticated visual/data E2E.
- Public promotion only after explicit user approval.
- Real authenticated PDF/image interpretation→review.
- Real authenticated classification lifecycle.
- Natural liquidity authenticated save→refresh→visible.
- Append-only cancellation/reversal semantics.
- Server-side transaction search + total + Excel-compatible CSV.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary recovery.
- All CIPÓ blockers listed above.
- Volvo exact trim/km.
- Open Finance pricing/SLA/product×bank.
- Planning/FGTS recalculation under no-future-accrual rule.
- Performance only after correctness/parity.
- Audit of all project dependencies/improvements since 07/07/2026 so none disappear across chats.
- Preserve official-reference visual language, compact Atualizações, no large whitespace regressions, mobile/desktop usability, fixed links, backup and traceability.
