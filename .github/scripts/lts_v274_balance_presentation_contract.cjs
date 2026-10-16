const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const source=fs.readFileSync('releases/v274/lts-v228-bank-flow.js','utf8');
const original=fs.readFileSync('releases/v273/lts-v228-bank-flow.js','utf8');
class Element{constructor(text=''){this.textContent=text;this.children=[];this.style={};this.title='';}appendChild(e){this.children.push(e);return e;}querySelector(s){return this.children.find(e=>'.'+e.className===s)||null;}insertAdjacentElement(_,e){elements[e.id]=e;}remove(){delete elements[this.id];}}
let elements;
function boot(src){elements={ltsBankEvidence:new Element()};const today={date:'2026-10-15',is_today:true,Itaú:{balance_basis:'observed_bank_position_and_recent_movements',opening_balance:1000,balance:950.30,net:250},fix86_columns:{saldo_anterior_operacional:1000}};const row=new Element();row.children=Array.from({length:8},(_,i)=>new Element(i===4?'R$ 1.450,30':'untouched'));elements['d-'+today.date]=row;
 const cash={status:'ready',date:today.date,data:{as_of:today.date,cash:1200.30,day:{Itaú:{balance:700.30},Bradesco:{balance:0},C6:{balance:500}}}};
 const ctx={window:{__LTS_V178_STATE:{cash},__LTS_V178_REVIEW:{cashComplete:s=>s.status==='ready'&&s.date===today.date&&s.data.as_of===today.date}},today:()=>today.date,V:'Fluxo Diário',ACC:'Consolidado',FLOWQ:{observed_bank_movements:{}},Intl,Number,Object,Math,document:{getElementById:id=>elements[id],createElement:()=>new Element(),querySelectorAll:()=>[],querySelector:()=>null},mergedFlowDays:()=>[today],dayEvents:()=>[],flowVals:()=>({prev:1,en:400,ex:150,fin:1450.30}),flowSemanticTitle:e=>e.description,flowSemanticMeta:()=>'',render:()=>42};
 vm.createContext(ctx);vm.runInContext('('+src.slice(src.indexOf('function runtime()'),src.indexOf('\n function install()'))+')()',ctx);return{ctx,cash,today,row,run:()=>ctx.render()};}
let checks=0;function check(fn){fn();checks++;}
let h=boot(source);
check(()=>assert(elements.ltsBankEvidence.textContent.includes('inclusive no dia de hoje')));
check(()=>assert(elements.v274ReceivedPosition.textContent.includes('1.200,30')));
check(()=>assert(elements.v274ReceivedPosition.textContent.includes('Não é uma consulta em tempo real')));
check(()=>assert.equal(h.row.children[4].textContent,'R$ 1.450,30'));
check(()=>assert(h.row.children[4].title.includes('previsões')));
check(()=>{h.run();h.run();assert.equal(h.row.children[4].children.length,1)});
check(()=>{h.ctx.ACC='Itaú';h.run();assert(elements.v274ReceivedPosition.textContent.includes('700,30'));assert(!elements.v274ReceivedPosition.textContent.includes('1.200,30'))});
check(()=>{h.ctx.ACC='Bradesco';h.run();assert(elements.v274ReceivedPosition.textContent.includes('R$ 0,00'))});
check(()=>{h.ctx.ACC='C6';h.run();assert(elements.v274ReceivedPosition.textContent.includes('500,00'))});
check(()=>{h.cash.status='loading';h.run();assert(elements.v274ReceivedPosition.textContent.includes('indisponível'));assert(!elements.v274ReceivedPosition.textContent.includes('500,00'))});
check(()=>{h.cash.status='ready';h.cash.data.as_of='2026-10-14';h.run();assert(elements.v274ReceivedPosition.textContent.includes('indisponível'))});
check(()=>{h.cash.data.as_of=h.today.date;h.cash.data.day.C6.balance=null;h.run();assert(elements.v274ReceivedPosition.textContent.includes('indisponível'))});
for(const value of ['   ',false,[],[1],{},NaN,Infinity])check(()=>{h.cash.data.day.C6.balance=value;h.run();assert(elements.v274ReceivedPosition.textContent.includes('indisponível'))});
for(const value of [0,'0',' 12.50 ',-2])check(()=>{h.cash.data.day.C6.balance=value;h.run();assert(!elements.v274ReceivedPosition.textContent.includes('indisponível'))});
check(()=>{h.ctx.V='Dashboard';h.run();assert(!elements.v274ReceivedPosition)});
check(()=>{h.ctx.V='Fluxo Diário';h.ctx.ACC='Consolidado';h.run();assert(elements.v274ReceivedPosition.textContent.includes('1.200,30'))});
const inputs=[{date:'2026-10-15',is_today:true,Itaú:{balance_basis:'observed_bank_position_and_recent_movements'},fix86_columns:{saldo_anterior_operacional:1000}},{date:'2027-01-01',Itaú:{balance:99}},{date:'2026-01-01',historical:true,Itaú:{balance_basis:'relative_tracked_bank_ledger'},fix86_columns:{}},{date:'2027-02-01',projection_complete:false,C6:{projection_complete:false}}];
for(const account of ['Consolidado','Itaú','C6'])for(const input of inputs)check(()=>{const a=boot(original),b=boot(source);a.ctx.ACC=b.ctx.ACC=account;const before=JSON.stringify(input);assert.equal(JSON.stringify(a.ctx.flowVals(input)),JSON.stringify(b.ctx.flowVals(input)));assert.equal(JSON.stringify(input),before)});
check(()=>assert(!/\b(fetch|rpc|execute_sql)\s*\(/.test(source)));
console.log(JSON.stringify({passed:checks,scope:'Full presentation runtime with DOM doubles; flow calculation parity; not browser or production QA'},null,2));
