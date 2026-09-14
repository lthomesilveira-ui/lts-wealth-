# V162 — Despesas pure-reader hardening, not live activation

14/09/2026. The user asks to implement improvements and eliminate outstanding work. This package fixes newly reproduced defects in the already-committed, inactive read-model module. It does not replay the earlier denied UI activation or the denied financial operations. Full delivery remains incomplete.

## Fixed in code
1. A complete cash-detail list must agree with declared total, bucket counts/amounts, explicit transfer treatment, monthly totals and operational-pending amount. Previously matching summary totals could conceal inconsistent complete detail. Partial/capped recent lists are explicitly not forced to the whole total. Duplicate row identity cannot claim a complete recent list.
2. Months absent in both series remain in the requested timeline with null values. Previously they disappeared entirely. An explicit zero remains distinct from absent data; no values or dates are fabricated.
3. Request lifecycle now guards synchronous re-entry as well as asynchronous late replies. Cancel/dispose/period-change callbacks cannot invoke an obsolete loader or resurrect values after disposal. Invalid new selections clear stale values before rejecting. No retries, network or financial writes were added.

## Evidence
The local baseline was reconstructed from the current GitHub file and verified at blob 7e30773693db80be2fefd1ba2da264afbe02417b. Twenty-six new synthetic regression cases were run against it: seven passed and nineteen failed. After the fixes all twenty-six passed. The existing fourteen dual-reader tests, reconstructed at their exact Git blob, also passed locally. JavaScript syntax checks passed. The updated existing CI workflow will additionally run the unchanged integrity/month/adapter/browser suites plus these regressions; remote success is not assumed and must be read from its actual run.

Expected tested module blob: bf66e59258158527392e61a6c5b4e583d549e05d. New regression-suite blob: 713ce8e167919cf24fb59e84f3dcd97822cabe1b. Tests contain synthetic data only, no source financial details. They validate code behavior, not the user's real totals, actual app layout or authenticated session.

## Financial and delivery boundary
A permitted read-only classification query at 23:16 UTC returned seven card source lines and two bank groups still pending application, with stored summary counts forty and eleven. All decisions were already received; none was reapplied or re-asked here. No source data, categories, balances, SQL functions, caches, active HTML, candidate/runtime or manifest changed.

The prior local ZIP integration package remains uncommitted after its tool denial. It was inspected, not submitted again, and is not part of this code change. This accepted-or-proposed independent hardening must not be presented as resolution of denied operations or a new Despesas screen. Previously diagnosed historical duplicates, vehicle-advance extra consumption, payment markers, attribution, summary sync, shorter child label and full manual/session gates remain open. No deadline or unattended execution is promised.

Full previous state is retained in LTS_WEALTH_EXECUTION_STATE_BEFORE_READER_HARDENING_2026-09-14.md. Existing decisions, audit pointers, classification scope, protected financial history and every unrelated master-backlog dependency remain binding. Resume via RETOMAR_LTS_WEALTH.md and the current execution state.
