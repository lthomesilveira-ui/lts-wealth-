# Documentary own outbound transfers

A newly received posted PIX to the same CPF at another connected owned bank
remained in spending even after source-specific classification as an own
transfer. The receiving bank had not provided its new statement. Treating the
outbound leg as spending overstated expenses; creating an incoming leg would
invent a receipt.

Exclude only the exact expense occurrence when source ID, posting date, amount,
bank-observed coverage and own-transfer category all match. The posted BRL PIX
must have matching payer/receiver CPF, a matching owned source checking-account
identity and a matching owned identity at the receiver's different connected
bank. A source-specific own-transfer review decision is required. No name-only,
amount-only, pending, card, foreign-currency, deleted or future match qualifies.

This changes only spending. It leaves the bank source, outgoing cash effect,
balances and unmatched receiving leg unchanged. It creates no receipt, account,
expense, payment, transfer execution or settlement. The pending-review snapshot
profile is updated atomically so its guard includes this exact new producer.

Native PostgreSQL17 fixtures execute the full current expense function with
invented source providers, verify exact exception scope and negative cases,
source preservation, private ACLs and version-guarded install/rollback. Actual
owner data and published-session verification are separate private evidence.
