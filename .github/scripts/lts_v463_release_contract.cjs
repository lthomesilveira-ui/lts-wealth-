'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),root='releases/v463/',prior='releases/v458/';
const m=JSON.parse(fs.readFileSync(root+'manifest.json')),b=JSON.parse(fs.readFileSync(prior+'manifest.json'));
assert.equal(m.release,'v463');assert.equal(m.base_release,'v458');assert.equal(m.protected_manifest.sha256,hash(prior+'manifest.json'));
assert.deepEqual([...Object.keys(m.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
for(const[n,h]of Object.entries(b.files))assert.equal(hash(prior+n),h,'Preserved immutable predecessor '+n);
for(const[n,h]of Object.entries(m.files)){assert.equal(hash(root+n),h,'Candidate manifest '+n);if(n.endsWith('.js'))new vm.Script(fs.readFileSync(root+n,'utf8'),{filename:n});}
const provenance=JSON.parse(fs.readFileSync(root+'provenance.json'));assert.equal(provenance.financial_source_writes,false);assert.equal(provenance.authentication_changed,false);assert.equal(provenance.timeouts_changed,false);
for(const n of['lts-v225-open-finance.js','lts-v415-product-refresh.js','lts-v227-read-transport.js']){let expected=fs.readFileSync(prior+n,'utf8');if(n==='lts-v225-open-finance.js')expected=expected.replaceAll('Reconciliadas: ','Gastos confirmados: ').replaceAll(' · Com provisórias: ',' · Incluindo valores a conferir: ');assert.equal(fs.readFileSync(root+n,'utf8'),expected,'Only customer wording may change in bank intake; transport guards preserved');}
assert(fs.readFileSync(root+'lts-v384-startup-1.js','utf8').includes(fs.readFileSync(root+'lts-expense-presentation-model.js','utf8')),'Startup bundle includes the canonical channel model');
console.log(JSON.stringify({pass:true,release:'v463',assets:Object.keys(m.files).length,protected:'v458',financial_writers_and_transport_preserved:true}));
