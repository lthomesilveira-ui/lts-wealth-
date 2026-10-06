# V250: dated historical layer batching and workbook total recomposition

The full-query historical reader previously fetched the same dated resource
sources once per day and repeatedly concatenated JSON arrays. It now reads
liquidity/FGTS layers once per range and accumulates rows in an array. The full
response, order, nulls, source bases and current/future days remain identical.

The workbook cash overlay previously cleared all liquidity totals after restoring
dated bank positions. It now recomposes them using only its existing dated
resource fields and complete bank proof. Null arithmetic preserves unknowns;
missing D0, RSU or FGTS is never treated as zero or today's resource copied back.
Bank/economic facts, source events and standalone resource positions are unchanged.

Live operator rollback validation passed before deployment:
- Full JSON parity and repeat parity for a two-year current/future range, the July
  resource-boundary range and a 731-day older historical range.
- Controlled warm comparisons: full-query stage 1586.2 to 968.5 ms; boundary stage
  123.1 to 73.6 ms; older historical stage 2313.0 to 789.1 ms. Earlier first/second
  timings include memo warming and must not be presented as controlled speedups.
- Workbook proof checks every day, unaffected fields, source events and future,
  dated D0 recomposition and an in-memory unknown-resource fixture. Only one
  additional day of available D0 is recovered; this does not fill earlier gaps.
- All candidate DDL and cache writes roll back; function definitions/ACLs restore.
  Private receipt table has RLS and all external execution/data access revoked.
- A preliminary workbook QA operator-precedence error rolled back and was fixed
  before PASS. It was not an application/source error.

SQL files are operator-only probes, not production deployments. Execute DDL with
migration tooling, inspect the private report for PASS, then apply the two guarded
patches. Bump the existing source epoch once after the workbook output change,
so enclosing cached responses cannot retain cleared totals. Warm and verify the
complete 2026-2027 view after deployment. Server-stage timings are not phone or
browser acceptance. Frozen releases and existing identity/source guards remain.

The earlier missing historical resource fields still require primary workbook
formula/date verification and liquidity classification; these patches do not
invent resource values or certify source completeness. Product UI acceptance,
expense/wealth performance, forecasting omissions, retention/restore and legacy
CI triage remain separate.

