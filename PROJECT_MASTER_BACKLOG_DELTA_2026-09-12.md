# Master backlog delta — integrated Flow package, 12/09/2026

Read together with PROJECT_MASTER_BACKLOG.md. The complete older list is unchanged. This delta supersedes old statuses only for the explicitly listed items and preserves every other dependency. Tests and human approval remain separate.

## Completed in implementation and automated QA
- [x] Apply the already-received current Itaú statement through the authorized connector; preserve source, before-images and original forecasts.
- [x] Import six missing source facts once and link two exact monthly forecast replacements. No synthetic bank adjustment or real payment.
- [x] Correct historical source-date balance selection and verify current account/source-position consistency. No retrospective current-value backfill.
- [x] Preserve an explicit unresolved historical bank residual rather than inventing an adjustment.
- [x] Show bank evidence dates separately from subsequent projection dates.
- [x] Recognize Personnalite and all source card-invoice events in the recovered Flow.
- [x] Resolve due/cash/payment dates using exact bank, amount and cycle evidence; reject wrong/ambiguous matches.
- [x] Use current verified open Aeternum detail rather than the older legacy snapshot.
- [x] Unify open/closed summaries for Bradesco, Itaú and C6 card-name shapes: descending LTS categories, status/total, pending items, full documented detail and back/close navigation.
- [x] Keep source-only dates/finals/installments. Unknown purchase year is explicit.
- [x] Distinguish unclassified credits from pending spending. Preserve fee/reversal cancellation without another bank debit.
- [x] Restore the missing save-feedback helper and stop late boot callbacks from overriding Updates navigation.
- [x] Retain default 36 calendar days, manual ranges, bank filters, historical tree, projection actions, prior financial edits and future-award separation.
- [x] Execute integrated real-input database assertions and Chromium desktop/mobile plus WebKit mobile fixture tests. All pass on the tested product.
- [x] Preserve source evidence and runtime definition snapshots privately; public code contains no financial before-images or credentials.

## Publication / human gates
- [~] Expose the tested integrated product through fixed homologation; verify main Pages and post-manifest three workflows. Metadata selection alone is not deployment.
- [ ] Material human Flow homologation in the user's actual signed-in session.
- [ ] Actual session classification save-refresh-readback lifecycle before bulk-classification release. Stateful fixture lifecycle passed but does not close this external gate.

## Documentary residuals — must not be dropped
- [ ] Resolve the small historical Bradesco-to-observed residual without invented money. Current balance agrees with its screenshot.
- [ ] Link the current generic small Bradesco card debit to a current documented billing unit/cycle. Older Prime statement is not sufficient.
- [ ] Current Visa Itaú source detail/identity where absent. Do not report an undocumented zero balance.
- [ ] Every unrelated gap in PROJECT_MASTER_BACKLOG.md and prior immutable checkpoints remains open unless separately evidenced closed.

Dashboard, Reports, other-module redesign and public-root promotion are not part of this package. Dashboard still requires a full proposed image and explicit approval.
