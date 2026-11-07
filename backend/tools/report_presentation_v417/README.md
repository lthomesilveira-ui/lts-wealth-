# V417 report presentation

A deterministic additive release built from immutable V415 assets. Run `python3 backend/tools/report_presentation_v417/build.py` to create the candidate or verify an existing candidate byte-for-byte. It never changes published V415 files, bank data, server functions or mobile routing.

The unit suite reproduces the prior rejection of valid three-month card references and verifies mixed-window, invalid and incomplete data. The browser suite renders the actual changed components offline with invented values at mobile and desktop widths, including closed/open details, incomplete references, failure and retry. These checks are not physical-device, full-app or private authenticated-session certification.

The CI staging step writes generic Git blobs/trees only after the render checks pass. It does not create commits, update branches or deploy. A separate reviewed fast-forward commit can use the reported tree, followed by the normal PR checks. The candidate retains its own versioned URL; promotion of the stable mobile pointer is a separate release action.
