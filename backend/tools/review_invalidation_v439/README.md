# Refresh review rows after a card classification

A successful card classification already invalidates the authenticated read
transport. The outgoing review list had its own ready state and did not listen
to the card confirmation event. It could keep showing an earlier response and
ask to classify the same source again, even though the decision was persisted.

V439 listens to the existing successful-save event, supersedes any earlier
review request and requests the current list through the existing bounded
transport. A late response cannot restore the pre-decision list. Unrelated
drafts, search and pagination remain intact. A failed refresh retains the known
list and its existing warning. Unknown data never becomes a fabricated zero.

The builder checks every predecessor asset and creates a separate immutable
release. Only the reader callback, its bundled copy, release identity and
provenance change. Financial calculations, source identities, mutation calls,
authentication, cache policy and request arguments remain unchanged.

Lifecycle tests reproduce the predecessor and cover ready and in-flight reads,
multiple confirmations, unrelated drafts, session changes, malformed data and
failure/retry. Chromium and WebKit render mobile and desktop states using only
invented fixtures, including default and expanded disclosures. Synthetic
verification does not certify private-session or physical-device acceptance.
