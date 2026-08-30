# LTS Wealth — WIP35 v142 Final Recovery Checkpoint

Checkpoint date: 2026-08-30

## Release identity
- Integrated candidate main SHA: `204d5a019f7334ae6361c747552da15659919487`.
- Candidate: `wip35-v142-candidate.html`.
- Public fallback remains `index.html` / WIP35-v136, protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public fallback was not promoted and is not user-approved; effective prior visual baseline remains v135.
- Fixed homologation entrypoint: `homologacao.html`.
- At this checkpoint creation, `homologacao-current.json` still targets v141. Moving it to v142 is a separate homologation exposure step, not a public promotion.
- Real authenticated visual E2E: not performed / not claimed.

## Candidate composition frozen by this checkpoint
v142 is a coherent recovery package over the validated v141 chain and includes:
- stable v142 version ownership;
- restored executive Dashboard/cockpit;
- action-first Atualizações with an obvious natural-language launch surface;
- `Resolver agora` first-screen summary for maintenance, classification review and documents requiring a decision;
- reviewed expense/income routing to the existing approval flow;
- reviewed resgate/aplicação UI v2 with explicit preview and approval;
- hardened pt-BR amount parser (`5 mil`, `R$ 5.000`, `5000`, `3k`, `R$ 1.250,50`);
- Flow v13 effective bank↔asset liquidity propagation without income/expense double effect;
- reconciled Planning executive renderer with the Excel→current/FGTS D+30 bridge;
- executive-first Patrimônio read model/presentation;
- inherited v141 Flow balance emphasis, document outcomes, CIPÓ documentary coverage and backup metadata;
- mobile/desktop density and overflow cleanup.

## Planning P0 conclusion
The Excel→current discrepancy that blocked Jan/2027 interpretation is closed for the current model/evidence set.

Audited result:
- first management point: 08/01/2027;
- conservative FGTS request-by: 09/12/2026;
- projected FGTS already existing on the request date: R$32.309,05;
- worst balance before contingency: R$-21.046,80;
- worst balance after conservative planned FGTS D+30: R$+11.262,25;
- first uncovered gap through 28/02/2027: none.

Required interpretation: January is a liquidity-management point covered by the already-modeled D+30 FGTS contingency if requested on time. It is not evidence of real patrimonial insufficiency.

Historical bridge evidence retained:
- old Excel `Saldo Ex RSUs` was already negative by Dec/2026;
- 283 vested RSU units were documented as sold/liquidated on 05/08/2026; net proceeds R$19.095,04; theoretical gross R$19.673,72; R$578,68 difference remains explicitly unitemized and is not inferred;
- historical FGTS R$25.585,03 maps to an exact CAIXA→Itaú credit on 07/05/2026 and same-day R$25.000 investment, proving that historical withdrawal/current FGTS are different temporal states;
- Coopharma duplicate hypothesis was rejected;
- future Nov RSUs are not the cause of deterioration;
- permanent Planning bridge QA = 19/19 PASS.

## Backend / financial gates
Gates are intentionally staged to avoid timeout-prone nesting.

- Heavy v14: 24 suites / 293 checks / PASS.
- Delta v15: 5 suites / 67 checks / PASS.
  - liquidity writer v2 10/10;
  - transactional rollback 15/15;
  - liquidity read path 12/12;
  - browser ACL 17/17;
  - Dashboard cockpit 13/13.
- Delta v16: 2 suites / 19 checks / PASS.
  - refresh-v2 contract 11/11;
  - real transactional effective-surface refresh 8/8.
- Total staged evidence: 31 suites / 379 checks PASS.

Liquidity transactional QA performs a real R$100 application inside a deliberate database subtransaction, verifies bank -R$100 / D0 asset +R$100 / economic effect R$0 across effective Flow/Planning/Dashboard/Patrimônio/future cache, then rolls all financial/cache QA mutations back. No QA movement persists.

## Browser / deploy evidence
Round 3 branch smoke after deterministic Planning ownership fix:
- branch code SHA: `89ac771d0473165201400c2afe1dd31ed14fea88`;
- run: `33342878089`;
- candidate-smoke: SUCCESS;
- desktop 1440×1000: PASS;
- mobile 390×844: PASS;
- Planning bridge ownership: PASS both viewports;
- liquidity UI/parser: PASS;
- Dashboard: PASS;
- final action-first polish: PASS;
- zero new console/page errors;
- zero root overflow.

Integrated main evidence on `204d5a019f7334ae6361c747552da15659919487`:
- candidate-smoke run `33342968051`: SUCCESS;
- Pages run `33342967458`: build SUCCESS / report-build-status SUCCESS / deploy SUCCESS;
- public fallback guard remained unchanged;
- fixed homologation manifest remained v141 during these tests.

Important limit: these are non-authenticated browser composition/runtime tests plus separately authenticated backend contract/transaction tests. They are not authenticated visual E2E and are not user homologation.

## Historical and financial invariants that remain protected
- Historical Despesas economic total: R$8.623.752,53.
- Analytical historical cache: 3.860/3.860 exact.
- Historical effective parity: 2.030 days / 147 months exact through 2025.
- Certified historical card allocation: 38 cycles / 650 rows / R$885.855,19.
- Aggregate historical fallback: 314 rows / R$2.650.846,36; never promote without composition evidence.
- FIX86 transversal guardrails remain mandatory.
- C6 Aug/2024 R$66,70 remains unresolved at individual-detail level.
- CIPÓ Consórcio Itaú R$303,60 remains unresolved.
- CIPÓ Condomínio formula/cut remains unresolved; arithmetic proximity never authorizes rewrite.
- Post-2029 TR values are never fabricated.
- Volvo valuation remains provisional pending exact trim/km evidence.
- Classification triage may order human review only; it must not invent categories.
- Document association requires explicit identity/competence/as-of context; no filename inference.

## Open after this checkpoint
- expose v142 through the fixed homologation manifest only after confirming this checkpoint/docs state;
- verify fixed homologation redirect + candidate smoke + Pages on the manifest-switch SHA;
- user material visual homologation through the same `/homologacao.html` URL;
- real authenticated visual E2E remains pending/unclaimed;
- real-session save→refresh→visible-result verification for the liquidity writer;
- explicit cancellation/repair UX for a previously confirmed liquidity movement;
- Despesas final refinement without regression;
- continuing Mastercard/Visa/C6 documentary recovery;
- continuing CIPÓ blockers;
- human classification where evidence remains absent;
- guided document association UI;
- Volvo refinement only with trim/km evidence;
- Open Finance production provider/consent/spend only after explicit user decision;
- public `index.html` promotion only after explicit user approval.

This checkpoint freezes the evidence-backed v142 recovery package; it does not authorize public promotion or new financial assumptions.
