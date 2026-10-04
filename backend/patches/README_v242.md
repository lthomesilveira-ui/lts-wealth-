# V242

The cash-flow editor failed because the existing cache invalidation trigger
used a DELETE without a predicate. The patch retains economic records and
invalidates only derived read data.

Apply against the existing V241 database in this order:

1. `cache_write_failure_v242.sql`
2. `source_key_cache_v242.sql`
3. `liquidity_and_flow_cache_v242.sql`
4. `fgts_receipt_identity_v242.sql`
5. `linear_flow_assembly_v242.sql`

The final flow cache is scoped by authenticated owner, São Paulo date, range
and source epoch. Source writes invalidate it. A source change during a read
prevents the old result from entering the cache.

FGTS withdrawal and subsequent monthly contributions require an explicit
owner policy. The projected receipt consists of its exact source components;
matched posted bank entries replace forecasts. A withdrawal moves availability
from FGTS to bank cash, without increasing the total wealth.

Settled brokerage withdrawals reduce the previous available-resource position
until a later primary statement supersedes that position. Component allocation
remains dated to its original statement; no share quantity or execution price
is inferred.

Personal documents, values and transaction identities belong in the private
audit record. Repository tests use synthetic data.
