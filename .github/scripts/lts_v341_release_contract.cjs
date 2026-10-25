'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const root=path.resolve('releases/v341'),base=path.resolve('releases/v339'),read=(r,n)=>fs.readFileSync(path.join(r,n),'utf8'),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const m=JSON.parse(read(root,'manifest.json')),p=JSON.parse(read(root,'provenance.json'));
assert.equal(m.release,'v341');assert.equal(m.version,'v341');assert.equal(m.base_release,'v339');
assert.equal(fs.readdirSync(root).length,77);assert.deepEqual(fs.readdirSync(root).sort(),[...Object.keys(m.files),'manifest.json'].sort());
for(const [name,hash]of Object.entries(m.files))assert.equal(sha(fs.readFileSync(path.join(root,name))),hash,name);
for(const [name,hash]of Object.entries(m.protected))assert.equal(sha(fs.readFileSync(name)),hash,name);
assert.equal(Object.keys(p.protected_base_files).length,77);
for(const [name,hash]of Object.entries(p.protected_base_files))assert.equal(sha(fs.readFileSync(path.join(base,name))),hash,'Immutable base '+name);
const changed=fs.readdirSync(root).filter(n=>read(root,n)!==read(base,n)).sort();
assert.deepEqual(changed,['app.html','lts-v225-open-finance.js','lts-v227-read-transport.js','manifest.json','provenance.json'].sort());
assert.equal(read(root,'app.html'),read(base,'app.html').replaceAll('V339','V341').replace('v339-component-boot-20261025','v341-bank-collection-20261025'));
function rewrite(name,patches){
 let expected=read(base,name);
 for(const [old,next]of patches){assert.equal(expected.split(old).length,2,'Unique base anchor '+name+': '+old.slice(0,65));expected=expected.replace(old,next);}
 assert.equal(read(root,name),expected,'Only the specified scheduling changes: '+name);
}
rewrite('lts-v227-read-transport.js',[
 ['  const waiting=[];let active=false,pumpTimer=null,order=0;\n',`  const waiting=[],holds=new Set();let active=false,pumpTimer=null,order=0;
  // BEGIN COLLECTION READ HOLD
  // A collection starts after the admitted reader finishes. Other expensive
  // reads wait until collection ends; cash/status and writes stay independent.
  function holdHeavyReads(){
   let resolveReady,released=false,ready=false,timer;
   const promise=new Promise(resolve=>resolveReady=resolve);
   const hold={notify(){if(!active&&!released&&!ready){ready=true;resolveReady(true)}},release(){
    if(released)return;released=true;clearTimeout(timer);holds.delete(hold);resolveReady(false);pump();
   }};
   holds.add(hold);hold.notify();timer=setTimeout(hold.release,90000);
   return {ready:promise,release:hold.release};
  }
  function releaseReadHolds(){for(const hold of [...holds])hold.release();}
  // END COLLECTION READ HOLD
`],
 ['   pumpTimer=null;if(active||!waiting.length)return;',`   pumpTimer=null;if(!active)for(const hold of holds)hold.notify();
   if(active||holds.size||!waiting.length)return;`],
 ['  window.__LTS_V227_TRANSPORT={installed:true,invalidate,get revision(){return revision}};',
  '  window.__LTS_V227_TRANSPORT={installed:true,invalidate,holdHeavyReads,get revision(){return revision}};'],
 ["{invalidate();if(typeof FLOWQ!=='undefined')FLOWQ=null}","{invalidate();releaseReadHolds();if(typeof FLOWQ!=='undefined')FLOWQ=null}"]
]);
rewrite('lts-v225-open-finance.js',[
 ['    function connections() { return Array.isArray(state.status?.connections) ? state.status.connections : []; }\n',
  '    function connections() { return Array.isArray(state.status?.connections) ? state.status.connections : []; }\n    function releaseRefreshReads(hold=state.readHold) { if(state.readHold===hold)state.readHold=null;hold?.release(); }\n'],
 ['      if (!signedIn()) { clearTimeout(state.timer); state.syncing=false; return; }',
  '      if (!signedIn()) { clearTimeout(state.timer); releaseRefreshReads(); state.syncing=false; return; }'],
 ["state.error=''; state.message=freshness.collectionMessage(state.status,state.refreshBaseline,Date.now()); paint(); refreshScreens(); return;",
  "state.error=''; state.message=freshness.collectionMessage(state.status,state.refreshBaseline,Date.now()); paint(); refreshScreens(); releaseRefreshReads(); return;"],
 ['        paint(); return;','        paint(); releaseRefreshReads(); return;'],
 ['      const epoch=state.epoch,gen=generation();\n      state.manualRefresh=',
  '      const epoch=state.epoch,gen=generation();\n      let readHold=null;\n      state.manualRefresh='],
 ['        if(state.statusRead)await state.statusRead;\n        if(!activeSession(epoch,gen))return;\n',`        if(state.statusRead)await state.statusRead;
        if(!activeSession(epoch,gen))return;
        readHold=window.__LTS_V227_TRANSPORT?.holdHeavyReads?.()||null;state.readHold=readHold;
        const ready=readHold?await readHold.ready:true;
        if(!activeSession(epoch,gen)){releaseRefreshReads(readHold);return;}
        if(ready!==true)throw Error('Consulta anterior ainda não concluída');
`],
 ["      } catch(error) { if(!activeSession(epoch,gen))return;state.syncing=false; state.error='Não foi possível atualizar as contas. Tente novamente.'; paint(); }",
  "      } catch(error) { releaseRefreshReads(readHold);if(!activeSession(epoch,gen))return;state.syncing=false; state.error='Não foi possível atualizar as contas. Tente novamente.'; paint(); }"],
 ['    function clearSession() { clearTimeout(state.timer);state.epoch++;','    function clearSession() { clearTimeout(state.timer);releaseRefreshReads();state.epoch++;'],
 ['if(state.status||state.statusRead)clearSession();','if(state.status||state.statusRead||state.readHold)clearSession();']
]);
assert.equal(p.frontend_only,true);assert.equal(p.backend_changed,false);assert.equal(p.financial_source_data_changed,false);
assert.equal(p.physical_mobile_validated,false);assert.equal(p.private_http_validated,false);
assert.equal(p.boot_registrations.length,32);
for(const name of ['lts-v225-open-finance.js','lts-v227-read-transport.js'])cp.execFileSync(process.execPath,['--check',path.join(root,name)],{stdio:'pipe'});
console.log(JSON.stringify({pass:true,release:'v341',files:77,changed_runtime_assets:2,unchanged_other_runtime_assets:true,financial_code_outside_scheduling_exact:true,existing_read_deadlines_exact:true,immutable_base_files:77,backend_changed:false}));
