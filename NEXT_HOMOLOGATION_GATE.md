# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current baseline
- Public fallback: WIP35-v136 in `index.html`; unchanged and not user-approved.
- User effective visual baseline: v135.
- v139 real authenticated boot failed on the user's notebook, stuck on `Carregando seu LTS…`.
- Root cause: v136 core state is lexical (`let`/`const`), while candidate layers incorrectly treated it as `window.*`; the v138 render guard could therefore block the real lexical `D` forever.
- The former Chromium test had a false-green gap because it supplied synthetic `window.D/window.S`; that mode is retired.
- v140 introduced a real lexical bridge without changing public v136. The user then confirmed v140 opened successfully in a real mobile session.
- Current material candidate: `wip35-v141-candidate.html`.
- Latest verified candidate chain head: `2bb8f5968cd2bc0ad19ba756d1522307593ccd3c`.
- Public fallback blob remains locked to `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Real authenticated visual E2E remains PENDING / NOT CLAIMED.

## Candidate evidence currently green
### Browser / serving
- Candidate smoke run **33282756752**: SUCCESS.
- GitHub Pages run **33282756246**: SUCCESS on the same head SHA.
- Chromium chain: v141 → v140 → v139 → v138 → v137 → v136.
- Real lexical bridge only; no synthetic D/S/render payload.
- Candidate parser and JavaScript syntax checks: PASS.
- v137/v138/v139/v141 injections/stamps verified by smoke.
- No new browser/page errors and no material root overflow in desktop/mobile smoke.
- This remains a non-authenticated browser composition test, not authenticated visual E2E.

### Readiness / security / shape
- `lts_candidate_fast_readiness_qa_v5`: **35/35 PASS**.
- `lts_candidate_ui_contract_qa_v1`: **17/17 PASS** against the real cached payload.
- UI contract covers Flow days, Card open cycles/history, category options, semantic review, Planning summary/layers/episodes, Updates items/maintenance/documents, and Wealth summary/CIPÓ/Volvo object contracts.
- Browser RPC ACL: 48 `lts_browser_*` functions; anon exposure = 0; 39 explicitly available to authenticated where required.
- Latest latency sample: Despesas ~103 ms; Flow 33d ~10 ms; classification queue ~1.45 s.
- v140 now installs the legacy Flow v1/v2/v3 → browser Flow v4 bridge as soon as lexical `S` is available, before product `D` must finish loading. This removes the initial-Flow race that could otherwise escape through the old slow v3 path.

### Financial/data invariants
- Core financial regression: **15/15 PASS** after v141/v140 changes.
- Expense v9: 19/19 PASS.
- Expense v10: 18/18 PASS.
- Planning QA: 23/23 PASS.
- Wealth QA: 18/18 PASS.
- Classification cache consistency: 5/5 PASS.
- Document lifecycle/change summary: 17/17 PASS.
- Documentary expense counterparty/merchant QA: 4/4 PASS.
- Card-history coverage QA: 5/5 PASS.
- Historical expense total invariant remains R$8,623,752.53; effective expense cache remains exact 3,767/3,767 rows.

## v141 product package
### Atualizações
- Backend currently has 25 maintenance checks: 10 technically actionable and 15 covered/monitoring.
- v141 presents **6 near/current operational checks** first:
  - C6 October cycle;
  - Mastercard October cycle;
  - Aeternum October cycle;
  - IPVA/licenciamento 2027 review;
  - Bradesco statement refresh;
  - C6 statement evidence.
- Four distant 2030/2031 salary/IPVA coverage checks remain auditable but collapsed.
- Fifteen covered/monitoring checks remain auditable but collapsed.
- Classification is presented as a separate workstream, not added to the headline operational-action count.
- Old duplicated v139 far-future block is hidden in v141 to avoid double presentation.
- Inner candidate badges are hidden and header/footer identify v141 while still stating public v136 is the preserved fallback.

### Fluxo Diário
- Financial truth remains Flow v12.
- Browser path is Flow v4/authenticated-only with exact cache parity.
- Initial boot is now protected by early v140 Flow v4 routing, not only by later v139 installation.
- Backend 33-day path remains comfortably below latency gate.
- User confirmed v140 real mobile boot, but full authenticated visual Flow inspection is still pending.

### Despesas
- Timeout architecture remains replaced by exact-parity cache-backed reads.
- Month/year/rolling analysis and documentary merchant/counterparty lens remain in candidate.
- Card merchant is shown only with structured individual purchase evidence; category-only/recovered/aggregate history never becomes fabricated merchant detail.
- Full authenticated visual inspection remains pending.

### Cartões
- Real cached payload currently supplies 3 open cycles and 153 monthly history points.
- Candidate cockpit separates open exposure, next cash pressure, contracted installments, historical trajectory and classification backlog.
- Historical coverage remains dynamic: 34 certified cycles, 553 category-allocation rows / R$821,898.39, 318 aggregate fallback rows / R$2,714,803.16, plus recovered C6 detail separately.
- No historical cycle may be certified from total/reference alone.

### Planejamento
- Real payload contract currently supplies 5 liquidity layers and 3 negative episodes.
- Certified semantics remain: first real modeled gap 08/01/2027; worst balance R$-21,046.80; FGTS request-by date 09/12/2026 for the first gap; FGTS remains ~D+30 contingency, never automatic cash.
- v131 12/01 counterfactual remains preserved/explained.
- Candidate remains materially redesigned from the rejected report-style layout.

### Patrimônio
- UI contract verifies `wealth_executive.assets` is a named object, with explicit `cipo_396` and `volvo_xc40` contracts; an earlier draft gate incorrectly expected an array and was fixed rather than changing product data.
- CIPÓ market estimate/debt and Volvo documentary debt remain separated from future schedules.
- Visual homologation remains pending.

## Classification status
- Current card review: 48 pending groups / 53 lines across August and future September cycles.
- Safe suggestion groups: 0. No auto-classification is authorized.
- The 26 economically effective August card lines remain genuine human-review gaps unless documentary/history evidence changes.
- Real authenticated save → refresh → UI click path remains pending because it cannot be safely simulated without a real authorized session; do not claim it as tested.

## Historical evidence gaps
- Visa Infinite Itaú 2025: 12/12 certified.
- Mastercard Itaú 2025 certified: Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct remain candidate-only; Sep/Dec blocked.
- Mastercard Itaú 2024 certified: Mar/May/Aug/Sep/Oct/Dec; Jan/Feb/Apr/Jun/Jul/Nov pending.
- C6 Aug/2024 individual-detail gap R$66.70 remains explicit.
- File Library remains intermittent; technical retrieval failure is not evidence absence and authorizes no inference.

## CIPÓ unresolved items
- Condomínio formula/cut remains unresolved; duplicate-looking raw rows must not be suppressed without full closure.
- Consórcio Itaú R$303.60 remains unresolved; mathematical overlap signal is insufficient to choose an invalid row.
- Post-2029 financing tail is TR-dependent and must never be treated as zero or fabricated exact values.

## Open Finance
- Provider-neutral private staging/writer v2 exists and architecture QA is 14/14 PASS.
- Provider delete is staged evidence, never a silent delete of canonical LTS history.
- No provider account, credential, consent or paid commitment exists.
- A real sandbox/provider/consent/commercial step requires user decision and is not a blocker for the next visual homologation.

## Minimum package before next user look
1. Public fallback unchanged. **GREEN.**
2. Real-user boot regression fixed. **GREEN on user mobile v140; notebook/full navigation still not claimed.**
3. Candidate parser/Chromium chain without synthetic readiness. **GREEN.**
4. Pages deployed on verified chain SHA. **GREEN.**
5. Readiness including UI payload-shape contract. **GREEN 35/35.**
6. Core financial regression. **GREEN 15/15.**
7. Critical Despesas/Fluxo performance regressions technically fixed. **GREEN internally.**
8. Cartões/Planejamento/Atualizações material UX package. **IMPLEMENTED in v141; user visual approval pending.**
9. Historical/classification/CIPÓ unresolved evidence stays explicit. **GREEN as guardrail; no inference applied.**
10. Real authenticated visual E2E. **PENDING / NOT CLAIMED.**
11. Promotion to `index.html`. **NOT AUTHORIZED / NOT DONE.**

## Readiness to ask user
Continue autonomous checks while they can materially reduce risk. Ask user only when the remaining blocker is genuinely visual/authenticated behavior or a real financial/classification decision. Do not ask for basic QA.

Latest immutable evidence: `backups/wip35-v141-readiness-ui-contract-batch11-2026-08-29.json`.
