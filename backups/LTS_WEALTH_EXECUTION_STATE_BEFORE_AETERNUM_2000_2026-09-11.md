# LTS Wealth — Execution State

Last material update: 2026-09-11, current Itaú statement received; reconciliation application blocked; actual card-reader audit.

This compact file is the operational restart point. The full previous execution-state document is preserved unchanged at `backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_USER_CONFIRMATIONS_2026-09-11.md`. No historical checkpoint or master-backlog dependency was deleted.

## Latest override — read before earlier checkpoints
- The current Itaú checking-account statement was re-uploaded and is available. Original PDF, verified extraction and full account/card audit are saved in the private Drive. Do NOT ask for the same statement again.
- PDF arithmetic: 43 bank transaction lines and 19 daily closes verified at zero difference within the document. This is not yet ledger/application reconciliation.
- The attempted Supabase reconciliation transaction was blocked by the tool safety layer. Readback confirmed no new statement record, none of the six proposed bank facts and no new account anchor. No alternate route was used to apply the blocked transaction. The current Itaú balance is therefore STILL NOT CORRECTED in the app.
- Durable private report: `LTS_Wealth_Conferencia_Contas_Cartoes_2026-09-11.md` in the user's Drive. It includes original-file storage pointers, exact amounts, source lines, the old balance formula, the proposed documentary bridge, bank comparisons and actual reader results. Do not publish those private details here.
- Actual card audit found missing Personnalite recognition in the frontend, contractual-due-date versus cash-date lookup failure for the imported Itaú invoice, newer Aeternum operational total versus old detail, and a negative unclassified-credit presentation issue in C6. These are OPEN product/data-linkage defects, despite prior synthetic fixture PASS.
- All cards must use the user-approved Visa Aeternum inline model, confirmed LTS names/categories, descending category totals, explicit pending items and full documented invoice access. The current open-invoice branch does not yet match the closed-invoice presentation. Do not claim all-card parity delivered.
- Latest checkpoint: `backups/V162_ITAU_STATEMENT_RECEIVED_WRITE_BLOCKED_CARD_AUDIT_2026-09-11.md`. This supersedes previous requests for the now-received current Itaú statement. No frontend, schema or financial data was changed by this audit/documentation package.

## Published window and earlier release evidence
- The user requested five preceding days, today and thirty following days whenever opening Flow.
- Tested product `41587c9d21904354b5dec7cb936452ffaae55eae` changes only the recovery frontend: default D-5 through D+30 inclusive, all 36 calendar days; reload, Flow navigation, default chip and Hoje restore this window. Manual periods and bank filters remain available. Public index.html is unchanged.
- Recovery browser smoke `34646535785` and dedicated window browser gate `34646535781` are SUCCESS. The latter covers desktop, mobile, year boundary, bank-filter preservation, manual ranges, navigation, reload and late boot callbacks. Local browser navigation was blocked by the runtime administrator; it is not claimed.
- Backend mixed-range QA passed with five historical days and thirty-one current/future days under an eight-second limit and controlled authenticated database claims. This is not signed-in browser E2E.
- Window publication commit `bbb3984bc4015f1cca22bf973783e7e99c80b4f7` and its main Pages/post-manifest tests were checked in the preceding delivery. Public-root promotion remains unauthorized. This audit does not introduce a new product build.
- The earlier private `source_documents` audit key `itau-current-balance-20260911` still exists. Its document-availability condition is superseded by the new Drive evidence, but its database status was not updated because the application transaction was blocked.
- Earlier release receipt: `backups/V162_DEFAULT_WINDOW_GATE_RECEIPT_2026-09-11.md`. Earlier review: `backups/V162_DEFAULT_WINDOW_ITAU_REVIEW_2026-09-11.md`. Do not mistake those earlier missing-document statements for the latest state.

## Restart protocol
1. Read this file and `PROJECT_START_HERE.md`; use GitHub and the private database as operational truth, not chat recall.
2. Before repository writes, freshness-check main, active branch and the SHAs of this file, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `CANONICAL_DELIVERY_MASTER_PLAN.md` and the newest checkpoint. Re-read changed or relevant sections; do not replay unchanged long histories.
3. Preserve all open financial, documentary, classification and reconciliation dependencies. Older release headings are historical when superseded by this state and the newest checkpoint.
4. User updates use `Concluído / Em execução / Próximos passos`. No microbuilds, no basic QA delegation and no claim of authenticated visual E2E without execution.
5. Never force branch updates, overwrite parallel work, invent financial facts or publish private financial evidence/passwords in this public repository.

## Current product
- Active recovery branch: `recovery-v152-flow-20260910`.
- User-approved functional reference: V150/V151 Daily Flow; V152 is audited comparison evidence. V153 was the material loss point.
- Fixed homologation: `homologacao.html` -> `wip35-v162-candidate.html`, direct preserved Flow source in protected `index.html`.
- Reader: `lts_browser_flow_v11`; bridge: `v150-flow-direct-current-read-v3`; guarded writer: `lts_browser_flow_mutate_v2`.
- No cumulative V137–V152 timer/observer wrapper runtime. Dashboard remains hidden/out of scope; canonical v1.24 remains rejected, not approved.
- Public root and promotion status remain unchanged. No new functional release was made by this audit.

## Latest completed data package — preserved
- The user confirmed that the revised September payment to Larissa replaces the existing health-related projection. The original record was preserved and the amount changed through the existing append-only Flow writer.
- The October Pix to Larissa is the existing Volvo insurance commitment. Recipient/evidence metadata was enriched; there is exactly one cash event.
- The entire Itaú investment total is the already-mapped Cofrinho. A new dated position was appended; the prior dated position remains intact. No income, yield or bank movement was invented.
- The presented Mercado Pago DDA boleto is not the user's obligation. Its rejection is persisted privately; it remains absent from Flow. No action was taken inside the bank.
- The supplied password opened the C6 archive. The decoded original CSV and the confirmations are stored privately outside chat; password values are not persisted in project documents or database metadata.
- C6 detail: nine source records; eight current-cycle detail records, including a fee/reversal pair; a prior payment record remains source evidence only. The existing paid invoice is linked and detail reconciles at zero difference. No new bank debit was created.
- Existing exact project classification rules were reused, not issuer categories. A line without an existing rule remains pending.
- Applied generic migration: `evidence_current_asset_latest_snapshot_guard_2026_09_11`. The current evidence reader now selects the latest dated snapshot per existing asset identity, preventing a new snapshot from being summed as a second asset.

## Verified evidence boundary
- Earlier post-write V18/V11 Flow read confirmed the revised health amount, one insurance event, zero rejected-boleto events, one current Cofrinho position, preserved previous position, preserved financing edit and unchanged Itaú card scheduling. This does not validate the current Itaú checking-account balance or every card's UI access.
- C6 consumer RPC returned its eight rows at zero difference; the newly noticed negative pending-credit aggregate is a separate presentation issue. Controlled authenticated database-role tests are NOT signed-in browser or physical-iPhone E2E.
- The card classification-review cache was refreshed in the preceding data package. Bulk classification is still NOT released until a real browser save -> refresh -> readback/self-heal lifecycle passes.

## Checkpoints and private evidence
- Previous completed data checkpoint: `backups/V162_USER_CONFIRMATIONS_C6_IMPORT_CHECKPOINT_2026-09-11.md`.
- Prior applied refresh: `backups/V162_FLOW_REAL_DATA_REFRESH_CHECKPOINT_2026-09-11.md`.
- Private retrieval: owner-scoped `source_documents` records for the prior `user_confirmation` and `card_statement_csv` package; metadata contains before-images, decisions, checksums, private Drive pointers and the consumer-RPC QA receipt. The new checking-account PDF and audit are in Drive but NOT yet indexed/applied in Supabase.
- Preserve all remaining dependencies in `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and `CANONICAL_DELIVERY_MASTER_PLAN.md`.

## Next work
Resolve the application blockage through permitted execution without bypassing the tool block. Use the already-preserved current statement; do not request it again. Before further homologation, apply and read back the documentary reconciliation, verify historical continuity, repair card recognition/date linkage and prove all-card invoice presentation where actual detail exists. Recover/reprocess the already-registered newer Aeternum source; retain the small Bradesco debit's identity gap, Visa Itaú evidence gap, unclassified-credit issue, classification lifecycle and all other master-backlog dependencies. A future Dashboard requires a complete proposed image and explicit approval before implementation.
