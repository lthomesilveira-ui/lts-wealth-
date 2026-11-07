# Full-horizon financial scenarios

An additive immutable UI candidate based on V417. The first negative balance and the minimum balance are selected independently from every server-provided daily balance through the configured maximum horizon. With no negative day, report that fact and the positive or zero minimum, including its date. Ties use the earliest day. Unknown values, missing dates, duplicates or incomplete coverage do not become zero and cannot certify a full-horizon minimum.

Before the optional premises metadata arrives, the existing five-complete-future-years policy is used; the dashboard must not fall back to the following year. Annual rollover extends the horizon automatically. Explicit filters in the Flow view do not shorten the global scenario cards. No financial values are recalculated and no bank/forecast/auth records are written.

build.py guards all predecessor assets and is reproducible. test.cjs covers 25 pure-model cases. The browser suite renders the complete app with invented HTTP data in Chromium/WebKit at mobile/desktop widths, testing late deficits, positive minima, explicit Flow ranges and incomplete data. These tests are not an authenticated owner session or a physical-iPhone certificate.

The staging step creates only generic Git blobs/trees after tests, never commits, branch updates or deployment. Normal review, protected historical tests, publication and served-byte verification remain separate requirements. Existing published releases are immutable.
