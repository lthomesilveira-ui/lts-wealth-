# Verified broad spending natures

A small, explicit merchant catalog can resolve a broad spending nature when the
bank's merchant-category code, provider category and identified business agree.
The official business references are embedded in the rules. This records neither
a product, patient, beneficiary, clinical purpose nor recurring status. Existing
source decisions, conflicts, retired categories and different historical category
choices retain priority. Generic intermediaries and inconsistent activity codes
remain proposed or unresolved.

Candidate reads are separate from a service-only application. The caller must
submit the exact reviewed source IDs, hashes, categories and rule IDs. Sources
are locked; the eligible set is recomputed; stale or concurrent decisions abort
the entire operation. Every source-specific decision has an audit explicitly
identifying the delegated assistant and evidence, never a fabricated owner
confirmation. Replay is idempotent. No merchant-wide semantic rule or new expense
is written. Only historical sources before the observed-expense ingestion boundary
are eligible, so this does not add duplicate spending to the accounting history.

The existing suggestion reader also recognizes additional payment intermediaries
and withholds an education proposal when a medical descriptor contradicts the
activity code. Strong same-purchase evidence and existing historical preferences
keep their precedence. Its OID, ACL, owner and configuration are preserved with a
full-definition lease. New helpers are invokers with empty search paths and no
anonymous/authenticated grants. There is no schedule, new client endpoint or UI
release; V312 continues rendering the proposals and learning from decisions.

Native PostgreSQL 17 reuses the real V312 engine/writer tests, then verifies the
bounded application, explicit provenance, unchanged source/event/rule hashes,
learning, ownership/hash/evidence guards, replay and client denial. Its before and
after payloads drive actual protected V312 assets at desktop and two mobile widths.
Those fixtures are not a production HTTP session, physical device or full restore.
