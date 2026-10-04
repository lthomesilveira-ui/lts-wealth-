'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const digest=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
for(const release of ['v242','v244','v245']){
 const root='releases/'+release+'/',m=JSON.parse(fs.readFileSync(root+'manifest.json'));
 for(const [file,hash] of Object.entries(m.files))assert.equal(digest(root+file),hash,release+' '+file);
 for(const [file,hash] of Object.entries(m.protected))assert.equal(digest(file),hash,'protected '+file);
}
const memo=fs.readFileSync('backend/patches/flow_background_materialization_v245.sql','utf8');
assert.match(memo,/source_fingerprint='v245\.1:'\|\|cache_epoch/);
assert.match(memo,/IF cache_epoch<>/);
assert.match(memo,/REVOKE ALL ON FUNCTION public\.lts_warm_flow_cache_v245\(\) FROM PUBLIC,anon,authenticated/);
assert.match(memo,/GRANT EXECUTE ON FUNCTION public\.lts_warm_flow_cache_v245\(\) TO service_role/);
assert.match(memo,/set_config\('request.jwt.claims',coalesce\(previous_claims,''\),true\)/);
const identity=fs.readFileSync('backend/patches/cofrinho_documented_identity_v245.sql','utf8');
assert.match(identity,/bank_raw_hash.*s\.raw_hash/);assert.match(identity,/m\.bank_event_id=f\.id AND m\.status='active'/);
const movements=fs.readFileSync('backend/patches/cofrinho_movement_identity_v245.sql','utf8');
assert.match(movements,/m\.event_date>anchor\.dt AND m\.event_date<=p_date/);
assert.match(movements,/m\.user_id=p_user_id/);
assert(!/INSERT INTO public\.financial_events|UPDATE public\.financial_events|GRANT.*authenticated/i.test(movements));
console.log('PASS V245 source fingerprints, private warming, exact bank identity and frozen releases');
