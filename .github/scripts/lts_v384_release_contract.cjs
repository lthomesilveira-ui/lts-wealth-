'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),vm=require('node:vm'),{build,hash}=require('./lts_v384_bundle.cjs');
const base='releases/v383',root='releases/v384',m=JSON.parse(fs.readFileSync(root+'/manifest.json')),p=JSON.parse(fs.readFileSync(root+'/provenance.json'));
assert.equal(m.release,'v384');assert.equal(m.version,'v384');assert.equal(m.base_release,'v383');
for(const[n,h]of Object.entries(m.files))assert.equal(hash(fs.readFileSync(root+'/'+n)),h,n);
for(const[n,h]of Object.entries(m.protected))assert.equal(hash(fs.readFileSync(n)),h,n);
for(const[n,h]of Object.entries(p.protected_base_files))assert.equal(hash(fs.readFileSync(base+'/'+n)),h,n);
const expected=build(base);assert.equal(fs.readFileSync(root+'/app.html','utf8'),expected.html);
assert.equal(expected.bundles.length,2);assert.equal(expected.bundles.flatMap(b=>b.sources).length,59);
for(const b of expected.bundles){assert.equal(fs.readFileSync(root+'/'+b.file,'utf8'),b.content);new vm.Script(b.content,{filename:b.file});}
const changed=fs.readdirSync(root).filter(n=>!fs.existsSync(base+'/'+n)||hash(fs.readFileSync(root+'/'+n))!==hash(fs.readFileSync(base+'/'+n))).sort();
assert.deepEqual(changed,['app.html','lts-v227-read-transport.js','lts-v384-read-priority.js','lts-v384-startup-1.js','lts-v384-startup-2.js','manifest.json','provenance.json'].sort());
for(const n of fs.readdirSync(base).filter(n=>!['app.html','manifest.json','provenance.json','lts-v227-read-transport.js'].includes(n)))assert.equal(hash(fs.readFileSync(root+'/'+n)),hash(fs.readFileSync(base+'/'+n)),n+' exact source preserved');
const oldTransport=fs.readFileSync(base+'/lts-v227-read-transport.js','utf8'),newTransport=fs.readFileSync(root+'/lts-v227-read-transport.js','utf8');
// Only these three lines may differ: priority selection, dynamic queue ordering
// and retention of the queued request name. Auth, cache, holds, deadlines,
// buffering, request bodies and the one-reader admission remain exact.
const altered=line=>line.includes('const priority=name=>')||line.includes('waiting.sort(')||line.includes('const item={resolve,');
assert.equal(oldTransport.split('\n').filter(l=>!altered(l)).join('\n'),newTransport.split('\n').filter(l=>!altered(l)).join('\n'));
assert.equal(oldTransport.split('\n').filter(altered).length,3);assert.equal(newTransport.split('\n').filter(altered).length,3);
assert(newTransport.includes('priority(a.name)-priority(b.name)||a.order-b.order'));
assert.deepEqual(Object.keys(m.files).concat('manifest.json').sort(),fs.readdirSync(root).sort());
assert.equal(p.backend_changed,false);assert.equal(p.financial_reader_logic_changed,false);assert.equal(p.date_behavior_changed,false);assert.equal(p.layout_changed,false);assert.equal(p.read_admission_priority_changed,true);
console.log(JSON.stringify({pass:true,release:'v384',startup_scripts_before:59,startup_scripts_after:2,original_startup_sources:59,original_sources_exact:58,transport_priority_lines_changed:3,financial_queries_and_date_code_exact:true,published_v383_exact:true,protected_root_exact:true}));
