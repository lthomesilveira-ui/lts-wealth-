# Estado vigente — V285 publicada em 17/10/2026

Aplicativo: https://lthomesilveira-ui.github.io/lts-wealth-/releases/v285/app.html
PR da versão: https://github.com/lthomesilveira-ui/lts-wealth-/pull/165
Head validado: e3bf99a52441af1df46c974444a9b4538382017d
Commit publicado: c6f092806d2996b64c80b4417fb8769a2df4ffe5
Pages: execução 39078821370 concluída com sucesso.

A V285 altera quatro expressões em um único arquivo de apresentação. Grupos genéricos deixam de implicar um beneficiário. Chaves internas, pessoas explicitamente informadas, cálculos, detalhamento, edição, exportação e a proteção de cobertura diária da V284 permanecem preservados. A raiz e as versões anteriores não foram promovidas ou reescritas.

As 17 verificações finais da PR passaram. A matriz própria da V285 verificou Lançamentos, contexto, pagamentos, projeção, navegação e recuperação de sessão em dimensões de desktop e celular, com fontes sintéticas isoladas. O teste legado V173 teve uma falha inicial de inicialização móvel com null.flow e passou na reexecução do mesmo código, sem relaxar os critérios. Os registros das duas execuções permanecem disponíveis.

A publicação conferiu o release e as versões anteriores. Uma conferência independente também validou por SHA256 todos os 67 arquivos efetivamente servidos da V285. A abertura pública mostrou a identificação V285 e a tela de entrada. A sessão real da V284 verificada anteriormente não foi convertida em prova de sessão real da V285. Aceite pessoal e aparelho físico continuam separados dos testes controlados.

Uma correção delimitada de agrupamento explícito foi aplicada no backend e verificada antes/depois. Ela preserva decisões, categorias, pessoas, valores, demais campos, permissões e todos os outros registros. Os recibos e as fontes particulares ficam no registro privado, sem dados financeiros publicados neste repositório.

O pós-teste complementar da conciliação nominal foi registrado sem reescrever o recibo inicial. As correções já aplicadas não devem ser reaplicadas com validações antigas. O trabalho documental das séries futuras e das condições dos awards continua separado de comprovação aritmética e de publicação.

Permanecem abertos os limites históricos e vínculos individuais, premissas futuras, vigência de novos vencimentos, conciliação residual de ativos/contratos, proveniência semântica restante, desempenho real, casos de relatórios/edição/upload, proteção administrativa e isolamento HTTP, restauração completa isolada e aceite pessoal. Conservar P01–P16, FB244-01–14 e os lotes anteriores. Não inferir renovações, novos grants, pagamentos, estornos ou uma data de Closing.

A autorização de execução já dada permanece válida. Avançar nas tarefas independentes sem novo Permitir/Continue rotineiro. Health fica fora desta frente e Continuity Watch permanece desligado.

Retomada privada: LTS_CONTINUAR.md, checkpoint LTS-CONTINUAR-V285-20261017. Este topo prevalece sobre os estados antigos preservados integralmente abaixo.

---

## Histórico anterior preservado integralmente

# Estado vigente — V268 publicada em 13/10/2026

Homologação: https://lthomesilveira-ui.github.io/lts-wealth-/releases/v268/app.html
Código incorporado pelo PR133: https://github.com/lthomesilveira-ui/lts-wealth-/pull/133
Head validado: 02c0235415b863997a6c0e4720ead81a69c3fdcb
Commit do código no main: 823b4ba5aaf86afd76a53330d83f2992e626db0d

A V268 tem uma interface isolada. Diferencia realizado, previsão, pagamento a confirmar, lacuna e ausência de comprovação. Copiar Consolidado preserva a seleção e os valores desconhecidos. A recuperação de leituras invalidadas contempla solicitações em andamento, troca de sessão e saída da rota. As fontes e os controles financeiros anteriores foram preservados; evidências financeiras particulares ficam fora deste repositório público.

Validação: 18 checks finais aprovados; novos controles em Chromium/WebKit, desktop/celular; documentos, cartões, classificações, períodos, edição e repetição idempotente exercitados com dados controlados. Pages run38466150522 PASS: 669 arquivos de V268 e dez releases anteriores conferidos por SHA256. O endereço foi aberto diretamente e mostrou V268 e a tela de entrada. Isso não é prova de sessão real autenticada nem de iPhone físico.

Antes deste handoff, 2.998 dos 2.999 blobs preexistentes estavam iguais. A única alteração anterior era o workflow de Pages para publicar/verificar V268. Raiz, V264, outros releases publicados e frozen-v181 não foram alterados. O estado V267 abaixo é histórico; sua cópia integral está também em evidence/archive/LTS_WEALTH_EXECUTION_STATE_v267_20261013.md.

O projeto não está integralmente encerrado. Permanecem evidências de conciliação histórica, premissas futuras, pagamentos não comprovados, verificações administrativas de Auth, sessões reais, restauração completa e aceite em aparelho. As respostas financeiras já recebidas continuam válidas; não criar lançamentos ou novas perguntas por ausência de evidência técnica.

Checkpoint privado: LTS-CONTINUAR-V268-20261013.
Retomada canônica: LTS_CONTINUAR.md e Evidencias_LTS_Wealth_V268_2026-10-13.json no conjunto privado do projeto. Health fora; Continuity Watch OFF.

---

## Histórico preservado

## Current execution — 13 October 2026 (V267 backend; V264 interface)

V267 is an execution-only backend optimization. Two immutable invoker text expressions now inline with every function reference explicitly qualified. The existing paid-cycle identity query now reuses a prepared plan; its entire source query, uniqueness and payment/owner/date/status guards are unchanged. This caches a plan, never a financial result. Prior V266 fixes remain applied.

Actual private database evidence passed: complete Flow/Expenses response parity and Wealth parity excluding only its calculation clock; unchanged source events and expense identities; 2,414 source/edge texts with zero differences; 730 unique daily rows and current-cash arithmetic; five paid-identity checks including deleted invoice and unposted debit rejection; all 147 authenticated no-identity calls denied. Owners/ACLs remain identical. Local public source contracts pass 36 checks. Publication/controlled-browser results are tracked separately in the private receipt; no signed-session or physical-device acceptance is implied.

One paired source-invalidated server observation improved Flow from 11,498.0 to 9,100.1 ms and Expenses from 8,801.8 to 7,142.1 ms. Fifteen independent paid-identity expression sites improved from 726.6 to 91.4 ms, with the exact same source result. This is not an SLA: P13 remains open, as do all unrelated backlog/source/recovery/acceptance items. Do not infer restored historical anchors, recovered missing identities, paid bills or future-series renewals from a performance change.

The static security advisor records two intentional `function_search_path_mutable` observations for fully qualified, table-free, immutable invoker helpers with no client grants. Every SECURITY DEFINER data reader retains its fixed path. See `backend/patches/README_v267.md` for the narrow justification and review trigger; administrative Auth and remaining signed-session/cross-owner proof are not cleared.

The published app stays `releases/v264/app.html`. No root/interface/prior-release asset, financial source, classification, bank connection, V248 draft or schedule changes. Continuity Watch stays OFF. No new financial question is needed. The exact previous execution state is archived as `backups/EXECUTION_STATE_BEFORE_V267_2026-10-13.md`; the complete private current state/receipts remain in LTS_CONTINUAR.md.

--- Prior execution preserved ---

## Current execution — 13 October 2026 (V266 backend; V264 interface)

The published interface remains `releases/v264/app.html`. The V266 backend round fixes a due-date rollover: an unresolved recorded invoice must continue using its uniquely matched received bill after the due date, rather than reverting to an older snapshot. Received amount, composition, source date and unreported-payment status remain separate facts. Closed cycles, newer documentary overrides, ambiguous sources and unrelated periods retain their prior guards.

The calendar audit now distinguishes a recorded past-due obligation awaiting payment evidence from a missing projection. It keeps genuine future gaps, without creating or extending forecasts. The server-only lock registry has RLS and no client grants; existing internal readers remain available.

Actual private database validation passed: nine invoice/evidence/rollback checks, full 2026–2027 daily coverage and arithmetic, current cash parity, unchanged expense identities, unchanged financial source events, repeated wealth facts, and denial of 147 authenticated LTS routines without identity claims. Cold-read timings are recorded in the private receipt and are not physical-device acceptance.

Open work remains: historical anchors and source links, future-series conditions, unreceived bank/payment evidence, residual debt/property/award/investment reconciliation, leaked-password Auth configuration, cold/device performance, V248 isolated PostgreSQL/Storage recovery, PENDING/POSTED identity work, individual UX/report cases and personal acceptance. A daily backup integrity pass is not a complete recovery pass. No new financial question is required by this round. Keep resolved decisions and the historical source limits.

No interface asset, protected root, prior release, payment, banking connection or personal acceptance was changed. The V248 draft remains separate. Publication and source integration evidence are in the private continuity record.

--- Earlier execution records preserved ---

## Current consolidated register — V236, 1 October 2026

Read [LTS_WEALTH_V236_CLOSEOUT_MATRIX.md](LTS_WEALTH_V236_CLOSEOUT_MATRIX.md) first for current statuses and source limits. The isolated successor is `releases/v236/app.html`; its publication and QA evidence are recorded in the private delivery receipt. The fixed legacy manifest and protected root are separate entries and do not identify the latest isolated release. Earlier sections below remain historical and must not recreate already answered questions or resolved incidents. No user/physical-phone acceptance is implied.

--- Earlier record preserved ---

# Current execution — V231, 1 October 2026

The authorized Despesas round is implemented in isolated releases/v231, based on main 7d868ec52cf82652dfa77c309c0bbd33024368c5. PR 96 tracks the release; publication and the exact final commit are recorded in the private continuity receipt. Earlier execution statements below are historical. Root, V181 and all earlier releases stay immutable.

Original workbook identities are verified against source date, amount, category and description. The reader preserves original categories and exposes worksheet/row references; it does not infer missing people or properties. Larissa is unified at the source grouping layer. Headline totals, group totals and monthly expense cells open their own dated composition, with audited corrections and invalidation of related reports. Invoice totals without a complete purchase source remain visible documentary gaps, never classifiable purchases. Source-family matching prevents the same received purchase from being appended twice. Current-month purchases remain in the review queue after month rollover.

Real-data checks passed for unchanged source financial records, unique expense keys, report/detail/group/monthly parity, persisted correction with original evidence and unrelated rows preserved, three-bank daily rollforward, pending forecasts, and same-purchase installment learning. All test decisions were rolled back. Controlled desktop/mobile tests passed for full monetary values, complete details, invoice links, cancel/save failure/success, selected-period retention and the existing Dashboard, Flow, RSU, card, refresh and manual-entry workflows. The additional full cold-projection rerun did not produce a confirmed result because of a tool interruption; the projection calculation was unchanged by this release. Existing V230 evidence remains historical evidence, not a new pass.

Open: missing historical invoice composition, current classifications without source evidence, prior documentary dependencies and human acceptance. No values or classifications were invented to clear these items. Legacy V171–177 workflow failures remain visible and were not removed or treated as new acceptance. LTS Continuity Watch stays OFF.

--- Previous execution state preserved ---

# LTS Wealth — Execution State

## Active execution — 23/09/2026

PR #69 is now merged (`1187e9d3af5958be8db5d5cf89253059ff483959`) and published (Pages `35924579834` success); all ten PR workflows passed first attempt. Authenticated new-build reload, rapid selected-period replacement and exact DOM arithmetic over 12 and 156 months passed. The full-history read was ready at the 62-second observation. Real loans/property drilldowns matched every displayed row. These close the scoped period-ownership/subtotal issues, not unrelated source, receipt-classification, net-asset/debt or physical-phone acceptance gates. The paragraph below records the earlier pre-publication state.

Manual browser login succeeded. PR #68/main `4c651486bc13ac06cd870f7ca3add2cdc09c87d7` passed authenticated reload, current Dashboard/Flow equality and unavailable uncertified historical balances with preserved movements. A subsequent isolated V183 period-ownership fix is locally passing 13 deterministic tests; publication and authenticated rapid-filter checks remain next. See the current master-backlog section and `backups/V183_PERIOD_OWNERSHIP_2026-09-23.md`. Do not ask for another login while the authorized browser session works, or claim the complete successor is ready from these scoped checks.

## Latest authorized scope — 23/09/2026

Implement bounded backwards historical reconciliation, not an exhaustive 2013 balance gate. Preserve 2013+ expenses, certify balances only over an evidenced contiguous interval, disclose unknown earlier balances, and protect app events from 08/07/2026 onward. September 2018 is not a certified start merely because later workbook date cells are valid. See the current override at the top of the master backlog and homologation gate. The independent coverage policy is being added only to isolated V183; fixed V181 and protected root remain unchanged. Other backlog items remain open unless individually proven closed.

## Current state — V181 homologation (22/09/2026)

V181 is selected at the fixed entry after PR #37 exposure merge `7a885d5a35204cc40e6661aa19369e89b3a65b01`. The authorized browser verified the published Dashboard after login/session entry and full reload, the current-day Flow equality, exactly one documentary movement on the reported due date, and Dashboard → Flow → Dashboard return. Nine exposure PR gates passed. This is agent-run QA, not user acceptance. The V180 record below remains a historical checkpoint. Continue the V181 register and publication receipt. Keep 137 unresolved identity reviews, aggregate-only invoice composition, April 2026 share-sale source, physical-phone QA and all prior open dependencies. Do not infer a successful post-merge signed-out smoke workflow or promote the protected root.

Business date 22/09/2026. V180 is published only in homologation. Implementation, database refresh, automated gates, served-byte verification and authenticated browser QA are complete; user acceptance remains pending.

## Current release

- Candidate `wip35-v180-candidate.html`; fixed entry `homologacao.html`.
- Tested product head `9d1c926dca02b70b69a7add6a7afc0dfec5c6671`.
- PR #30 product merge `810935171f77215e172c7617753695cce967a2c8`.
- PR #31 exposure merge `319789d06956c00171864dbe3e61bb60d961908f`.
- Product gate `35746263140` SUCCESS.
- Exposure gate `35747307190` and protected V171–V177 matrix SUCCESS.
- Pages deployment `35747832616` SUCCESS.
- Published asset/signed-out runtime gate `35747837646` SUCCESS.
- Authenticated fixed-entry, full reload and Dashboard → Fluxo → Dashboard: PASS in the authorized notebook browser session. Current-day reader status was ready/complete, date-aligned and sum-consistent; its HTTP response and all concurrent readers were successful.
- Publication receipt: `backups/V180_HOMOLOGATION_PUBLICATION_2026-09-22.md`.

The protected index hash and prior candidates remain unchanged. No production/root promotion occurred. Do not describe this QA as the user's own acceptance test.

## Delivery scope

- Preserved the V179 cash recovery contract: current-day cash is independent from long projection work, with a bounded retry and no partial/stale/zero substitution.
- Applied the completed documentary refresh to bank anchors, investments, brokerage components and current/future invoice cycles without fabricating movements or double counting prior balances.
- Corrected the refresh path for the actual future-flow cache consumed by the published browser and rebuilt dependent product caches in the safe order.
- Reconciled brokerage total, available and unavailable components with explicit residuals rather than an invented category assignment.
- Applied the global expense-label rule: no account-holder prefix; named people remain separated where supported; unresolved identity remains pending internally.
- Preserved complete expense pagination, totals, source keys, scroll/search behavior, apartment breakdown, historical coverage since 2013, RSU vesting-versus-availability, cash-only hide-zero and all previously accepted contracts.

## Open — do not erase or mark closed

1. User acceptance of V180 and issues #23/#24. Automated and agent-run authenticated QA are evidence, not user acceptance.
2. Physical-phone validation for V180; automated responsive/mobile regression passed, but no physical phone was available in this run.
3. Unsupported beneficiary/property identities. Preserve original source context and a specific review question; never guess the account holder.
4. Historical invoice totals without individual purchase/category support. Retain the economic total; do not fabricate purchases, dates or beneficiaries.
5. April 2026 share-sale original source remains missing.
6. Every previous unclosed dependency in the complete legacy state, master backlog and gates remains open unless its own closure evidence says otherwise, including broader planning, reconciliation, provider/input and historical-audit work.

## Full continuity preserved

The complete pre-V178 state remains archived byte-for-byte in `backups/V177_EXECUTION_STATE_BEFORE_V178_2026-09-20.md` (blob `b89104e9898c2ec04c65c4253daae371d4c9017d`). The matching handoff is `backups/V177_CONTINUITY_HANDOFF_BEFORE_V178_2026-09-20.md` (blob `a813bea2d533f09fd920197bef5c9318d9ffc704`). Read both alongside `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, the current manifest and open issues. Earlier release declarations are historical, not certification against later defects.

## Private execution evidence

The user's Library contains the full V177/V178 decisions and the private V180 documentary/QA record under `/LTS Wealth/Feedbacks/`. Supabase is authoritative for private evidence, data updates, review state and migration history. Public repository records remain sanitized.

## Next action

The user may perform one consolidated review of V180 at the fixed homologation link. If a new defect appears, reproduce it against the published authenticated flow and source evidence, preserve the current release, and only publish a coherently tested successor. No production promotion is authorized.

## Current override checkpoint — 23/09/2026 UTC (22/09 São Paulo)

The preceding V180 test invitation is superseded. The fixed homologation entry is V181; an isolated V183 candidate exists but is **not** ready for user QA or promotion. Its published authenticated Dashboard showed a complete same-day position after reload and Dashboard → Daily Flow → Dashboard, with the Flow's same-day total matching. This check is not a historical-cash certification or a 23/09 São Paulo rollover test. The visible release badge was isolated to V183; hidden legacy labels, intermittent V176 `null.flow` CI page errors and real-device validation remain open.

The master backlog's V183-F01–F10 gates remain open/partial. A read-only 2013–2026 effective-flow scan verified yearly presence and absence of duplicate exact source keys but not economic uniqueness, historical bank openings, invoice coverage, transfer counterparties or continuity. Source review found the user's small Bradesco Visa invoice belongs to the already inventoried Infinite Prime family; the corresponding historical invoice cycle is absent from `card_invoices`, and a separate Bradesco historical instrument has unidentified product. Do not import an invoice blindly: several cash, obligation and expense readers consume that table, so check the generic bank debit linkage and side effects first. The financial examples and source documents are in the private feedback register. No financial rows were changed in this checkpoint. Continue from the master backlog and private record; do not ask for QA of the intermediate version or alter the protected root.
