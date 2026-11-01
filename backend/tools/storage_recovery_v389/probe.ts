// Ephemeral recovery test. It cannot read an existing document or accept a path.
import { CONFIG } from './probe_config.ts';
const encode = new TextEncoder();
const sha = async (data: Uint8Array) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', data))).map(x => x.toString(16).padStart(2,'0')).join('');
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: {'Content-Type':'application/json','Cache-Control':'no-store'} });
function environmentKey(plural: string, legacy: string) {
  const value = Deno.env.get(plural);
  if (value) { try { const parsed = JSON.parse(value); if (typeof parsed.default === 'string') return parsed.default; } catch { /* use the platform's existing legacy key */ } }
  return Deno.env.get(legacy) || '';
}
function keyHeaders(key: string): Record<string, string> {
  return key.startsWith('eyJ') ? {'apikey':key,'Authorization':'Bearer '+key} : {'apikey':key};
}
Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({error:'method_not_allowed'},405);
  if (Date.now() >= CONFIG.expiresAt) return json({error:'probe_expired'},410);
  const token = req.headers.get('x-lts-recovery-key') || '';
  if (token.length !== 64 || await sha(encode.encode(token)) !== CONFIG.nonceHash) return json({error:'unauthorized'},401);
  if (!/^recovery-probe\/[a-f0-9-]{36}\.bin$/.test(CONFIG.path) || CONFIG.bucket !== 'lts-documents') return json({error:'invalid_fixed_scope'},500);
  const base = Deno.env.get('SUPABASE_URL') || '';
  const admin = environmentKey('SUPABASE_SECRET_KEYS','SUPABASE_SERVICE_ROLE_KEY');
  const anonymous = environmentKey('SUPABASE_PUBLISHABLE_KEYS','SUPABASE_ANON_KEY');
  if (!base || !admin || !anonymous) return json({error:'server_configuration_unavailable'},503);
  const bytes = encode.encode('LTS Wealth isolated Storage verification\n'+CONFIG.probeId+'\nçãé\n');
  const expected = await sha(bytes), path = CONFIG.path.split('/').map(encodeURIComponent).join('/');
  const objectUrl = base+'/storage/v1/object/'+CONFIG.bucket+'/'+path;
  const downloadUrl = base+'/storage/v1/object/authenticated/'+CONFIG.bucket+'/'+path;
  const result: Record<string, unknown> = {probe_id:CONFIG.probeId,bucket:CONFIG.bucket,path:CONFIG.path,expected_sha256:expected,bytes:bytes.length,financial_sources_modified:0,existing_documents_read:0};
  let created = false;
  try {
    const upload = await fetch(objectUrl,{method:'POST',headers:{...keyHeaders(admin),'Content-Type':'application/octet-stream','x-upsert':'false'},body:bytes});
    result.upload_status = upload.status;
    if (!upload.ok) return json({...result,pass:false,phase:'upload'},502);
    created = true;
    const read = await fetch(downloadUrl,{headers:keyHeaders(admin)});
    const downloaded = new Uint8Array(await read.arrayBuffer());
    result.download_status = read.status;result.download_sha256 = await sha(downloaded);result.binary_equal = read.ok && expected === result.download_sha256;
    const denied = await fetch(downloadUrl,{headers:keyHeaders(anonymous)});
    result.anonymous_status = denied.status;result.anonymous_denied = !denied.ok;
    await denied.arrayBuffer();
    const publicRead = await fetch(base+'/storage/v1/object/public/'+CONFIG.bucket+'/'+path);
    result.public_status = publicRead.status;result.public_denied = !publicRead.ok;
    await publicRead.arrayBuffer();
    result.pass = result.binary_equal === true && result.anonymous_denied === true && result.public_denied === true;
  } catch { result.pass = false;result.phase = 'transport'; }
  finally {
    // Only the unique canary successfully created in this request is removed.
    if (created) {
      const removed = await fetch(base+'/storage/v1/object/'+CONFIG.bucket,{method:'DELETE',headers:{...keyHeaders(admin),'Content-Type':'application/json'},body:JSON.stringify({prefixes:[CONFIG.path]})});
      result.cleanup_status = removed.status;result.cleanup_ok = removed.ok;
      await removed.arrayBuffer();
      if (!removed.ok) result.pass = false;
    }
  }
  return json(result,result.pass === true ? 200 : 502);
});
