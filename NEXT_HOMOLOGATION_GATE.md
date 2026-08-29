# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current baseline
- Public fallback: WIP35-v136 in `index.html`; untouched.
- User’s effective visual baseline: v135, because newer visuals have not been personally homologated.
- Isolated candidate: `wip35-v139-candidate.html`.
- Latest effective candidate-chain commit: `3459b8138a63eba5417a48439da4b46195c4d084`.
- Browser candidate smoke run 33276722702: SUCCESS on exact commit; four-frame chain opened, v137/v138/v139 injections verified, zero browser errors.
- Chromium readiness mode used a neutral synthetic payload + local RPC no-op + render no-op only after a clean boot. This is explicitly NOT authenticated E2E.
- Public fallback blob guard still matches v136 exactly.
- Real authenticated visual E2E: PENDING / NOT CLAIMED.

## Candidate evidence currently green
### Financial/data invariants
- Historical expense total invariant: R$8,623,752.53.
- Effective expense cache: 3,767/3,767 rows, zero mismatch.
- Expense v9: 19/19 PASS after latest browser-readiness fixes.
- Expense v10: 18/18 PASS after latest browser-readiness fixes.
- Core financial regression: 15/15 PASS after latest browser-readiness fixes.
- Candidate fast readiness v3: 15/15 PASS in ~133.9 ms.
- Browser RPC ACL: 48 `lts_browser_*` RPCs, anon exposed = 0.
- Planning QA: 23/23 PASS.
- Wealth QA: 18/18 PASS.
- Classification cache consistency: 5/5 PASS.
- Document lifecycle/change summary: 17/17 PASS.
- Flow cache parity/security: PASS.
- Documentary expense counterparty/merchant QA: 4/4 PASS.
- Card-history coverage QA: 5/5 PASS.

### Chromium candidate smoke
Run 33276722702 / job 99164624563:
- `chainOk=true` for v139 → v138 → v137 → v136.
- `injectionsOk=true`.
- v137 CSS present.
- v138 CSS present.
- v139 CSS/stamp present.
- `baselineErrors=[]`.
- `candidateErrors=[]`.
- `bootNewErrors=[]`.
- `newErrors=[]`.
- Immutable evidence: `backups/wip35-v139-browser-smoke-batch9-2026-08-29.json`.

This closes a non-authenticated browser composition/readiness layer only. It is not authenticated visual E2E, financial click-path E2E, or user homologation.

### Auth→RPC path
Transactional simulated JWT/`authenticated` checks passed without residual writes for:
- `lts_browser_expense_executive_v4` → cached executive expense contract.
- `lts_browser_expense_merchant_drilldown_v1` → documentary structured-card-merchant contract.
- `lts_browser_card_history_coverage_v1` → dynamic historical coverage contract.
- `lts_browser_flow_v4` → successful future read.
- `lts_browser_document_lifecycle_v1` → `document-lifecycle-v2-change-summary`.
- `lts_browser_product_v1` → `ok=true`, cache payload `lts-product-fix86-v36`.

This closes an auth/RPC layer only. It is not browser rendering, click E2E, or visual homologation.

## Despesas candidate
- Timeout architecture replaced by exact-parity cache-backed read (~0.20s backend versus ~29.2s old path).
- Month/year/rolling analysis, category trend/ranking and certified month drilldown remain available.
- Range-level documentary lens is wired in candidate:
  - card merchant appears only when structured individual purchase evidence exists;
  - cash counterparties are separate;
  - recovered category-only and aggregate fallback never become fabricated merchants.
- Example 2023→29/08/2026 evidence coverage: structured card merchants 289 rows / R$66,200.29; category-certified history R$821,898.39; recovered-category C6 R$58,727.98; aggregate fallback remains explicit.
- Blocker before closure: real authenticated visual/browser retest.

## Cartões candidate / historical validation
- Cockpit presents open exposure, next cash pressure, contracted installments, bill agenda, 12M trajectory and classification pending.
- Historical coverage is dynamic, not a hardcoded certification list:
  - 34 certified cycles;
  - 553 certified category-allocation rows / R$821,898.39;
  - 318 aggregate-fallback rows / R$2,714,803.16;
  - C6 recovered detail shown separately.
- Visa Infinite Itaú 2025: 12/12 certified.
- Mastercard Itaú 2025 certified: Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct still candidate; Sep/Dec blocked.
- Mastercard Itaú 2024 certified: Mar/May/Aug/Sep/Oct/Dec; Jan/Feb/Apr/Jun/Jul/Nov pending.
- C6 Aug/2024 individual detail gap R$66.70 remains blocked.
- Latest File Library retry briefly returned the workbook but targeted retrieval then failed technically again. No new Mastercard cycle was certified from partial snippets.
- Historical recovery does not need to reach zero fallback before visual homologation, but every remaining gap must stay explicit.

## Fluxo
- Future candidate read uses `lts_browser_flow_v4`, authenticated-only.
- Current parity: 30/30 days and 13/13 events against Flow v12.
- 33-day cached backend benchmark ~13ms versus ~4.59s direct.
- Mutations invalidate future cache.
- Chromium candidate boot is now clean; this still does not prove authenticated data rendering.
- Blocker before closure: real authenticated visual/browser retest of original timeout regression.

## Planejamento
- Single-pass executive model ~3.96s versus ~9.84s old implementation, JSON parity exact.
- First modeled gap remains 08/01/2027; worst gap R$-21,046.80; 3 episodes; FGTS remains ~D+30 contingency; v131 12/01 counterfactual preserved.
- Candidate is materially redesigned from rejected report layout.
- Blocker: real visual homologation.

## Atualizações / classification / documents
- Primary queue = 6 near actions; 4 far-future coverage items collapsed; 2 informational items collapsed as context.
- Workflow line compacted; classification confidence/history/options evidence-backed.
- Current card review: 48 groups, 9 suggestions, 0 safe auto-application groups.
- 26 economically effective August card lines were checked against exact history/rules and remain genuine review gaps.
- Scoped classification refresh and permanent cache QA are green.
- Lifecycle v2 `O que mudou` is based only on applied targets.
- Confirmation/manual-invoice writes use targeted refreshes.
- v137/v138 premature-render defects found by Chromium have been fixed; candidate now boots with zero browser errors before synthetic readiness.
- Blocker: authenticated save/click→refresh→UI validation.

## CIPÓ
- Current reconciliation remains explicitly incomplete where evidence is insufficient.
- Condomínio: early exact duplicates found, but deduplication does not reproduce source `Pago`; closest tested deduplicated gap still R$1,312.268. No automatic correction.
- Consórcio Itaú: source R$19,508.10 vs raw ledger R$19,811.70; R$303.60 delta mathematically signals overlap but does not prove invalid row. No automatic correction.
- These gaps are not blockers for visual UX homologation, but must remain visible/documented.

## Open Finance
- Provider-neutral connection/sync/staging architecture exists with RLS and no browser policy.
- Idempotency is protected by user/provider/resource/provider-record key.
- External `created/updated/deleted` lifecycle is representable; provider delete never silently deletes canonical LTS history.
- `open-finance-architecture-qa-v2`: 10/10 PASS.
- Research file `OPEN_FINANCE_PROVIDER_RESEARCH_2026-08-29.md` currently ranks Pluggy as first sandbox candidate, Belvo benchmark, Klavi alternative to validate.
- No account, token, credential, bank consent, production plan or commercial commitment exists.
- Open Finance production is not a blocker for the next visual homologation; real provider/consent/paid decision requires user approval later.

## Minimum package before next user look
1. Critical Despesas/Fluxo backend regressions technically fixed with parity gates green. **GREEN internally; visual authenticated retest pending.**
2. Cartões/Planejamento materially redesigned. **IMPLEMENTED; user visual approval pending.**
3. Atualizações primary decision flow compact and evidence-backed. **IMPLEMENTED; click-path auth E2E pending.**
4. Inputs lifecycle shows actual applied changes. **IMPLEMENTED; authenticated UI validation pending.**
5. Candidate parser/static smoke. **GREEN.**
6. Chromium composition/readiness smoke. **GREEN via run 33276722702; not authenticated E2E.**
7. Auth→RPC contract on core candidate surfaces. **GREEN transactionally; not visual E2E.**
8. Fast readiness / browser ACL. **GREEN 15/15; 48 browser RPCs, anon exposure 0.**
9. Public v136 fallback untouched. **GREEN.**
10. No financial/data gate regression. **GREEN: core 15/15, expense v9 19/19, expense v10 18/18.**
11. Do not claim authenticated visual E2E unless actually done. **Still pending/unclaimed.**

## Readiness
- Backend/data safety: GREEN.
- Candidate parser/Chromium smoke: GREEN.
- Financial regressions: GREEN.
- Auth→RPC contract: GREEN.
- Historical card recovery: PARTIAL BY EVIDENCE; blocked gaps preserved.
- Real authenticated visual E2E: PENDING.
- User visual homologation of latest candidate: PENDING.
- Promotion to `index.html`: NOT AUTHORIZED / NOT DONE.

## Trigger to ask user to test
Do not ask for basic QA. Ask only when no further meaningful non-visual/internal check can reduce risk without the user. At that point provide a short ordered homologation script focused on the pages/features changed since v135.
