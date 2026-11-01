'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),crypto=require('node:crypto');
const {sample}=require('./lts_v390_fixtures.cjs'),model=require('../../releases/v390/lts-property-reconciliation-model.js');
const s=sample(),before=JSON.stringify(s),build=x=>model.build(x.wealth,x.page,x.range),m=build(s);
assert(m.bridge.works.coverageExplanation);assert.equal(m.bridge.works.gap,2);
assert.equal(Math.round((m.bridge.works.unique-m.bridge.works.coverageExplanation.amount)*100),Math.round(m.bridge.works.canonical*100));
assert.equal(m.bridge.works.coverageExplanation.bank_payment_confirmed,false);assert.equal(JSON.stringify(s),before);
let cases=0;
for(const change of [
 e=>e.status='unproved',e=>e.amount=3,e=>e.sha256='c'.repeat(64),e=>e.file='missing.xlsm',e=>e.payment_row=31,e=>e.services_payment_row=30,
 e=>e.description='Different item',e=>e.services_description='Different service',e=>e.date='2020-01-15',e=>e.payment_sheet='Other',
 e=>e.cash_sheet='Other',e=>e.cash_column='AB10',e=>e.cash_services_row=null,e=>e.cash_label_absent=false,
 e=>e.bank_payment_confirmed=true,e=>e.ledger_reclassification_allowed=true,e=>e.new_cash_event_allowed=true,
 e=>e.cash_close=0,e=>e.cash_services_amount=null,e=>e.cash_outflow=1,e=>e.cash_services_amount=1]){
 const x=sample();change(x.wealth.wealth.cipo_reconciliation.consortium.itau_source_audit.snapshot_scope.works_cash_coverage_explanation);
 const result=build(x);assert(result.bridge,'proven acquisition comparison retained');assert.equal(result.bridge.works.coverageExplanation,undefined);assert.equal(result.bridge.works.gap,2);cases++;
}
for(const change of [r=>delete r.consortium.itau_source_audit.snapshot_scope.works_cash_coverage_explanation,r=>r.components[1].status='exact',r=>r.components[1].method='raw_exact_description']){
 const x=sample();change(x.wealth.wealth.cipo_reconciliation);assert.equal(build(x).bridge.works.coverageExplanation,undefined);cases++;
}
const base='releases/v389',root='releases/v390',hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const manifest=JSON.parse(fs.readFileSync(root+'/manifest.json')),prov=JSON.parse(fs.readFileSync(root+'/provenance.json'));
for(const[n,h]of Object.entries(manifest.files))assert.equal(hash(root+'/'+n),h,n);
for(const[n,h]of Object.entries(manifest.protected))assert.equal(hash(n),h,n);
for(const[n,h]of Object.entries(prov.protected_base_files))assert.equal(hash(base+'/'+n),h,n);
assert.deepEqual(fs.readdirSync(root).sort(),fs.readdirSync(base).sort());
assert.deepEqual(fs.readdirSync(root).filter(n=>hash(root+'/'+n)!==hash(base+'/'+n)).sort(),[...prov.runtime_changes,'manifest.json','provenance.json'].sort());
const read=(p,n)=>fs.readFileSync(p+'/'+n,'utf8'),bundle='lts-v384-startup-1.js';
assert.equal(read(root,bundle),read(base,bundle).replace(read(base,'lts-property-reconciliation-model.js'),read(root,'lts-property-reconciliation-model.js')).replace(read(base,'lts-v179-cash-recovery.js'),read(root,'lts-v179-cash-recovery.js')));
const live=process.env.LTS_MOBILE_RELEASE||'v390';assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:live,entry:'../releases/'+live+'/app.html'});
assert.equal(prov.financial_reader_logic_changed,false);assert.equal(prov.date_behavior_changed,false);
console.log(JSON.stringify({pass:true,release:'v390',rejection_cases:cases,amounts_and_gap_preserved:true,source_only_not_payment:true,previous_releases_unchanged:true}));
