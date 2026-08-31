# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-08-31 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before writing.

## Conduct
- Preserve every open financial/documentary dependency; never compact it away.
- Project updates to the user use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, valuation or reconciliation.
- Ask the user only when a real financial/classification/documentary decision is required.
- Test before asking user homologation; do not delegate basic QA.
- Never claim authenticated visual E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.

## Release state
- Public fixed root: `https://lthomesilveira-ui.github.io/lts-wealth-/`
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`
- Current homologation manifest remains **v142** (`wip35-v142-candidate.html`). Do not move to v143 before final v143 integration/gates/smoke/Pages/docs.
- Public `index.html` fallback remains WIP35-v136, protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Main known at this handoff: `53b586b3feec95089d26cfc2cf797576131c2b50`; re-fetch before any write.
- Active branch: `v143-life-real-feedback`; branch was still advancing when this handoff was written. Re-fetch branch head.

## User feedback v142 that v143 must close before next homologation
1. Dashboard: preserve D+3 liquidity hero, add a second balance including FGTS, and move the negative-cash action much higher. Human wording: explain that without an action the account crosses zero; if FGTS is the contingency, show request-by date and ~D+30 timing.
2. Dashboard vs Planning: Planning must stop repeating Dashboard. It becomes `Liquidez detalhada`, explaining negative windows, resource order and conditional inflows.
3. Atualizações: button must open reliably; surface evidence-assisted classification. Classification order is own LTS history first, public merchant research second, user confirmation when ambiguous.
4. Recurrence/future audit: generic, not hardcoded to salary/IPVA. Compare recurring history against future 12 months; examples such as school, condominium, IPTU, salary etc. are examples only. No automatic value projection from historical median.
5. Despesas: values must be auditable; human labels and context. Drill-down must explain `Benjamin · Educação`, `Benjamin · Saúde`, Rafiki, IPTU, financing/loans etc.; avoid technical `merchant` language as primary UI. Clicking ranked lines must open composition.
6. Cartões: restore card detail model with semantic/classification consolidation plus raw-item evidence. Add card×month table so user can validate what is considered for C6, Itaú and Bradesco. Open invoice = observed amount; future installments = known contracted floor, not predicted closing.
7. C6 open invoice must show the same useful consolidated-by-classification block as the good Aeternum model, while retaining `A classificar` where evidence is insufficient.
8. Patrimônio: restore RSUs/vestings as a major component; show current vested position, all future known vesting/availability events, and a read-only `Simular antecipação` scenario. Future awards stay outside acquired current net worth until vesting/settlement.
9. Patrimônio: restore loans/financings and create CIPÓ 396 drill-down with purchase/reform historical outlays, documentary debt, market central estimate, equity and financing schedule; do not call the difference tax profit without a validated tax/cost rule.
10. Volvo XC40 financing: user confirmed Bradesco. 60 installments, first 08/09/2026, last 08/08/2031, R$2,886.43 each. Must appear in Bradesco Flow and Patrimônio. Account-assignment QA 6/6 PASS.
11. Button QA: user should not have to test every button. Static census plus runtime navigation/click-through must be green; financial writers remain transactional/rollback QA unless real authenticated execution is safe.

## v143 implementation already present on active branch
- `wip35-v143-candidate.html` wraps v142, keeping public fallback untouched.
- `wip35-v143-life-real.js`: human Dashboard, `Liquidez detalhada`, expense drill-down, card×month matrix, card composition, RSUs/vestings, anticipation scenario, CIPÓ detail, Volvo/financing visibility.
- `wip35-v143-feedback-polish.js`: evidence-first classification panel, recurring-future audit panel, focus/scroll behavior for opened details.
- `wip35-v143-ownership.js`: added after a runtime smoke exposed lower-layer renderer/navigation reclaims; uses configurable accessor ownership so future versions can still override deliberately.
- Button static audit is being expanded to include v143 files rather than only the inherited 174-button v142 census.

## Classification evidence example
- `GULA GULA MORUMBI`: two Aeternum Sep/2026 lines, total R$725.46, still `A classificar` in purchase detail.
- Merchant enrichment exists: merchant `Gula Gula`, suggested category `Restaurantes`, confidence 0.99, provider `public_research`, official site evidence, status `taxonomy_review` because historical taxonomy between restaurant/leisure labels is protected. Do not auto-confirm taxonomy.
- General rule: exact user-confirmed semantic rule > exact historical single-category evidence > public merchant identification suggestion > manual review. Marketplaces/payment intermediators never imply final merchant purpose.

## Backend/gates current evidence
- Core financial regression v5: **15/15 PASS**.
- Shared Flow QA updated truthfully from retired Flow v12/operational v3 assumptions to **Flow v13 / operational v4**, **6/6 PASS**.
- Candidate UI extension QA updated from old browser RPC v9/v3 assumption to current browser RPC v10/API40 + operational v4, **6/6 PASS**.
- Heavy gate v14: **293 checks / 24 suites PASS** after current-QA fixes.
- Delta v15: **67 / 5 PASS**.
- Delta v16: **19 / 2 PASS**.
- New v17 life-real/current-rollover delta: **32 / 4 PASS**.
- Individual staged evidence therefore totals **411 checks / 35 suites**, but before final certification rerun on a frozen final DB/code fingerprint; do not describe as one monolithic same-fingerprint gate until then.
- Real authenticated visual E2E remains pending/unclaimed.

## Important fixed financial guardrails
- Despesas historical invariant: R$8,623,752.53; 3,860/3,860 analytical rows; zero missing/extra/mismatch.
- Historical card certified allocation: 38 cycles / 650 rows / R$885,855.19.
- Aggregate fallback: 314 rows / R$2,650,846.36; preserve aggregate-only when purchase composition is unavailable.
- C6 Aug/2024 explicit detail gap R$66.70; never invent the line.
- CIPÓ open blockers remain unresolved: Itaú consortium delta R$303.60; condominium source formula/cut; R$6,654.50 = R$6,502.70 + R$151.80 is arithmetic overlap evidence only; no suppression.
- Planning Excel bridge: management point 08/01/2027; FGTS request-by 09/12/2026; conservative projected FGTS on request date R$32,309.05; worst before contingency -R$21,046.80; worst after planned FGTS +R$11,262.25. This is liquidity management, not proven resource insufficiency.
- RSU current documentary vested value R$32,772.30 and 459.483 units; old 283-unit sale settled 05/08/2026, theoretical gross R$19,673.72 vs liquid proceeds R$19,095.04; R$578.68 difference not itemized and must not be invented.
- Liquidity movement writer: bank↔asset, economic effect zero, explicit preview/approval, Flow v13 / Planning / Dashboard / Wealth v5 / future cache refresh; QA writes rolled back.

## Historical reconciliation still open and must continue after v143 package
- Mastercard open evidence 2019–2025 registry, especially fragmented/partial cycles; 2023 has 12 ledger-only payments totaling R$496,689.05 with independent category matrix missing.
- Visa 2017 and Visa Infinite Itaú 2024 aggregate-only documentary gaps remain explicit.
- CIPÓ consortium/condominium blockers above.
- Classification with no sufficient evidence.
- Guided document association UI.
- Liquidity cancellation/reversal semantics.
- Volvo exact trim/km refinement before valuation refinement.
- Open Finance provider/pricing/SLA/bank-coverage decision remains backlog; no external consent/spend/credential without explicit user decision.
- Real authenticated visual E2E and user homologation.

## Immediate execution after handoff
1. Re-fetch `main` and active branch.
2. Finish v143 deterministic ownership/nav smoke; do not weaken the test.
3. Ensure v143 button census includes v143-generated controls and zero unresolved identifiable buttons.
4. Run branch candidate smoke desktop/mobile and inspect logs/artifact, including real navigation clicks in unauthenticated shell; separately preserve transaction/ACL QA for financial actions.
5. Freeze backend fingerprint and rerun staged v14 + v15 + v16 + v17 evidence.
6. Synchronize `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md` and create immutable v143 checkpoint.
7. Re-fetch `main`, integrate branch via normal PR/merge; no force.
8. Verify same-SHA candidate-smoke + Pages on main.
9. Only after all above, switch fixed homologation manifest v142→v143 and ask user to retest. Do not promote public `index.html`.
