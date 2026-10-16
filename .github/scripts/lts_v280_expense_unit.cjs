'use strict';
// Local deterministic VM: exact production functions and handlers; fictional data.
// DOM double preserves native input internals as an opaque field, not a date parser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const ROOT=path.resolve('releases/v280'),BASE=path.resolve('releases/v279');
const files=['lts-v183-v168-feedback-safe.js','lts-v169-v168-feedback-closure.js','lts-v183-expense-history-candidate.js'];
const line=(s,n)=>{const x=s.split('\n').find(x=>x.includes(n));assert(x,n);return x.trim()};
const block=(s,a,b)=>{const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i,a);return s.slice(i,j).trim()};
const defer=()=>{let resolve;return{promise:new Promise(r=>resolve=r),resolve:v=>resolve(v)}};
const settle=async()=>{for(let i=0;i<8;i++)await new Promise(r=>setImmediate(r))};
function environment(root=ROOT){
 const [a,b,c]=files.map(f=>fs.readFileSync(path.join(root,f),'utf8')),candidate=a.includes('function bindExpenseDraft()');
 const calls=[],pending=[],pending168=[],auth=[],trace=[];let nodes=new Map(),html='',serial=0,hold=false,hold168=false;
 const st={expense:{key:'ytd',tab:'overview',loading:false,token:0,data:{tag:'seed168'},context:{tag:'context'},error:null,customFrom:'',customTo:''},transactions:{rows:[{tag:'rows'}]}};
 const monthly169={data:{tag:'169'},key:'seed169',error:null,token:0};
 const state={expense:{key:'2026-01-01|2026-09-20',token:0,data:{tag:'seed175'},loading:false,error:null},monthly:{token:0,data:{tag:'monthly175'},key:'2026-01-01|2026-09-20',loading:false,error:null,progress:''}};
 const makeNode=(id,value='')=>({id,value,serial:++serial,isConnected:true,dataset:{},onclick:null,oninput:null,onchange:null,
  focus(){ctx.document.activeElement=this},replaceWith(prior){this.isConnected=false;prior.isConnected=true;nodes.set(id,prior)},
  selectionStart:null,selectionEnd:null,setSelectionRange(start,end,direction){this.selectionStart=start;this.selectionEnd=end;this.selectionDirection=direction}});
 const presetKeys=['ytd','6m','12m','all','custom'];let presets=[];
 const ctx={console,Date,Promise,queueMicrotask,st,v168:st,state,V:'Despesas',BOOT:{generation:1},D:{user:'a'},CF:{kept:10},FLOWFROM:'2026-01-01',FLOWTO:'2026-12-31',ACC:'Itaú',EXP:new Set(['one']),
  esc:x=>String(x??''),date:x=>x,today:()=> '2026-09-20',addMonths:(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+n);return d.toISOString().slice(0,10)},
  document:{activeElement:null,getElementById:id=>nodes.get(id)||null,querySelectorAll:s=>s==='[data-v168-exp-range]'?presets:[]},
  S:{auth:{onAuthStateChange:fn=>auth.push(fn)}},toast2:message=>trace.push({toast:message}),
  rpc:async(name,args)=>{calls.push({owner:'v168',name,args});if(hold168){const gate=defer();pending168.push({gate,args});return gate.promise}return{tag:'v168-'+args.p_from,period:{from:args.p_from,to:args.p_to}}},
  expenseContextWithinBudget:async()=>({tag:'context'}),
  directRpc:async(name,args)=>{calls.push({owner:'v175',name,args});if(hold){const gate=defer();pending.push({gate,args});return gate.promise}return{data:{tag:'v175-'+args.p_from,period:{from:args.p_from,to:args.p_to}}}},
  refresh:route=>{if(ctx.V===route)ctx.render()}};
 ctx.window=ctx;ctx.__LTS_V169_STATE={monthly:monthly169};vm.createContext(ctx);
 const helpers=candidate?block(a,'    // Keep editor-only values','    async function expenseContextWithinBudget'):'';
 const bindings=candidate?'bindExpenseDraft();':line(a,"document.querySelectorAll('[data-v168-exp-range]').forEach(b=>b.onclick=()=>{const key=")+line(a,"const apply=document.getElementById('v168ExpenseApply');if(apply)apply.onclick=");
 vm.runInContext(`(()=>{
 ${line(a,'function expenseRange(key)')}
 ${line(a,'function expenseRangeError(r)')}
 ${helpers}
 ${line(a,'async function ensureExpense(force)')}
 ${line(a,'function periodButtons()')}
 globalThis.controls=periodButtons;globalThis.range168=()=>expenseRange(st.expense.key);globalThis.ensure168=ensureExpense;
 globalThis.bind168=()=>{${bindings}};
 ${candidate?'globalThis.before=preserveExpenseDraftControls;globalThis.restore=restoreExpenseDraftControls;globalThis.draft=()=>syncExpenseDraft();globalThis.sync168=syncExpenseReaders;':''}
 })();`,ctx,{filename:files[0]});
 vm.runInContext(`(()=>{const state=window.__LTS_V169_STATE;globalThis.bind169=()=>{
 ${line(b,"document.querySelectorAll('[data-v168-exp-range]').forEach(b=>{const old=")}
 ${line(b,"const apply=document.getElementById('v168ExpenseApply');if(apply){const old=")}
 }} )();`,ctx,{filename:files[1]});
 const bind175=candidate?block(c,'      const bindPeriodAction=b=>','\n    }\n\n    dashboard='):line(c,"document.querySelectorAll('[data-v168-exp-range]').forEach(b=>{const old=")+line(c,"const apply=document.getElementById('v168ExpenseApply');if(apply){const old=");
 vm.runInContext(`(()=>{const v169=window.__LTS_V169_STATE;
 ${block(c,'function expenseRange(){','async function directRpc(')}
 ${block(c,'function currentRead(','async function loadMonthly(')}
 ${block(c,'async function ensureExpense(force=false){','async function ensureCards(')}
 globalThis.ensure175=ensureExpense;${candidate?'globalThis.sync175=syncExpenseReaders;':''}
 globalThis.bind175=()=>{${bind175}};
 globalThis.after175=()=>{const tab=v168.expense.tab;const r=expenseRange(),key=r.from+'|'+r.to;
 ${line(c,"if(['overview','categories'].includes(tab)&&(state.expense.key!==key")}
 };
 })();`,ctx,{filename:files[2]});
 const rebuild=()=>{
  for(const n of nodes.values())n.isConnected=false;
  if(ctx.document.activeElement)ctx.document.activeElement=null;
  nodes=new Map();presets=[];html=ctx.V==='Despesas'?ctx.controls():'';
  if(ctx.V==='Despesas'){
   for(const key of presetKeys){const n=makeNode('preset-'+key);n.dataset.v168ExpRange=key;presets.push(n)}
   for(const m of html.matchAll(/<input id="([^"]+)"[^>]*value="([^"]*)"/g))nodes.set(m[1],makeNode(m[1],m[2]));
   if(html.includes('id="v168ExpenseApply"'))nodes.set('v168ExpenseApply',makeNode('v168ExpenseApply'));
  }
 };
 ctx.render=()=>{if(candidate){ctx.sync175();ctx.sync168()}const saved=candidate?ctx.before():null;rebuild();if(candidate)ctx.restore(saved);ctx.bind168();ctx.bind169();ctx.bind175();if(ctx.V==='Despesas')ctx.after175()};
 const select=key=>presets.find(n=>n.dataset.v168ExpRange===key).onclick();
 const node=key=>nodes.get(key==='from'?'v168ExpenseFrom':key==='to'?'v168ExpenseTo':key);
 const input=(key,value,event='input')=>{const n=node(key);assert(n,'input '+key);n.value=value;n['on'+event]?.({target:n})};
 const applied=()=>({key:st.expense.key,from:st.expense.customFrom,to:st.expense.customTo,range:JSON.parse(JSON.stringify(ctx.range168()))});
 const slots=()=>JSON.stringify({v168:st.expense,v169:monthly169,v175:state});
 const resolve=(index=0,tag='response')=>{const p=pending[index];assert(p,'pending '+index);p.gate.resolve({data:{tag,period:{from:p.args.p_from,to:p.args.p_to}}})};
 const navigate=route=>{ctx.V=route;ctx.render()};
 ctx.render();return{ctx,st,state,monthly169,calls,pending,pending168,trace,select,node,input,applied,slots,resolve,navigate,hold:()=>hold=true,hold168:()=>hold168=true,html:()=>html,auth:event=>auth.forEach(fn=>fn(event)),renderNav:()=>{ctx.bind169();ctx.bind175()}};
}
const results=[];
async function test(name,fn){await fn();results.push({test:name,result:'PASS'});console.log('PASS '+name)}
async function race(root){const e=environment(root);e.hold();e.select('6m');await settle();assert.equal(e.pending.length,1);e.select('custom');await settle();e.input('from','2026-09-01');e.input('to','2026-09-30');for(let i=0;i<e.pending.length;i++)e.resolve(i);await settle();return e}
async function main(){
 await test('baseline loses the draft under a real delayed V175 response',async()=>{const e=await race(BASE);assert.notEqual(e.node('from').value,'2026-09-01')});
 await test('candidate keeps draft and applied period under the same delayed V175 response',async()=>{const e=await race(ROOT);assert.equal(e.node('from').value,'2026-09-01');assert.equal(e.node('to').value,'2026-09-30');assert.equal(e.applied().key,'6m');assert.equal(e.applied().range.from,'2026-04-01')});
 await test('opening/reopening custom and typing do not mutate applied slots or start reads',async()=>{const e=environment();e.st.expense.customFrom='2025-01-01';e.st.expense.customTo='2025-06-01';const before=e.slots(),applied=e.applied(),count=e.calls.length;e.select('custom');e.select('custom');e.input('from','2026-08-01');e.input('to','2026-08-20','change');e.ctx.render();await settle();assert.equal(e.slots(),before);assert.deepEqual(e.applied(),applied);assert.equal(e.calls.length,count)});
 await test('empty field, other field, native partial node and focus survive repaint',async()=>{const e=environment();e.select('custom');e.input('from','');e.input('to','2026-08-20');const n=e.node('from');n.nativeSegments='09/__/2026';n.focus();e.ctx.render();assert.equal(e.node('from'),n);assert.equal(e.ctx.document.activeElement,n);assert.equal(n.nativeSegments,'09/__/2026');assert.equal(n.value,'');assert.equal(e.node('to').value,'2026-08-20')});
 for(const [name,from,to,message]of [['empty','','2026-08-20',/válido/],['inverted','2026-09-10','2026-09-01',/válido/],['calendar-invalid','2026-02-30','2026-03-01',/válido/],['future','2026-09-01','2026-09-30',/Fluxo Diário/],['before-history','2013-10-09','2026-09-20',/10\/10\/2013/]])await test('invalid Apply '+name+' keeps draft and all applied slots',async()=>{const e=environment();e.select('custom');e.input('from',from);e.input('to',to);const before=e.slots(),applied=e.applied();e.node('v168ExpenseApply').onclick();await settle();assert.equal(e.slots(),before);assert.deepEqual(e.applied(),applied);assert.equal(e.calls.length,0);assert.equal(e.node('from').value,from);assert.equal(e.node('to').value,to);assert.match(e.ctx.draft().error,message);assert.match(e.html(),/role="alert"[^>]*data-v280-expense-draft-error/)});
 await test('valid Apply commits once and clears validation error',async()=>{const e=environment();e.select('custom');e.input('from','');e.node('v168ExpenseApply').onclick();e.input('from','2026-08-01');e.input('to','2026-08-31');e.node('v168ExpenseApply').onclick();await settle();assert.equal(e.applied().key,'custom');assert.equal(e.applied().range.from,'2026-08-01');assert.equal(e.ctx.draft().error,null);assert.equal(e.calls.filter(x=>x.owner==='v175').length,1);assert.equal(e.calls.filter(x=>x.owner==='v168').length,1);assert(e.calls.every(x=>x.args.p_from==='2026-08-01'&&x.args.p_to==='2026-08-31'))});
 await test('same applied preset closes editor without invalidation; different preset discards draft',async()=>{const e=environment();e.select('custom');e.input('from','2026-08-01');const before=e.slots();e.select('ytd');await settle();assert.equal(e.node('from'),undefined);assert.equal(e.slots(),before);e.select('custom');assert.equal(e.node('from').value,'2026-01-01');e.input('from','2026-08-02');e.select('12m');await settle();e.select('custom');assert.equal(e.node('from').value,'2025-10-01');assert.equal(e.applied().key,'12m')});
 await test('tab and route navigation keep draft and native node in the same session',async()=>{const e=environment();e.select('custom');e.input('from','');const n=e.node('from');n.nativeSegments='08/__/2026';e.st.expense.tab='categories';e.ctx.render();assert.equal(e.node('from'),n);e.navigate('Fluxo Diário');e.navigate('Despesas');assert.equal(e.node('from'),n);assert.equal(n.nativeSegments,'08/__/2026');assert.equal(n.value,'')});
 await test('repeated renderNav does not stack invalidation or clear V169 on invalid Apply',async()=>{const e=environment();e.select('custom');e.input('from','');for(let i=0;i<4;i++)e.renderNav();const before=e.slots();e.node('v168ExpenseApply').onclick();await settle();assert.equal(e.slots(),before);e.input('from','2026-09-01');e.input('to','2026-09-10');for(let i=0;i<4;i++)e.renderNav();const token=e.state.monthly.token;e.node('v168ExpenseApply').onclick();await settle();assert.equal(e.state.monthly.token,token+1);assert.equal(e.calls.filter(x=>x.owner==='v175').length,1)});
 await test('BOOT generation retires draft and old Apply/preset actions before invalidation',async()=>{const e=environment();e.select('custom');e.input('from','2026-08-01');const apply=e.node('v168ExpenseApply').onclick;const oldPreset=e.ctx.document.querySelectorAll('[data-v168-exp-range]').find(n=>n.dataset.v168ExpRange==='6m').onclick;e.ctx.BOOT.generation++;e.ctx.D={user:'b'};const before=e.slots();apply();oldPreset();assert.equal(e.slots(),before);assert.equal(e.calls.length,0);e.ctx.render();assert.equal(e.node('from'),undefined);e.select('custom');assert.equal(e.node('from').value,'2026-01-01')});
 await test('fallback D identity and auth callback also discard editor without querying',async()=>{for(const mode of ['fallback','auth']){const e=environment();if(mode==='fallback'){delete e.ctx.BOOT;e.ctx.render()}e.select('custom');e.input('from','2026-08-01');if(mode==='fallback')e.ctx.D={user:'b'};else e.auth('SIGNED_OUT');e.ctx.render();assert.equal(e.node('from'),undefined);await settle();assert(e.calls.every(x=>x.args.p_from==='2026-01-01'))}});
 await test('external applied-signature change discards unrelated editor',async()=>{const e=environment();e.select('6m');await settle();e.select('custom');e.input('from','2026-08-01');e.st.expense.key='ytd';e.ctx.render();assert.equal(e.node('from'),undefined);e.select('custom');assert.equal(e.node('from').value,'2026-01-01')});
 await test('obsolete V175 response cannot replace newly applied data or draft',async()=>{const e=environment();e.hold();e.select('6m');await settle();e.select('custom');e.input('from','2026-09-01');e.input('to','2026-09-10');e.node('v168ExpenseApply').onclick();await settle();assert.equal(e.pending.length,2);e.input('to','2026-09-15');e.resolve(1,'new');await settle();e.resolve(0,'old');await settle();assert.equal(e.state.expense.data.tag,'new');assert.equal(e.node('to').value,'2026-09-15');assert.equal(e.applied().range.to,'2026-09-10')});
 await test('late applied response leaves invalid draft and its error intact',async()=>{const e=environment();e.hold();e.select('6m');await settle();e.select('custom');e.input('from','2026-09-01');e.input('to','2026-09-30');e.node('v168ExpenseApply').onclick();e.resolve();await settle();assert.match(e.ctx.draft().error,/Fluxo Diário/);assert.equal(e.node('to').value,'2026-09-30');assert.equal(e.applied().key,'6m');assert.equal(e.calls.filter(x=>x.owner==='v175').length,1)});
 await test('retry reads applied period, not draft, and cash-flow state stays unchanged',async()=>{const e=environment();const cf=JSON.stringify([e.ctx.CF,e.ctx.FLOWFROM,e.ctx.FLOWTO,e.ctx.ACC,[...e.ctx.EXP]]);e.select('custom');e.input('from','2026-08-01');e.input('to','2026-08-31');await e.ctx.ensure175(true);await e.ctx.ensure168(true);await settle();assert(e.calls.every(x=>x.args.p_from==='2026-01-01'&&x.args.p_to==='2026-09-20'));assert.equal(JSON.stringify([e.ctx.CF,e.ctx.FLOWFROM,e.ctx.FLOWTO,e.ctx.ACC,[...e.ctx.EXP]]),cf);assert.equal(e.node('from').value,'2026-08-01')});
 await test('all presets use unchanged applied date ranges',async()=>{const e=environment();for(const [key,from]of [['all','2013-10-10'],['12m','2025-10-01'],['6m','2026-04-01'],['ytd','2026-01-01']]){e.select(key);await settle();assert.equal(e.applied().range.from,from);assert.equal(e.applied().range.to,'2026-09-20')}});
 await test('new generation with applied custom seeds only saved dates, never the old draft',async()=>{const e=environment();e.select('custom');e.input('from','2026-08-01');e.input('to','2026-08-31');e.node('v168ExpenseApply').onclick();await settle();e.input('from','');e.input('to','2026-09-30');const old=e.node('from');e.ctx.BOOT.generation++;e.ctx.D={user:'b'};e.ctx.render();assert.notEqual(e.node('from'),old);assert.equal(e.node('from').value,'2026-08-01');assert.equal(e.node('to').value,'2026-08-31')});
 await test('obsolete V168 response cannot replace current report or editing nodes',async()=>{const e=environment();e.hold168();e.select('6m');await settle();e.select('custom');e.input('from','2026-09-01');e.input('to','2026-09-10');e.node('v168ExpenseApply').onclick();await settle();assert.equal(e.pending168.length,2);e.input('from','');const n=e.node('from');e.pending168[1].gate.resolve({tag:'new168'});await settle();e.pending168[0].gate.resolve({tag:'old168'});await settle();assert.equal(e.st.expense.data.tag,'new168');assert.equal(e.node('from'),n);assert.equal(n.value,'')});
 const result={scope:'Exact V168/V169/V175 snippets with deterministic DOM double; native segment behavior needs browser verification',sha256:Object.fromEntries(files.map(f=>[f,crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,f))).digest('hex')])),passed:results.length,results};fs.writeFileSync('qa/v280-expense-unit-results.json',JSON.stringify(result,null,2)+'\n');return result;
}
module.exports={environment,settle,defer,ROOT,BASE};if(require.main===module)main().catch(e=>{console.error(e);process.exitCode=1});
