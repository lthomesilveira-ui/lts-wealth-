# LTS Wealth — Execution State

Last material update: 2026-09-12. Integrated documentary bank reconciliation and uniform Flow invoice presentation. The previous state is preserved unchanged in backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_INTEGRATED_2026-09-12.md. Read this file before historical blocked/missing-document statements.

## Current product and publication boundary
- Active branch: recovery-v152-flow-20260910. Approved functional reference: V150/V151 Flow; V152 comparison; V153 material loss point.
- Tested integrated product: f202ec7f24f832952ba62b9d27ab9d179135280a. Recovery smoke 34696883261, default-window gate 34696883239 and integrated invoice/browser gate 34696883289 are SUCCESS.
- The publication manifest now selects that tested product for fixed homologacao.html -> wip35-v162-candidate.html. Verify the resulting main Pages deployment and post-manifest three browser checks before reporting it live. A metadata commit itself does not prove publication.
- Protected index.html and the old wrapper source files remain untouched. The recovery still uses the preserved Flow component directly, with no cumulative wrapper runtime, permanent polling or MutationObserver. No public-root promotion or Dashboard work is authorized.
- Default D-5 through D+30 inclusive (36 calendar days) remains: initial load, reload, Flow re-entry and Hoje restore it; manual dates survive bank selection.

## Financial correction APPLIED — supersedes the prior Itaú blockage
- The already-received current Itaú checking-account statement was applied successfully through the authorized Supabase connector after the renewed user delivery request. No alternate permission route was used.
- Six missing source facts were added once; two matching monthly projections were replaced through separate audited links while originals were retained. Four dated documentary closes and the current source-date account anchor were recorded. No real bank payment or synthetic balancing entry was created.
- The historical reader now uses dated evidence at or before each row plus effective intervening movements, rather than ignoring newer documentary closes. Earlier rows are not backfilled from a later current balance.
- Itaú documentary closes and current source-based projection match the supplied statement. C6 has one current paid-invoice debit and its documented zero closing position. The Bradesco current balance matches the supplied screenshot; a small unresolved historical-to-observed residual is explicitly shown, not hidden by a fabricated cash entry.
- Bank source dates are shown. The source is dated 11/09; the app does not pretend that a projection on 12/09 is a new live bank query.
- Private source_documents for the applied Itaú statement retain exact source checksum, Drive path, before-image, six facts, replacement provenance, integrated QA and runtime function-definition snapshots. The original PDF and extraction were already saved outside chat; do not request another upload.

## Shared invoice experience IMPLEMENTED
- Contract: all-cards-aeternum-summary-source-v1. All recognized issuers use the same inline summary, descending net LTS category totals, documentary status/total, pending items, full documented detail, back and close controls.
- Personnalite recognition is restored. Exact due/cash/payment-date linkage resolves the Itaú debit on its evidenced cash date while preserving the contractual due date. No nearest-month or different-bank match is used.
- Aeternum current open source uses its 96 verified rows, not the older 64-row legacy snapshot. Mastercard closed source has 66 rows; C6 has eight current-cycle rows. Each current source sum matches its respective total and each invoice has one cash event.
- Open and closed invoices share the presentation. Open total may grow; arithmetic agreement is not payment confirmation. Missing current other-Visa evidence is explicitly shown rather than inventing purchases or reusing another month's invoice.
- C6 pending reversal is shown as a positive credit-to-review magnitude, separately from unclassified spending. Source dates, finals and installment counters are shown only when documented; day/month without a year stays explicitly incomplete.
- Existing LTS rules and unambiguous exact historical classifications are reused, never issuer categories or invented purposes.
- The missing save-feedback helper was restored in the isolated shell. A classification save no longer throws toast-is-undefined. Late boot callbacks no longer send the user from Updates back to Flow.

## Verified boundaries
- Integrated real-consumer-input database QA passed in approximately 1.57 seconds under an eight-second limit: dated Itaú closes, six unique facts, two replaced forecasts, single card cash events, exact card sums, date separation, wrong-bank/month rejection, unknown Prime-cycle rejection, pending-credit separation and all earlier user decisions.
- Browser CI passed Chromium desktop/mobile and WebKit mobile. It exercised five documented card-name shapes plus missing evidence, shared summaries/full details, credit and source fields, stateful classification save-refresh-reload, default/manual ranges and route stability. Zero recorded page errors or horizontal overflow.
- Browser values are isolated fixtures, not the user's actual session. Database reads used controlled claims and separate authenticated-role probes. Physical-iPhone/user-session E2E and human product approval are NOT claimed.
- Anonymous invoice access is rejected; authenticated permission remains required. No grants or RLS boundary were relaxed.
- Consumer QA and a checksumed snapshot of the five changed runtime function definitions are in the private applied-statement record. Existing daily-backup call returned success with inserted=0; do not call it a new full backup.

## Preserve earlier decisions
Keep the user's financing edit; the revised same-obligation Larissa payment; one Volvo insurance Pix obligation; dated Cofrinho positions separate from bank cash; rejection of the unrelated Mercado Pago DDA; separate invoice due and cash dates; vested-only current RSU treatment; C6 prior payment excluded from new consumption. Preserve original data and all old checkpoints.

## Remaining gates and next work
- The current small Bradesco debit lacks a securely linked current Visa invoice. The older Prime invoice is not evidence for the current cycle. Current Visa Itaú detail remains an evidence gap; absence is not zero.
- The historical Bradesco residual remains explicitly unresolved; current position agreement does not certify all historical movements.
- Bulk classification remains unreleased until the real browser/session save-refresh-readback lifecycle is evidenced. Fixture success proves the mechanical path, not that final external gate.
- Material human Flow homologation remains separate from automated PASS. Dashboard needs a complete proposed image and explicit approval before code.
- Complete backlog = PROJECT_MASTER_BACKLOG.md plus PROJECT_MASTER_BACKLOG_DELTA_2026-09-12.md. No other open financial, documentary, semantic, recurrence, reconciliation or product dependency was deleted.
- Latest acceptance evidence: backups/V162_INTEGRATED_FLOW_ACCEPTANCE_2026-09-12.md. Implementation evidence: backups/V162_INTEGRATED_FLOW_RECONCILIATION_INVOICES_2026-09-12.md.

## Restart and writes
Read this state, PROJECT_START_HERE.md, the product contract and decision ledger. Before writes, refresh main, active branch, master backlog and delta, NEXT_HOMOLOGATION_GATE.md, LTS_WEALTH_CONTINUITY_HANDOFF.md, CANONICAL_DELIVERY_MASTER_PLAN.md and latest checkpoint. Re-read changed/relevant sections. Never force branches, overwrite parallel work, invent financial rules or publish private evidence/passwords. User updates use Concluído / Em execução / Próximos passos. Source verification, application, consumer read, browser fixture, live publication and user approval are distinct states.
