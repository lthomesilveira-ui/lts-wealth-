# Bank expense reading within the requested period

The bank expense reader limits automatic transfer matching to posting dates that can contribute an expense in the requested period. Both sides of an automatic pair have the same posting date. Owner-confirmed transfers and the bank's monthly deduplication keep their existing readers.

The reader skips flow context when there are no eligible debits. It classifies rows after duplicate exclusion and normalizes fallback rules once for the result. Existing explicit classifications and ambiguous rules retain their precedence.

The guarded migration updates one function in place. The PostgreSQL checks compare complete results with the predecessor and cover empty windows, multiple owners, automatic and owner-confirmed transfers, duplicate matches, rule precedence and a divergent predecessor.
