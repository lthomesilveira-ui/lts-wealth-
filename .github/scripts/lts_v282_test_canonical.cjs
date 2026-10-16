'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {setup,commit,tick,plain,baseRow,adjustment,button,respond,source,sourcePath}=require('./lts_v282_canonical_harness.cjs');
const checks=[];
async function check(name,fn){await fn();checks.push({name,passed:true});}
async function start(e){const done=e.test.ensureTransactions();await tick();return {done};}
(async()=>{
 await check('canonical OF daily row and signed adjustment preserve full raw fields',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[baseRow,adjustment]);await done;
  assert.deepEqual(plain(e.test.st.transactions.rows),[baseRow,adjustment]);assert.equal(e.test.st.transactions.total,80);assert.equal(e.test.st.transactions.count,2);
  assert.deepEqual(e.requests[0].args,{p_from:'2026-10-16',p_to:'2026-10-16',p_group:null,p_subgroup:null,p_offset:0,p_limit:10000,p_query:null});
  assert.equal(e.calls.filter(c=>c.name==='lts_browser_transactions_v2').length,0);
 });
 await check('pagination remains atomic and validates short-page progression',async()=>{
  const e=setup(),{done}=await start(e);const meta={row_count:2,matched_count:2,total:80,matched_total:80};
  respond(e,0,[baseRow],{...meta,next_offset:1});await tick();assert.equal(e.requests.length,2);assert.equal(e.requests[1].args.p_offset,1);assert.equal(e.test.st.transactions.rows,null);assert.equal(e.test.st.transactions.loading,true);
  respond(e,1,[adjustment],meta);await done;assert.equal(e.test.st.transactions.rows.length,2);assert.equal(e.test.st.transactions.total,80);
 });
 await check('real10000-row boundary and10005-row total close correctly',async()=>{
  const e=setup(),{done}=await start(e);const first=Array.from({length:10000},(_,i)=>({...baseRow,key:'row:'+i,amount:1}));const meta={row_count:10005,matched_count:10005,total:10005,matched_total:10005};
  respond(e,0,first,{...meta,next_offset:10000});await tick();assert.equal(e.requests[1].args.p_offset,10000);respond(e,1,Array.from({length:5},(_,i)=>({...baseRow,key:'last:'+i,amount:1})),meta);await done;assert.equal(e.test.st.transactions.rows.length,10005);assert.equal((e.test.expenseTransactions().match(/data-v281-expense-row-key=/g)||[]).length,100);
 });
 await check('local100-row pagination preserves full count/total and global detail index without RPC',async()=>{
  const e=setup(),{done}=await start(e);const all=Array.from({length:10005},(_,i)=>({...baseRow,key:'large:'+i,description:'Row '+i,amount:1})),meta={row_count:10005,matched_count:10005,total:10005,matched_total:10005};
  respond(e,0,all.slice(0,10000),{...meta,next_offset:10000});await tick();respond(e,1,all.slice(10000),meta);await done;
  const next={dataset:{v281ExpenseTransactionsPage:'next'},isConnected:true},prev={dataset:{v281ExpenseTransactionsPage:'prev'},isConnected:true};e.controls.pages=[next,prev];e.test.bindExpenseTransactionActions();const calls=e.calls.length;
  next.onclick();assert.equal(e.test.st.transactions.pageIndex,1);let html=e.test.expenseTransactions();assert.equal((html.match(/data-v281-expense-row-key=/g)||[]).length,100);assert.match(html,/Exibindo 101 a 200 de 10005/);assert.match(html,/data-v281-expense-transaction-detail="100"/);assert.equal(e.test.st.transactions.total,10005);assert.equal(e.test.st.transactions.count,10005);
  e.controls.details=[button(100)];e.test.bindExpenseTransactionActions();e.controls.details[0].onclick();assert.equal(e.modals[0].title,'Row 100');prev.onclick();assert.equal(e.test.st.transactions.pageIndex,0);
  e.test.st.transactions.pageIndex=100;html=e.test.expenseTransactions();assert.equal((html.match(/data-v281-expense-row-key=/g)||[]).length,5);assert.match(html,/Exibindo 10001 a 10005 de 10005/);assert.equal(e.calls.length,calls);
  await commit(e,'2026-10-15');assert.equal(e.test.st.transactions.pageIndex,0);prev.onclick();next.onclick();assert.equal(e.test.st.transactions.pageIndex,0);respond(e,2,[]);await tick();assert.equal(e.test.st.transactions.pageIndex,0);
 });
 await check('local page buttons reject detached nodes/changed route/session',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,Array.from({length:101},(_,i)=>({...baseRow,key:'small:'+i})));await done;
  const b={dataset:{v281ExpenseTransactionsPage:'next'},isConnected:true};e.controls.pages=[b];e.test.bindExpenseTransactionActions();b.isConnected=false;b.onclick();assert.equal(e.test.st.transactions.pageIndex,0);b.isConnected=true;e.context.V='Atualizações';b.onclick();assert.equal(e.test.st.transactions.pageIndex,0);e.context.V='Despesas';e.events.forEach(fn=>fn('SIGNED_OUT'));b.onclick();assert.equal(e.test.st.transactions.pageIndex,0);
 });
 await check('over10000-row stale page2 cannot replace current day result',async()=>{
  const e=setup('2026-10-15'),{done}=await start(e);const first=Array.from({length:10000},(_,i)=>({...baseRow,key:'old:'+i,amount:1})),meta={row_count:10005,matched_count:10005,total:10005,matched_total:10005};respond(e,0,first,{...meta,next_offset:10000});await tick();
  await commit(e,'2026-10-16');respond(e,2,[baseRow]);await tick();respond(e,1,Array.from({length:5},(_,i)=>({...baseRow,key:'old:last:'+i,amount:1})),meta);await done;await tick();assert.equal(e.requests.length,3);assert.equal(e.test.st.transactions.count,1);assert.equal(e.test.st.transactions.rows[0].key,baseRow.key);assert.equal(e.test.st.transactions.total,100);
 });
 for(const change of [{revision:'changed-large'},{total:10006,matched_total:10006}])await check('over10000-row page2 metadata change rejected '+Object.keys(change)[0],async()=>{
  const e=setup(),{done}=await start(e);const first=Array.from({length:10000},(_,i)=>({...baseRow,key:'large:'+i,amount:1})),meta={row_count:10005,matched_count:10005,total:10005,matched_total:10005};respond(e,0,first,{...meta,next_offset:10000});await tick();respond(e,1,Array.from({length:5},(_,i)=>({...baseRow,key:'large:last:'+i,amount:1})),{...meta,...change});await done;assert.match(e.test.st.transactions.error,/mudaram/);assert.equal(e.test.st.transactions.rows,null);assert.equal(e.test.st.transactions.total,null);
 });
 await check('stale empty response cannot suppress newer applied day',async()=>{
  const e=setup('2026-10-15'),{done}=await start(e);await commit(e,'2026-10-16');assert.equal(e.requests.length,2);
  respond(e,1,[baseRow]);await tick();respond(e,0,[]);await done;assert.equal(e.test.st.transactions.rows[0].key,baseRow.key);assert.equal(e.test.st.transactions.rangeKey,'2026-10-16|2026-10-16');
 });
 await check('stale nonempty cannot leak into empty day or clear pending loading',async()=>{
  const e=setup(),{done}=await start(e);await commit(e,'2026-10-15');respond(e,0,[baseRow]);await done;
  assert.equal(e.test.st.transactions.rows,null);assert.equal(e.test.st.transactions.loading,true);respond(e,1,[]);await tick();assert.deepEqual(plain(e.test.st.transactions.rows),[]);
 });
 await check('period change while page2 awaits retires all older-page accumulation',async()=>{
  const e=setup('2026-10-15'),{done}=await start(e);const meta={row_count:3,matched_count:3,total:300,matched_total:300};
  respond(e,0,[baseRow],{...meta,next_offset:1});await tick();await commit(e,'2026-10-16');assert.equal(e.requests.length,3);
  respond(e,2,[baseRow]);await tick();respond(e,1,[{...baseRow,key:'old2'}],{...meta,next_offset:2});await done;await tick();assert.equal(e.requests.length,3);assert.equal(e.test.st.transactions.count,1);
 });
 await check('same-date reapply and force replace ownership',async()=>{
  const e=setup(),{done}=await start(e);await commit(e,'2026-10-16');const fresh=e.test.ensureTransactions(true);await tick();assert.equal(e.requests.length,3);
  respond(e,2,[baseRow]);await fresh;respond(e,1,[]);respond(e,0,[]);await done;await tick();assert.equal(e.test.st.transactions.rows[0].key,baseRow.key);
 });
 await check('draft opening/editing and invalid future apply preserve current ownership',async()=>{
  const e=setup(),{done}=await start(e);const token=e.test.st.transactions.token;
  e.test.setDraft('2026-10-15','2026-10-15');e.context.render();assert.equal(e.test.st.transactions.token,token);
  await commit(e,'2026-10-17');assert.equal(e.requests.length,1);assert.equal(e.test.st.transactions.token,token);respond(e,0,[baseRow]);await done;assert.equal(e.test.st.transactions.count,1);
 });
 for(const variant of ['SIGNED_OUT','SIGNED_IN','BOOT'])await check('session guard '+variant,async()=>{
  const e=setup(),{done}=await start(e);
  if(variant==='BOOT')e.context.BOOT.generation++;else e.events.forEach(fn=>fn(variant));
  if(variant==='SIGNED_OUT'){e.context.D=null;e.test.syncExpenseReaders();respond(e,0,[baseRow]);await done;assert.equal(e.test.st.transactions.rows,null);return;}
  const fresh=e.test.ensureTransactions();await tick();respond(e,1,[baseRow]);await fresh;respond(e,0,[]);await done;assert.equal(e.test.st.transactions.count,1);
 });
 const invalids=[
  ['wrong range',{from:'2026-10-15'}],['wrong offset',{offset:2}],['missing revision',{revision:null}],['wrong group',{group:'Imóvel'}],['wrong matched count',{matched_count:2}],['wrong matched total',{matched_total:99}],['count too small',{row_count:0,matched_count:0}],['count too large',{row_count:2,matched_count:2}],['sum mismatch',{total:99,matched_total:99}],['nonadvancing offset',{next_offset:0,row_count:2,matched_count:2}],['skipped offset',{next_offset:2,row_count:3,matched_count:3}],['invalid next offset',{next_offset:undefined}],['rows missing',{rows:null}],['nonfinite amount',{rows:[{...baseRow,amount:'NaN'}]}],['missing key',{rows:[{...baseRow,key:''}]}],['invalid date kind',{rows:[{...baseRow,date_kind:'invented'}]}]
 ];
 for(const [name,override]of invalids)await check('reject '+name+' without render retry loop',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[baseRow],override);await done;assert.ok(e.test.st.transactions.error,name);assert.equal(e.test.st.transactions.rows,null);assert.equal(e.test.st.transactions.loading,false);
  for(let i=0;i<4;i++)e.test.expenseTransactions();await tick();assert.equal(e.requests.length,1);
 });
 for(const field of ['amount','total','row_count','matched_total','matched_count'])for(const value of [[125],true,' ',null,'100'])await check('strict numeric rejection '+field+'='+JSON.stringify(value),async()=>{
  const e=setup(),{done}=await start(e);const override=field==='amount'?{rows:[{...baseRow,amount:value}]}:{[field]:value};respond(e,0,[baseRow],override);await done;assert.ok(e.test.st.transactions.error);assert.equal(e.test.st.transactions.rows,null);
 });
 await check('missing or invalid day date never falls back to event_date',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[{...baseRow,date:null}]);await done;const html=e.test.expenseTransactions();assert.match(html,/Data não informada/);assert.ok(!html.includes('16/10/2026'));assert.equal(e.test.expenseTransactionDate({...baseRow,date:'2026-02-30'}),'Data não informada');assert.equal(e.test.expenseTransactionDate({...adjustment,period:null}),'Competência não informada');assert.equal(e.test.expenseTransactionDate({...adjustment,period:'2026-99'}),'Competência não informada');assert.equal(e.test.expenseTransactionDate({...baseRow,date:['2026-10-16']}),'Data não informada');
 });
 await check('reject duplicate keys across pages',async()=>{
  const e=setup(),{done}=await start(e);const meta={row_count:2,matched_count:2,total:200,matched_total:200};respond(e,0,[baseRow],{...meta,next_offset:1});await tick();respond(e,1,[baseRow],meta);await done;assert.ok(e.test.st.transactions.error);assert.equal(e.test.st.transactions.rows,null);
 });
 await check('revision change across pages rejects full result',async()=>{
  const e=setup(),{done}=await start(e);const meta={row_count:2,matched_count:2,total:80,matched_total:80};respond(e,0,[baseRow],{...meta,next_offset:1});await tick();respond(e,1,[adjustment],{...meta,revision:'new'});await done;assert.match(e.test.st.transactions.error,/mudaram/);assert.equal(e.test.st.transactions.rows,null);
 });
 await check('page metadata total/count changes reject full result',async()=>{
  const e=setup(),{done}=await start(e);const meta={row_count:2,matched_count:2,total:80,matched_total:80};respond(e,0,[baseRow],{...meta,next_offset:1});await tick();respond(e,1,[adjustment],{...meta,total:90,matched_total:90});await done;assert.match(e.test.st.transactions.error,/mudaram/);
 });
 await check('empty intermediate page rejects without further requests',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[],{row_count:2,matched_count:2,total:0,matched_total:0,next_offset:1});await done;assert.ok(e.test.st.transactions.error);assert.equal(e.requests.length,1);
 });
 await check('explicit retry recovers error; render alone never retries',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[baseRow],{total:99,matched_total:99});await done;
  const retry={isConnected:true,addEventListener(type,fn){this.click=fn}};e.controls.retry=retry;e.test.bindExpenseTransactionActions();assert.match(e.test.expenseTransactions(),/Tentar novamente/);retry.click();await tick();assert.equal(e.requests.length,2);respond(e,1,[baseRow]);await tick();assert.equal(e.test.st.transactions.error,null);assert.equal(e.test.st.transactions.count,1);
 });
 await check('renderer preserves negative amount/month semantics/current category/explicit beneficiary',async()=>{
  const e=setup(),{done}=await start(e);const row={...adjustment,beneficiary:'Pessoa explícita',description:'<script>bad</script>'};respond(e,0,[row]);await done;const html=e.test.expenseTransactions();
  assert.match(html,/competência/);assert.match(html,/-R\$\s*20,00/);assert.match(html,/Assinaturas/);assert.match(html,/Mastercard Itaú/);assert.match(html,/Pessoa explícita/);assert.ok(!html.includes('16/10/2026'));assert.ok(!html.includes('<script>bad'));assert.match(html,/&lt;script&gt;/);assert.ok(!html.includes('data-v168-flow-row'));assert.match(html,/data-v281-expense-row-key/);
 });
 await check('detail is local/read-only; no flow target, inferred property or data write',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[adjustment]);await done;e.controls.details=[button(0)];e.test.bindExpenseTransactionActions();const before=e.calls.length;e.controls.details[0].onclick();
  assert.equal(e.calls.length,before);assert.equal(e.modals.length,1);assert.match(e.modals[0].body,/Ajuste negativo documentado/);assert.ok(!e.modals[0].body.includes('data-v168-flow-row'));assert.ok(!e.modals[0].body.includes('data-v168-save'));assert.ok(!e.modals[0].body.includes('CIPÓ'));assert.ok('data-v281-expense-transaction-modal' in e.modals[0].attributes);
 });
 await check('detail buttons reject detached nodes and route changes',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[baseRow]);await done;const b=button(0);e.controls.details=[b];e.test.bindExpenseTransactionActions();b.isConnected=false;b.onclick();assert.equal(e.modals.length,0);b.isConnected=true;e.context.V='Atualizações';b.onclick();assert.equal(e.modals.length,0);
 });
 await check('period invalidation closes open canonical detail and retires stale buttons',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[baseRow]);await done;const b=button(0);e.controls.details=[b];e.test.bindExpenseTransactionActions();b.onclick();const modal=e.modals[0];await commit(e,'2026-10-15');assert.equal(modal.removed,true);b.onclick();assert.equal(e.modals.length,1);respond(e,1,[]);await tick();
 });
 await check('session invalidation closes open canonical detail',async()=>{
  const e=setup(),{done}=await start(e);respond(e,0,[baseRow]);await done;e.controls.details=[button(0)];e.test.bindExpenseTransactionActions();e.controls.details[0].onclick();e.events.forEach(fn=>fn('SIGNED_OUT'));e.context.D=null;e.test.syncExpenseReaders();assert.equal(e.modals[0].removed,true);e.controls.details[0].onclick();assert.equal(e.modals.length,1);
 });
 await check('invoice reader remains on transactions_v2 with original args',async()=>{
  const e=setup();await e.test.ensureInvoices();assert.deepEqual(e.calls[0],{name:'lts_browser_transactions_v2',args:{p_from:'2013-10-10',p_to:null,p_query:'fatura',p_direction:null,p_account:null,p_limit:300,p_offset:0}});
 });
 const output={candidate:sourcePath,sha256:crypto.createHash('sha256').update(source).digest('hex'),method:'Exact candidate readers and rendering functions in Node VM, synthetic RPC/DOM; no SQL/network/browser/deployment.',total:checks.length,passed:checks.length,checks};
 fs.writeFileSync(path.resolve('qa/ledger-unit-result.json'),JSON.stringify(output,null,2)+'\n');console.log(JSON.stringify({total:checks.length,passed:checks.length,sha256:output.sha256,results:path.resolve('qa/ledger-unit-result.json')},null,2));
})().catch(error=>{console.error(error);process.exitCode=1});
