'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lts-v183-exact-flow-navigation.js','utf8');
function harness({day='2014-02-03',edit=false,fail=false,invalid=false}={}){
 const calls=[],microtasks=[],recovery={default_range_applied:true},review={lastRoute:'Atualizações'};
 let v162Last='Atualizações';
 const button={},ctx={window:{__LTS_V162_FLOW_RECOVERY_STATUS:recovery,__LTS_V170_STATE:review},V:'Atualizações',document:{querySelectorAll:()=>[button]}};
 const original=function(event){calls.push(['handler',this===button,event]);if(fail)throw Error('fixture');if(invalid)return;ctx.V='Fluxo Diário';ctx.render();calls.push(['load',day,day]);calls.push(['focus',day,edit])};
 button.onclick=original;
 ctx.render=function(){
  const entered162=ctx.V==='Fluxo Diário'&&v162Last!==ctx.V;v162Last=ctx.V;
  const entered170=ctx.V==='Fluxo Diário'&&review.lastRoute!==ctx.V;review.lastRoute=ctx.V;
  if(entered162&&recovery.default_range_applied)microtasks.push(()=>calls.push(['default162']));
  if(entered170)microtasks.push(()=>calls.push(['default170']));
  button.onclick=original;return 'rendered';
 };
 vm.runInNewContext('('+source.slice(source.indexOf('function runtime(){'),source.indexOf('\n const shell='))+')()',ctx);
 return {button,ctx,calls,recovery,review,flush:()=>{microtasks.splice(0).forEach(fn=>fn())}};
}
test('historical exact day is not overwritten by either route default',()=>{const h=harness();h.button.onclick('event');h.flush();assert.deepEqual(h.calls,[['handler',true,'event'],['load','2014-02-03','2014-02-03'],['focus','2014-02-03',false]]);assert.equal(h.recovery.default_range_applied,true)});
test('future edit keeps original handler, exact date and editor flag',()=>{const h=harness({day:'2028-04-12',edit:true});h.button.onclick();h.flush();assert.deepEqual(h.calls.slice(1),[['load','2028-04-12','2028-04-12'],['focus','2028-04-12',true]])});
test('normal navigation still requests default after explicit visit',()=>{const h=harness();h.button.onclick();h.ctx.V='Dashboard';h.ctx.render();h.ctx.V='Fluxo Diário';h.ctx.render();h.flush();assert.ok(h.calls.some(x=>x[0]==='default162'));assert.ok(h.calls.some(x=>x[0]==='default170'))});
test('throw or invalid row restores previous route and default state',()=>{for(const opts of [{fail:true},{invalid:true}]){const h=harness(opts);if(opts.fail)assert.throws(()=>h.button.onclick(),/fixture/);else h.button.onclick();assert.equal(h.review.lastRoute,'Atualizações');assert.equal(h.recovery.default_range_applied,true)}});
test('rerenders rebind exactly once and preserve return value',()=>{const h=harness();assert.equal(h.ctx.render(),'rendered');h.ctx.render();h.button.onclick();assert.equal(h.calls.filter(x=>x[0]==='handler').length,1)});
test('isolated module has no writers and shared files remain unmodified',()=>{assert.doesNotThrow(()=>new Function(source));assert.doesNotMatch(source,/S\.rpc|\.insert\(|\.update\(|\.delete\(/);assert.doesNotMatch(fs.readFileSync('index.html','utf8'),/lts-v183-exact-flow-navigation/)});
