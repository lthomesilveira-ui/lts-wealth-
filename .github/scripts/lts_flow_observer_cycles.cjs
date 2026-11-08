'use strict';
const fs=require('fs');const path=require('path');const {chromium}=require('playwright');
const base=path.resolve('releases/v277');
function lines(file,a,b){return fs.readFileSync(path.join(base,file),'utf8').split('\n').slice(a-1,b).join('\n')}
const code={
 v168: lines('lts-v183-v168-feedback-safe.js',346,347)+'\nlet mutating=false;\n'+lines('lts-v183-v168-feedback-safe.js',352,352),
 v169: lines('lts-v169-v168-feedback-closure.js',130,130)+'\n'+lines('lts-v169-v168-feedback-closure.js',135,135),
 v170: lines('lts-v170-v169-review.js',125,127)+'\n'+lines('lts-v170-v169-review.js',129,129)+'\n'+lines('lts-v170-v169-review.js',135,135),
};
(async()=>{
 fs.mkdirSync('qa',{recursive:true});const browser=await chromium.launch({headless:true,args:['--no-sandbox']});const results=[];
 const cases=[
 {name:'no_observers',layers:[]},
 {name:'v170_bank_no_brand',layers:['v170'],brand:false},
 {name:'v168_v169_bank',layers:['v168','v169']},
 {name:'v168_v169_v170_bank',layers:['v168','v169','v170']},
 {name:'v168_v169_v170_bank_v169_owner',layers:['v168','v169','v170'],top:'v169-v168-feedback-closure'},
 {name:'v170_idempotent_note',layers:['v170'],brand:false,idempotent:true}
 ];
 for(const c of cases){
  const page=await browser.newPage();let errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.setContent('<div id="scope"></div><iframe id="frame"></iframe>');
  await page.evaluate(top=>window.__LTS_TOP_CANDIDATE_VERSION=top,c.top||'v176-flow-expense-audit');
  const frame=page.frames()[1];
  await frame.setContent((c.brand===false?'':'<header class="brand"><small><b>V169</b> · Homologação</small></header>')+'<div class="flow-sticky-controls"></div><div class="fv-foot"></div><main id="app">Synthetic bank flow</main>');
  const out=await frame.evaluate(async cfg=>{
   window.V='Fluxo Diário';window.ACC='Itaú';window.mergedFlowDays=()=>[];window.historicalCashParts=()=>({internalNet:0});window.money=String;
   const nativeMO=window.MutationObserver,nativeRAF=window.requestAnimationFrame.bind(window),nativeCancel=window.cancelAnimationFrame.bind(window);
   const stats={callbacks:{},records:{},rafScheduled:{},rafExecuted:{},samples:[],pending:0,maxPending:0,stopped:false};const observers=[],rafs=new Set();let installing='none';
   window.MutationObserver=class extends nativeMO{constructor(cb){const layer=installing;super((records,self)=>{stats.callbacks[layer]=(stats.callbacks[layer]||0)+1;stats.records[layer]=(stats.records[layer]||0)+records.length;const old=installing;installing=layer;try{cb(records,self)}finally{installing=old}});observers.push(this)}};
   window.requestAnimationFrame=fn=>{const layer=installing;stats.rafScheduled[layer]=(stats.rafScheduled[layer]||0)+1;stats.pending++;stats.maxPending=Math.max(stats.maxPending,stats.pending);const id=nativeRAF(ts=>{rafs.delete(id);stats.pending--;if(stats.stopped)return;stats.rafExecuted[layer]=(stats.rafExecuted[layer]||0)+1;const old=installing;installing=layer;try{fn(ts)}finally{installing=old}});rafs.add(id);return id};
   const start=performance.now();
   for(const layer of cfg.layers){installing=layer;let src=cfg.code[layer];if(cfg.idempotent&&layer==='v170')src=src.replace(/if\(note\)note.innerHTML=('[^\n]+');/,'if(note&&note.innerHTML!==$1)note.innerHTML=$1;');(0,eval)('(function(){'+src+'})();')}
   installing='seed';document.querySelector('#app').appendChild(document.createTextNode(' switched Consolidado → Itaú'));
   return await new Promise(resolve=>{
    const capture=()=>stats.samples.push({ms:Math.round(performance.now()-start),callbacks:{...stats.callbacks},rafExecuted:{...stats.rafExecuted},pending:stats.pending});
    const sampler=setInterval(capture,200);
    setTimeout(()=>{capture();clearInterval(sampler);stats.stopped=true;observers.forEach(o=>o.disconnect());rafs.forEach(id=>nativeCancel(id));stats.elapsedMs=performance.now()-start;stats.finalHistoryNotes=document.querySelectorAll('.v168-history-note').length;stats.finalBrand=document.querySelector('.brand small')?.textContent||null;resolve(stats)},1100);
   });
  },{...c,code});
  results.push({name:c.name,...out,errors});await page.close();
 }
 await browser.close();fs.writeFileSync(path.resolve('qa/observer-cycle-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
