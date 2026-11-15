# V446: resume interrupted classification readers

Cancelling superseded reads correctly freed admission, but cancelled background
classifications retained an error/throttle state after a complete new product
was installed. The actual authenticated candidate reproduced an unavailable
action count after the update had completed.

Income/expense and card queue owners now refresh from the existing product-ready
event. A forced income refresh coalesces one follow-up while an older attempt is
still settling, like the existing card reader. Existing generation guards remain;
queries, offsets, search terms, drafts, save state and classification writers are
retained. No decision or mutation is triggered by this recovery.

The new immutable candidate inherits V444 cancellation/bounded recovery and V445
aligned initial horizon. Tests hold classification requests, replace the product,
verify resumed actual rendered counts, preserve a draft and assert unchanged
financial content and zero writes in Chromium/WebKit at desktop/mobile widths.
Canonical promotion remains separate from candidate publication and acceptance.
