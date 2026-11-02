# Daily Cofrinho reconciliation

The V245 reader replaced the daily provider balance with a fixed documentary
position plus later recorded redemptions. V381 added uniquely identified bank
redemptions and V399 corrected date selection and separated FGTS. Those fixes
did not reconnect the already verified Cofrinho component mapping to daily
Open Finance positions. The V399 batched D0 reader also independently repeated
the documentary-only calculation.

V402 reads only the existing reviewed component set. Its original reviewed
component values must add to the common reviewed total, so removing or
unverifying one mapping cannot silently produce a partial balance. Every live
component must come from the same successful collection, same owner, item and
connection, with its verified identity, BRL net valuation and valid source time.
Unmapped CDBs, expired or malformed collections, future source timestamps and
mixed active valuations are excluded. A withdrawn component can explicitly be
zero; a missing component cannot.

Use the provider refresh timestamp and the observation cut, rather than the
investment `date` field, which can point to a following business day. A bank
receipt after that source timestamp changes the available balance once. A
receipt already included in the source position is not subtracted again. An
unlinked same-day manual movement is not assigned an invented time.

Preserve explicit owner positions on their own dates. A subsequent verified
provider day updates automatically. Preserve all dates before the original
reviewed reconciliation boundary and all other assets' rules. Current position,
dated composition, effective asset position, batched D0 and downstream flow
consumers share the same reader. Existing fingerprints include the provider
payload; the migration advances the existing read-cache epoch once.

The patch creates no financial event, asset position, mapping, adjustment,
yield, payment or transfer. It does not change backup, retention or job settings.
No new data table is required. Published V399 assets remain unchanged; V402 adds
a compact source disclosure showing the mapped net components, position day,
later movements, available amount and separate consultation time.

Native PostgreSQL 17 tests use synthetic records only. Browser fixtures verify
WebKit and Chromium at mobile and desktop widths; they do not certify a private
HTTP session or physical iPhone. Production acceptance must compare actual
historical sources, future projections and protected source hashes separately.
