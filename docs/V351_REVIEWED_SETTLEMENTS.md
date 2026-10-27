# Reviewed card settlement and posted cash

A C6 issuer labels a cycle payment OTHER_PAYMENT although the same cycle, exact amount and date are supported by a posted checking debit. Preserve that issuer type. Accept only the reviewed C6 policy with its exact invoice/payment identities, matching cycle date, unique billing account, original bank description and complete purchase coverage. Generic OTHER_PAYMENT and partial/ambiguous payments remain rejected.

C6 includes previous invoice payments among card transactions. Separate those exact payment records from purchase/credit consumption using the same explicit payment signals as the source reader. Preserve merchant refunds. Keep every raw item in the documentary manifest, and require complete coverage of the remaining purchases before excluding a bank payment from consumption.

Reuse the existing reviewed links for other cards. Record existing posted debits as bank statement facts, replace only explicitly identified outdated forecasts, and compare the complete cash event set before/after. Preserve consumption, future events and existing settlement contracts. No payment or transfer is executed. No published frontend asset changes: the current UI already excludes cycles marked settlement_confirmed.

Native PostgreSQL exercises the actual settlement functions, source mutation rejection, payment vs refund, old FULL_PAYMENT cycle-window defenses and replay. Private source activation and live reader comparison remain separate requirements.
