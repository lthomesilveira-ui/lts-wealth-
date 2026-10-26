# Keep the default monthly summary on the current month

When the dashboard remained open over a month boundary, its business date moved
forward while the default month retained its initial value. After October31 to
November1 in Sao Paulo, the V341 component requested October1–31 instead of
November1. The selected month and period were visible, but the default overview
no longer followed the current month.

V342 records whether the current month is being followed. A month or year
boundary updates this default on the next existing render or data refresh.
An explicitly selected historical month stays selected; selecting the current
month resumes following it. A new signed-in session starts on the current month.
Existing day, sequence and session guards continue rejecting old responses.

Only the month component changes. The exact release contract reconstructs it
from V341 using four state-management edits. Monthly calculations, source data,
bank positions, classifications, invoices, cash flow, collection coordination,
query deadlines, styling and other runtime assets remain byte-for-byte identical.
No database migration or financial mutation is part of this change.

The actual component is exercised with synthetic clocks for a local month/year
boundary, UTC midnight while Sao Paulo is still in the preceding day, a day
boundary within the same month, a historical selection, selecting the current
month again, a late response and a new session. Browser CI reproduces V341's
issue, then verifies the new release at desktop1440 and mobile390/360 widths.
The existing financial interface suite checks monthly values, three-bank
arithmetic, unknown versus zero, actions, detail navigation and the complete
365-day export. Evidence contains only synthetic accounts and HTTP responses.

This is not a new midnight timer or background collection job. It follows the
current month when the existing render/refresh runs. Synthetic browser checks
do not certify a production signed-in session or a physical iPhone.
