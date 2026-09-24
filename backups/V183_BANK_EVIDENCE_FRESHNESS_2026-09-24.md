# Bank maintenance evidence

Maintenance freshness now considers already-applied statement evidence in account provenance as well as the reconciliation registry. It requires a valid non-future date, explicit statement evidence, and a valid SHA-256 checksum (or nonempty checksum list).

The migration runs nine synthetic provenance cases and checks that all account rows and all non-bank maintenance checks remain identical. Existing freshness thresholds, financial amounts, classification decisions, permissions, and the fixed UI entry point are unchanged. It does not request or import another document.
