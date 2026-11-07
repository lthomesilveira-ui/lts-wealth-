# V417 report presentation

A deterministic additive release built from immutable V415 assets. Run build.py to create the candidate or verify an existing candidate byte-for-byte. Prior release files, financial records, server functions and authentication remain unchanged.

The unit suite reproduces the prior rejection of valid three-month card references. The browser suite renders the actual changed components offline with invented values at mobile and desktop widths, including closed/open details, incomplete references, failure and retry. These checks are not a full-app, physical-device or private authenticated-session certification.

promote.py prepares the mobile pointer and Pages workflow in the test workspace, retains every prior static release check with the new pointer parameter, and verifies all those checks. The served-assets verifier adds V417 and continues to verify every previously protected release.

The CI job has read-only repository permissions. stage_objects.py now only exports the exact reviewed files and their hashes into the test artifact. It does not call the GitHub API, write Git objects, create commits, update branches or deploy. Workflow changes must use the separately authorized repository connector; a workflow-token permission refusal is not retried or overridden. Publication occurs only after a reviewed merge through the normal Pages workflow, with served verification distinct from fixture acceptance.
