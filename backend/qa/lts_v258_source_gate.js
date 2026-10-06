'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const sql=fs.readFileSync('backend/patches/single_evaluation_v258.sql','utf8');
assert.equal((sql.match(/CREATE OR REPLACE FUNCTION/g)||[]).length,2);
assert.match(sql,/V258_SOURCE_LEASE_CHANGED/);
assert.match(sql,/431c65167423e6eb1cafb7a53677b4e6/);
assert.match(sql,/69425f213c14d19e61a43a1463db42dc/);
assert.match(sql,/target AS MATERIALIZED/);
assert.match(sql,/patched AS MATERIALIZED/);
assert.match(sql,/SELECT \(p\.corrected_row\)\.\* FROM patched p/);
assert.equal((sql.match(/LANGUAGE sql/g)||[]).length,2);
assert.equal((sql.match(/STABLE/g)||[]).length,2);
assert(!/SECURITY DEFINER|GRANT|REVOKE|INSERT INTO|UPDATE public\.|DELETE FROM|ALTER TABLE|CREATE TABLE/i.test(sql));
const manifest=JSON.parse(fs.readFileSync('releases/v258/manifest.json','utf8'));
assert.equal(manifest.release,'v258');assert.equal(Object.keys(manifest.files).length,60);
for(const name of [...Object.keys(JSON.parse(fs.readFileSync('releases/v257/manifest.json')).files),'manifest.json'])assert(manifest.protected['releases/v257/'+name]);
for(const name of Object.keys(manifest.files))if(name!=='app.html')assert.equal(fs.readFileSync('releases/v258/'+name,'utf8'),fs.readFileSync('releases/v257/'+name,'utf8'),name);
assert.equal(fs.readFileSync('releases/v258/app.html','utf8'),fs.readFileSync('releases/v257/app.html','utf8').replaceAll('V257','V258').replace('v257-consolidated-20261006','v258-single-evaluation-20261006'));
require('../../.github/scripts/lts_v225_static_gate.js');
console.log('PASS V258 exact two private read functions, unchanged ACL source, same approved interface and protected V257 assets');


const audit=fs.readFileSync('backend/patches/readonly_history_audit_v258.sql','utf8');
assert.match(audit,/V258_READONLY_AUDIT_SOURCE_LEASE_CHANGED/);
assert.match(audit,/exception when read_only_sql_transaction then/);
assert.match(audit,/raise log 'LTS_FLOW_READ_AUDIT_READONLY/);
assert.match(audit,/insert into public\.lts_access_audit/);
assert(!/WHEN OTHERS|GRANT|REVOKE|ALTER TABLE|transaction_read_only.*off/i.test(audit));
