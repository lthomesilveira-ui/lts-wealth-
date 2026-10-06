# V255 — exact documentary daily aggregation

This guarded patch replaces only the repeated per-day income/expense scans in the existing private documentary bank sum function. It groups the same rows once, then looks up each exact date/account. All source filters, duplicate rows, signed amounts, anchor/calibration decisions, balance arithmetic, unknown positions and response fields remain unchanged. No helper, grants, schedules, frontend changes or financial-source writes are introduced.

The patch requires the exact current function lease. Check live migration history before applying; it deliberately refuses to overwrite another definition.

## Validation

- Full JSON and serialized text parity on current/next year, 2019–2020 and the July boundary, including repeats and read-only execution.
- Current/next component: 1281.040 → 183.543 ms; historical: 85.691 → 90.115 ms; July: 24.925 → 27.949 ms. These are component measurements on the same prepared inputs.
- Synthetic in-memory duplicates, refunds, NULL/withheld sources, sub-cent precision, unknown/relative positions and unvisited invalid values preserved. No source rows were inserted.
- Full 2026–2027 output exactly preserved after a private cache miss in each variant: 730 days, 365 in 2027. One paired run was 12779.196 → 12538.352 ms. Shared buffers were already warm; this small overall difference is not evidence that the full cold bottleneck is resolved.
- DDL, private diagnostic clone and cache fixtures rolled back; source lease/ACL restored before deployment. The clone is never part of production.
- Initial test-only alias ambiguity and statement delimiter errors were corrected after rollback; no failed candidate was committed to production.

Run the SQL QA scripts only through an authorized maintenance connection. They determine the current pilot dynamically; no owner IDs, emails or credentials are embedded. GitHub CI validates source contracts, not live SQL results or authenticated browser acceptance.
