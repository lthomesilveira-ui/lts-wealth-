'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const predecessor = 'releases/v433/';
const release = 'releases/v436/';
const prior = JSON.parse(fs.readFileSync(predecessor + 'manifest.json'));
const next = JSON.parse(fs.readFileSync(release + 'manifest.json'));

assert.equal(next.release, 'v436');
assert.equal(next.base_release, 'v433');
assert.equal(next.protected_manifest.sha256, sha(fs.readFileSync(predecessor + 'manifest.json')));
assert.deepEqual(Object.keys(next.files).sort(), Object.keys(prior.files).sort());
assert.deepEqual([...Object.keys(next.files), 'manifest.json'].sort(), fs.readdirSync(release).sort());
for (const [name, expected] of Object.entries(prior.files)) {
  assert.equal(sha(fs.readFileSync(predecessor + name)), expected, 'predecessor ' + name);
  assert.equal(sha(fs.readFileSync(release + name)), next.files[name], 'candidate ' + name);
}
const changed = Object.keys(next.files).filter(name => next.files[name] !== prior.files[name]).sort();
assert.deepEqual(changed, ['app.html', 'lts-v183-v168-feedback-safe.js', 'lts-v312-card-review.js',
  'lts-v384-startup-1.js', 'lts-v384-startup-2.js', 'provenance.json']);
const entry=process.env.LTS_MOBILE_RELEASE||'v436';assert.match(entry,/^v[0-9]+$/);assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')), {release:entry,entry:'../releases/'+entry+'/app.html'});
assert(fs.readFileSync(release + 'app.html', 'utf8').includes('V436'));
const provenance = JSON.parse(fs.readFileSync(release + 'provenance.json'));
for (const flag of ['financial_values_changed', 'mutation_paths_changed', 'query_arguments_changed',
  'cache_or_auth_policy_changed']) assert.equal(provenance[flag], false);
console.log(JSON.stringify({pass: true, release: 'v436', assets: Object.keys(next.files).length, changed}));
