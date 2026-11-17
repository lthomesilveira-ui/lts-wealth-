# Paid utility recurrence identity

A retired forecast can already have a posted utility payment counted in expenses while recurrence coverage still calls its month missing. This patch adds a read-only receipt identity for that already documented occurrence. It does not create a payment, change a bank row, or add another expense.

The private helper requires the archived exact forecast, one active occurrence retirement, the recorded immutable bank hash and actual amount/date, the same checking account, a prior authenticated classification for the same utility identifier and company recipient, a current matching property/category, covering bank position and a unique posted monthly debit. Reversed, ambiguous, deleted, pending, cross-owner, other-account and changed-source evidence fails closed. Variable actual bills need not equal their planning estimate.

The original payroll/card/Aeternum receipt branches remain byte-for-byte intact. Two producers are added to the closed review profile; all prior entries stay unchanged. Existing function metadata and privileges are asserted, and no public access to the new private helper is granted. Installer and rollback refuse active workers or source drift. Rollback requires review of any active utility retirements; the unreachable private helper is retained after rollback.

Run `python3 build.py` to regenerate the exact guarded SQL and manifest. The workflow uses PostgreSQL17 for nine native test groups; fixtures contain invented data. Existing original reader definitions are preserved for exact patch and metadata verification; their unrelated payroll/card dependencies are not replaced or claimed as a new synthetic end-to-end test. Real-owner receipt and expense parity must be checked separately at installation.
