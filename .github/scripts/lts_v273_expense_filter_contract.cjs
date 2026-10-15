'use strict';
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),path=require('path');
const root=__dirname;fs.mkdirSync('qa',{recursive:true});
const original=fs.readFileSync('releases/v272/lts-v183-v168-feedback-safe.js','utf8');
const candidate=fs.readFileSync('releases/v273/lts-v183-v168-feedback-safe.js','utf8');
const line=(src,name)=>src.split('\n').find(x=>new RegExp('(?:async )?function '+name+'\\(').test(x));
const block=(src,start,end)=>src.slice(src.indexOf(start),src.indexOf(end,src.indexOf(start)));
const flush=async(n=30)=>{for(let i=0;i<n;i++)await new Promise(setImmediate)};
class Button{constructor(dataset={}){this.dataset=dataset;this.listeners=[];this.onclick=null;}addEventListener(type,fn){if(type==='click')this.listeners.push(fn)}click(){const callbacks=[...this.listeners,...(this.onclick?[this.onclick]:[])];for(const fn of callbacks)fn.call(this,{currentTarget:this});}}
function harness(src,{rpc:respond,now='2026-10-15T18:00:00Z',fallback=true}={}){
 let instant=now;class FixedDate extends Date{constructor(...args){super(...(args.length?args:[instant]))}static now(){return new Date(instant).getTime()}}
 const st={expense:{key:'custom',tab:'overview',loading:false,token:0,data:null,context:null,error:null,customFrom:'2026-10-01',customTo:'2026-10-15'},transactions:{rows:null},wealth:{}};
 const contextTimers=[];const calls=[],views=[],notices=[],elements={},buttons=['ytd','6m','12m','all','custom'].map(v168ExpRange=>new Button({v168ExpRange}));
 const context={st,v168:st,state:{expenseLoadScheduled:false},V:'Despesas',topScope:null,Date:FixedDate,Intl,Promise,Error,Number,String,Array,Map,Set,JSON,Math,queueMicrotask,setTimeout:(fn,ms)=>ms===12000?(contextTimers.push({fn,active:true}),contextTimers.at(-1)):setImmediate(fn),clearTimeout:t=>t&&'active' in t?t.active=false:clearImmediate(t),
 today:()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new FixedDate()),
 addMonths:(iso,n)=>{let d=new Date(iso+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+n);return d.toISOString().slice(0,10)},date:v=>String(v).split('-').reverse().join('/'),
 S:{rpc(name,args){calls.push({name,args});return respond?respond(name,args,calls):Promise.resolve({data:{period:{from:args.p_from,to:args.p_to},id:args.p_from},error:null})}},
 document:{getElementById:id=>elements[id]||null,querySelector:sel=>sel==='[data-v168-exp-retry]'?elements.retry||null:null,querySelectorAll:sel=>sel==='[data-v168-exp-range]'?buttons:[]},
 loading:()=>'<LOADING>',errorBox:x=>'<ERROR>'+x,head:()=>'',sourceLabel:()=>'',periodButtons:()=>'',expenseTabs:()=>'',expenseOverviewV168:r=>'<READY>'+r.id,expenseCategoriesV168:()=>'',expenseCardsV168:()=>'',expenseTransactions:()=>'',esc:String,toast2:x=>notices.push(x),
 bindChart(){},refresh(route){if(context.V===route)context.render()},renderNav(){}
 };
 vm.createContext(context);
 const snippets=[line(src,'expenseRange'),line(src,'rpc'),src.split('\n').find(x=>x.includes('const pause=')),line(src,'rpcRead'),line(src,'ensureExpense'),line(src,'despesasV168Final'),block(src,'    function bindCommonV168(){','    function bindWealthV168()')];
 if(src.includes('function expenseRangeError'))snippets.unshift(line(src,'expenseRangeError'),line(src,'expenseContextWithinBudget'));
 vm.runInContext(snippets.join('\n'),context);
 if(fallback){const legacy=fs.readFileSync(path.join('releases',src===original?'v272':'v273','lts-v171-v170-review.js'),'utf8');vm.runInContext(block(legacy,'    async function ensureExpenseV171(){','    async function ensureWealthV171(){')+'\n'+line(legacy,'after').replace('function after(){','function after171(){'),context)}
 context.render=()=>{const html=context.despesasV168Final();views.push(html);elements.v168ExpenseFrom={value:st.expense.customFrom};elements.v168ExpenseTo={value:st.expense.customTo};elements.v168ExpenseApply=new Button();elements.retry=html.includes('data-v168-exp-retry')?new Button():null;context.bindCommonV168();if(fallback)context.after171();return html};
 return {st,calls,views,notices,context,buttons,elements,expireContext(){contextTimers.filter(t=>t.active).forEach(t=>{t.active=false;t.fn()})},setNow:v=>instant=v,apply(from,to){elements.v168ExpenseFrom.value=from;elements.v168ExpenseTo.value=to;elements.v168ExpenseApply.click()}};
}
const results=[];async function test(name,fn){await fn();results.push({name,status:'PASS'});console.log('PASS',name)}
(async()=>{
 await test('Original V272: rejection is hidden and re-enters automatic loading',async()=>{
  let main=0;const h=harness(original,{rpc:async name=>{if(name.includes('context'))return{data:{},error:null};if(++main>12)return new Promise(()=>{});return{data:null,error:{message:'invalid expense range'}}}});h.st.expense.customTo='2026-10-31';h.context.render();await flush(100);assert(main>=12);assert(h.views.length>=4);assert(h.views.every(x=>x.includes('<LOADING>')&&!x.includes('<ERROR>')));h.context.V='Dashboard';
 });
 await test('Candidate: a rejected main RPC is called once and remains a readable error through rerenders',async()=>{
  const h=harness(candidate,{rpc:async name=>name.includes('context')?{data:{},error:null}:{data:null,error:{message:'temporary read failure'}}});h.context.render();await flush();assert.equal(h.calls.filter(x=>!x.name.includes('context')).length,1);assert.equal(h.st.expense.loading,false);assert(h.views.at(-1).includes('<ERROR>temporary read failure'));for(let i=0;i<10;i++)h.context.render();await flush();assert.equal(h.calls.filter(x=>!x.name.includes('context')).length,1);assert(h.elements.retry);
 });
 await test('Candidate: explicit retry makes one new request and succeeds',async()=>{
  let main=0;const h=harness(candidate,{rpc:async(name,args)=>name.includes('context')?{data:{},error:null}:++main===1?{data:null,error:{message:'temporary'}}:{data:{id:'recovered'},error:null}});h.context.render();await flush();h.elements.retry.click();await flush();assert.equal(main,2);assert.equal(h.st.expense.data.id,'recovered');assert(h.views.at(-1).includes('<READY>recovered'));
 });
 await test('Candidate: switching preset clears previous failure and starts only one new request',async()=>{
  let main=0;const h=harness(candidate,{rpc:async(name,args)=>name.includes('context')?{data:{},error:null}:++main===1?{data:null,error:{message:'temporary'}}:{data:{id:args.p_from},error:null}});h.context.render();await flush();h.buttons.find(x=>x.dataset.v168ExpRange==='ytd').click();await flush();assert.equal(main,2);assert.equal(h.st.expense.data.id,'2026-01-01');assert.equal(h.st.expense.error,null);
 });
 await test('Candidate: applying another valid interval issues one request, not render plus forced duplicate',async()=>{
  const h=harness(candidate);h.context.render();await flush();h.apply('2026-09-01','2026-09-30');await flush();assert.equal(h.calls.filter(x=>!x.name.includes('context')).length,2);assert.equal(h.st.expense.data.id,'2026-09-01');
 });
 await test('Candidate: future end is preserved, explained, and never sent or retried',async()=>{
  const h=harness(candidate);h.context.render();await flush();const count=h.calls.length;h.apply('2026-10-01','2026-10-31');await flush();for(let i=0;i<10;i++)h.context.render();await flush();assert.equal(h.calls.length,count);assert.equal(h.st.expense.customTo,'2026-10-31');assert.equal(h.elements.v168ExpenseTo.value,'2026-10-31');assert(h.st.expense.error.includes('Fluxo Diário'));assert(h.st.expense.error.includes('15/10/2026'));assert(!h.elements.retry);assert.equal(h.st.expense.loading,false);
 });
 await test('Candidate: correcting future interval clears the validation error and reads once',async()=>{
  const h=harness(candidate);h.st.expense.customTo='2026-10-31';h.context.render();await flush();assert.equal(h.calls.length,0);h.apply('2026-10-01','2026-10-15');await flush();assert.equal(h.calls.filter(x=>!x.name.includes('context')).length,1);assert.equal(h.st.expense.error,null);assert(h.views.at(-1).includes('<READY>'));
 });
 await test('Candidate: stale response cannot replace newer selected period',async()=>{
  const deferred=[];const h=harness(candidate,{rpc:(name,args)=>name.includes('context')?Promise.resolve({data:{},error:null}):new Promise(resolve=>deferred.push({resolve,args}))});h.context.render();h.apply('2026-09-01','2026-09-30');assert.equal(deferred.length,2);deferred[1].resolve({data:{id:'new'},error:null});await flush();deferred[0].resolve({data:{id:'old'},error:null});await flush();assert.equal(h.st.expense.data.id,'new');assert.equal(h.st.expense.customFrom,'2026-09-01');assert.equal(h.st.expense.loading,false);
 });
 await test('Candidate: navigation while pending does not repaint another route; return uses completed state',async()=>{
  let finish;const h=harness(candidate,{rpc:name=>name.includes('context')?Promise.resolve({data:{},error:null}):new Promise(resolve=>finish=resolve)});h.context.render();h.context.V='Dashboard';const count=h.views.length;finish({data:{id:'done'},error:null});await flush();assert.equal(h.views.length,count);h.context.V='Despesas';h.context.render();await flush();assert.equal(h.calls.filter(x=>!x.name.includes('context')).length,1);assert(h.views.at(-1).includes('<READY>done'));
 });
 await test('Candidate: BRT day boundary rejects UTC-today until Sao Paulo midnight without changing dates',async()=>{
  const h=harness(candidate,{now:'2026-10-16T02:59:59Z'});h.st.expense.customTo='2026-10-16';h.context.render();await flush();assert.equal(h.calls.length,0);assert(h.st.expense.error.includes('15/10/2026'));h.setNow('2026-10-16T03:00:00Z');h.apply('2026-10-01','2026-10-16');await flush();assert.equal(h.calls.filter(x=>!x.name.includes('context')).length,1);assert.equal(h.st.expense.customTo,'2026-10-16');assert.equal(h.st.expense.error,null);
 });
 await test('Both readers accept clamped successful payloads; no response-period mismatch loop in V168',async()=>{
  for(const src of [original,candidate]){const h=harness(src,{rpc:async(name,args)=>({data:name.includes('context')?{}:{id:'clamped',period:{from:args.p_from,to:'2026-10-10'}},error:null})});h.context.render();await flush();assert.equal(h.st.expense.data.id,'clamped');assert.equal(h.st.expense.loading,false);assert.equal(h.calls.filter(x=>!x.name.includes('context')).length,1)}
 });
 await test('Context is still a load barrier, but context rejection cannot discard successful main data',async()=>{
  let contextDone;const h=harness(candidate,{rpc:name=>name.includes('context')?new Promise((resolve,reject)=>contextDone=reject):Promise.resolve({data:{id:'main'},error:null})});h.context.render();await flush();assert.equal(h.st.expense.loading,true);assert.equal(h.st.expense.data,null);contextDone(Error('context unavailable'));await flush();assert.equal(h.st.expense.data.id,'main');assert.equal(h.st.expense.context,null);
 });
 await test('Optional context has a bounded wait; late context cannot overwrite the completed main report',async()=>{
  let finish;const h=harness(candidate,{rpc:name=>name.includes('context')?new Promise(resolve=>finish=resolve):Promise.resolve({data:{id:'main'},error:null})});h.context.render();await flush();assert.equal(h.st.expense.loading,true);h.expireContext();await flush();assert.equal(h.st.expense.loading,false);assert.equal(h.st.expense.data.id,'main');assert.equal(h.st.expense.context,null);finish({data:{late:true},error:null});await flush();assert.equal(h.st.expense.context,null);assert.equal(h.calls.length,2);
 });
 await test('Candidate V175 categories reader independently rejects future before RPC and holds terminal state',async()=>{
  const src=fs.readFileSync('releases/v273/lts-v183-expense-history-candidate.js','utf8');let calls=0,renders=0;const state={expense:{token:0,key:'',data:null,loading:false,error:null}};const c={state,v168:{expense:{tab:'categories'}},expenseRange:()=>({from:'2026-10-01',to:'2026-10-31'}),today:()=> '2026-10-15',Date,Number,Error,String,V:'Despesas',render(){renders++},directRpc:async()=>{calls++;return{data:{},error:null}},currentRead:()=>true};vm.createContext(c);vm.runInContext(block(src,'    async function ensureExpense(force=false){','    async function ensureCards('),c);await c.ensureExpense();for(let i=0;i<10;i++)await c.ensureExpense();assert.equal(calls,0);assert.equal(renders,1);assert.equal(state.expense.loading,false);assert.equal(state.expense.rangeInvalid,true);
 });
 await test('Expense candidate does not alter Flow asset, SQL, financial values, or generic rpcRead behavior',async()=>{assert(candidate.includes(line(original,'rpcRead')));assert(!candidate.includes("FLOWPRESET='Todos'"));assert(fs.existsSync('releases/v273/manifest.json'))});
 fs.writeFileSync('qa/v273-expense-filter-unit.json',JSON.stringify({suite:'V272 expense filter synthetic source contracts',database:false,browser:false,tests:results},null,2)+'\n');console.log('All',results.length,'checks passed.');
})().catch(error=>{console.error(error);process.exitCode=1});
