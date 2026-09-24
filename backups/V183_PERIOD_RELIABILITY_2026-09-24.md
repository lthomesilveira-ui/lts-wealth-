# V183 period reliability

- Monthly base aggregation now enforces the same inclusive effective-date window as the expense detail. Card purchase dates and competence dates retain their existing meanings.
- Migration aborts on function drift, changed full-period reports or partial-period/detail disagreement. It does not edit source transactions or authentication.
- Historical source lookup has a non-unique user/reference expression index. Migration compares complete historical reader outputs before and after and aborts if they differ.
- Candidate-only Flow presentation synchronizes its year selector and hides stale table rows during loading, failure or an interval mismatch. Existing reader data is retained.
- Local regression: 58 JavaScript tests, 30 historical-coverage assertions and eight Python tests passed. Live authenticated UI verification is pending; this is not full product acceptance.
- Public root and the fixed V181 entry remain unchanged. Private data, screenshots and financial QA figures are excluded from this receipt.
