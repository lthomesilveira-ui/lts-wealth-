// Inert defaults. Deployment fills only a random token HASH, fixed canary path
// and short expiry. Neither the token nor any platform secret is committed.
export const CONFIG = {
  nonceHash: 'UNCONFIGURED', expiresAt: 0,
  bucket: 'lts-documents', path: 'UNCONFIGURED', probeId: 'UNCONFIGURED',
};
