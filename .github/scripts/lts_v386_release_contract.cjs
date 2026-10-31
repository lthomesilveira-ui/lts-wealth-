'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const base='releases/v385',root='releases/v386',read=(p,n)=>fs.readFileSync(p+'/'+n,'utf8'),hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const m=JSON.parse(read(root,'manifest.json')),p=JSON.parse(read(root,'provenance.json'));
assert.equal(m.release,'v386');assert.equal(m.base_release,'v385');
for(const[n,h]of Object.entries(m.files))assert.equal(hash(root+'/'+n),h,n);
for(const[n,h]of Object.entries(m.protected))assert.equal(hash(n),h,n);
for(const[n,h]of Object.entries(p.protected_base_files))assert.equal(hash(base+'/'+n),h,n);
assert.deepEqual(fs.readdirSync(root).sort(),fs.readdirSync(base).sort());
const changed=fs.readdirSync(root).filter(n=>hash(root+'/'+n)!==hash(base+'/'+n)).sort();
assert.deepEqual(changed,[...p.runtime_changes,'manifest.json','provenance.json'].sort());
assert.equal(read(root,'app.html'),read(base,'app.html').replaceAll('V385','V386').replace('v385-rank-layout-20261031','v386-patrimony-evidence-20261031'));
const ui='lts-v365-homologation.js',legacy='lts-v183-v168-feedback-safe.js';
for(const source of[ui,legacy]){
 const bundle=['lts-v384-startup-1.js','lts-v384-startup-2.js'].find(b=>read(base,b).includes(read(base,source)));
 assert(bundle);assert.equal(read(root,bundle),read(base,bundle).replace(read(base,source),read(root,source)));
 assert(!/Schiavalli/i.test(read(root,source)),'excluded asset has no UI row');
}
const a=read(base,ui),b=read(root,ui),start=s=>s.slice(0,s.indexOf('  function '+(s.includes('  function fgtsPosition')?'fgtsPosition':'overview')+'(')),end=s=>s.slice(s.indexOf('  function rsu('));
assert.equal(start(a),start(b));assert.equal(end(a),end(b),'all non-overview UI and existing actions exact');
const removed='<div class="v168-stat"><span>Schiavalli<small>posição documental ainda não localizada</small></span><b>—</b></div>';
assert.equal(read(root,legacy),read(base,legacy).replace(removed,''),'only obsolete legacy row removed');
for(const n of fs.readdirSync(root).filter(n=>n.endsWith('.js')&&![ui,legacy,'lts-v384-startup-1.js','lts-v384-startup-2.js'].includes(n)))assert.equal(hash(root+'/'+n),hash(base+'/'+n),'exact financial reader/transport '+n);
assert(read(root,'lts-v225-consolidated.css').startsWith(read(base,'lts-v225-consolidated.css')));
assert.equal((read(root,'app.html').match(/<script src=/g)||[]).length,2);
assert.deepEqual(JSON.parse(read('mobile','current.json')),{release:'v386',entry:'../releases/v386/app.html'});
assert.deepEqual(Object.keys(m.files).concat('manifest.json').sort(),fs.readdirSync(root).sort());
assert.equal(p.financial_source_data_changed,false);assert.equal(p.financial_reader_logic_changed,false);assert.equal(p.date_behavior_changed,false);
console.log(JSON.stringify({pass:true,release:'v386',financial_and_date_code_exact:true,frozen_v385_exact:true,phantom_ui_removed:true,unknown_fgts_not_zero:true}));
