import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';

const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const {PGlite}=createRequire(path.join(root,'backend/qa/v442/package.json'))('@electric-sql/pglite');
const db=new PGlite(),read=n=>fs.readFileSync(path.join(here,n),'utf8');
const tests=[],clone=structuredClone;
async function test(name,fn){await fn();tests.push(name);console.log('PASS',name);}
await db.exec('CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;');
await db.exec(fs.readFileSync(path.join(root,'backend/qa/v439/baseline/schema.sql'),'utf8'));
await db.exec('CREATE SCHEMA lts_product_refresh_private_v415;CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);');
const legacy=fs.readFileSync(path.join(root,'backend/qa/v439-reconciliation/verified_legacy_obligations.sql'),'utf8');
await db.exec(legacy.slice(legacy.indexOf('CREATE OR REPLACE FUNCTION lts_projection_private_v412.card_legacy_obligations_match(')));
for(const n of ['provision','calculate','profile'])await db.exec(read(n+'-original.sql'));
for(const sig of ['lts_projection_private_v412.card_new_spend_provision(jsonb,date)','lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)','lts_product_refresh_private_v415.review_profile_v450()'])
 await db.exec(`REVOKE ALL ON FUNCTION ${sig} FROM PUBLIC,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION ${sig} TO service_role;`);
await db.exec(read('calculate-original.sql').replace('FUNCTION lts_projection_private_v412.calculate(', 'FUNCTION lts_projection_private_v412.calculate_before('));

const rule=(key,family,due)=>({series_key:key,description:'Fixture '+key,account:family==='aeternum'?'Bradesco':family==='c6'?'C6':'Itaú',direction:'expense',method:'history_total_budget',starts_on:'2026-11-01',ends_on:family==='aeternum'?null:'2027-01-31',source_kind:'card_invoice',card_family:family,card_budget_mode:'scoped',history_window_months:3,due_day:due,budget_definition:{allowances:[{id:'fixture_extra',amount_brl:200,funded_by_series:'card_aeternum'}]}});
const policy={schema_version:1,approved_on:'2026-11-01',review:'calendar_year',horizon_years:5,current_month_card_budget:'known_only',rules:[rule('card_c6','c6',5),rule('card_itau','itau_mastercard',16),rule('card_aeternum','aeternum',3)]};
policy.rules[2].new_spend_provision={starts_on:'2027-02-01',amount_brl:'7200.00',source_ref:'fixture:decision'};
const history=policy.rules.flatMap(r=>['2026-08-01','2026-09-01','2026-10-01'].map(month=>({series_key:r.series_key,month,amount_brl:10000,coverage:'complete',source_refs:['fixture:history']})));
const months=[];for(let y=2026;y<=2036;y++)for(let m=1;m<=12;m++)months.push(`${y}-${String(m).padStart(2,'0')}`);
const slots=policy.rules.flatMap(r=>months.filter(m=>m>='2026-11').map(month=>({series_key:r.series_key,event_date:`${month}-${String(r.due_day).padStart(2,'0')}`,known_amount_brl:'2500.00',known_complete:true,authoritative:false,cancelled:false,legacy_estimate_brl:0,replacement_amount_brl:0,replacement_refs:[],source_refs:['fixture:known:'+r.series_key+':'+month],verified_budget_scopes:[{scope:'general',consumed_brl:500},...(r.series_key==='card_aeternum'?[{scope:'fixture_extra',target_brl:200,consumed_brl:0}]:[])]})));
const rolling=clone(policy);rolling.rules[2].new_spend_provision.lead_months=3;
const signature='lts_projection_private_v412.calculate';
async function calculate(p=rolling,s=slots,h=history,asof='2026-11-16',before=false){return(await db.query(`SELECT ${signature}${before?'_before':''}($1,$2,$3,$4) result`,[JSON.stringify(p),JSON.stringify(h),JSON.stringify(s),asof])).rows[0].result;}
const baseline=await calculate(policy,slots,history,'2026-11-16',true);
const snapshot=JSON.stringify({policy,rolling,history,slots});
await db.exec(read('provision.sql'));await db.exec(read('calculate.sql'));
await test('Existing rules without rolling lead retain the exact original complete result',async()=>assert.deepEqual(await calculate(policy),baseline));
await test('Original pre-cutover additions are reproduced before the rolling correction',async()=>assert.deepEqual(baseline.events.filter(e=>e.series_key==='card_aeternum'&&e.event_date<'2027-02-01').map(e=>e.event_date),['2026-12-03','2027-01-03']));
await test('November as-of emits no December or January provision and starts once in February',async()=>{
 const x=await calculate(),e=x.events.filter(e=>e.series_key==='card_aeternum');
 assert.equal(e[0].event_date,'2027-02-03');assert.equal(e[0].signed_amount,-7200);
 assert.equal(e.length,59);assert.equal(new Set(e.map(v=>v.source_ref)).size,59);
 const year=x.series.find(v=>v.series_key==='card_aeternum').annual_totals.find(v=>v.year===2026);
 assert.equal(year.additional_brl,0);assert.equal(year.budget_total_brl,2500);
});
for(const [asof,first]of[['2026-12-01','2027-03-03'],['2026-12-31','2027-03-03'],['2027-01-01','2027-04-03'],['2027-02-28','2027-05-03'],['2027-11-30','2028-02-03'],['2028-02-29','2028-05-03']])
 await test('Rolling calendar boundary '+asof+' -> '+first,async()=>{const e=(await calculate(rolling,slots,history,asof)).events.filter(e=>e.series_key==='card_aeternum');assert.equal(e[0].event_date,first);assert.ok(e.every(v=>v.signed_amount===-7200));assert.equal(e.length,new Set(e.map(v=>v.source_ref)).size);});
await test('Known obligations remain additive and original input rows are preserved',async()=>{const e=(await calculate()).events.find(v=>v.event_date==='2027-02-03');assert.equal(e.known_amount_brl,2500);assert.equal(e.budget_total_brl,9700);assert.deepEqual((await calculate()).replacement_refs,[]);assert.equal(JSON.stringify({policy,rolling,history,slots}),snapshot);});
await test('Other card rules and every other emitted event remain identical',async()=>assert.deepEqual((await calculate()).events.filter(e=>e.series_key!=='card_aeternum'),baseline.events.filter(e=>e.series_key!=='card_aeternum')));
await test('No historical average or extra allowance is used for a rolling fixed provision',async()=>{const x=await calculate(rolling,slots,[]);const r=x.series.find(v=>v.series_key==='card_aeternum');assert.equal(r.uses_history,false);assert.equal(r.reference_amount_brl,7200);assert.deepEqual(r.warnings,[]);assert.equal(x.events.find(v=>v.event_date==='2027-02-03').signed_amount,-7200);});
await test('Original minimum start date is respected when later than rolling boundary',async()=>{const p=clone(rolling);p.rules[2].new_spend_provision.starts_on='2027-05-01';assert.equal((await calculate(p)).events.find(v=>v.series_key==='card_aeternum').event_date,'2027-05-03');});
for(const flag of ['authoritative','cancelled'])await test(flag+' retains existing precedence',async()=>{const s=clone(slots);s.find(v=>v.series_key==='card_aeternum'&&v.event_date==='2027-02-03')[flag]=true;assert.ok(!(await calculate(rolling,s)).events.some(v=>v.series_key==='card_aeternum'&&v.event_date==='2027-02-03'));});
for(const value of [null,-1])await test('Unknown obligations '+value+' never become zero',async()=>{const s=clone(slots);s.find(v=>v.series_key==='card_aeternum'&&v.event_date==='2027-02-03').known_amount_brl=value;const x=await calculate(rolling,s);assert.ok(!x.events.some(v=>v.series_key==='card_aeternum'&&v.event_date==='2027-02-03'));assert(x.warnings.find(v=>v.series_key==='card_aeternum').codes.includes('unreconciled_periods'));});
await test('Unverified historical obligations still block projection',async()=>{const s=clone(slots);s.find(v=>v.series_key==='card_aeternum'&&v.event_date==='2027-02-03').legacy_estimate_brl=100;assert.ok(!(await calculate(rolling,s)).events.some(v=>v.series_key==='card_aeternum'&&v.event_date==='2027-02-03'));});
for(const value of [null,'3',3.5,-1,13,{},true])await test('Invalid lead rejected: '+JSON.stringify(value),async()=>{const p=clone(rolling);p.rules[2].new_spend_provision.lead_months=value;await assert.rejects(()=>calculate(p),/antecedência/);});
await test('Date and source guards for the original provision remain active',async()=>{for(const patch of [{starts_on:'2027-02-03'},{amount_brl:'0'},{source_ref:''}]){const p=clone(rolling);Object.assign(p.rules[2].new_spend_provision,patch);await assert.rejects(()=>calculate(p),/Confira/);}});
await test('Timezone cannot move the calendar boundary',async()=>{await db.exec("SET TIME ZONE 'UTC'");const a=await calculate();await db.exec("SET TIME ZONE 'America/Sao_Paulo'");assert.deepEqual(await calculate(),a);});

// Restore all exact predecessors and their original access controls before lifecycle QA.
for(const n of ['provision','calculate','profile'])await db.exec(read(n+'-original.sql'));
const attrs=async()=> (await db.query("SELECT jsonb_agg(to_jsonb(p)-'prosrc' ORDER BY oid) a FROM pg_proc p WHERE oid IN('lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'::regprocedure,'lts_projection_private_v412.card_new_spend_provision(jsonb,date)'::regprocedure,'lts_product_refresh_private_v415.review_profile_v450()'::regprocedure)")).rows[0].a;
const oldAttrs=await attrs(),oldProfile=(await db.query('SELECT lts_product_refresh_private_v415.review_profile_v450() p')).rows[0].p;
await test('Guarded installation preserves function metadata and advances epoch exactly once',async()=>{await db.exec(read('install.sql'));assert.deepEqual(await attrs(),oldAttrs);await db.exec(read('install.sql'));assert.equal((await db.query('SELECT epoch FROM public.lts_read_cache_epoch_v242')).rows[0].epoch,2);});
await test('Complete producer manifest retains all dependencies except the two exact revised hashes',async()=>{const p=(await db.query('SELECT lts_product_refresh_private_v415.review_profile_v450() p')).rows[0].p;assert.equal(p.producers.length,oldProfile.producers.length);for(let i=0;i<p.producers.length;i++){assert.equal(p.producers[i].signature,oldProfile.producers[i].signature);if(![signature+'(jsonb,jsonb,jsonb,date)','lts_projection_private_v412.card_new_spend_provision(jsonb,date)'].includes(p.producers[i].signature))assert.deepEqual(p.producers[i],oldProfile.producers[i]);}for(const k of ['tables','views','epoch_tables'])assert.deepEqual(p[k],oldProfile[k]);});
await test('Rollback restores original complete output and keeps access controls',async()=>{await db.exec(read('rollback.sql'));assert.deepEqual(await calculate(policy),baseline);assert.deepEqual(await attrs(),oldAttrs);await db.exec(read('install.sql'));});
await test('Unknown concurrent definition rejects installation without changing other functions',async()=>{await db.exec(read('calculate.sql').replace('DECLARE provision_start','DECLARE /* fixture drift */ provision_start'));await assert.rejects(()=>db.exec(read('install.sql')),/predecessor changed/);await db.exec('ROLLBACK');await db.exec(read('calculate.sql'));});
const ui=createRequire(import.meta.url)(path.join(root,'releases/v454/lts-v412-projection-policy.js'));
await test('New actual summary and dynamic start are accepted by the published-candidate UI model',async()=>{const x=await calculate(rolling,slots,[]),m=ui.build(x),r=m.series.find(v=>v.key==='card_aeternum');assert.equal(r.newSpendProvision.startsOn,'2027-02-01');assert.equal(r.newSpendProvision.leadMonths,3);assert.equal(r.usesHistory,false);const next=ui.build(await calculate(rolling,slots,[],'2026-12-01'));assert.equal(next.series.find(v=>v.key==='card_aeternum').newSpendProvision.startsOn,'2027-03-01');});
await test('UI rejects invalid rolling lead metadata',async()=>{for(const lead of ['3',-1,13,1.5]){const p=await calculate();p.series.find(v=>v.series_key==='card_aeternum').new_spend_provision.lead_months=lead;assert.throws(()=>ui.build(p),/Invalid projection/);}});
fs.mkdirSync(path.join(root,'qa/v454'),{recursive:true});fs.writeFileSync(path.join(root,'qa/v454/calculation-tests.json'),JSON.stringify({pass:true,synthetic:true,tests},null,2));
for(const [name,asof]of [['november','2026-11-16'],['december','2026-12-01']]){
 const value=await calculate(rolling,slots,[],asof);
 fs.writeFileSync(path.join(root,'qa/v454/fixture-'+name+'.json'),JSON.stringify({...value,events:undefined,replacement_refs:undefined}));
}
await db.close();
