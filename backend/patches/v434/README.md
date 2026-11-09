# Dated Coopharma balance

The commitments reader used to return an unavailable Coopharma balance even
when a dated creditor position was present. It now accepts a finite,
nonnegative balance on a documented position at or before the requested date.
Payroll installments remain a separate schedule.

The patch replaces one existing reader in place and checks its predecessor,
ownership, grants and configuration. Existing readers and historic positions
continue to use the same contract. The database patch contains no owner data.
The native PostgreSQL test covers dated evidence, older dates, missing or
invalid positions, separate installment amounts, and isolated owner scope.
