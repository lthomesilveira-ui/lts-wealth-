# V256: linear observed-position guard and classification lookup

The future-day guard previously rebuilt its entire JSON array on each append.
It now collects the same day rows in a PostgreSQL array and serializes once,
preserving row order and duplicates. The existing guard's bank conditions,
unknown values, adjustment arithmetic, metadata and early returns are unchanged.

The existing recent-event classification lateral query now has an OFFSET 0
evaluation barrier. Its one classification JSON supplies the same output fields;
matching rules, ambiguity decisions and classifications are unchanged.

The patch requires the exact original definitions of both existing private
functions and unique replacement anchors. CREATE OR REPLACE retains their ACLs
and properties. It adds no function, grant, table, cache key, schedule, financial
source write or frontend change.

Validation scripts run only in a transaction ending with ROLLBACK:

- full cold application-cache miss comparison, with captured real guard input;
- complete JSON/text/repeat equality for historical, July, future-year and
  current-date-to-next-year ranges;
- pure in-memory fixtures for NULL inputs, missing/empty arrays, existing guards,
  threshold/subcent cases, unknown positions, duplicates/order and error parity.

Temporary epoch increments invalidate private read memos only for the test
transaction. Financial sources are untouched. Physical buffers may be warm;
component or private-cache-miss timings are not browser/mobile measurements.
The remaining first-build bottleneck and real authenticated UI acceptance stay
open. Legacy CI checks stay active even when they fail.

Run local source contracts from the repository root with:

    node backend/qa/lts_v245_source_gate.js
    node backend/qa/lts_v246_source_gate.js
    node backend/qa/lts_v256_source_gate.js

The generic QA resolves the authorized owner at runtime and contains no owner
identifier, email, credential, private balance or bank transaction record.
