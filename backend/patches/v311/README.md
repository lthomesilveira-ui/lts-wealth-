# Future card invoices

A partial recent-purchase feed must not replace all remaining installments of
the latest received Aeternum bill. V311 uses its complete, exact account/bill
composition and explicit installment numbers and terms. It adds recent purchases
and credits once and projects only remaining numbered installments. An installment
already supplied for a future cycle replaces the projection for its purchase;
equal amounts alone do not match purchases. Paid bills and issuer totals keep
their precedence. No new shopping or recurring charge is assumed.

All existing card, invoice, detail and Flow readers consume the corrected cycles.
Future cycles remain projections: an independent issuer total is not fabricated
from their own line sum. Their details retain the received versus projected items.
The exact closed C6 documentary cycle also replaces a leftover past-cycle
installment projection without asserting that the closed bill was paid.

Build with `backend/tools/build_card_forecast_patch_v311.py`, supplying the four
current definitions as `{name:{definition:...}}`. Definition leases reject drift,
and OID, ACL, owner, volatility and configuration are checked after replacement.
New helpers are invokers with an empty search path and no client-role grants.
Invalidate derived source epochs/memos when deploying; preserve source records.

`backend/qa/lts_v311_ci.py` runs bounded synthetic fixtures on PostgreSQL 17,
including amount/line agreement, exact future installment replacement, credits,
payments, account/owner/currency/deletion guards, issuer precedence, replay and
definition drift. Its forecast payload is rendered through the real V309 assets
at desktop, 390px and 360px widths. This is not a production browser session or a
full DB/Storage restore. Actual deployed consumers require separate rollback QA.
