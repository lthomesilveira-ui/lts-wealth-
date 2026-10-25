# C6 future invoice detail

The compatibility invoice reader could return the correct future C6 total with
only received purchases, or no items, while the canonical card cycle already
contained the remaining installments. Consumers of `metadata.items` saw partial
composition beside a complete known amount.

Reuse one materialized C6 cycle payload from the existing prepared reader. Attach
its items only for a unique future open/projected cycle with matching amount,
due date and exact nonempty item sum. Incomplete, ambiguous or mismatching cycles
leave the previous detail intact. Preserve the replaced detail snapshot and
distinguish projected items from received items. No new invoice, amount, due date,
settlement, grant or endpoint is introduced; historical/current C6 and other
cards remain exact.

The function lease preserves OID, owner, ACL and all attributes except its body.
Eight source/financial/catalog/decision/document fingerprints remain exact.
Native PostgreSQL fixtures reproduce the old discrepancy and verify agreement,
unsafe compositions, owner isolation, replay and drift. Browser checks use the
published V312 assets with synthetic payloads at desktop/mobile widths; they do
not certify a private HTTP session or a physical device.
