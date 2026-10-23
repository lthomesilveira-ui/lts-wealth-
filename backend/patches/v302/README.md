# V302: posted settlement of an already-confirmed partial obligation

A bank debit can already be paired with an existing forecast by the source
context, so it is not a new bank expense. If the forecast stays projected,
the expense can nevertheless be absent. This opt-in operation requires the
original explicit partial-obligation confirmation, its earlier posted partial
payment, a separately inspected bank-schedule document identifying the payee,
and exactly one posted checking debit. Amount/date alone are insufficient.

The existing realized-source reader keeps its original contract-payment branch
unchanged. A separate private, immutable JSON validator admits only the explicit
partial-obligation evidence. The original event amount, date, category and
previously confirmed beneficiary remain exact. No future cycle is inferred.
The source hashes, prior event and source-document identity remain in the
private receipt; no private manifest belongs in this repository.
The manifest's event hash replaces `created_at` with its Unix epoch before
hashing the complete row. A different session timezone must not invalidate
the same source instant; the validator compares offset-qualified instants.

The earlier receipt's raw hash is retained for audit. Reader validity uses the
source ID, owner, bank/account, date, amount, posted status and exact payee
identity, so unrelated provider bookkeeping does not silently un-realize a paid
obligation. Deleted, reversed, moved or differently attributed sources fail
closed. The helper has no public, anonymous or authenticated execution grant;
existing reader identity, invoker semantics and ACL are preserved.
The bank-classification reader reuses this exact binding's previously confirmed
category/person. A later source-specific owner decision retains precedence.
This prevents Flow from reverting the now-paid source to an unknown category;
no merchant-wide rule or new person decision is written.
The original cash source engines also retain the exact paid event after it
leaves the forecast statuses. No second row or balancing overlay is appended.
Tests must compare relative and economic cash fields as well as visible bank
balances: a fixed observed balance must not mask a missing underlying debit.

Run the operation first in a rolled-back transaction with `lts.v302.input` set
to a reviewed private manifest. Check source/other-event/expense fingerprints,
current Flow and observed cash independently, then commit the same operation.
Reapplication must be a no-op. This is not full historical certification,
private HTTP/device acceptance, or closure of the broader backlog.
