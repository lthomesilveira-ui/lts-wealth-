# LTS Health dedicated repository split manifest

This manifest is architecture-only. Never copy private health rows, exported source files, storage objects, passwords, tokens, service-role keys, database dumps, browser local storage, or authenticated session material into Git.

## Frontend allowlist for dedicated repository

Copy only the production Health surface and non-sensitive support files after the dedicated repository exists:

- `index.html`
- `app.js`
- `styles.css`
- `config.js`
- `inbox.html` and `audit.html` only while they remain redirect compatibility shims
- `MIGRATION.md`
- this manifest
- non-sensitive Supabase deployment documentation under `supabase/`

Legacy/prototype files must be reviewed before copying. They are not automatically part of the dedicated repository.

## Explicit denylist

Do not commit:

- any health export, CSV, JSON, XML, ZIP, PDF, image, or database dump containing user data
- any `health-inbox` object or signed URL
- any row-level migration snapshot containing private values
- service-role/secret keys or refresh/access tokens
- browser auth state, cookies, local/session storage
- environment files containing secrets
- generated logs that include filenames, biomarker values, medication data, or other private content

Publishable Supabase client keys may be present in browser configuration because they are not secrets; authorization must still be enforced by RLS.

## Repository cutover sequence

1. Create/connect the dedicated `lts-health` repository.
2. Copy only the allowlisted files after a manual denylist review.
3. Keep `LTS_HEALTH_ACTIVE_BACKEND = 'bridge'` in the first dedicated-repo deployment.
4. Smoke-test the dedicated repository against the existing bridge without changing user-visible data behavior.
5. Complete and validate Supabase data/storage migration.
6. Change only `LTS_HEALTH_ACTIVE_BACKEND` to `dedicated`.
7. Run authenticated read/upload/inspect smoke tests.
8. Publish the dedicated URL and keep the old `/health/` route available as rollback/redirect until observation is complete.

## Rollback

Rollback is configuration/deployment based. Switch the active backend profile back to `bridge` and/or restore the previous deployment. Do not delete source data from the shared project during the rollback window.
