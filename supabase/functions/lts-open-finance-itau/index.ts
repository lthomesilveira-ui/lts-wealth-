import { makeHandler } from './handler.mjs';

// Names/booleans only. Never log credentials, tokens, request bodies or financial payloads.
console.info(JSON.stringify({ event: 'open_finance_configuration',
  client_id_configured: Boolean(Deno.env.get('PLUGGY_CLIENT_ID')),
  client_secret_configured: Boolean(Deno.env.get('PLUGGY_CLIENT_SECRET')),
  item_id_configured: Boolean(Deno.env.get('PLUGGY_ITAU_ITEM_ID')) }));
Deno.serve(makeHandler((name: string) => Deno.env.get(name)));
