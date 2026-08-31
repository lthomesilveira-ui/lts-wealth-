# LTS Wealth — Next Homologation Gate

Purpose: minimum evidence-backed package before asking the user to inspect the next material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` and the latest immutable checkpoint.

## Current release baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Effective prior visual baseline remains v135.
- Fixed homologation URL: `homologacao.html`.
- `homologacao-current.json` remains **v142** (`wip35-v142-candidate.html`).
- Main re-fetched immediately before this documentation package: `53b586b3feec95089d26cfc2cf797576131c2b50`.
- v143 implementation code head: `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## v143 package now internally green before integration
Branch smoke run `33399959217` on exact code SHA `0291737238b6b0bd69fe4c9bf3c348598a4b2277`: **SUCCESS**.

Validated:
- full v143→v142→v141→v140→v139→v138→v137→index composition chain;
- desktop 1440×1000 PASS;
- mobile 390×844 PASS;
- Dashboard owner v143 true;
- Planejamento owner v143 true;
- Despesas owner v143 true;
- Cartões owner v143 true;
- Patrimônio owner v143 true;
- nav owner v143 true;
- inherited v142 Dashboard/nav/Planning/Wealth pointers redirect to v143;
- real navigation click-through changes `window.V` for every main destination;
- nav label is `Liquidez detalhada` while internal destination remains `Planejamento`;
- zero root overflow;
- zero console/page errors;
- button census **197 identifiable / 197 wired / 0 unresolved / 0 anonymous**.

Important limit: this is non-authenticated browser runtime/composition/click-through evidence. It is not authenticated visual E2E.

## P0 product requirements closed in v143 package
- Dashboard is again **“Sua vida financeira, em uma tela.”**.
- D+3 realizable liquidity remains the hero.
- FGTS-inclusive reading is separate and explicitly restricted/D+30, never presented as cash available today.
- Future liquidity risk is high in the page with human cross-zero wording and request-by timing.
- `Fatura vencida / a confirmar` is restored to the executive snapshot.
- Planejamento is visually `Liquidez detalhada` and deepens rather than repeats Dashboard.
- Jan/2027 is described as a management point, not proven patrimonial insolvency, because the audited planned FGTS contingency leaves the horizon positive when initiated on time.
- Atualizações remains action/checklist-first and contains evidence-assisted classification.
- Recurrence audit UI is generic; no fixed list of condominium/IPTU/education/salary examples controls behavior.
- Despesas has clickable evidence-backed composition with human context.
- Cartões restores classification consolidation + raw evidence + Cartão × mês and keeps open-bill vs future-installment semantics separate.
- Patrimônio restores vested RSU/future vestings, read-only anticipation scenario, CIPÓ drill-down and Volvo Bradesco financing.

## Financial conclusion that must not change by assumption
- first management point: **08/01/2027**;
- FGTS request-by: **09/12/2026**;
- documentary FGTS 18/08/2026: **R$17.509,05**;
- existing accrual model: **R$3.700/mês**;
- projected FGTS already existing on request date: **R$32.309,05**;
- worst balance before contingency: **R$-21.046,80**;
- worst balance after planned contingency: **R$+11.262,25**;
- first uncovered gap through 28/02/2027: none.

Required interpretation: January is a liquidity-management point covered by the already-modeled D+30 FGTS contingency if requested on time. It is not evidence of real patrimonial insufficiency.

## Final backend evidence frozen before integration
Fingerprint before and after the entire final battery: `85a1b60816a5b84dfe3b41341ed27948`.

Staged gates:
- v14: **24 suites / 293 checks / PASS**;
- v15: **5 suites / 67 checks / PASS**;
- v16: **2 suites / 19 checks / PASS**;
- v17: **4 suites / 32 checks / PASS**;
- total staged: **35 suites / 411 checks PASS**.

Supplemental read-model QA:
- `lts_v143_life_real_backend_qa_v2`: **16/16 PASS** on the same fingerprint.

The 411-check set is same-fingerprint staged evidence, not a single monolithic gate. Transactional liquidity QA deliberately rolls back all QA movement/cache mutations.

## Invariants and blockers still open
- Despesas invariant **R$8.623.752,53**; analytical cache 3.860/3.860 exact.
- Certified card allocation 38 cycles / 650 rows / R$885.855,19.
- Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 R$66,70 detail gap remains explicit.
- Mastercard/Visa historical documentary gaps remain open; no inferred purchase detail.
- CIPÓ consortium delta R$303,60 and condominium formula/cut remain unresolved; arithmetic proximity does not authorize suppression or rewrite.
- Post-2029 TR is never fabricated.
- Volvo valuation refinement waits for exact trim/km evidence.
- Classification ambiguity waits for user confirmation when evidence does not close.
- Guided document association UI remains open.
- Liquidity cancellation/reversal semantics remain open and must be append-only/auditable.
- Open Finance provider/pricing/SLA/bank coverage remains open; no consent/spend without explicit user decision.
- Real authenticated visual E2E remains pending/unclaimed.

## Exact remaining gate before user sees v143
1. Re-fetch `main` and branch after this documentation/checkpoint commit.
2. Integrate `v143-life-real-feedback` through normal merge/PR semantics; no force.
3. Candidate-smoke must pass on the integrated **same SHA of main**.
4. GitHub Pages build/report/deploy must pass on that exact same main SHA.
5. Verify protected `index.html` blob unchanged.
6. Only then move `homologacao-current.json` from v142 to `wip35-v143-candidate.html`.
7. Run fixed-entrypoint candidate-smoke + Pages on the manifest-switch SHA.
8. Only after those are green ask the user for material visual homologation through the fixed `/homologacao.html` URL.
9. Public `index.html` remains untouched until explicit user approval.

There is currently **no user QA action required**. Integration/deployment verification remains autonomous work.
