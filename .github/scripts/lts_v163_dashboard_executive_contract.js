'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const model=require(path.join(root,'lts-dashboard-read-model.js'));

const sufficient=model.build({
  as_of:'2026-09-15',
  liquidity:{bank_cash:1000,d0:200,d3_vested:300,through_d3:1500,fgts_d30:400},
  planning_audited:{covers_horizon:true,worst_before_brl:125,management_point_date:'2026-10-15'},
  horizons:[{id:'30d',date:'2026-10-15',current_liquidity_balance:600},{id:'90d',date:'2026-12-14',current_liquidity_balance:125}]
});
assert.equal(sufficient.decision.state,'sufficient');
assert.equal(sufficient.decision.coveredUntil,'2026-12-14');
assert.equal(sufficient.kpis.shortTerm.value,1200);
assert.equal(sufficient.kpis.shortTerm.method,'bank_cash_plus_d0');

const negative=model.build({
  liquidity:{through_d3:1500,d3_vested:300},
  planning_audited:{first_negative_date:'2026-11-01',worst_before_brl:-250},
  horizons:[{id:'90d',date:'2026-12-14',current_liquidity_balance:-250}]
});
assert.equal(negative.decision.state,'negative');
assert.equal(negative.decision.firstNegative,'2026-11-01');
assert.equal(negative.decision.coveredUntil,'2026-10-31');
assert.equal(negative.kpis.shortTerm.value,1200);
assert.equal(negative.kpis.shortTerm.method,'through_d3_minus_vested');

const unknown=model.build({liquidity:{bank_cash:0},planning_audited:{},horizons:[]});
assert.equal(unknown.decision.state,'unknown');
assert.equal(unknown.kpis.bankCash,0);
assert.equal(unknown.kpis.shortTerm.value,null);

const candidate=fs.readFileSync(path.join(root,'wip35-v163-candidate.html'),'utf8');
const runtime=fs.readFileSync(path.join(root,'lts-dashboard-executive-v1.js'),'utf8');
const readModel=fs.readFileSync(path.join(root,'lts-dashboard-read-model.js'),'utf8');
for(const token of ['index.html?v163-dashboard-executive','wip35-v162-flow-recovery.js','lts-expense-screen-alignment.js','lts-dashboard-executive-v1.js'])assert.ok(candidate.includes(token),`candidate missing ${token}`);
for(const token of ['Tenho dinheiro suficiente?','Primeiro saldo negativo','Caixa coberto até','Pior saldo projetado','Dinheiro em contas','Contas + curto prazo','RSUs vested','FGTS','Despesas (mês)','lts_browser_dashboard_cockpit_v1','mobile_nav_six_fixed:true','financial_writer_changed:false'])assert.ok(runtime.includes(token),`runtime missing ${token}`);
for(const forbidden of ['setInterval(','MutationObserver(','lts_browser_flow_mutate_v2','lts_browser_semantic_feedback_v1'])assert.equal(runtime.includes(forbidden),false,`runtime contains forbidden ${forbidden}`);
assert.ok(readModel.includes('bank_cash_plus_d0'));
assert.ok(readModel.includes('through_d3_minus_vested'));
console.log(JSON.stringify({pass:true,contract:model.CONTRACT,cases:['sufficient','negative','unknown'],flow_preserved:true,expense_preserved:true,writer_changed:false}));
