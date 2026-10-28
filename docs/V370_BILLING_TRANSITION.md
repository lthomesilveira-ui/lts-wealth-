# Billing-cycle transition

A due-day edit within the same month can create two projected payments when the first new due date skips a month. The confirmed transition now retains each original cycle and its purchase composition while moving its cash date into the new monthly sequence.

The shared invoice reader, Cards and the Flow use the same transition. Original purchases, installment counts, historical payments and other card families remain unchanged. A new official bank statement replaces its projected counterpart by the effective payment date; a bank cycle already on the new calendar is not shifted a second time.

Validation executes five leased production function bodies in PostgreSQL17, using a controlled clock and synthetic sources. It checks the skipped month, the first payment once, later installments, narrow/full ranges, provider refresh, official-statement precedence, unchanged history/Itaú/other owner, source and function attributes, and owner read isolation. Private production reads and rendered acceptance are recorded separately after application.
