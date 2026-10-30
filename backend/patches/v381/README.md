# V381 — documented Cofrinho redemptions

The Cofrinho reader used only manually represented asset movements after a dated
primary balance. A posted bank receipt could therefore appear in bank cash while
the asset leg remained absent from the Cofrinho calculation.

The reader now also subtracts an unrepresented receipt when the existing owner,
bank connection, checking account, provider identity, posted date, currency,
amount and explicit bank product description all agree. An existing movement is
recognized by its source identifier and exact legs, never by amount/date alone.
Conflicting source links are exposed by the component reader and are not
automatically reclassified. Later primary balances absorb earlier redemptions.

No bank event, movement, expense, investment product mapping or yield is created.
Other assets keep their existing calculation. Existing public function signatures
and service-only permissions are preserved; the new helper is service-only and
security invoker. A cache epoch change invalidates prior browser Flow results.

This does not turn the MeuPluggy proxy into a live bank connection. The provider
documents daily upstream updates and disallows manual proxy updates:
https://docs.pluggy.ai/pt/docs/guides/meu-pluggy-personal-use

Nor does a residual position difference prove investment yield or product
composition. Those require dated primary evidence; owner confirmations remain
separate from provider positions.

Validation: PostgreSQL17 fixtures cover missing/represented receipts, repeated
reads, equal-amount distinct identities, wrong bank/account/owner, pending/deleted
sources, a later primary balance and conflicting links. Native owner-scoped
checks and unchanged financial-source hashes are recorded privately. Fixtures
do not certify a private browser session, device or full recovery.
