# Documented C6 installment clock change

A provider clock change split the same installment chains into two timestamp identities three hours apart. Earlier observations kept projecting installments already covered by the later documented chain.

Bridge the clock blocks only for a documented chain with two observations in each block, exactly a three-hour gap, matching civil purchase date, institution, account, card, merchant, plan and cycle offset, unique installment numbers and compatible installment rounding. Retain the original identity for ambiguous chains. Preserve every original amount, classification, date and source item. This changes derived projections only; invoice payment and raw imports remain intact.

The core reader patch has an exact source lease and preserves function attributes. The pure helper is private. Native contracts execute the actual projection CTEs and cover incompatible identities, ambiguous installments, owner isolation, conservation and replay. Full live cycle and consumer comparison is required separately; synthetic tests do not certify a private browser session.
