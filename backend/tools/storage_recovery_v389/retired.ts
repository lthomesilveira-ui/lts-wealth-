// The test endpoint is closed after verification. It has no Storage access.
Deno.serve(() => new Response(JSON.stringify({error:'recovery_probe_closed'}), {
  status:410,headers:{'Content-Type':'application/json','Cache-Control':'no-store'},
}));
