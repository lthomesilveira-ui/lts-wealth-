# Readable reconstruction of the frozen consumer suite

This package changes transport size only. It reconstructs the exact frozen PostgreSQL consumer suite and all its companion files. It does not change a test, SQL statement, dependency stub, wrapper, ACL or expected result. The final SQL must have SHA256 `67e7b99236fce6f3892e4b69b713d3716105e523d11587ef6e5a57771ec9bac8` and still expects 339 unique results.

Run `python3 generate.py --output reconstructed` in a local work directory after independent review. The generator validates every source-file hash, builds all output bytes in memory, verifies every frozen output hash and filename, and only then writes to a new empty output directory. It does not connect to PostgreSQL, execute a shell command, upload files or read private mappings. A later approved CI invocation must run the original reconstructed runner; existence of generated files is not a PostgreSQL pass.

## Inspectable sources

- consumer_suite.template.sql is the original SQL with exactly 15 named slots: four complete consumer bodies and eleven synthetic fixture values. All remaining SQL is unchanged text.
- frozen_files contains the original four sanitized consumer bodies and all other frozen companion files, including the original output manifest.
- fixtures/base_rows.json holds the seven fully readable seed rows for staging, expenses, card rows and relationship evidence.
- fixtures/document_case.json holds the matched-document case with one explicit reference to the same synthetic card items.
- generate.py creates the 112 distinct synthetic purchases with an explicit loop, their 105 posted and seven pending states, the independent November cycle, and the existing named malformed/duplicate alternatives. Every field update is ordinary Python and JSON.

This is domain fixture generation, with no compression stream, base64, binary encoding, encrypted payload or generic chunk decoder. All identities and financial values are synthetic and already present in the reviewed public fixture. The private original/synthetic map and real financial snapshots are not included.

SOURCE_MANIFEST.json is the source transport allowlist. OUTPUT_CONTRACT.json lists exact reconstructed output filenames, byte sizes and SHA256 values. The original PUBLIC_MANIFEST.json inside frozen_files is copied unchanged into the output; it describes reconstructed files, not this smaller source package. The source manifest is not a release or upload authorization.
