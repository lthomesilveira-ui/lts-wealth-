# V251 workbook range reads

The historical workbook overlay repeatedly read the entire cash history to discover the first C6 activity date and recomputed per-day sums for each proof. The patch memoizes the identical first-date query privately and groups identical signed sums once per range. It preserves the original workbook/bank precedence, every event, ordering, unknown values and combined resource totals.

Requires the already deployed V250 workbook definition. An exact source lease rejects incompatible production definitions. The new helper has no PUBLIC, anon, authenticated or service_role EXECUTE; the existing caller's ownership and ACL remain unchanged. Its memo uses owner, current date, full source epoch and current source fingerprint. A genuine read-only cache miss computes the original date and does not persist a memo; financial or permission errors still propagate.

Live transactional validation passed for 2026–2027, 2019–2020 and the July 2026 boundary with full JSON equality and repeat equality. A separate warmed comparison of the same input measured the overlay at 1910.6 -> 1737.5 ms for 2026–2027 and 653.6 -> 419.4 ms for the July boundary. These are component timings, not whole-app or phone acceptance. The first broader trial had asymmetric cache warmth and is not an attributable benchmark.

Read-only stale-cache fallback and invalid-owner rejection passed. Candidate DDL and memo writes rolled back; original source/ACL restored, candidate helper absent and zero candidate cache rows. Frozen V245 and V246 source guards passed locally. No financial source, classification, account position, pending card record, infrastructure or frozen release file changed.

The app still requires owner sign-in for authenticated visual acceptance. Full cold latency, earlier D0/RSU/FGTS provenance, downstream card status reconciliation, retention/restore and the wider backlog remain open. Do not claim these closed from the component comparison.
