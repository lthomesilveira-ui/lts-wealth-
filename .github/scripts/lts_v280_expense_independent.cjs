'use strict';
// Additional independent cases on the candidate author's exact-function VM.
// No browser, network or database. Native date-segment fidelity remains a CI test.
const {environment,settle,ROOT,BASE}=require('./lts_v280_expense_unit.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const results=[];
const clone=x=>JSON.parse(JSON.stringify(x));
const fields=e=>({from:e.node('from')?.value,to:e.node('to')?.value});
const test=async(name,fn)=>{try{await fn();results.push({name,pass:true});console.log('PASS '+name)}catch(error){results.push({name,pass:false,error:String(error.stack||error)});console.log('FAIL '+name+' '+error.message)}};
const apply=e=>e.node('v168ExpenseApply').onclick();
(async()=>{
await test('Only V168 and V175 differ; financial range validators and reader functions retain exact source',async()=>{
 const changed=fs.readdirSync(BASE).filter(n=>n.endsWith('.js')||n.endsWith('.css')||n==='index.html').filter(n=>!fs.readFileSync(path.join(BASE,n)).equals(fs.readFileSync(path.join(ROOT,n))));
 assert.deepEqual(changed.sort(),['lts-v183-expense-history-candidate.js','lts-v183-v168-feedback-safe.js']);
 const base=fs.readFileSync(path.join(BASE,'lts-v183-v168-feedback-safe.js'),'utf8'),candidate=fs.readFileSync(path.join(ROOT,'lts-v183-v168-feedback-safe.js'),'utf8');
 for(const prefix of ['function expenseRange(key)','function expenseRangeError(r)','async function ensureExpense(force)','async function ensureTransactions(force)']){
  assert.equal(candidate.split('\n').find(s=>s.includes(prefix)),base.split('\n').find(s=>s.includes(prefix)),prefix);
 }
});
await test('Direct DOM editing without input events survives a synchronous repaint and does not commit',async()=>{
 const e=environment();e.select('custom');const before=e.slots();e.node('from').value='2026-07-05';e.node('to').value='2026-08-11';e.ctx.render();await settle();
 assert.deepEqual(fields(e),{from:'2026-07-05',to:'2026-08-11'});assert.equal(e.slots(),before);assert.equal(e.calls.length,0);
});
await test('Both empty controls remain empty through 50 repaints and retain their native identities',async()=>{
 const e=environment();e.select('custom');e.input('from','');e.input('to','');const from=e.node('from'),to=e.node('to');
 for(let i=0;i<50;i++)e.ctx.render();await settle();assert.equal(e.node('from'),from);assert.equal(e.node('to'),to);assert.deepEqual(fields(e),{from:'',to:''});assert.equal(e.calls.length,0);
});
await test('Editing only one field keeps the other field and applied error/data untouched',async()=>{
 const e=environment();e.st.expense.error='existing read error';e.state.expense.error='existing historical error';const before=e.slots();e.select('custom');e.input('to','2026-09-03');e.ctx.render();await settle();
 assert.deepEqual(fields(e),{from:'2026-01-01',to:'2026-09-03'});assert.equal(e.slots(),before);assert.equal(e.calls.length,0);
});
await test('Every invalid boundary uses the existing exact validation message with zero read or slot changes',async()=>{
 const cases=[['','2026-09-03','Informe um período válido.'],['2026-08-01','','Informe um período válido.'],['2026-02-30','2026-03-05','Informe um período válido.'],['2026-09-10','2026-09-09','Informe um período válido.'],['2013-10-09','2013-10-10','O histórico de despesas começa em 10/10/2013. O período escolhido foi preservado.'],['2026-09-20','2026-09-21','Despesas realizadas estão disponíveis até 2026-09-20. Para datas futuras, consulte o Fluxo Diário. O período escolhido foi preservado.']];
 for(const [from,to,message]of cases){const e=environment();e.select('custom');e.input('from',from);e.input('to',to);const before=e.slots();apply(e);await settle();assert.equal(e.ctx.draft().error,message);assert.equal(e.slots(),before);assert.equal(e.calls.length,0)}
});
await test('Inclusive historical start, leap day and today retain the existing valid range contract',async()=>{
 for(const [from,to]of [['2013-10-10','2013-10-10'],['2024-02-29','2024-02-29'],['2026-09-20','2026-09-20']]){const e=environment();e.select('custom');e.input('from',from);e.input('to',to);apply(e);await settle();assert.equal(e.ctx.draft().error,null);assert.equal(e.applied().key,'custom');assert(e.calls.length>0);assert(e.calls.every(x=>x.args.p_from===from&&x.args.p_to===to))}
});
await test('Old input events and old Apply cannot mutate a replacement draft in the same session',async()=>{
 const e=environment();e.select('custom');e.input('from','2026-07-01');const input=e.node('from'),oldChange=input.onchange,oldApply=e.node('v168ExpenseApply').onclick;e.select('6m');await settle();e.select('custom');e.input('from','2026-08-02');const before=e.slots(),count=e.calls.length;
 input.value='2026-02-01';oldChange({target:input});oldApply();await settle();assert.equal(e.node('from').value,'2026-08-02');assert.equal(e.slots(),before);assert.equal(e.calls.length,count);
});
await test('Repeated active Custom clicks and renderNav are idempotent while a draft is open',async()=>{
 const e=environment();e.select('custom');e.input('to','2026-08-04');const before=e.slots(),from=e.node('from'),to=e.node('to');
 for(let i=0;i<100;i++){e.renderNav();e.select('custom')}await settle();assert.equal(e.slots(),before);assert.equal(e.calls.length,0);assert.equal(e.node('from'),from);assert.equal(e.node('to'),to);
});
await test('Selecting the already-applied preset discards draft but changes no report slots',async()=>{
 const e=environment();e.select('custom');e.input('from','2026-08-05');const before=e.slots();for(let i=0;i<20;i++)e.renderNav();e.select('ytd');await settle();assert.equal(e.slots(),before);assert.equal(e.calls.length,0);assert.equal(e.node('from'),undefined);e.select('custom');assert.equal(e.node('from').value,'2026-01-01');
});
await test('Reopening after a previously applied Custom follows the effective preset rather than historical custom fields',async()=>{
 const e=environment();e.select('custom');e.input('from','2026-07-01');e.input('to','2026-07-21');apply(e);await settle();e.select('12m');await settle();const applied=e.applied(),count=e.calls.length;e.select('custom');await settle();assert.deepEqual(fields(e),{from:applied.range.from,to:applied.range.to});assert.equal(e.calls.length,count);assert.equal(e.applied().key,'12m');
});
await test('A delayed applied-reader failure leaves the draft and its validation feedback intact',async()=>{
 const e=environment();e.hold();e.select('6m');await settle();e.select('custom');e.input('from','2026-09-01');e.input('to','2026-09-30');apply(e);const error=e.ctx.draft().error;
 e.pending[0].gate.resolve({error:{message:'synthetic reader failure'}});await settle();assert.equal(e.ctx.draft().error,error);assert.equal(e.node('to').value,'2026-09-30');assert.equal(e.state.expense.error,'synthetic reader failure');assert.equal(e.applied().key,'6m');
});
await test('All expense tabs and route departure retain draft while readers see only applied dates',async()=>{
 const e=environment();e.select('custom');e.input('from','2026-08-02');e.input('to','2026-08-19');const applied=e.applied(),from=e.node('from');
 for(const tab of ['categories','monthly','cards','transactions','overview']){e.st.expense.tab=tab;e.ctx.render();await settle();assert.deepEqual(e.applied(),applied);assert.equal(e.node('from'),from)}
 e.navigate('Fluxo Diário');e.navigate('Despesas');await settle();assert.deepEqual(fields(e),{from:'2026-08-02',to:'2026-08-19'});assert.equal(e.calls.length,0);
});
await test('New BOOT generation discards unapplied edits even when the retained applied selector is custom',async()=>{
 const e=environment();e.select('custom');e.input('from','2026-07-01');e.input('to','2026-07-21');apply(e);await settle();e.input('from','2026-08-01');const oldNode=e.node('from'),oldApply=e.node('v168ExpenseApply').onclick,oldChange=oldNode.oninput;e.ctx.BOOT.generation++;e.ctx.D={user:'other'};e.ctx.render();const count=e.calls.length;
 oldNode.value='2026-01-02';oldChange({target:oldNode});oldApply();await settle();assert.notEqual(e.node('from'),oldNode);assert.deepEqual(fields(e),{from:'2026-07-01',to:'2026-07-21'});assert.equal(e.calls.length,count);
});
await test('Fallback identity and auth epoch reject retained old actions before invalidating V169/V175',async()=>{
 for(const mode of ['fallback','auth']){const e=environment();if(mode==='fallback'){delete e.ctx.BOOT;e.ctx.render()}e.select('custom');e.input('from','2026-08-01');e.input('to','2026-08-10');const applyOld=e.node('v168ExpenseApply').onclick,presetOld=e.ctx.document.querySelectorAll('[data-v168-exp-range]').find(n=>n.dataset.v168ExpRange==='6m').onclick,before=e.slots();if(mode==='fallback')e.ctx.D={user:'new'};else e.auth('SIGNED_IN');applyOld();presetOld();await settle();assert.equal(e.slots(),before);assert.equal(e.calls.length,0)}
});
await test('External change to custom applied dates replaces draft and old input nodes',async()=>{
 const e=environment();e.select('custom');e.input('from','2026-07-01');e.input('to','2026-07-21');apply(e);await settle();e.input('to','2026-08-01');const n=e.node('to');e.st.expense.customFrom='2026-06-01';e.st.expense.customTo='2026-06-20';e.ctx.render();assert.notEqual(e.node('to'),n);assert.deepEqual(fields(e),{from:'2026-06-01',to:'2026-06-20'});
});
await test('Repeated repaints do not attach controls on another route or alter cash and flow state',async()=>{
 const e=environment();e.select('custom');e.input('to','');const before=clone([e.ctx.CF,e.ctx.FLOWFROM,e.ctx.FLOWTO,e.ctx.ACC,[...e.ctx.EXP]]);e.navigate('Patrimônio');for(let i=0;i<50;i++)e.ctx.render();await settle();assert.equal(e.node('from'),undefined);assert.deepEqual(clone([e.ctx.CF,e.ctx.FLOWFROM,e.ctx.FLOWTO,e.ctx.ACC,[...e.ctx.EXP]]),before);e.navigate('Despesas');assert.equal(e.node('to').value,'');
});
const hashes=Object.fromEntries(['lts-v183-v168-feedback-safe.js','lts-v183-expense-history-candidate.js'].map(n=>[n,crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,n))).digest('hex')]));
const report={scope:'Independent additional exact-function VM tests; native browser behavior requires CI',hashes,passed:results.filter(x=>x.pass).length,failed:results.filter(x=>!x.pass).length,results};fs.writeFileSync('qa/v280-expense-independent-results.json',JSON.stringify(report,null,2)+'\n');console.log('RESULT '+report.passed+' PASS '+report.failed+' FAIL');if(report.failed)process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1});
