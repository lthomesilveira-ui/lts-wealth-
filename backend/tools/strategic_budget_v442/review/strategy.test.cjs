const assert=require('node:assert/strict'),{derive,kind}=require('./strategy.js');
const months=Array.from({length:12},(_,i)=>({month:`2026-${String(i+1).padStart(2,'0')}`,income_target:3000,income_regular:0}));
const row=(category,ref)=>({category,reference_monthly:ref,months:months.map(m=>({month:m.month,target:ref,target_basis:'history',actual:0,card_actual:0,pending:0}))});
const original={ok:true,as_of:'2026-11-12',year:2026,months,rows:[row('Condomínio',3500),row('Restaurantes',600),row('Categoria desconhecida',100)],income_approvals:{},category_aliases:{}};
const flow={current_future:{events:[],from:'2026-11-12',to:'2026-12-31'}},cards={cards:[]};let n=0;
function test(name,fn){fn();n++;console.log('PASS',name)}
test('Unknown category remains unreviewed',()=>assert.equal(kind('Categoria desconhecida'),'unreviewed'));
test('History never becomes a recommendation nor zero merely due to deficit',()=>{const p=derive(original,flow,cards);assert.equal(p.rows[1].months[11].target,null);assert.equal(p.months[11].target,null);assert.equal(p.rows[1].months[11].strategy.history,600)});
test('Documented proposed amount is retained despite income shortfall',()=>{const p=structuredClone(original);p.planning={months:{'2026-12':{'Restaurantes':{status:'reviewed_proposal',target:500,reason:'Synthetic reviewed alternative',evidence:['Synthetic case: recurring need and feasible reduction compared']}}}};const q=derive(p,flow,cards);assert.equal(q.rows[1].months[11].target,500);assert.equal(q.rows[1].months[11].target_basis,'proposal')});
test('Incomplete recommendation evidence is not accepted',()=>{const p=structuredClone(original);p.planning={months:{'2026-12':{'Restaurantes':{status:'reviewed_proposal',target:500,reason:'',evidence:[]}}}};assert.equal(derive(p,flow,cards).rows[1].months[11].target,null)});
test('Reviewed proposal does not erase incurred spending',()=>{const p=structuredClone(original);p.rows[1].months[10].actual=700;p.planning={months:{'2026-11':{'Restaurantes':{status:'reviewed_proposal',target:500,reason:'Synthetic test',evidence:['Synthetic source']}}}};assert.equal(derive(p,flow,cards).rows[1].months[10].target,700)});
test('Owner approved target preserved',()=>{const p=structuredClone(original);p.rows[1].months[11].target_basis='owner';p.rows[1].months[11].target=450;assert.equal(derive(p,flow,cards).rows[1].months[11].target,450)});
test('Input untouched',()=>{const before=JSON.stringify(original);derive(original,flow,cards);assert.equal(JSON.stringify(original),before)});

test('Received noninstallment card purchase remains known floor, payment excluded',()=>{const cs={cards:[{family:'synthetic',cycles:[{month:'2026-12-01',items:[{source_id:'one',provider_status:'PENDING',amount:75,category:'Restaurantes'},{source_id:'payment',provider_status:'POSTED',amount:75,category:'Restaurantes',is_payment:true}]}]}]};const q=derive(original,flow,cs);assert.equal(q.rows[1].months[11].strategy.floor,75);assert.equal(q.rows[1].months[11].target,null)});

test('Payroll exclusion requires matching identity and net-income arithmetic',()=>{const p=structuredClone(original),e={event_date:'2026-12-31',description:'Empréstimo Coopharma',category:'Categoria desconhecida',signed_amount:-400,source:'synthetic_schedule',source_ref:'loan-one',competence_month:'2026-12',competence_evidence:['Synthetic dated service record']};const f={current_future:{...flow.current_future,events:[e]}};assert.equal(derive(p,f,cards).rows[2].months[11].strategy.floor,400);p.planning={payroll_withholding:[{date:e.event_date,source:e.source,source_ref:e.source_ref,amount:400,base_income:2000,net_income:1600,evidence:['synthetic documentary withholding']} ]};assert.equal(derive(p,f,cards).rows[2].months[11].strategy.floor,0);p.planning.payroll_withholding[0].net_income=1700;assert.equal(derive(p,f,cards).rows[2].months[11].strategy.floor,400)});

test('History-based cash estimates do not become contractual floors',()=>{const f={current_future:{...flow.current_future,events:[{event_date:'2026-12-01',source:'planning_projection_v412',source_ref:'estimated',description:'Parcela de despesa estimada',category:'Restaurantes',signed_amount:-900,confidence:'owner_authorized_12m_history'}]}};assert.equal(derive(original,f,cards).rows[1].months[11].strategy.floor,0)});
test('Cash payment date never silently becomes service competence',()=>{const e={event_date:'2026-12-05',source:'synthetic',source_ref:'condo',description:'Condomínio',category:'Condomínio',signed_amount:-400};const f={current_future:{...flow.current_future,events:[e]}};let q=derive(original,f,cards);assert.equal(q.rows[0].months[11].strategy.floor,0);assert.equal(q.strategy.cash_without_competence[0].amount,400);e.competence_month='2026-11';e.competence_evidence=['Synthetic service month record'];q=derive(original,f,cards);assert.equal(q.rows[0].months[10].strategy.floor,400);assert.equal(q.rows[0].months[11].strategy.floor,0);assert.equal(q.strategy.cash_without_competence.length,0)});
test('Exact canonical card identity prevents a second commitment under a beneficiary label',()=>{
 const p=structuredClone(original);p.rows[1].months[10].actual=175;p.rows[1].months[10].card_actual=175;
 const it={source_id:'canonical-card-one',provider_status:'PENDING',amount:175,category:'Pessoa — Restaurantes',purchase_date:'2026-11-03'};
 const cs={cards:[{family:'synthetic',cycles:[{month:'2026-11-01',items:[it]}]}]};
 p.card_category_evidence=[{source_ref:it.source_id,purchase_date:it.purchase_date,raw_category:it.category,category:'Restaurantes',amount:175}];
 const before=JSON.stringify([p,cs]),q=derive(p,flow,cs);
 assert.equal(q.rows[1].months[10].strategy.floor,175);assert(!q.rows.some(r=>r.category===it.category));assert.equal(JSON.stringify([p,cs]),before);
 for(const field of ['source_ref','purchase_date','raw_category','amount']){const changed=structuredClone(p);changed.card_category_evidence[0][field]=field==='amount'?174:'changed';assert(derive(changed,flow,cs).rows.some(r=>r.category===it.category),field);}
 const conflict=structuredClone(p);conflict.card_category_evidence.push({...p.card_category_evidence[0],category:'Outra categoria'});assert(derive(conflict,flow,cs).rows.some(r=>r.category===it.category));
});
test('Projected installment reuses exact original purchase category without a new transaction',()=>{
 const p=structuredClone(original),it={source_id:'canonical-installment',provider_status:'PROJECTED',amount:80,category:'Pessoa — Restaurantes',purchase_date:'2026-10-03',total_installments:4,installment_number:3};
 p.card_category_evidence=[{source_ref:it.source_id,purchase_date:it.purchase_date,raw_category:it.category,category:'Restaurantes',amount:80}];
 const q=derive(p,flow,{cards:[{family:'synthetic',cycles:[{month:'2026-12-01',items:[it]}]}]});assert.equal(q.rows[1].months[11].strategy.floor,80);assert(!q.rows.some(r=>r.category===it.category));
});
test('A received charge and its credit cancel without becoming a second commitment',()=>{
 const cs={cards:[{family:'synthetic',cycles:[{month:'2026-11-01',items:[{source_id:'fee',category:'Restaurantes',amount:75,provider_status:'POSTED'},{source_id:'refund',category:'Restaurantes',amount:-75,provider_status:'POSTED'}]}]}]};
 const q=derive(original,flow,cs);assert.equal(q.rows[1].months[10].strategy.floor,0);assert.equal(q.rows[1].months[10].actual,0);
});
test('Signed recorded card credits are subtracted from overlap before adding distinct purchases',()=>{
 const p=structuredClone(original);p.rows[1].months[10].actual=-50;p.rows[1].months[10].card_actual=-75;
 const cs={cards:[{family:'synthetic',cycles:[{month:'2026-11-01',items:[{source_id:'purchase',category:'Restaurantes',amount:100,provider_status:'POSTED'},{source_id:'credit',category:'Restaurantes',amount:-75,provider_status:'POSTED'}]}]}]};
 const q=derive(p,flow,cs);assert.equal(q.rows[1].months[10].strategy.floor,50);assert.equal(q.rows[1].months[10].actual,-50);
});
test('Missing amounts cannot become zero commitments',()=>assert.throws(()=>derive(original,flow,{cards:[{family:'synthetic',cycles:[{month:'2026-12-01',items:[{source_id:'one',category:'Restaurantes',amount:null,provider_status:'PENDING'}]}]}]}),/amount unavailable/));
test('An unknown received purpose stays in the canonical unknown bucket exactly once',()=>{
 const p=structuredClone(original);p.rows.push(row('Sem classificação',null));p.rows[3].months[10].actual=25;p.rows[3].months[10].card_actual=25;
 const q=derive(p,flow,{cards:[{family:'synthetic',cycles:[{month:'2026-11-01',items:[{source_id:'unresolved',category:'A classificar',amount:25,provider_status:'PENDING'}]}]}]});
 assert(!q.rows.some(r=>r.category==='A classificar'));assert.equal(q.rows[3].months[10].strategy.floor,25);assert.equal(q.rows[3].months[10].actual,25);
});
console.log(n+' tests passed; synthetic only; owner-session verification is separate');


// Exact malformed-payroll evidence regression; synthetic only.
require('./payroll-proof-regression.cjs');
