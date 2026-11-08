# Additional owner-confirmed FGTS redemption

A bank credit identified only as a transfer from Caixa does not establish its
purpose. Once the owner identifies an exact posted credit as FGTS, existing
readers must treat it as an asset redemption without adding another bank credit
or inventing a principal/interest split.

The receipt validator retains its original bank, account-owner, currency and
posted-state checks. The additional path requires a dated source-specific owner
statement, exact amount and account, and a matching source fingerprint.
Only the established order/updatedAt metadata exception can tolerate a later
consultation; changing financial fields invalidates the proof. Duplicate owner
evidence fails closed.

The position reader now selects the latest uniquely evidenced withdrawal while
preserving earlier dates and the original scheduled-component receipt. Dated
post-withdrawal positions remain owner evidence, with their actual source label.
The migration changes no stored financial row and preserves each function's
other attributes. Native PostgreSQL tests use synthetic identities and values.
Private confirmation data, statements, zero-position insertion and bank-source
checks belong in the private project record.

