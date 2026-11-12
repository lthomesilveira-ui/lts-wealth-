// Fully synthetic source fixtures. Production definitions and owner data are not bundled.
import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';import assert from 'node:assert/strict';
const root=new URL('../',import.meta.url),read=p=>fs.readFileSync(new URL(p,root),'utf8');
const migration=read('supabase/migrations/20261112015043_respect_card_budget_gap_terms.sql');
const helper=migration.slice(migration.indexOf('CREATE OR REPLACE FUNCTION lts_projection_private_v412.card_budget_exempt_periods_v1'),migration.indexOf('\nDO $migration$'));
const db=new PGlite(),q=(sql,args=[])=>db.query(sql,args),results=[];
const owner='00000000-0000-4000-8000-000000000001',other='00000000-0000-4000-8000-000000000002';
async function test(name,fn){await fn();results.push(name);console.log('PASS',name)}
await db.exec(read('tests/fixtures/card-budget-gap-setup.sql'));await db.exec(helper);
const rule={series_key:'card_c6',description:'card_c6',card_family:'c6',source_kind:'card_invoice',method:'history_total_budget',direction:'expense',active:true,starts_on:'2028-01-01',ends_on:'2028-02-29',account:'C6'};
async function policy(r=rule){await db.exec('TRUNCATE test_policy');if(r)await q('insert into test_policy values($1,$2)',[owner,JSON.stringify({rules:[r]})]);}
async function reset(){await db.exec('TRUNCATE test_known,evento_base,financial_events,test_date_shift');await policy();await q("insert into test_known values($1,'card_c6','2028-04-01','2028-04-05',100,false,false,true,'[\"fixture:invoice\"]')",[owner]);}
async function months(){return(await q("select to_char(period_start,'YYYY-MM') m from lts_projection_private_v412.card_budget_exempt_periods_v1($1,'2028-01-10','2028-12-31') order by period_start",[owner])).rows.map(x=>x.m);}
async function legacy(date='2028-06-05',value='100',account='C6',uid=owner){await q('insert into evento_base values($1,1,$2)',[uid,JSON.stringify({dia:date,valor:value,desc:'card_c6',conta:account,efeito:'saida'})]);}
await reset();
await test('Budget term and exact invoice month remain expected',async()=>assert.deepEqual(await months(),['2028-03','2028-05','2028-06','2028-07','2028-08','2028-09','2028-10','2028-11','2028-12']));
await test('No interpolated spending between documented invoices',async()=>{await q("insert into test_known values($1,'card_c6','2028-08-01','2028-08-05',100,false,false,true,'[\"fixture:later\"]')",[owner]);assert.ok((await months()).includes('2028-07'));assert.ok(!(await months()).includes('2028-08'));});
await test('Legacy obligation missing from flow is still expected',async()=>{await legacy();assert.ok(!(await months()).includes('2028-06'));});
await test('Account spelling or divergent account cannot hide same-series debt',async()=>{await q("update evento_base set dados=jsonb_set(dados,'{conta}','\"Alternate account\"')");assert.ok(!(await months()).includes('2028-06'));});
await test('Confirmed cash-date shift governs expected month',async()=>{await q("insert into test_date_shift values($1,'c6',1)",[owner]);assert.ok((await months()).includes('2028-06'));assert.ok(!(await months()).includes('2028-07'));});
await test('Independent financial source is expected even without a flow event',async()=>{await q("insert into financial_events(user_id,event_date,amount,description_raw) values($1,'2028-09-05',-100,'card_c6')",[owner]);assert.ok(!(await months()).includes('2028-09'));});
await test('Suppressed source does not restore a cancelled expectation',async()=>{await q('update financial_events set is_suppressed=true');assert.ok((await months()).includes('2028-09'));});
for(const field of ['complete','due_date','reference_month','amount_brl','source_refs'])await test(`Unknown ${field} preserves review`,async()=>{await reset();await q(`update test_known set ${field}=NULL`);assert.deepEqual(await months(),[]);});
for(const amount of ['NaN','Infinity','-Infinity'])await test(`Nonfinite amount ${amount} preserves review`,async()=>{await reset();await q('update test_known set amount_brl=$1',[amount]);assert.deepEqual(await months(),[]);});
for(const [date,amount] of [['unknown','100'],['infinity','100'],['-infinity','100'],['2028-06-05','unknown'],['2028-06-05','NaN']])await test(`Malformed legacy input ${date}/${amount} preserves review`,async()=>{await reset();await legacy(date,amount);assert.deepEqual(await months(),[]);});
await test('Other owner sources do not affect this audit',async()=>{await reset();await legacy('2028-06-05','100','C6',other);assert.ok((await months()).includes('2028-06'));});
await test('No known schedule preserves review',async()=>{await reset();await db.exec('TRUNCATE test_known');assert.deepEqual(await months(),[]);});
await test('Duplicate canonical schedule preserves review',async()=>{await reset();await db.exec('insert into test_known select * from test_known');assert.deepEqual(await months(),[]);});
await test('Conflicting family does not exempt any month',async()=>{await reset();await policy({...rule,card_family:'aeternum'});assert.deepEqual(await months(),[]);});
for(const change of [{ends_on:null},{active:false},{method:'fixed'},{direction:'income'},{source_kind:'other'}])await test('Rule outside the approved card-budget shape is untouched',async()=>{await reset();await policy({...rule,...change});assert.deepEqual(await months(),[]);});
await test('No policy is a no-op',async()=>{await reset();await policy(null);assert.deepEqual(await months(),[]);});
await test('Midmonth end retains whole cutoff month conservatively',async()=>{await reset();await policy({...rule,ends_on:'2028-03-02'});assert.ok(!(await months()).includes('2028-03'));});
await test('Helper remains private and invoker-only',async()=>{const r=(await q("select prosecdef,has_function_privilege('authenticated','lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date)','EXECUTE') allowed from pg_proc where oid='lts_projection_private_v412.card_budget_exempt_periods_v1(uuid,date,date)'::regprocedure")).rows[0];assert.deepEqual(r,{prosecdef:false,allowed:false});});
await test('Migration adjusts expectation rather than ending card identities',()=>{assert.equal((migration.match(/AND NOT c\.budget_not_expected/g)||[]).length,1);assert.ok(migration.includes("FILTER(WHERE NOT c.budget_not_expected OR c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count+c.transition_count>0)"));assert.ok(!migration.includes("WHEN c.budget_not_expected THEN 'no_payment_due'"));assert.ok(migration.includes('Card gap helper changed'));assert.ok(migration.includes('Recurring gap audit changed'));});
await test('Audit helper has no financial writes',()=>{assert.ok(!/\b(?:INSERT INTO|UPDATE |DELETE FROM)\b/i.test(helper));});
console.log(JSON.stringify({pass:true,checks:results.length}));await db.close();
