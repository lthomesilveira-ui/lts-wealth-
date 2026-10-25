# Preserve explicit workbook transfer meaning in historical readers

The legacy history reader reset the transfer flag to false. Old own-bank
receipts whose imported category was absent could therefore enter recurring
income review, even where the original workbook explicitly called them bank
transfers. An outgoing leg could already be excluded from spending while its
incoming leg remained ordinary income.

V336 adds an internal, source-specific workbook evidence register. It records
the original sheet, row, SHA256, category and bank endpoints alongside the exact
imported source payload. The resolver rejects source drift, changed amount,
date, direction, bank, description and later conflicting owner context. It does
not infer another transfer from an amount/date/name match or create missing
legs. Historical reader amounts, dates, accounts, source identities and order
are unchanged. Only proved legs receive transfer/category/exclusion meaning.

Evidence is populated privately after one-to-one original-workbook matching.
No owner identifiers, source rows, financial amounts or private workbook hashes
are shipped in this repository. Exceptional negative workbook values, missing
or duplicate rows and ambiguous identities stay unresolved. The importer does
not edit the workbook or source tables. Its positive source amounts are
magnitudes; explicit source descriptions, endpoints and imported direction
must agree. It does not certify that every counter-leg is present or settled.

The existing history function OID, owner, ACL, configuration and all attributes
except its body are preserved under a definition lease. The internal table has
RLS, a service-role-only policy and no anonymous/authenticated grants. The
invoker helper is not callable by those roles. Existing statement-level cache
invalidation is attached to evidence changes; it creates no financial event.

Native PostgreSQL17 fixtures exercise both existing legs, net-zero cash for an
explicit pair, unchanged cash identity/unrelated rows/function attributes,
17 rejection cases, owner isolation, denied internal access, invalidation and
idempotent replay. Fixtures are not real cross-owner HTTP, physical-device or
full historical reconciliation certificates. Live source fingerprints and
read-only preview evidence remain private and are recorded separately.
