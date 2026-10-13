# Received invoice rollover and obligation evidence

An unresolved recorded cycle used a received bill on its due date, then reverted to an older snapshot on the next day. The eligibility cutoff excluded every past-due bill, including an exact open/projected cycle whose payment was not reported.

The amount and composition readers retain that received bill when owner, family, cycle and due date match an unresolved recorded cycle. The existing protections for closed cycles, newer manual sources, uniqueness and eligible received data remain in force. Missing historical cycles are not seeded by this exception. No payment is inferred and no financial row is edited.

The recurring calendar audit retains overdue recorded forecasts as unconfirmed obligations. They do not prove a payment, and they are separated from truly absent future projections. Evidence includes original source identities; the audit creates no forecast.

The lock registry is already server-only by grants. RLS adds protection without introducing browser policies or changing internal access.

Apply these source-guarded patches only to their stated definition baseline. They were applied and verified in the private project. Reapplying a completed definition patch deliberately fails its lease; do not remove that guard.

Validation: `backend/qa/lts_v266_rollover_rollback.sql`, `lts_v266_product_rollback.sql`, and `lts_v266_authenticated_scope_rollback.sql`. Cold probes use transactional cache invalidation and roll back all effects. The private receipt contains dates, measurements, source comparisons and remaining limits. These probes are scenario-specific and are not proof of complete source coverage or physical-device acceptance.

The V264 interface, protected root and prior releases stay unchanged. No private financial data or source identifiers are included here.
