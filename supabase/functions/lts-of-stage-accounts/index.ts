// Retired temporary account writer. The canonical authenticated Itaú adapter
// performs checked, idempotent writes to staging and never promotes finance.
// Deploy with verify_jwt=true. This legacy route performs no provider calls,
// database writes, or secret reads.
Deno.serve(() => new Response(JSON.stringify({
  error: "LEGACY_STAGING_ENDPOINT_RETIRED",
  replacement: "lts-open-finance-itau",
  promotion_enabled: false
}), {
  status: 410,
  headers: {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff"
  }
}));
