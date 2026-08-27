// LTS Health frontend backend selection.
// Keep this file free of private health data and secret/service-role credentials.
// Publishable Supabase keys are intentionally client-safe; the active bridge remains
// the shared project until the dedicated Health migration is fully validated.
window.LTS_HEALTH_CONFIG = Object.freeze({
  mode: 'bridge',
  backend: Object.freeze({
    label: 'temporary-shared-bridge',
    projectRef: 'tadhkamnwtsbdozwkyut',
    url: 'https://tadhkamnwtsbdozwkyut.supabase.co',
    publishableKey: 'sb_publishable__p3SAbpThUIKtDr7A4llPw_AVkOaNkm'
  }),
  storageBucket: 'health-inbox',
  inspectFunction: 'health-inspect-upload'
});
