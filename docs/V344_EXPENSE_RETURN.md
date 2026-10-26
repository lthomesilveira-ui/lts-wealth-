# Expense detail return navigation

Entering a property component replaced the parent expense drawer and left only a close control. V344 adds an explicit return control above the title. It returns through property components and investment-archive levels, then closes to the original group view. Period, search text, list visibility and scroll are retained on return. A parent is read again through the existing guarded reader rather than reusing an unfinished request.

Navigation history is limited to the active drawer and is cleared on close, route change, sign-in, sign-out and data invalidation. An older child response cannot replace a parent after return. Existing financial detail totals, pagination, revision checks, signed values, category decisions, transport and cash readers are retained.

The immutable release contains the same 77 files as V342 and changes one runtime asset. It does not implement the proposed category/group/macrogroup reorganization or a database migration. V343's documentary spending correction is a separate backend change.

Validation reproduces the prior missing return and exercises actual release assets with isolated synthetic HTTP on desktop and mobile widths. It also preserves shared transport, refresh, month rollover and broader interface/export checks. Synthetic browser tests do not certify a signed-in production session or a physical iPhone.
