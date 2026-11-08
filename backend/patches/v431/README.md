# Confirmed schedule and posted counterpart

A previously confirmed own-account Pix schedule can become a posted debit and a
unique credit in the confirmed destination. One bank can supply a conflicting
payer CPF on the received record. That conflict must not create a new income
when the owner's source-specific destination confirmation, both account owners,
routing, dates, currencies and amounts independently prove the pair.

V431 adds only that derived pairing path. It reuses the existing V304 validator
for the confirmed posted debit, requires both current account ownership records,
and rejects ambiguous debit/credit matches. It preserves provider rows, the
original confirmation, per-account cash and all existing explicit pair paths.
It never creates an owner confirmation or applies a generic same-amount rule.

The migration guards the exact predecessor and preserves the reader's OID,
permissions and all other function attributes. The helper is executable only by
the existing service role and owner. Native PostgreSQL tests use synthetic data;
live source evidence belongs in the private project record.

The C6 October evidence renewal is a separate private, guarded data operation:
all fifteen purchase identities and canonical purchase contents matched before
renewing only the payment manifests. It is not part of this migration.

