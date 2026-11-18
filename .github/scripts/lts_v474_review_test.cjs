'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const {read} = require('../../releases/v474/lts-review-read.js');

const digest = path => crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex');
const release = 'releases/v474/';
const manifest = JSON.parse(fs.readFileSync(release + 'manifest.json'));
assert.equal(manifest.release, 'v474');
assert.equal(manifest.protected_manifest.sha256, digest('releases/v471/manifest.json'));
for (const [name,hash] of Object.entries(manifest.files)) assert.equal(digest(release + name), hash, name);
const income = 'lts_browser_income_review_queue_v296';
const args = {p_offset: 0};
const success = {data: {ok:true}, error:null};
async function simulate(outcomes, applicable = () => true) {
  let calls = 0;
  const result = await read(async (name, actual) => {
    assert.equal(name, income);
    assert.equal(actual, args);
    const response = outcomes[calls++];
    if (response instanceof Error) throw response;
    return response;
  }, income, args, applicable);
  return {calls, result};
}
(async () => {
  const aborted = {data:null, error:{message:'Aborted'}};
  const denied = {data:null, error:{status:403, message:'Access denied'}};
  const invalid = {data:{ok:false}, error:null};
  const expired = {data:null, error:{message:'Sessão expirada'}};
  for (const final of [success, denied, invalid, expired]) {
    assert.deepEqual(await simulate([final]), {calls:1, result:final});
  }
  assert.deepEqual(await simulate([aborted,success]), {calls:2,result:success});
  assert.deepEqual(await simulate([aborted,aborted]), {calls:2,result:aborted});
  assert.deepEqual(await simulate([new TypeError('Failed to fetch'),success]), {calls:2,result:success});
  let checks = 0;
  assert.deepEqual(await simulate([aborted], () => ++checks === 1), {calls:1,result:aborted});
  await assert.rejects(() => read(() => assert.fail('writer called'),'lts_browser_card_review_save_v312',{},()=>true), /Unknown/);
  console.log('Verified release integrity, recovery of a single failed read, terminal errors and obsolete requests.');
})().catch(error => { console.error(error); process.exitCode=1; });
