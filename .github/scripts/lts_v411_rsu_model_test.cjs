'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const api=require('../../lts-v411-rsu-policy.js');
const base=()=>JSON.parse(fs.readFileSync('backend/patches/v411/reader_contract.json','utf8'));
test('server values remain gross 1500 / net 1050; no second reserve',()=>{const p=base(),copy=JSON.stringify(p),m=api.build(p);assert.deepEqual(m.total,{gross:150000,net:105000,reserve:45000});assert.deepEqual(m.regular,{gross:100000,net:70000});assert.deepEqual(m.cash,{gross:50000,net:35000});assert.equal(JSON.stringify(p),copy);});
test('unallocated amount stays unknown; brokerage cash is untouched',()=>{const m=api.build(base());assert.equal(m.reference.unallocatedNet,null);assert.equal(m.reference.brokerageCash,300);assert.equal(m.reference.knownAfterReserve,105300);assert.equal(m.reference.asOf,null);});
test('no owner policy means no replacement model',()=>{const p=base();p.policy.enabled=false;assert.equal(api.build(p),null);});
test('receipt day does not become a position date',()=>{const p=base();p.morgan_reference.received_at=null;p.morgan_reference.received_on='2030-01-02';const m=api.build(p);assert.equal(m.reference.asOf,null);assert.equal(m.reference.receivedOn,'2030-01-02');});
test('optional reference, scenario and payroll may be absent',()=>{const p=base();p.morgan_reference=null;p.acceleration=null;p.payroll_policy=null;assert.equal(api.build(p).reference,null);});
test('documented pre-2026 and 2026 grants coexist without changing dates',()=>{const p=base(),original=p.future_schedule.map(r=>[r.eligibility_date,r.available_date]);const c=p.future_schedule[0].components[0];c.grant_id='SYNTHETIC_PRE_2026';c.grant_date='2025-03-31';c.grant_year=2025;c.grant_link_status='documentary';c.acceleration_eligible=true;p.future_schedule[0].acceleration_eligible=true;const m=api.build(p);assert.equal(m.schedule[0].eligible,true);assert.equal(m.acceleration.grants[1].eligible,false);assert.deepEqual(m.schedule.map(r=>[r.eligibilityDate,r.availableDate]),original);});
test('a mixed group has no group-wide acceleration',()=>{const p=base(),r=p.future_schedule[0],original=r.components[0];r.components=[{...original,award_id:'SYNTHETIC_A',quantity:5,gross_value_brl:500,net_value_brl:350,reserve_value_brl:150,grant_id:'A',grant_date:'2025-03-31',grant_year:2025,acceleration_eligible:true},{...original,award_id:'SYNTHETIC_B',quantity:5,gross_value_brl:500,net_value_brl:350,reserve_value_brl:150,grant_id:'B',grant_date:'2026-03-31',grant_year:2026,acceleration_eligible:false}];r.acceleration_eligible=false;const m=api.build(p);assert.equal(m.schedule[0].eligible,false);assert.equal(m.schedule[0].components.filter(c=>c.eligible).length,1);});
test('explicit zero is distinct from missing data',()=>{const p=base();p.future_schedule=[];for(const k of Object.keys(p.summary))if(k.endsWith('_brl'))p.summary[k]=0;assert.equal(api.build(p).total.net,0);delete p.summary.schedule_net_brl;assert.throws(()=>api.build(p));});
test('decimal cents are parsed without floating point multiplication',()=>{assert.equal(api.cents('0.29'),29);assert.equal(api.cents('10000000.99'),1000000099);assert.throws(()=>api.cents('1.005'));assert.throws(()=>api.cents(true));assert.throws(()=>api.cents(null));});
test('row matching uses the explicit net, date, quantity and group identity',()=>{const p=base(),g=api.build(p).schedule[0],r=p.future_schedule[0];assert(api.matchGroup(r,g));assert(!api.matchGroup({...r,net_value_brl:490},g));assert(!api.matchGroup({...r,available_date:'2030-04-04'},g));assert(!api.matchGroup({...r,group_key:'other'},g));});
const invalid=[
 ['version',p=>p.version='unknown'],['schema',p=>p.schema_version=2],['wrong factor',p=>p.policy.net_factor=.49],
 ['cash deducted again',p=>p.policy.cash_already_available_untouched=false],['retention included',p=>p.policy.retention_award_excluded=false],
 ['scope duplicates',p=>p.policy.scope=['RSU','RSU']],['missing net',p=>delete p.summary.schedule_net_brl],
 ['unknown net',p=>p.summary.schedule_net_brl=null],['fractional cent',p=>p.summary.schedule_net_brl='1050.001'],
 ['total mismatch',p=>p.summary.schedule_net_brl=1049.99],['reserve mismatch',p=>p.summary.schedule_reserve_brl=449],
 ['duplicate group',p=>p.future_schedule.push(structuredClone(p.future_schedule[0]))],
 ['duplicate component',p=>p.future_schedule[1].components[0].award_id=p.future_schedule[0].components[0].award_id],
 ['no components',p=>p.future_schedule[0].components=[]],['component mismatch',p=>p.future_schedule[0].components[0].net_value_brl=699],
 ['invalid vesting day',p=>p.future_schedule[0].eligibility_date='2030-02-30'],
 ['availability before vesting',p=>p.future_schedule[0].available_date='2030-03-30'],
 ['unknown grant accelerated',p=>p.future_schedule[0].components[0].acceleration_eligible=true],
 ['2026 grant accelerated',p=>{const c=p.future_schedule[0].components[0];c.grant_date='2026-03-31';c.grant_id='AFTER_CUTOFF';c.grant_year=2026;c.acceleration_eligible=true;}],
 ['mixed or unknown group accelerated',p=>p.future_schedule[0].acceleration_eligible=true],
 ['grant year contradicts source date',p=>{const c=p.future_schedule[0].components[0];c.grant_date='2025-03-31';c.grant_year=2026;}],
 ['undated reference claimed dated',p=>p.morgan_reference.reference_date_known=true],
 ['receipt date presented as position',p=>p.morgan_reference.as_of_date='2030-01-02'],
 ['reference replaces dated source',p=>p.morgan_reference.replaces_dated_position=true],
 ['unallocated net invented',p=>p.morgan_reference.unallocated_net_brl=1.4],
 ['reference net mismatch',p=>p.morgan_reference.known_awards_net_brl=1049],
 ['new calendar from conditional event',p=>p.acceleration.calendar_unchanged=false],
 ['unconfirmed date invented',p=>p.acceleration.confirmed_date='2030-01-10'],
 ['2026 grant included in condition',p=>p.acceleration.grants[1].acceleration_eligible=true],
 ['invalid closing price',p=>p.acceleration.contract_price_usd=-1],
 ['payroll deducted twice',p=>p.payroll_policy.actual_net_preserved=false],
 ['payroll applied to actual',p=>p.payroll_policy.forecasts_only=false]
];
for(const[name,change]of invalid)test('rejects '+name,()=>{const p=base();change(p);assert.throws(()=>api.build(p));});
