# V417 report presentation

A deterministic additive release built from immutable V415 assets. Run build.py to create the candidate or verify an existing candidate byte-for-byte. Prior release files, financial records, server functions and authentication remain unchanged.

The unit suite reproduces the prior rejection of valid three-month card references. The browser suite renders the actual changed components offline with invented values at mobile and desktop widths, including closed/open details, incomplete references, failure and retry. These checks are not a full-app, physical-device or private authenticated-session certification.

promote.py prepares the mobile pointer and Pages workflow, retains every prior static release check with the new pointer parameter, and verifies all those checks before staging. The served-assets verifier adds V417 and continues to verify every previously protected release.

The CI staging step writes generic Git blobs/trees only. It does not create commits, update branches or deploy. A separate reviewed fast-forward commit uses the reported tree and triggers normal PR checks. Publication occurs only after merge through the normal Pages workflow; a served verification is distinct from rendered fixture acceptance.
