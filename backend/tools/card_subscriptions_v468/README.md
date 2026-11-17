# Specific recurring card forecasts

This package adds only owner-approved, individually identified subscription forecasts to the existing projection builder. It does not restore a general card budget or write bank, invoice, purchase or financial-event rows.

Rules are private owner data, outside this repository. They contain a verified card family, card suffix, merchant aliases, amount, cadence, cash calendar and owner evidence. The existing known card cycle has priority. A charge already included in that cycle is not added again; final invoices are retained. Missing composition, repeated identities and ambiguous merchant prices remain unresolved rather than being interpreted as zero.

The guarded builder patch reuses the card read already needed for scoped planning, appends the derived events before the existing worker captures its summary, and preserves the previous calculation and source guards. The cash dates use an existing received cycle or the current card-calendar helper. Later C6 dates without a received cycle remain estimates, including weekend adjustment.

Run build.py, then test_native.py with an isolated PostgreSQL 17 server. The test uses invented data only. Native fixtures cover owner separation, invalid rules, overlapping subscriptions, monthly and annual cadence, known and official invoices, refunds, incomplete readers, duplicate periods, ambiguous prices, preservation of the original result, and private privileges. Existing V467 model parsing is checked against the synthetic SQL output.

Installation and the private owner rule update are separate operations. Install only after these gates pass. Recompute through the existing owner queue, then verify the real published application. Test success is not a claim of real-device validation or global performance acceptance.

