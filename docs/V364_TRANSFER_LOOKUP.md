# Direct source lookup for a documented transfer

Live verification after V363 exposed a slow documentary pair lookup. The
reviewed contract already identifies both bank source UUIDs. Re-reading every
posted bank transaction for each consumer added avoidable work.

Use primary-key source lookups while retaining the same documentary validator,
owner/account/date/amount/routing checks, exact reviewed hashes, prior observation,
original confirmation scope, uniqueness and ACLs. Canonical card-document
deduplication remains required if such a source is encountered. No bank data,
financial event, confirmation or documentary proof is rewritten.

Native PostgreSQL re-executes the V363 actual validators, writer, shared reader,
Flow provenance expression and 30 negative cases against the optimized lookup.
It compares qualified pairs and function security attributes before and after.
Production delivery also requires a plan/timing comparison, unchanged financial
values and verification of the live Dashboard, Flow and classification queue.
