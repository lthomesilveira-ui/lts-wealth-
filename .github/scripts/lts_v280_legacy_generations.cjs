'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const path=require('node:path'),ROOT=path.resolve('releases/v280');
const BASE=path.resolve('releases/v279');
const {environment,settle,defer,names}=require('./lts_v280_reader_session.cjs');
const src171=fs.readFileSync(ROOT+'/lts-v171-v170-review.js','utf8');
const src175=fs.readFileSync(ROOT+'/lts-v183-expense-history-candidate.js','utf8');
const block=(s,a,b)=>{const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i);return s.slice(i,j)};
const line=(s,n)=>s.split('\n').find(x=>x.includes(n));
let passed=0;
async function test(name,fn){await fn();passed++;console.log('PASS '+name)}
function setupLegacy(root,mode,route){
 const e=environment(root),context=defer();e.ctx.legacyState={expenseLoadScheduled:true};
 e.ctx.K='synthetic';e.ctx.U='https://example.invalid';e.ctx.AbortController=AbortController;
 e.ctx.S.auth.getSession=async()=>({data:{session:{access_token:'synthetic'}}});
 e.ctx.fetch=async()=>({ok:true,json:async()=>({tag:'prior-session-main'})});
 vm.runInContext(`(()=>{${block(src175,'    let expenseReadEpoch=0;','    function yearChunks(')}globalThis.realDirectRpc=directRpc;})();`,e.ctx);
 e.ctx.S.rpc=(name,args)=>name.includes('context_lens')?context.promise:e.ctx.realDirectRpc(name,args);
 vm.runInContext(`(()=>{const state=legacyState;${line(src171,'function expenseRange()')}${block(src171,'    async function ensureExpenseV171(){','    async function ensureWealthV171()')}globalThis.legacy171=ensureExpenseV171;})();`,e.ctx);
 const enter=[],paint=[],render=e.ctx.render;e.ctx.render=()=>{enter.push(e.st.expense.data?.tag||null);render();paint.push(e.st.expense.data?.tag||null)};
 if(mode==='fallback'){delete e.ctx.BOOT;e.ctx.render();enter.length=0;paint.length=0}
 const transition=()=>{if(mode==='generation')e.ctx.BOOT.generation++;else if(mode==='auth')e.auth('SIGNED_OUT');e.ctx.D=route==='signed-out'?null:{user:'b'};if(route==='away')e.ctx.V='Patrimônio'};
 return {e,context,enter,paint,transition};
}
(async()=>{
 for(const name of names)for(const outcome of ['success','error'])await test(name+' ignores '+outcome+' before first new-generation render',async()=>{
  const e=environment(),p=e.begin(name),calls=[...e.calls],before=JSON.stringify(e.slot(name)),renders=e.renders();e.ctx.BOOT.generation++;e.ctx.D={user:'b'};
  e.release(calls,'old',outcome==='error');await p;await settle();assert.equal(JSON.stringify(e.slot(name)),before);assert.equal(e.renders(),renders);
  e.ctx.render();assert.equal(e.slot(name).loading,false);assert.equal('data' in e.slot(name)?e.slot(name).data:e.slot(name).rows,null);
 });
 for(const mode of ['generation','auth','fallback'])for(const route of ['expense','signed-out','away'])await test('V171 late context '+mode+'/'+route+' clears before paint',async()=>{
  const {e,context,enter,paint,transition}=setupLegacy(ROOT,mode,route),p=e.ctx.legacy171();await settle();transition();context.resolve({data:{tag:'prior-session-context'}});await p;
  if(route==='away'){assert.equal(e.st.expense.data.tag,'prior-session-main');e.ctx.V='Despesas';e.ctx.render()}
  assert.equal(enter[0],'prior-session-main');assert(paint.every(x=>x===null));assert.equal(e.st.expense.data,null);assert.equal(e.st.expense.context,null);assert.equal(e.st.expense.loading,false);
 });
 for(const mode of ['generation','auth','fallback'])await test('V171 after first '+mode+' sync cannot overwrite replacement loading/data',async()=>{
  const {e,context,transition}=setupLegacy(ROOT,mode,'expense'),p=e.ctx.legacy171();await settle();transition();e.ctx.render();e.st.expense.loading=true;e.st.expense.data={tag:'current'};const before=JSON.stringify(e.st.expense),renders=e.renders();
  context.resolve({data:{tag:'prior-context'}});await p;assert.equal(JSON.stringify(e.st.expense),before);assert.equal(e.renders(),renders);
 });
 await test('V279 counterproof exposes V171 late main/context after render',async()=>{
  const {e,context,paint,transition}=setupLegacy(BASE,'generation','expense'),p=e.ctx.legacy171();await settle();transition();context.resolve({data:{tag:'prior-session-context'}});await p;assert.deepEqual(paint,['prior-session-main']);
 });
 await test('V175 heavy-tab shell hides all V169 monthly consumers in chain',async()=>{
  const e=environment();e.ctx.trace=[];e.ctx.legacy169={monthly:{data:{tag:'prior-session-monthly'}}};
  vm.runInContext(`(()=>{const baseExpenses=()=>{trace.push(v168.expense.tab);return v168.expense.tab==='monthly'?legacy169.monthly.data.tag:'overview-shell'};${block(src175,'    function shellForHeavyTab(){','    function expensesV175(){')}globalThis.heavyShell=shellForHeavyTab;})();`,e.ctx);
  e.st.expense.tab='monthly';assert.equal(e.ctx.heavyShell(),'overview-shell');assert.equal(e.st.expense.tab,'monthly');assert.deepEqual([...e.ctx.trace],['overview']);
 });
 console.log('TOTAL',passed);
})().catch(e=>{console.error(e);process.exitCode=1});
