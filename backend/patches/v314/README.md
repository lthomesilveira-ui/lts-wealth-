# Superseded classification snapshots

The older review could keep an archived open snapshot pending after its closed
bill had replaced it. The overlay refreshed open bills only, so closed-cycle
classification results from the archive survived.

Remove only explicitly archived review IDs when the exact owner/family/month/due
date has a complete received composition with zero unresolved purchases. Its
account, institution and bill identity must match one active bank invoice; source
count and net amount must match the closed documentary composition and total.
No purpose, payment or monetary value is assigned and raw snapshots stay intact.

The existing overlay keeps its OID, owner, ACL and configuration. A new private
invoker helper has an empty search path and no client-role grants. Full-definition
leases, metadata checks and replay protect deployment. PostgreSQL 17 uses the real
old and transformed overlay with bounded synthetic sources and thirteen invalid
or ambiguous evidence cases. Real-source rollback QA is separate; these tests
are not private HTTP, a physical device or a full restore.
