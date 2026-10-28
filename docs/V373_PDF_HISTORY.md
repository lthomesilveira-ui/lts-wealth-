# V373: documentary historical composition

A dedicated read-only source layer can attach a reviewed bank PDF to an existing historical consolidated expense. Signed items must match the document total and row count. The consolidated amount, category, cash effects and all ledger rows remain unchanged; any difference stays explicit. The original workbook reader and earlier clients remain unchanged.

An original day/month without a year remains day/month. PDF references identify document, page, column and record rather than invented spreadsheet cells. Issuer categories are provenance, not new owner classifications or beneficiaries.

Private tables have no direct authenticated access. The public RPC is SECURITY INVOKER and delegates to an owner-checked private reader. Tests cover isolation, missing identity, source completeness, parent signature, signed credits, unchanged legacy results and financial rows, and rendered PDF/workbook flows at desktop and mobile widths. No private statement is included in the repository or synthetic fixtures.

An existing signed workbook invoice adjustment may explain the difference. The reader requires the same owner, instrument, date, description and period, a unique positive consolidated row, the explicit workbook-adjustment source kind, and a matching document net. Ordinary refunds and ambiguous consolidated rows do not qualify. Both original ledger rows retain their signs and values.
