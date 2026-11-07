# Source reader transaction

The service-only Open Finance source RPC was marked `STABLE`. PostgREST runs a
POST to a stable function in a read-only transaction, so the existing memo
readers skip storing calculated results. Multiple nested reads and consecutive
source windows can repeat the same historical engines.

This patch marks only that exact reviewed source RPC `VOLATILE`, matching its
existing calls to memo writers, and reloads PostgREST's schema metadata. Its
body, invoker security, service-only grants, owner, 20-second limit, source
window guard, financial engines, five-minute expiry and epoch checks stay
unchanged. No source tables, history, bank writes or schedules change.

The isolated PostgreSQL 17 fixture installs the exact deployed source and memo
readers over invented data and bounded engine stubs. It reproduces six engine
calls with the old read-only transaction versus one with reusable memos,
compares complete JSON payloads and financial source signatures, verifies TTL
and epoch invalidation, denied roles and foreign-owner/window guards, and checks
replay and atomic rejection of an unreviewed body. This is not a financial
history, real identity, real device or full recovery certification.

Live acceptance must additionally verify the unchanged real source payload and
the existing authorized Edge sync path. A successful retry does not prove that
all resource-pressure causes are resolved; keep capacity monitoring open.

Reference: https://docs.postgrest.org/en/v14/references/transactions.html

If a rollback is needed, first verify the same source body and ACL, mark this
function `STABLE` again and notify `pgrst` to reload its schema. Existing memo
readers still support read-only transactions, without storing a new memo.
