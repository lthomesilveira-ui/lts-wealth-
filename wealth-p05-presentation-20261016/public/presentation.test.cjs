'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=__dirname,src=fs.readFileSync(path.join(root,'lts-v226-card-composition.js'),'utf8');
const a=src.indexOf('function documentaryPaymentNote('),b=src.indexOf('    const v233Formatters',a);
const note=vm.runInNewContext('('+src.slice(a,b).trim()+')');
const n=src.indexOf('function upcomingPanel('),m=src.indexOf('    function unresolvedPanel(',n);
const d=src.indexOf('function detailBody('),e=src.indexOf('    async function openDetail(',d);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const date=s=>s.split('-').reverse().join('/');
const fixture=JSON.parse(fs.readFileSync(path.join(root,'synthetic-fixture.json')));
const ev=fixture.expected;
const base={invoice_source_id:'33333333-3333-4333-8333-333333333333',basis:'open_finance_invoice_v263',amount:100,month:'2026-10-01',due_date:'2026-10-12',payment_status:'payment_not_reported',documentary_payment_evidence:ev,items:[{amount:60},{amount:40}]};
let count=0;const check=(label,fn)=>{fn();count++;};
function render(cycle){
 const context={documentaryPaymentNote:note,st:{cycles:{complete:true,active_billing_accounts:1,cards:[{bank:'Banco sintético',family:'synthetic',last4:'0000',cycles:[cycle]}]},loading:false,error:''},esc,date,month:s=>s,names:{synthetic:'Cartão sintético'},sum:xs=>xs.reduce((a,b)=>a+Number(b),0),money:n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n),cycleTotal:xs=>xs.reduce((s,x)=>s+x.amount,0),totalLabel:n=>'R$ '+Number(n).toFixed(2),openButton:(card,c,label)=>'<button>'+label+'</button>',sourceStamp:()=>'',unresolvedPanel:()=>'',grouped:()=>[],compositionEvidence:()=>({expected:100,complete:true,independentTotal:true,label:'Valor recebido da fatura',coverage:'total confere'}),category:()=>'',categoryCell:()=>'',descriptionCell:()=>'',formulaSource:()=>'',alternativeSource:()=>''};
 vm.createContext(context);
 vm.runInContext(src.match(/    const source=x=>.*;/)[0]+src.slice(n,m)+'\n'+src.slice(d,e),context);
 return {summary:context.upcomingPanel(false),detail:context.detailBody({...cycle,items:[]},cycle)};
}
for(const payment_status of ['payment_not_reported','payment_reported','paid',null]){
 check('valid note + badge / '+payment_status,()=>{
 const cycle={...structuredClone(base),payment_status},before=JSON.stringify(cycle),out=render(cycle);
 for(const html of [out.summary,out.detail]){assert.match(html,/Emissor: pagamento integral informado em 12\/10\/2026/);assert.match(html,/Banco: débito lançado no extrato em 14\/10\/2026/);assert.doesNotMatch(html,/pagamento não informado|precisa ser conferida novamente/);}
 assert.match(out.summary,/Fatura recebida do banco · pagamento integral informado pelo emissor/);
 assert.equal(JSON.stringify(cycle),before);assert.equal(cycle.due_date,'2026-10-12');assert.equal(cycle.month,'2026-10-01');
 });
}
for(const payment_status of ['payment_not_reported','payment_reported','paid',null]) {
 check('validated full payment removes only open composition prefix / '+payment_status,()=>{
  const c={...structuredClone(base),basis:'open_finance_composition',payment_status},before=JSON.stringify(c),html=render(c).summary;
  assert.match(html,/Compras recebidas · pagamento integral informado pelo emissor/);
  assert.doesNotMatch(html,/Em aberto|pagamento não informado/);assert.match(html,/Emissor: pagamento integral informado em 12\/10\/2026/);
  assert.equal(JSON.stringify(c),before);
 });
}
for(const patch of [
 {documentary_payment_evidence:undefined},
 {documentary_payment_evidence:{status:'source_changed',cash_effect:'none'}},
 {documentary_payment_evidence:{...ev,issuer_payment_type:'PARTIAL_PAYMENT'}},
 {documentary_payment_evidence:{...ev,amount:99}},
 {documentary_payment_evidence:{...ev,amount:'100'}},
 {amount:[100]},
 {documentary_payment_evidence:{...ev,currency:'USD'}},
 {documentary_payment_evidence:{...ev,basis:'reviewed_documentary_alias_and_posted_bank_transaction'}}
]) check('nonvalidated composition keeps original open prefix '+JSON.stringify(patch),()=>{
 const c={...structuredClone(base),basis:'open_finance_composition',...patch},before=JSON.stringify(c),html=render(c).summary;
 assert.match(html,/Em aberto · compras recebidas · pagamento não informado/);
 assert.doesNotMatch(html,/Compras recebidas · pagamento integral informado pelo emissor/);assert.equal(JSON.stringify(c),before);
});
for(const patch of [{issuer_payment_type:'PARTIAL_PAYMENT'},{bank_posting_status:'PENDING'},{bank_posting_date:'2026-10-13'},{issuer_payment_date:'2026-02-30'},{issuer_payment_date:'<img>'},{payment_date:'invalid'},{currency:'USD'},{cash_effect:'debit'},{amount:99},{amount:0},{amount:'Infinity'},{status:'paid'}]){
 check('reject invalid note and badge '+JSON.stringify(patch),()=>{
 const c={...structuredClone(base),documentary_payment_evidence:{...ev,...patch}};
 assert.equal(note(c,esc,date),'');assert.equal(note(c,null,null,'label'),' · pagamento não informado');
 const html=render(c).summary;assert.doesNotMatch(html,/pagamento integral informado pelo emissor|Emissor: pagamento integral/);
 });
}
for (const value of [true, false, [100], [], {}, '100', NaN, Infinity, -Infinity, null, undefined]) {
 check('reject non-numeric evidence amount '+String(value),()=>{
  const c={...structuredClone(base),documentary_payment_evidence:{...ev,amount:value}};
  assert.equal(note(c,esc,date),'');assert.equal(note(c,null,null,'label'),' · pagamento não informado');
 });
 check('reject non-numeric cycle amount '+String(value),()=>{
  const c={...structuredClone(base),amount:value};
  assert.equal(note(c,esc,date),'');assert.equal(note(c,null,null,'label'),' · pagamento não informado');
 });
}
for (const [amount, cycleAmount] of [[true,1],[1,true],[[100],100],[100,[100]]]) {
 check('coercion reproduction rejected '+JSON.stringify([amount,cycleAmount]),()=>{
  const c={...structuredClone(base),amount:cycleAmount,documentary_payment_evidence:{...ev,amount}};
  assert.equal(note(c,esc,date),'');assert.equal(note(c,null,null,'label'),' · pagamento não informado');
 });
}
check('genuine stale source remains visible',()=>{
 const c={...base,documentary_payment_evidence:{status:'source_changed',cash_effect:'none'}};
 assert.match(render(c).summary,/precisa ser conferida novamente/);assert.equal(note(c,null,null,'label'),' · pagamento não informado');
});
check('unrelated/no evidence remains source label',()=>{const c={...base};delete c.documentary_payment_evidence;assert.equal(note(c,esc,date),'');assert.equal(note(c,null,null,'label'),' · pagamento não informado');});
check('original documentary path remains separate',()=>{const c={...base,documentary_payment_evidence:{status:'identified_in_statement',basis:'reviewed_documentary_alias_and_posted_bank_transaction',payment_date:'2026-10-14',amount:100,currency:'BRL',cash_effect:'none'}};assert.match(note(c,esc,date),/Pagamento identificado no extrato em 14\/10\/2026/);assert.equal(note(c,null,null,'label'),' · pagamento não informado');});
check('formatter output escaped',()=>{assert.match(note(base,esc,()=>'<img src=x onerror=alert(1)>'),/&lt;img/);assert.doesNotMatch(note(base,esc,()=>'<img>'),/<img>/);});
check('no private data in expected annotation',()=>{const json=JSON.stringify(ev);assert.doesNotMatch(json,/manifest|raw_hash|source_id|user_id|documentary_sources|NEVER_RETURN/);assert.equal(Object.keys(ev).length,10);});
check('RPC unchanged and only two note sites',()=>{assert.equal((src.match(/documentaryPaymentNote\(cycle\|\|data,esc,date\)/g)||[]).length,1);assert.equal((src.match(/documentaryPaymentNote\(cycle,esc,date\)/g)||[]).length,1);assert.equal((src.match(/documentaryPaymentNote\(cycle,null,null,'label',source\(cycle.basis\)\)/g)||[]).length,1);assert.ok(src.includes("rpc('lts_browser_card_cycles_v229')"));});
check('no source writes or expense reader in presentation SQL',()=>{const sql=fs.readFileSync(path.join(root,'candidate-rollback-default.sql'),'utf8');assert.doesNotMatch(sql,/\b(?:UPDATE|DELETE FROM|INSERT INTO|ALTER TABLE|CREATE TABLE)\b/i);assert.doesNotMatch(sql,/lts_expense_effective|lts_current_received|lts_card_cycles_v226\(/);assert.ok(sql.endsWith('ROLLBACK;\n'));});

const out=render(base);fs.writeFileSync(path.join(root,'synthetic-summary.html'),out.summary);fs.writeFileSync(path.join(root,'synthetic-detail.html'),out.detail);
fs.writeFileSync(path.join(root,'local-test-result.json'),JSON.stringify({status:'passed',ui_json_cases:count,prior_v272_contract_cases:10,scope:'Exact candidate note, badge, upcomingPanel and detailBody extracted into isolated VM; synthetic data only',postgres_sql_executed:false,remote_reads:0,external_changes:0},null,2)+'\n');
console.log('PASS: '+count+' isolated UI/JSON cases; exact summary/detail functions.');
