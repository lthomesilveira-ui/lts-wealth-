'use strict';
// Read-only local test: execute the exact inherited fixture generators and the
// candidate's exact coverage helper. No browser, server, SQL, or network.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const SCRIPTS=path.resolve(process.env.LTS_PROJECTION_INHERITED_SCRIPTS||__dirname);
const CANDIDATE=path.resolve(process.env.LTS_PROJECTION_CANDIDATE_ROOT||'releases/v283');
const OUTPUT=path.resolve(process.env.LTS_PROJECTION_FIXTURE_OUTPUT||'projection-fullstack-fixture-results.json');
const candidate=fs.readFileSync(path.join(CANDIDATE,'lts-v179-cash-recovery.js'),'utf8');
const coverageSource=candidate.slice(candidate.indexOf('  function forecastCoverage('),candidate.indexOf('  function mergeForecast('));
assert(coverageSource.startsWith('  function forecastCoverage('));
const coverage=vm.runInNewContext('('+coverageSource.trim()+')',{Date,Set,Number});
const sharedPath=path.join(SCRIPTS,'lts_v284_synthetic_fixture.cjs'),shared=require(sharedPath);
const paymentPath=path.join(SCRIPTS,'lts_v284_payment_fullstack.js'),payment=fs.readFileSync(paymentPath,'utf8');
const from=payment.indexOf('function dayRow('),to=payment.indexOf('\nfunction awards()',from);assert(from>=0&&to>from);
const paymentSource=payment.slice(from,to);const paymentFlow=vm.runInNewContext(paymentSource+';flow',{Date});
const hash=x=>crypto.createHash('sha256').update(typeof x==='string'?x:JSON.stringify(x)).digest('hex');
const cases=[['2026-10-16','2027-12-31','2026-10-16',442],['2026-10-11','2027-12-31','2026-10-16',442],['2027-01-01','2027-12-31','2027-01-01',365],['2028-02-28','2028-03-01','2028-02-28',3],['2027-12-31','2027-12-31','2027-12-31',1]];
let assertions=0;const checks=[];
const check=(ok,name)=>{assert(ok,name);assertions++};
for(const [kind,make]of [['shared ledger/boot',(a,b)=>shared.response('lts_browser_flow_v242',{p_from:a,p_to:b})],['payment/fullstack',(a,b)=>paymentFlow(a,b)]]){
 for(const [from,to,asof,expected]of cases){
  const payload=make(from,to),before=hash(payload),actual=coverage([payload],asof,to),days=payload.flow.current_future.days;
  check(actual.complete===true,kind+' covers '+from+' to '+to);
  check(actual.expected_days===expected&&actual.received_days===expected,kind+' expected count');
  check(new Set(days.map(d=>d.date)).size===days.length,kind+' unique generated dates');
  check(before===hash(payload),kind+' exact fixture untouched by coverage validation');
  const missing=structuredClone(payload);missing.flow.current_future.days=missing.flow.current_future.days.filter(d=>d.date!==asof);
  check(coverage([missing],asof,to).complete===false,kind+' missing day remains failure');
  const duplicate=structuredClone(payload);duplicate.flow.current_future.days.push(structuredClone(days.find(d=>d.date===asof)));
  check(coverage([duplicate],asof,to).reason==='duplicate_date',kind+' duplicate remains failure');
  const unknown=structuredClone(payload);unknown.flow.current_future.days.find(d=>d.date===asof).fix86_columns.saldo_apos_fgts=null;
  check(coverage([unknown],asof,to).reason==='unknown_resource',kind+' unknown remains failure');
  checks.push({fixture:kind,from,to,as_of:asof,expected_days:expected,pass:true});
 }
}
const out={pass:true,assertions,cases:checks,scope:'exact existing daily fixture generators; complete daily calendars retained; missing/duplicate/unknown counterexamples fail; no browser/fullstack execution',source_hashes:{shared_fixture:hash(fs.readFileSync(sharedPath,'utf8')),payment_fixture_functions:hash(paymentSource),coverage_candidate:hash(candidate)}};
fs.writeFileSync(OUTPUT,JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2));
