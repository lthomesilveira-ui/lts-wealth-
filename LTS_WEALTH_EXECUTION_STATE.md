# LTS Wealth — Execution State

Last material update: 2026-09-11, gated default Flow window and open Itaú reconciliation review.

This compact file is the operational restart point. The full previous execution-state document is preserved unchanged at `backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_USER_CONFIRMATIONS_2026-09-11.md`. No historical checkpoint or master-backlog dependency was deleted.

## Latest request and release boundary
- The user reported that the Itaú balance does not match and requested five preceding days, today and thirty following days whenever opening Flow.
- Tested product `41587c9d21904354b5dec7cb936452ffaae55eae` changes only the recovery frontend: default D-5 through D+30 inclusive, all 36 calendar days; reload, Flow navigation, default chip and Hoje restore this window. Manual periods and bank filters remain available. Public index.html is unchanged.
- Recovery browser smoke `34646535785` and dedicated window browser gate `34646535781` are SUCCESS. The latter covers desktop, mobile, year boundary, bank-filter preservation, manual ranges, navigation, reload and late boot callbacks. Local browser navigation was blocked by the runtime administrator; it is not claimed.
- Backend mixed-range QA passed with five historical days and thirty-one current/future days under an eight-second limit and controlled authenticated database claims. This is not signed-in browser E2E.
- The fixed manifest selects the tested product for the publication package. Check the latest main Pages and post-manifest browser runs before claiming deployment. Public-root promotion remains unauthorized.
- Itaú reconciliation remains OPEN. Its current calculated balance uses an older documentary anchor less two legacy projections. A later uploaded account statement was recovered but was absent from the operational index; it still does not cover the current day. No balance adjustment, cancellation or bank fact was invented.
- Private `source_documents` audit key `itau-current-balance-20260911` preserves the actual values, source reference, formula, before-image, date ambiguity and missing current statement. The current checking-account statement is required to finish the reconciliation; investment and card statements cannot replace it.
- Latest release receipt: `backups/V162_DEFAULT_WINDOW_GATE_RECEIPT_2026-09-11.md`. Detailed review: `backups/V162_DEFAULT_WINDOW_ITAU_REVIEW_2026-09-11.md`. The open balance issue supersedes any earlier implication that all current bank balances were reconciled.

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
- Public root and promotion status remain unchanged. The preceding C6 data package did not alter frontend JavaScript or layout; the current window candidate is a separate frontend change.

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
- Post-write V18/V11 Flow read confirms the revised health amount, one insurance event, zero rejected-boleto events, one current Cofrinho position, preserved previous position, preserved financing edit and unchanged Itaú card scheduling. This does not validate the current Itaú checking-account balance.
- C6 consumer RPC `lts_browser_card_settlement_detail_v2` passed an eight-row/zero-difference check under PostgreSQL `authenticated` with controlled database claims. This is database-role testing, NOT signed-in browser or physical-iPhone E2E.
- The card classification-review cache was refreshed. Bulk classification is still NOT released until a real browser save -> refresh -> readback/self-heal lifecycle passes.

## Checkpoints and private evidence
- Previous completed data checkpoint: `backups/V162_USER_CONFIRMATIONS_C6_IMPORT_CHECKPOINT_2026-09-11.md`.
- Prior applied refresh: `backups/V162_FLOW_REAL_DATA_REFRESH_CHECKPOINT_2026-09-11.md`.
- Private retrieval: owner-scoped `source_documents` records for `user_confirmation` and `card_statement_csv`, reference date 2026-09-11; metadata contains before-images, decisions, checksums, private Drive pointers and the consumer-RPC QA receipt.
- Preserve all remaining dependencies in `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and `CANONICAL_DELIVERY_MASTER_PLAN.md`.

## Next work
Check publication receipt and obtain the current Itaú checking-account statement to reconcile without synthetic balancing entries. Continue practical Flow homologation, all-card Aeternum-model parity where actual detail exists and the small Bradesco card identity gap. Prove real classification persistence before inviting bulk work. Keep the accumulated classification backlog and every other historical/documentary gap. A future Dashboard requires a complete proposed image and explicit approval before implementation.
