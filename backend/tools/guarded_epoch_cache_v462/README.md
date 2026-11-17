# Guarded epoch card cache V462

Keep the V461 reuse semantics without repeatedly serializing every bank payload. Use the existing financial epoch only when the staging table's four statement triggers and their implementation match the exact reviewed definitions, all are enabled, and the session uses origin replication mode. That trigger compares every row field except the three collection bookkeeping fields, including any future semantic column.

Any unknown, altered or disabled trigger contract uses the complete V461 semantic-row hash. The guarded branch also binds its key to the requested owner. Other card inputs, epoch-race rejection, owner-scoped cache access, incomplete information, permissions and timeouts are preserved. This patch writes no financial data and adds no public endpoint or session memo.

Install and rollback require the exact predecessor and an idle, unlocked worker. The native PostgreSQL 17 suite uses the actual epoch-trigger definition and actual card-reader definitions; it verifies bookkeeping reuse, all semantic mutations, fallback after trigger drift, replica sessions, races, exact metadata/profile pins and worker-lock refusal. Live performance and UI acceptance are tracked separately in private evidence.
