# V306: evaluate audit period coverage once

EXPLAIN ANALYZE showed the same historical and future coverage counts being
re-evaluated by several aggregate expressions for each period. Materializing
the existing coverage CTE shares those exact counts within that statement.
It adds no persistent result cache, prewarming, financial data, projections,
output fields, public endpoint, role grant, memory setting or timeout change.

The patch is leased to the inspected definition, preserves its original
OID/owner/ACL/configuration/security/volatility and is a definition no-op on
replay. The private API and response version stay the same.

Validate complete JSON equality across current/historical as-of dates,
monthly/annual horizons and null/default horizons; test actual authenticated
SQL-role reads with cold existing result memos, inside rolled-back transactions.
Do not infer universal latency, private HTTP/device or full-backlog completion.

Reference: https://www.postgresql.org/docs/16/queries-with.html#QUERIES-WITH-CTE-MATERIALIZATION
