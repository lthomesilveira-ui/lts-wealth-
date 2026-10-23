# V303: reuse paid-source identities in the forecast audit

The forecast audit must not call an already-paid card obligation unpaid, or
call the current month's payroll advance missing, when the existing receipt
readers prove the exact bank occurrence. Bank descriptors and a legacy plan's
amount need not be identical to a received issuer invoice's actual payment.

This private read-only helper reuses the existing payroll match, documentary
invoice link, settlement contract, issuer-refresh annotation and owned legacy
plan checks. It does not create weaker amount/date/name matches. An ambiguous
bank-source-to-plan mapping remains unclassified by this helper.

The audit uses each proved source's original plan description to identify its
series. It removes only that same plan/date/series/direction from unconfirmed
obligations. Actual posted amount and date remain original. Evidence after the
requested as-of date does not cover the earlier period. Future periods still
need their own forecasts or owner assumptions.

No financial data, classifications or forecasts are written. The existing
audit signature, OID, owner, ACL and security attributes remain unchanged. The
new helper has no public, anonymous or authenticated execution grant. The
existing public response version remains compatible, with a receipt-identity
revision in provenance.

Validation: `backend/qa/lts_v303_ci_sql.py` emits an isolated schema with the
real V266 audit and V291 legacy-card check, but synthetic upstream receipt
dependencies. It tests thirty rejection/deduplication cases, owner/as-of
scope, current-month coverage, future-period parity, private grants and replay.
It does not certify the upstream documentary proof or a private browser session.
`backend/qa/lts_v303_integration_rollback.sql` separately tests existing live
receipts, complete source-row hashes, all canonical expenses, the exact monthly
response, original audit attributes, unchanged future periods and replay, with
everything rolled back. Neither test writes real financial data.
