# Readable reconstruction of the frozen atomic gate

This package reconstructs exactly the eleven public files of atomic gate0448. Its output PUBLIC_MANIFEST.json must retain SHA256 03d85202df6497331dac0e77b35ab7346e518cfe4b0be7a592c891faf80e8035. The expected results remain 175 functional, 10 concurrent and four empty-instance guard tests. Reconstruction is not a PostgreSQL pass.

## Explicit public dependency

First reconstruct the frozen consumer339 output directory using its separately reviewed public generator. No consumer source package is duplicated here. CONSUMER_DEPENDENCY.json lists the exact fourteen required consumer output filenames, sizes and hashes. The consumer SQL must have SHA256 3317e1c1001e04a9c7aaf1f6496e5b322d4754e395f1ebe868323f1a616eaba7. Every dependency is verified before extraction; a missing or edited companion file also rejects reconstruction.

After independent review, use `python3 generate.py --consumer-dir /path/to/reconstructed-consumer --output reconstructed-atomic`. The output directory must be empty. The generator verifies its source allowlist, all consumer dependencies, named extraction hashes and every frozen atomic output hash before writing anything. It never executes SQL or a shell command, connects, uploads or imports private files.

## Named and readable assembly

1. Extract initial_setup_before_first_fixture_case from the verified consumer SQL. Its boundary is the first literal SELECT public.fixture_case( and its complete prefix hash is pinned.
2. Replace the single initial empty-instance guard with the exact stricter guard already frozen in atomic0416. This affects only the assembled atomic setup; the consumer dependency is never modified.
3. Append atomic_suffix.template.sql. Its two named CONTROL slots contain the unchanged apply_control_synthetic.sql and rollback_control_synthetic.sql files.
4. Copy the other frozen atomic files unchanged and verify all eleven output byte sizes and SHA256 values, including the original atomic manifest.

This exposes every SQL statement and control plainly. No compression, base64, binary codec, generic chunk dictionary, private map, financial snapshot or authorization transcript is included. Consumer fixtures are reused only through their exact public output bytes; there is no hidden data source.

SOURCE_MANIFEST.json is this smaller transport allowlist. OUTPUT_CONTRACT.json describes reconstructed atomic outputs, while frozen_files/PUBLIC_MANIFEST.json is copied into that output unchanged. The later workflow must run the original atomic runner in a fresh, separate disposable PG17 instance, never the consumer suite's instance. CI must validate the current run's exit code, manifest and cleanup receipt and discard its container on failure. File existence alone is not success. This package grants no upload, CI, migration or production permission.

## Corrected consumer dependency

This revision follows the four explicitly parenthesized JSONB containment right operands in the corrected consumer bodies. The atomic controls, suffix, runner, strict empty-instance guard and all 175 + 10 + 4 expected tests remain byte-identical. Only the consumer-derived setup prefix and dependent hashes/references change. The previous consumer run failed compilation before its 339 checks; neither this reconstruction nor the earlier static review supplies a PostgreSQL pass for the corrected bodies.
