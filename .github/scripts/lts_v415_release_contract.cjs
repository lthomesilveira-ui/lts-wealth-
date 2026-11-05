'use strict';
const fs = require('node:fs'), crypto = require('node:crypto'), assert = require('node:assert/strict'), vm = require('node:vm');
const base = 'releases/v412', root = 'releases/v415', runtime = 'lts-v415-product-refresh.js';
const read = (dir, name) => fs.readFileSync(dir + '/' + name, 'utf8');
const hash = path => crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex');
const manifest = JSON.parse(read(root, 'manifest.json')), provenance = JSON.parse(read(root, 'provenance.json'));
const changed = ['app.html', 'index.html', 'lts-v227-read-transport.js', 'lts-v384-startup-1.js', 'lts-v412-projection-policy.js', 'manifest.json', 'provenance.json'];
assert.equal(manifest.release, 'v415'); assert.equal(manifest.version, 'v415'); assert.equal(manifest.base_release, 'v412'); assert.equal(manifest.entry, 'app.html');
assert.deepEqual([...Object.keys(manifest.files), 'manifest.json'].sort(), fs.readdirSync(root).sort());
assert.deepEqual(Object.keys(provenance.protected_base_files).sort(), fs.readdirSync(base).sort());
for (const [name, expected] of Object.entries(manifest.files)) assert.equal(hash(root + '/' + name), expected, 'V415 ' + name);
for (const [name, expected] of Object.entries(provenance.protected_base_files)) assert.equal(hash(base + '/' + name), expected, 'Immutable V412 ' + name);
assert.equal(manifest.protected_manifest.path, base + '/manifest.json'); assert.equal(hash(manifest.protected_manifest.path), manifest.protected_manifest.sha256);
assert.deepEqual(fs.readdirSync(root).sort(), [...fs.readdirSync(base), runtime].sort(), 'One new runtime');
for (const name of fs.readdirSync(base)) if (!changed.includes(name)) assert.equal(hash(root + '/' + name), hash(base + '/' + name), 'Preserved ' + name);
assert.equal(hash(root + '/' + runtime), hash(runtime));
assert.equal(read(root, 'app.html'), read(base, 'app.html').replaceAll('V412', 'V415').replace('v412-projection-policy-20261104', 'v415-durable-refresh-20261105'));
// The authentication client changes only by accepting AbortSignal on RPC fetches.
const originalIndex = read(base, 'index.html'), candidateIndex = read(root, 'index.html');
let restored = candidateIndex.replace('<script src="lts-v415-product-refresh.js"></script>', '')
  .replace('async rpc(fn,args={},options={})', 'async rpc(fn,args={})')
  .replace('body:JSON.stringify(args||{}),signal:options.signal', 'body:JSON.stringify(args||{})');
const integrationStart = restored.indexOf('const PRODUCT_REFRESH_RPC_V415='), integrationEnd = restored.indexOf('function bootPanel(){', integrationStart);
assert(integrationStart > 0 && integrationEnd > integrationStart); restored = restored.slice(0, integrationStart) + restored.slice(integrationEnd);
assert.equal(restored.split(' window.__LTS_V415_REFRESH?.stop();\n').length - 1, 2);
restored = restored.replaceAll(' window.__LTS_V415_REFRESH?.stop();\n', '');
const newStart = restored.indexOf('   const refreshState=PRODUCT_REFRESH_V415.acceptProduct(j);');
const newEnd = restored.indexOf("   run.finish({status:'ready'});", newStart);
const oldStart = originalIndex.indexOf("   if(!j?.mvp){BOOT.reloadRequired=true;throw Error('Product unavailable');}");
const oldEnd = originalIndex.indexOf("   run.finish({status:'ready'});", oldStart);
assert(newStart > 0 && newEnd > newStart && oldStart > 0 && oldEnd > oldStart);
restored = restored.slice(0, newStart) + originalIndex.slice(oldStart, oldEnd) + restored.slice(newEnd);
assert.equal(restored, originalIndex, 'All financial renderers, native login/session/storage and other routes remain exact');
for (const [index, match] of [...candidateIndex.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].entries()) new vm.Script(match[1], { filename: 'v415-index-inline-' + index });
for (const name of ['lts-v227-read-transport.js', 'lts-v384-startup-1.js']) {
  const candidate = read(root, name), original = read(base, name);
  let back = candidate.replace('product_(?!refresh_request_v415$)', 'product_')
    .replace('product_(?!refresh_(?:status|request)_v415$)', 'product_')
    .replace("name!=='lts_browser_product_refresh_status_v415'&&", '')
    .replace("name==='lts_browser_product_refresh_status_v415'?10000:", '');
  assert.equal(back, original, 'Only refresh transport routing differs: ' + name);
  new vm.Script(candidate, { filename: name });
}
for (const name of [runtime, 'lts-v412-projection-policy.js']) new vm.Script(read(root, name), { filename: name });
const mobile = process.env.LTS_MOBILE_RELEASE || 'v415';
assert.deepEqual(JSON.parse(read('mobile', 'current.json')), { release: mobile, entry: '../releases/' + mobile + '/app.html' });
for (const field of ['financial_event_writers_added', 'received_financial_payloads_modified', 'client_recalculates_financial_totals', 'auth_storage_changed', 'private_http_validated', 'physical_mobile_validated']) assert.equal(provenance[field], false, field);
for (const field of ['complete_product_only', 'async_product_refresh', 'no_healthy_banner', 'source_dated_positions_unchanged']) assert.equal(provenance[field], true, field);
assert.equal(provenance.status_polling_cap, 20); assert.equal(provenance.max_status_interval_ms, 30000);
console.log(JSON.stringify({ pass: true, release: 'v415', assets: fs.readdirSync(root).length, immutable_v412: true, native_auth_preserved: true, financial_renderers_preserved: true }));
