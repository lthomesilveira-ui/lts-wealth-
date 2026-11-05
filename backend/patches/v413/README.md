# V413 — bounded projection construction

Cold product initialization rebuilds the financial projection after a read cache
is invalidated. The V412 builder scanned and classified the entire baseline for
every projected slot. On the production failure path, this work exceeded the
existing request deadline before the product cache could be populated.

`build.sql` replaces only `lts_projection_private_v412.build(uuid,date)`. It
normalizes the baseline once, aggregates monthly facts and annual replacement
rows once, and aggregates card cycles once. The existing slot loop reads these
invocation-local buckets. No persistent cache or new database object is added.

## Preserved behavior

- The calculation function, source adapters, rule order, date order, horizon,
  income/expense classification, and all financial rules stay unchanged.
- Documentary precedence, duplicate and NULL references, signed zero, the global
  replacement-reference history, card transitions, incomplete card cycles,
  cancellations, and salary withholding retain their existing behavior.
- NULL lookup dimensions are excluded so that lookups preserve the original SQL
  equality semantics. Composite JSON array keys avoid delimiter collisions.
- The builder retains its existing stable, invoker function metadata and private
  execution privileges. There are no timeout, authentication, caller, frontend,
  financial-data, or scheduled-job changes in this patch.

## Installation and verification

The versioned Supabase migration checks the exact predecessor definition before
replacement and verifies private execution, volatility, and configuration after
replacement. Install the reviewed migration, not this source fragment alone.

The differential gate runs the previous V412 behavior suite with a wrapper that
compares complete original and optimized JSONB payloads, and adds targeted edge
cases. The GitHub Actions gate runs against PostgreSQL 17 in an isolated database
using synthetic data. Local PGlite results are supplementary evidence, not native
server or production performance evidence.

After installation, validate the actual projected output against a matching
source snapshot and measure complete cold product initialization under the
existing request deadline. A fast isolated builder is necessary but does not by
itself prove the full product request is fast enough. Restoration of a populated
cache also does not prove that later invalidations will cold-start successfully.
