# V162 — Existing-reader adapters and request lifecycle implemented/tested

14/09/2026. User asked to continue implementation. This package advances code and repeatable tests; it is not a newly deployed Despesas screen or a financial reconciliation certificate.

## Implemented
lts-expense-read-model.js normalizes the actual primary dual-lens schema, monthly-detail v2 and same-selection executive-v12 comparison. It preserves exact cents, signed values, categories and documented dates; validates totals/counts/periods; distinguishes levels of historical detail and missing data. Missing monthly points remain null, limited recent/ranking arrays are not full-ledger evidence, and two agreeing report totals are not independent source proof.

Its request controller ignores superseded asynchronous responses, clears stale values on period changes, handles auth/errors without raw-server leakage, and disposes in-memory state. No storage, timers, automatic retries, network, financial mutations or category inference are included.

.github/scripts/lts_expense_reader_adapter.cjs connects the monthly shape to the existing source-integrity checker with mandatory explicit identity bindings and reference treatment/coverage. It does not guess links, retrieve data or perform blocked calls. The original integrity checker is byte-identical to its prior Git blob.

The protected current component was read before coding: its actual primary path is expenseDualState/loadExpenseDual and the dual RPC, while executive/monthly are distinct additional report readers. Function-definition metadata corroborates the schema; no expense data was queried in this turn. Do not compare these financial meanings interchangeably.

## Evidence executed
Local syntax checks PASS. Node tests: 20 original checker + 52 monthly/executive/adapter/lifecycle + 14 dual-lens = 86 PASS. Tests include the adapter calling the unchanged checker, stale categories, exact identity/cent mismatches, incomplete/truncated data, control counted as consumption, missing/open-document evidence, late responses, logout and redacted failures.

Chromium synthetic fixture: eight checks at 1366x900 and eight at 390x844, sixteen PASS; all network requests blocked and zero attempted. This fixture is not the LTS page or a physical-iPhone/authenticated-real test. Workflow expense-read-contract.yml adds repeatable offline CI and synthetic JSON artifacts; its remote execution status must be obtained from its run receipt, not assumed from this local PASS.

## Activation / pending boundaries
Only new inert modules, tests, CI and continuity documents were committed. Active index, V162 candidate/runtime and manifest are unchanged, so the link still opens the previous application. No classifications, categories, source facts, cache values, economic rules or backend functions were changed. The seven answered card lines, two answered bank lines, shorter child label, summaries, historical duplicates, vehicle consumption, payment markers, beneficiary display, source freshness and actual-session/manual gates remain open as previously recorded.

Next integrate these tested modules into the existing component and validate on authorized, independently verified source data without bypassing denied operations. The user does not need another classification questionnaire. Despesas remains the priority; unrelated Dashboard/Patrimônio and full-period requirements remain intact. The prior full state is preserved in LTS_WEALTH_EXECUTION_STATE_BEFORE_EXPENSE_ADAPTERS_2026-09-14.md and RETOMAR_LTS_WEALTH.md points to the latest state.
