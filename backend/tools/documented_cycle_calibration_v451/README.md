An issuer refresh supplied a fully balanced C6 cycle with some installment
forecast fields absent. A processed full statement already proves the cycle,
account, amount, due date and forecast offset. The missing fields made the
combined calibration reject that existing evidence and block later purchases.

Reuse the statement's offset only when the same issuer cycle balances exactly,
the account, amount and due date agree, closing dates differ by at most one day,
at least one issuer forecast agrees and no known issuer forecast conflicts.
Incomplete statements, unverified hashes, different accounts, amounts, due dates
and known conflicting forecasts remain rejected. Existing conservative handling
of all other cycles stays. No source field or financial record is modified.

The installer changes only the reader and its pinned private source profile,
with compare-and-swap guards and preserved ownership, ACL and configuration.
Native PG17 exercises the actual reader, negative evidence cases, unchanged
sources, owner isolation, installation, reapplication, rollback and concurrency.
