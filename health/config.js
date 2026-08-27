// LTS Health frontend backend selection.
// Keep this file free of private health data and secret/service-role credentials.
// Publishable Supabase keys are intentionally client-safe.
const LTS_HEALTH_BACKENDS = Object.freeze({
  bridge: Object.freeze({
    label: 'temporary-shared-bridge-rollback-only',
    projectRef: 'tadhkamnwtsbdozwkyut',
    url: 'https://tadhkamnwtsbdozwkyut.supabase.co',
    publishableKey: 'sb_publishable__p3SAbpThUIKtDr7A4llPw_AVkOaNkm'
  }),
  dedicated: Object.freeze({
    label: 'dedicated-health-production',
    projectRef: 'plztdqyuqcjohiimudnr',
    url: 'https://plztdqyuqcjohiimudnr.supabase.co',
    publishableKey: 'sb_publishable_7SdlV1H52wVVbPEsN7i7hg_jbluJ8aI'
  })
});

// Production cutover completed after the 22-table + private Inbox migration gate passed.
// The bridge remains listed only as a short-lived rollback reference; the app does not use it.
const LTS_HEALTH_ACTIVE_BACKEND = 'dedicated';

window.LTS_HEALTH_CONFIG = Object.freeze({
  mode: LTS_HEALTH_ACTIVE_BACKEND,
  backend: LTS_HEALTH_BACKENDS[LTS_HEALTH_ACTIVE_BACKEND],
  backends: LTS_HEALTH_BACKENDS,
  storageBucket: 'health-inbox',
  inspectFunction: 'health-inspect-upload'
});
