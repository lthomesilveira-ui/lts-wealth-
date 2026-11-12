'use strict';const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),vm=require('node:vm');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),base='releases/v441/',root='releases/v442/';
const prior=JSON.parse(fs.readFileSync(base+'manifest.json')),m=JSON.parse(fs.readFileSync(root+'manifest.json'));
assert.equal(m.release,'v442');assert.equal(m.base_release,'v441');assert.equal(m.protected_manifest.sha256,hash(base+'manifest.json'));
assert.deepEqual([...Object.keys(m.files),'manifest.json'].sort(),fs.readdirSync(root).sort());
const changed=['app.html','lts-v441-budget-ui.js','lts-v441-budget-model.js','provenance.json'];
for(const[n,h]of Object.entries(prior.files)){assert.equal(hash(base+n),h);if(!changed.includes(n))assert.equal(hash(root+n),h,'Preserved '+n);}
for(const[n,h]of Object.entries(m.files)){assert.equal(hash(root+n),h);if(n.endsWith('.js'))new vm.Script(fs.readFileSync(root+n,'utf8'),{filename:n});}
assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v442',entry:'../releases/v442/app.html'});
const s=fs.readFileSync(root+'lts-v441-budget-ui.js','utf8');assert(s.includes('input.oninput=input.onchange='));assert(s.includes('&&value!==s.month'));assert(s.includes("V==='Despesas'"));assert(s.includes("tab==='monthly'"));assert(!s.includes("V==='Dashboard'"));
assert.equal(m.files['lts-v412-projection-policy.js'],prior.files['lts-v412-projection-policy.js']);
console.log(JSON.stringify({pass:true,release:'v442',assets:Object.keys(m.files).length,v441_immutable:true,financial_actuals_and_provision_code_preserved:true,strategic_proposals_added:true,budget_location:'Despesas/Balanço mensal'}));
