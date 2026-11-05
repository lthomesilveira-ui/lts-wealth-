# V414 — evaluate shared payload predecessors once

The cold product chain calls `lts_mvp_product_payload_v10_fix86` twice inside
`lts_product_payload_fix86_v2`: once for the complete payload and again for its
`product_contract`. Each evaluation reaches `lts_mvp_product_payload_v1`, which
computes a projection audit and a position directly and computes both again
through `lts_dashboard_horizon_v1`.

This patch changes exactly two existing functions:

1. `lts_product_payload_fix86_v2` materializes its complete predecessor once and
   obtains both the result and its `product_contract` from that value.
2. `lts_mvp_product_payload_v1` materializes its audit and position once. Its
   horizon CTE incorporates the unchanged standalone horizon query, replacing
   only those two calls with references to the already-computed inputs.

The structurally repeated audit and position evaluations fall from four to one
through this branch of the full product chain. Other expensive dependencies are
unchanged, so full cold initialization must still be timed separately.

## Contract and access

The standalone horizon function is unchanged. Its net-flow source remains
`lts_corrected_cashflow_v1`; it is not replaced by the operational audit's net
flow. All existing output fields, fixed metadata, ranges, ordering, null handling
and financial expressions are preserved.

There is no session variable, caller-supplied memoization, persistent cache,
owner data write, new function signature, privilege change, authentication change
or timeout change. The original security mode, volatility and search path of
each function remain unchanged. Materialization is local to one invocation.

The migration checks the exact predecessor definitions of both wrappers and
the horizon, and verifies their access and function metadata after replacement.
The native PostgreSQL gate compares complete JSONB results and observes actual
dependency call counts in a disposable synthetic database.

## Maintenance

The incorporated horizon query is a deliberate small snapshot of the guarded
standalone definition. A future change to horizon behavior must update this
incorporated query and its differential fixture together. No standalone horizon
callers change behavior in this release.
