# LTS Health runtime config contract

Goal: make backend cutover a configuration change instead of an application rewrite.

## Contract
The dedicated Health repository should load a small runtime config before app.js:

```js
window.LTS_HEALTH_CONFIG = Object.freeze({
  supabaseUrl: 'https://<health-project-ref>.supabase.co',
  publishableKey: '<publishable-key>',
  storageBucket: 'health-inbox',
  inspectFunction: 'health-inspect-upload',
  backendMode: 'dedicated-health'
});
```

Only publishable client configuration belongs in the public repository. Never commit service-role keys, database passwords, health exports, raw uploads, row dumps, access tokens, or user identifiers.

## Bridge mode
Until cutover, the current `/health/` app continues using the shared LTS Wealth Supabase project. This is intentionally temporary and is the rollback target.

## Cutover rule
Do not switch the public app until schema, RLS, storage, Edge Function, row-count, uniqueness, date-range and smoke-test gates pass on the dedicated Health project.

## Rollback rule
Rollback is config-only: restore the previous bridge URL/publishable key and redeploy. The source database remains untouched through the observation window.
