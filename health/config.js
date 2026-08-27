// LTS Health frontend backend selection.
// Keep this file free of private health data and secret/service-role credentials.
// Publishable Supabase keys are intentionally client-safe.
// Cutover is configuration-only and remains on the shared bridge until migration gates pass.
const LTS_HEALTH_BACKENDS = Object.freeze({
  bridge: Object.freeze({
    label: 'temporary-shared-bridge',
    projectRef: 'tadhkamnwtsbdozwkyut',
    url: 'https://tadhkamnwtsbdozwkyut.supabase.co',
    publishableKey: 'sb_publishable__p3SAbpThUIKtDr7A4llPw_AVkOaNkm'
  }),
  dedicated: Object.freeze({
    label: 'dedicated-health-target',
    projectRef: 'plztdqyuqcjohiimudnr',
    url: 'https://plztdqyuqcjohiimudnr.supabase.co',
    publishableKey: 'sb_publishable_7SdlV1H52wVVbPEsN7i7hg_jbluJ8aI'
  })
});

// Rollback/cutover switch: change only this value after every migration gate passes.
const LTS_HEALTH_ACTIVE_BACKEND = 'bridge';

window.LTS_HEALTH_CONFIG = Object.freeze({
  mode: LTS_HEALTH_ACTIVE_BACKEND,
  backend: LTS_HEALTH_BACKENDS[LTS_HEALTH_ACTIVE_BACKEND],
  backends: LTS_HEALTH_BACKENDS,
  storageBucket: 'health-inbox',
  inspectFunction: 'health-inspect-upload'
});
