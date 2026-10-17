# Readable reconstruction of the frozen consumer suite

This package changes transport size only. It reconstructs the exact frozen PostgreSQL consumer suite and all its companion files. It does not change a test, SQL statement, dependency stub, wrapper, ACL or expected result. The final SQL must have SHA256 `3317e1c1001e04a9c7aaf1f6496e5b322d4754e395f1ebe868323f1a616eaba7` and still expects 339 unique results.

Run `python3 generate.py --output reconstructed` in a local work directory after independent review. The generator validates every source-file hash, builds all output bytes in memory, verifies every frozen output hash and filename, and only then writes to a new empty output directory. It does not connect to PostgreSQL, execute a shell command, upload files or read private mappings. A later approved CI invocation must run the original reconstructed runner; existence of generated files is not a PostgreSQL pass.

## Inspectable sources

- consumer_suite.template.sql is the original SQL with exactly 15 named slots: four complete consumer bodies and eleven synthetic fixture values. All remaining SQL is unchanged text.
- frozen_files contains the original four sanitized consumer bodies and all other frozen companion files, including the original output manifest.
- fixtures/base_rows.json holds the seven fully readable seed rows for staging, expenses, card rows and relationship evidence.
- fixtures/document_case.json holds the matched-document case with one explicit reference to the same synthetic card items.
- generate.py creates the 112 distinct synthetic purchases with an explicit loop, their 105 posted and seven pending states, the independent November cycle, and the existing named malformed/duplicate alternatives. Every field update is ordinary Python and JSON.

This is domain fixture generation, with no compression stream, base64, binary encoding, encrypted payload or generic chunk decoder. All identities and financial values are synthetic and already present in the reviewed public fixture. The private original/synthetic map and real financial snapshots are not included.

SOURCE_MANIFEST.json is the source transport allowlist. OUTPUT_CONTRACT.json lists exact reconstructed output filenames, byte sizes and SHA256 values. The original PUBLIC_MANIFEST.json inside frozen_files is copied unchanged into the output; it describes reconstructed files, not this smaller source package. The source manifest is not a release or upload authorization.

## Compilation correction

This version changes only four JSONB containment right operands by adding explicit parentheses around JSONB field extraction. The previous fixture stopped at consumer compilation with a boolean-to-JSONB operator error, before the 339 result checks. All fixture values, dependency stubs, wrappers, ACL, cases, expected results, runner and generator logic remain unchanged. PostgreSQL compilation and all 339 results still require a reviewed rerun; local reconstruction does not certify runtime success.
