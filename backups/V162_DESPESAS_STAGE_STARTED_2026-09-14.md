# V162 — Despesas stage started: existing-reader audit and offline integrity verifier

14/09/2026. User requests Despesas as the next module and assumes all classifications are complete. The current question set is fully answered, but source application, reconciliation, report synchronization and patrimônio evidence remain distinct unfinished gates.

## Verified state
The read-only direct classification query succeeded: seven pending card sources and two bank groups, all previously answered; stored Updates counters remain forty/eleven. No new category, cash, database schema, cache or frontend mutation was performed. Main/active recovery branch were freshly compared.

Existing definitions show executive expense v3/v4 invoke cached report v12 over lts_expense_effective_read_cache, while monthly detail v2 uses total_rows_v5. The retained v2 line chain still has the older fix86 documentary bridge. This structural audit is complete; it does not assert a new measured monetary reconciliation or the live UI's full event wiring.

An additional expense-value comparison call was denied by the connector's security check. No result was returned and the comparison was not retried via another query, channel or local data execution. Do not convert this failure into a numeric report. Earlier denied source writes, naming and summary-refresh actions were not attempted.

## Concrete code prepared and tested
Added .github/scripts/lts_expense_integrity.cjs, an offline read-only contract checker for normalized source/report readings. It contains no SQL, network, credentials, category inference or data mutation. A future permitted adapter must provide verified canonical identities, period dates and economic treatment. The checker does not perform that adapter or repair totals.

Local Node syntax check passed and --self-test passed twenty synthetic scenarios: parity, old-purchase installment retained by competence, immutability, answered-versus-applied distinction, stale category, missing/extra/duplicate sources, one-cent difference, settlement double-counting, date-basis mismatch, unresolved controls, partial-detail honesty, missing document, empty-versus-verified-zero, open-invoice provisional state, projection, invalid money, no merchant-description linkage, and signed refund retention. These are unit tests of the checker, not actual user data, authenticated-browser E2E or a working updated report. CI/UI integration remains open.

## Next deliverable and boundaries
LTS_WEALTH_DESPESAS_EXECUTION_PLAN.md records source parity before presentation, existing category/month/person/origin drill-down, equivalent-period comparison, real evidence depth and preserved financial/taxonomy contracts. The requested priority advances Despesas before a new Dashboard without waiving its image-approval or public-root protection. Patrimônio requires independent asset/debt/date-base verification; categories alone cannot certify it.

No new UI version or link was published. V162 remains unchanged. Source application, summary sync, historical duplicate/vehicle-consumption/control defects, cost-center display, other-card evidence and manual-session/whole-period gates remain open. All prior states are retained immutably; no additional questions are needed from the user for the completed H set.
