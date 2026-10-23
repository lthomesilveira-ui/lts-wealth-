# V301 — preserve a recurring subscription without counting its payment twice

The subscription commitment and the categorized statement purchase were already
present. A newly posted checking-account debit was not connected to that source
and was included as another unclassified expense. The issuer's refreshed bill
also retained an earlier cycle's payment; validators that required the entire
payment array to contain a single payment could not accept the current cycle.

Apply `billing_window_settlement.sql` through the normal migration workflow.
The new policy is opt-in, tied to an exact reviewed link and source contract.
It selects exactly one full BRL checking-account payment strictly after the
statement closing and no later than the actual bank posting date. The complete
issuer payment array stays part of the unchanged evidence. No raw payment,
purchase, source date or amount is rewritten. Issuer civil dates and bank
posting dates remain separate.

A duplicate identity, two in-window payments, a partial payment, changed amount,
currency, mode, selected manifest or invalid date is rejected. Existing policies
retain their original branch. Both original reader definitions are leased by
MD5; replacement preserves their identities, owners, ACLs and configurations.
The new pure helper is invoker/immutable, with an empty search path and no
execution grant to PUBLIC, anon or authenticated.

The companion operation `backend/operations/confirm_subscription_and_income_v301.sql`
requires a private exact-source manifest in `lts.v301.input` and a caller-owned
transaction. It uses the existing authenticated category writers, preserves
unrelated decisions and every other canonical expense row, and freezes full
bank-source/event fingerprints and bank cash. It creates a reviewed payment
link and exact purchase-coverage contract only when every proof validates.
Existing explicit person/category decisions are not replaced. Reapplication
does not create another link, contract or classification.

The income confirmation is source-specific. Do not convert one employer
reimbursement into a rule for every incoming employer transfer. A recurring
card forecast is likewise not proof of a future paid bill.

Validation: 21 synthetic cycle-window cases, 21 strict integration cases for
the newly reviewed settlement and 21 for the previous settlement passed.
Two complete rolled-back operation trials passed; reapplication was a no-op.
The test recipes are `backend/qa/lts_v301_cycle_window.sql` and
`backend/qa/lts_v301_settlement_readonly.sql`. Run the latter separately for
each private owner/payment identity. Private manifests and financial receipts
must not be committed.

The frontend remains V296. This does not certify all historical reconciliations,
future automatic source-link enrollment, a private HTTP session, physical
devices, native restoration or the full project backlog.
