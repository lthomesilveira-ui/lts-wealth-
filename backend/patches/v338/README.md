# Original workbook transfer reversals

An exceptional negative original ledger value is not enough to normalize an imported transfer. V338 accepts it only with separately traced original per-bank cash: the same date and value cell, its incoming or outgoing block, the component total and opening/closing arithmetic. The existing effective historical cash must already agree with that signed contribution.

The resolver extends V336's positive-magnitude proofs with a private reversal register. It still matches exact source payload, date, description, bank, direction and amount, rejects later contradictory owner context, and avoids overlapping evidence. Only the historical transfer flag/category/exclusion changes. No amount, date, cash leg, current balance or future commitment is created or changed. Opposite signed reversals on different days must not be represented as a same-day paired transfer.

Internal evidence uses RLS and service-only grants. Evidence changes use the existing derived-cache invalidation. The historical function keeps its OID, owner, grants and other attributes under a full definition lease. The workbook and private proof rows are never published.

Native PostgreSQL17 tests exercise original negative incoming and outgoing values, all pre-existing V336 proofs, immutable cash/source identity, unrelated rows, definition attributes, rejection cases, role restrictions, invalidation and replay. They do not certify cross-owner HTTP, real devices or every historical counter-leg.
