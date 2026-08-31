# LTS Wealth — Next Homologation Gate

Purpose: minimum evidence-backed package before asking the user to inspect the next material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` and immutable checkpoints.

## Current release baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation URL: `homologacao.html`.
- v143 integrated normally through PR #6.
- Integrated baseline main SHA: `0526033f33ef90086388a946470313bd5002180c`.
- Candidate-smoke run `33401135988`: SUCCESS on that exact SHA.
- Pages run `33401135026`: SUCCESS on that exact SHA.
- `index.html` blob on that SHA remains exactly protected.
- `homologacao-current.json` is switched to `wip35-v143-candidate.html` in this coherent exposure package; post-switch same-SHA smoke + Pages are the only remaining technical release gate before user homologation.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## v143 package evidence
- Frozen implementation code SHA: `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- Branch candidate-smoke run `33399959217`: SUCCESS.
- Desktop 1440×1000 PASS; mobile 390×844 PASS.
- Dashboard/Planejamento/Despesas/Cartões/Patrimônio/nav ownership v143 true.
- Inherited v142 Dashboard/nav/Planning/Wealth pointers redirect to v143.
- Real main-nav click-through changes `window.V` for every destination.
- Nav shows `Liquidez detalhada` for internal `Planejamento`.
- Zero root overflow; zero console/page errors.
- Button census: **197 identifiable / 197 wired / 0 unresolved / 0 anonymous**.
- This remains non-authenticated browser runtime/composition evidence, not authenticated visual E2E.

## P0 product requirements closed in v143
- Dashboard: **“Sua vida financeira, em uma tela.”**, D+3 realizable liquidity hero, separate restricted/D+30 FGTS-inclusive reading, human cross-zero warning, request-by timing and `Fatura vencida / a confirmar`.
- Planejamento: visual label `Liquidez detalhada`, resource order bank cash → D0/Cofrinho → vested RSU → future vestings when actually available → FGTS D+30; negative episodes and action deadline explained without duplicating Dashboard.
- Atualizações: action/checklist-first, evidence-assisted classification, generic recurrence audit with no hardcoded example list and no historical-median auto-projection.
- Despesas: clickable evidence-backed composition using category/group/macrogroup/center-cost/human context.
- Cartões: classification consolidation + raw evidence + Cartão × mês; open invoice observed-now and future installments only known contracted floor.
- Patrimônio: vested RSU/future vestings, read-only anticipation scenario, CIPÓ drill-down and Volvo Bradesco financing.

## Audited Planning conclusion — immutable unless new evidence/decision
- first management point: **08/01/2027**;
- FGTS request-by: **09/12/2026**;
- documentary FGTS 18/08/2026: **R$17.509,05**;
- existing accrual model: **R$3.700/mês**;
- projected request-date FGTS: **R$32.309,05**;
- worst balance before contingency: **R$-21.046,80**;
- worst balance after planned contingency: **R$+11.262,25**;
- first uncovered gap through 28/02/2027: none.

Interpretation: January is a liquidity-management point covered by the already-modeled D+30 FGTS contingency if requested on time. It is not evidence of real patrimonial insufficiency.

## Final backend evidence
Fingerprint before and after the final staged battery: `85a1b60816a5b84dfe3b41341ed27948`.
- v14: 24 suites / 293 checks PASS.
- v15: 5 / 67 PASS.
- v16: 2 / 19 PASS.
- v17: 4 / 32 PASS.
- total staged: **35 suites / 411 checks PASS**.
- supplemental `lts_v143_life_real_backend_qa_v2`: **16/16 PASS** on same fingerprint.
The 411-check set is same-fingerprint staged evidence, not a single monolithic gate.

## Open invariants / blockers retained
- Despesas invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 R$66,70 detail gap remains explicit.
- Mastercard/Visa documentary gaps remain open; no inferred purchase detail.
- CIPÓ consortium delta R$303,60, overlap/date ambiguity and condominium formula/cut remain unresolved; no post-2029 TR fabrication.
- Volvo exact trim/km remains required before valuation refinement.
- Classification ambiguity still requires user confirmation when evidence does not close.
- Guided document association UI remains open.
- Liquidity cancellation/reversal semantics remain open and must be append-only/auditable.
- Open Finance provider/pricing/SLA/bank coverage remains open; no consent/spend without explicit user decision.
- Real authenticated visual E2E remains pending/unclaimed.

## Remaining gate before user action
1. Re-fetch the manifest-switch `main` SHA.
2. Candidate-smoke must PASS on that exact SHA and confirm the fixed entrypoint targets v143.
3. Pages build/deploy must PASS on that exact same SHA.
4. Reconfirm protected `index.html` blob is unchanged.
5. Optionally perform an additional deployed fixed-link unauthenticated browser/runtime check if tooling supports it; never call it authenticated E2E.
6. Only then state **AÇÃO SUA NECESSÁRIA** and ask the user for material visual homologation through the fixed `/homologacao.html` URL.
7. Public `index.html` remains untouched until explicit user approval.
