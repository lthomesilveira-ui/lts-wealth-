# V422 explicit management priority

A narrow presentation-only correction: the explicitly assigned management group for loans takes priority over a generic legacy financial-commitments category. The existing acquisition/vehicle precedence and every unrelated classification remain unchanged. Source categories, dates, amounts, row identity, owner and grants are preserved. This change does not itself implement the subgroup drawer or bank-pending explanation UI.

The production patch guards the exact observed predecessor and its execution attributes, preserving them except for the source-body insertion. Replay is idempotent. It does not write financial records, classify unrelated merchants, change access rights or confirm pending bank transactions.

Native PostgreSQL17 tests use 300 invented input combinations and a synthetic predecessor. Only the expected predecessor fingerprint is substituted in the isolated test copy; the production patch retains its real guard. The same textual transformation, property checks and replay are tested. Actual source totals, unaffected classifications and expected affected records must additionally be checked before/after production installation. Do not describe these tests as a real-user browser or complete security acceptance.
