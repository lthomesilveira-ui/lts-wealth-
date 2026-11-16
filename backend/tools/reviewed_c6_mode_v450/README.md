An issuer refresh changed the payment method of the same already reviewed C6
receipt from DEBIT_ACCOUNT to BANK_SLIP. The bank debit, invoice and issuer
payment identities, date and amount remained unchanged. Existing guards correctly
withdrew settlement acceptance; generic acceptance of BANK_SLIP is not appropriate.

Two existing readers now use a private immutable mode predicate. DEBIT_ACCOUNT
keeps its exact old behavior. BANK_SLIP is accepted only with a service-owned
review record bound to this exact owner, original link, bank debit, invoice,
issuer payment and original/current receipt objects. The old and new payment
JSON must differ only in paymentMode. The caller's source, canonical invoice,
posted bank, cycle, amount, currency, consumption and completeness checks stay.
Other receipts, duplicate IDs, changed dates/amounts, partials and unreviewed
BANK_SLIP entries remain rejected.

The installer updates the source-profile hashes atomically and preserves ACL,
security mode and configuration. It never updates financial source data or
creates a payment. The separate documentary review must preserve its before
record and recheck the full consumption manifest against current primary data.
Native PG17 covers the actual cycle/annotation/later-receipt readers and their
negative cases, plus guarded installation/rollback and private access.
