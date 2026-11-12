import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const db=new PGlite();
const read=p=>fs.readFileSync(new URL(p,import.meta.url),'utf8');
const results=[];
async function test(name,fn){await fn();results.push(name);console.log('PASS',name);}
const clone=x=>structuredClone(x);
await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
 CREATE TABLE public.legacy_namespace(usuario_id uuid,chave text,valor_bruto text,importado_em timestamptz);
 CREATE FUNCTION public.lts_forecast_series_key_v1(text) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT $1$$;`);
await db.exec(read('baseline/schema.sql'));
await db.exec(read('baseline/calculate.sql'));
await db.exec(read('baseline/calculate.sql').replace('FUNCTION lts_projection_private_v412.calculate(', 'FUNCTION lts_projection_private_v412.calculate_baseline('));
await db.exec(read('baseline/scope_slots_v416.sql'));
await db.exec(`CREATE FUNCTION lts_projection_private_v412.scope_match_v416(jsonb,jsonb,boolean) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT coalesce($1->>'scope','general')$$;`);
await db.exec(read('card_new_spend_provision.sql'));
for(const f of ['owner_policy','calculate','scope_slots_v416'])await db.exec(read(`candidate/${f}.sql`));
const rule=(key,family,day)=>({series_key:key,description:key,account:family==='aeternum'?'Bradesco':family==='c6'?'C6':'Itaú',direction:'expense',method:'history_total_budget',starts_on:'2026-11-01',ends_on:null,source_kind:'card_invoice',card_family:family,card_budget_mode:'scoped',history_window_months:3,due_day:day,budget_definition:{source_accounts:['Synthetic'],allowances:[{id:'synthetic_allowance',amount_brl:'700.00',funded_by_series:'card_aeternum'}]}});
const original={schema_version:1,approved_on:'2026-11-01',review:'calendar_year',horizon_years:5,owner_evidence_ref:'synthetic:initial',current_month_card_budget:'known_only',rules:[rule('card_c6','c6',5),rule('card_itau','itau_mastercard',12),rule('card_aeternum','aeternum',3)]};
const proposed=clone(original);
for(const r of proposed.rules){if(r.series_key==='card_aeternum')r.new_spend_provision={starts_on:'2027-02-01',amount_brl:'7500.00',source_ref:'synthetic:owner-decision'};else r.ends_on='2027-01-31';}
const history=original.rules.flatMap(r=>['2026-08-01','2026-09-01','2026-10-01'].map(month=>({series_key:r.series_key,month,amount_brl:'12000.00',coverage:'complete',source_refs:['synthetic:invoice']})));
const slots=original.rules.flatMap(r=>['2026-11','2026-12','2027-01','2027-02','2027-03','2027-12','2028-01'].map(month=>({series_key:r.series_key,event_date:`${month}-${String(r.due_day).padStart(2,'0')}`,known_amount_brl:'2400.00',known_complete:true,authoritative:false,cancelled:false,legacy_estimate_brl:0,replacement_amount_brl:0,replacement_refs:[],source_refs:[`synthetic:installments:${r.series_key}:${month}`],verified_budget_scopes:[{scope:'general',consumed_brl:'400.00'},...(r.series_key==='card_aeternum'?[{scope:'synthetic_allowance',target_brl:'700.00',consumed_brl:'0.00'}]:[])]})));
async function calculate(p=proposed,s=slots,h=history,asof='2026-11-02',name='calculate'){
 return (await db.query(`select lts_projection_private_v412.${name}($1::jsonb,$2::jsonb,$3::jsonb,$4::date) result`,[JSON.stringify(p),JSON.stringify(h),JSON.stringify(s),asof])).rows[0].result;
}
const old=await calculate(original,slots,history,'2026-11-02','calculate_baseline');
const current=await calculate();
await test('No-policy regressions: complete legacy output remains byte-equivalent',async()=>assert.deepEqual(await calculate(original),old));
await test('Nov/Dec/Jan events are unchanged, including old scoped allowances',async()=>assert.deepEqual(current.events.filter(e=>e.event_date<'2027-02-01'),old.events.filter(e=>e.event_date<'2027-02-01')));
await test('From February only Aeternum receives new-spend projection',async()=>assert.deepEqual([...new Set(current.events.filter(e=>e.event_date>='2027-02-01').map(e=>e.series_key))],['card_aeternum']));
await test('2400 known installments + 7500 provision = 9900, not a 7500 ceiling',async()=>{
 const e=current.events.find(e=>e.event_date==='2027-02-03');assert.equal(e.signed_amount,-7500);assert.equal(e.known_amount_brl,2400);assert.equal(e.budget_total_brl,9900);
});
await test('synthetic_allowance 700 allowance is not added separately to 7500',async()=>assert.equal(current.events.find(e=>e.event_date==='2027-02-03').signed_amount,-7500));
await test('Repeated reads are deterministic and generate one identity per card/month',async()=>{assert.deepEqual(await calculate(),current);assert.equal(new Set(current.events.map(e=>e.source_ref)).size,current.events.length);});
await test('Original input obligations are unchanged',async()=>{assert.equal(slots.length,21);assert.ok(slots.every(s=>s.known_amount_brl==='2400.00'));assert.deepEqual(current.replacement_refs,[]);});
await test('Known obligations above 7500 are preserved and still get the same provision',async()=>{const s=clone(slots);s.find(e=>e.event_date==='2027-02-03').known_amount_brl='11000.75';const e=(await calculate(proposed,s)).events.find(e=>e.event_date==='2027-02-03');assert.equal(e.budget_total_brl,18500.75);assert.equal(e.signed_amount,-7500);});
await test('Zero known installments still receives 7500',async()=>{const s=clone(slots);s.find(e=>e.event_date==='2027-02-03').known_amount_brl='0';const e=(await calculate(proposed,s)).events.find(e=>e.event_date==='2027-02-03');assert.equal(e.budget_total_brl,7500);});
for(const flag of ['authoritative','cancelled'])await test(`${flag} preserves documentary/owner precedence`,async()=>{const s=clone(slots);s.find(e=>e.event_date==='2027-02-03')[flag]=true;assert.ok(!(await calculate(proposed,s)).events.some(e=>e.event_date==='2027-02-03'));});
for(const amount of [null,'-1'])await test(`Unknown/invalid known amount ${amount} cannot become zero`,async()=>{const s=clone(slots);s.find(e=>e.event_date==='2027-02-03').known_amount_brl=amount;const x=await calculate(proposed,s);assert.ok(!x.events.some(e=>e.event_date==='2027-02-03'));assert.ok(x.warnings.find(e=>e.series_key==='card_aeternum').codes.includes('unreconciled_periods'));});
await test('Unreconciled legacy estimate is flagged rather than counted twice',async()=>{const s=clone(slots);s.find(e=>e.event_date==='2027-02-03').legacy_estimate_brl=100;const x=await calculate(proposed,s);assert.ok(!x.events.some(e=>e.event_date==='2027-02-03'));assert.ok(x.warnings.find(e=>e.series_key==='card_aeternum').codes.includes('unreconciled_periods'));});
await test('Historical coverage is not needed for fixed post-cutover provision',async()=>{const x=await calculate(proposed,slots,[]);assert.equal(x.events.find(e=>e.event_date==='2027-02-03').signed_amount,-7500);});
await test('Annual rollover never revives historical budgets/allowances',async()=>{const x=await calculate(proposed,slots,[],'2027-03-10');assert.ok(x.events.every(e=>e.series_key==='card_aeternum'&&e.signed_amount===-7500));const s=x.series.find(e=>e.series_key==='card_aeternum');assert.equal(s.uses_history,false);assert.equal(s.reference_amount_brl,7500);assert.deepEqual(s.warnings,[]);});
await test('Current-month known-only remains unchanged',async()=>{const x=await calculate(proposed,slots,[],'2027-02-01');assert.ok(!x.events.some(e=>e.event_date==='2027-02-03'));});
await test('Duplicate slots fail closed',async()=>assert.rejects(()=>calculate(proposed,[...slots,slots[0]]),/repetidas/));
for(const patch of [{amount_brl:'-7500'},{amount_brl:'0'},{amount_brl:'7500.001'},{starts_on:'2027-02-30'},{starts_on:'2027-02-03'},{source_ref:''}])await test(`Invalid provision fails closed: ${JSON.stringify(patch)}`,async()=>{const p=clone(proposed);Object.assign(p.rules[2].new_spend_provision,patch);await assert.rejects(()=>calculate(p),/Confira/);});
await test('Provision is rejected on a non-card/non-expense rule',async()=>{const p=clone(proposed);p.rules[2].direction='income';await assert.rejects(()=>calculate(p),/Confira/);});
await test('Scope adapter bypasses historical allowance logic only after cutover',async()=>{
 const s=slots.filter(x=>x.series_key==='card_aeternum'&&['2027-01-03','2027-02-03'].includes(x.event_date)).map(x=>{const r=clone(x);delete r.verified_budget_scopes;return r;});
 const cards={cards:[{family:'aeternum',complete:true,cycles:s.map(x=>({due_date:x.event_date,amount:'2400.00',complete:true,items:[{source_id:'synthetic:one',amount:'2400.00',scope:'general'}]}))}]};
 const x=(await db.query('select lts_projection_private_v412.scope_slots_v416($1,$2,$3) result',[JSON.stringify(proposed),JSON.stringify(s),JSON.stringify(cards)])).rows[0].result;
 assert.ok(x[0].verified_budget_scopes.some(x=>x.scope==='synthetic_allowance'));assert.deepEqual(x[1],s[1]);
});
const user='11111111-1111-4111-8111-111111111111';
await db.query('insert into public.legacy_namespace values($1,$2,$3,now())',[user,'lts_owner_projection_policy_v412',JSON.stringify(proposed)]);
await test('Actual owner_policy reader validates and returns the dated rule',async()=>{const x=(await db.query('select lts_projection_private_v412.owner_policy($1) result',[user])).rows[0].result;assert.equal(x.rules[2].new_spend_provision.amount_brl,'7500.00');});
await test('New helper is not callable by PUBLIC, anon or authenticated',async()=>{const x=(await db.query(`select has_function_privilege('anon','lts_projection_private_v412.card_new_spend_provision(jsonb,date)','EXECUTE') a,has_function_privilege('authenticated','lts_projection_private_v412.card_new_spend_provision(jsonb,date)','EXECUTE') b`)).rows[0];assert.equal(x.a,false);assert.equal(x.b,false);});
await db.exec(`CREATE SCHEMA qa; CREATE TABLE qa.fixture(name text primary key,value jsonb);
 CREATE SCHEMA lts_product_refresh_private_v415;
 CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
 CREATE TABLE public.lts_projection_replacement_rule(user_id uuid,active boolean,action text,replacement_source text,evidence jsonb,description_exact text,date_from date,date_to date);
 CREATE TABLE public.lts_recurring_plan_v366(user_id uuid,series_key text,direction text,confirmed_at timestamptz,active boolean,starts_on date,ends_on date);
 CREATE TABLE public.lts_commitment_documentary_schedule(user_id uuid,commitment_id text,due_date date,amount_total numeric);
 CREATE FUNCTION lts_projection_private_v412.reference_state(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT '{}'::jsonb$$;
 CREATE FUNCTION lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT null::jsonb$$;
 CREATE FUNCTION lts_product_refresh_private_v415.card_source_key(uuid) RETURNS text LANGUAGE sql STABLE AS $$SELECT 'synthetic-source'::text$$;
 CREATE FUNCTION public.lts_card_transition_cash_date_v370(uuid,text,date) RETURNS date LANGUAGE sql STABLE AS $$SELECT $3$$;
 CREATE FUNCTION lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb)
 RETURNS TABLE(series_key text,month date,amount_brl numeric,coverage text,source_refs jsonb,observed_days jsonb)
 LANGUAGE sql STABLE AS $$SELECT r.* FROM qa.fixture q CROSS JOIN LATERAL jsonb_to_recordset(q.value)r(series_key text,month date,amount_brl numeric,coverage text,source_refs jsonb,observed_days jsonb) WHERE q.name='history'$$;
 CREATE FUNCTION lts_projection_private_v412.calendar_templates_v412(uuid,jsonb)
 RETURNS TABLE(series_key text,template_year int,event_month int,event_day int,amount_brl numeric,source_ref text)
 LANGUAGE sql STABLE AS $$SELECT null::text,null::int,null::int,null::int,null::numeric,null::text WHERE false$$;
 CREATE FUNCTION lts_projection_private_v412.base_flow(uuid,date,date)
 RETURNS TABLE(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text)
 LANGUAGE sql STABLE AS $$SELECT r.* FROM qa.fixture q CROSS JOIN LATERAL jsonb_to_recordset(q.value)r(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text) WHERE q.name='base' AND r.event_date BETWEEN $2 AND $3$$;
 CREATE FUNCTION lts_projection_private_v412.known_card_periods_v412(uuid)
 RETURNS TABLE(series_key text,due_date date,amount_brl numeric,closed boolean,paid boolean,complete boolean)
 LANGUAGE sql STABLE AS $$SELECT r.* FROM qa.fixture q CROSS JOIN LATERAL jsonb_to_recordset(q.value)r(series_key text,due_date date,amount_brl numeric,closed boolean,paid boolean,complete boolean) WHERE q.name='cycles'$$;
 CREATE FUNCTION public.lts_card_cycles_v226(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT value FROM qa.fixture WHERE name='cards'$$;
 CREATE FUNCTION lts_projection_private_v412.scope_history_read_v416(uuid,jsonb,jsonb,date) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT $3$$;`);
const base=slots.map(s=>({event_date:s.event_date==='2027-02-03'?'2027-02-06':s.event_date,account:original.rules.find(r=>r.series_key===s.series_key).account,description:s.series_key,signed_amount:-Number(s.known_amount_brl),source:'synthetic_documented_installments',source_ref:s.source_refs[0],confidence:'documented'}));
const cycles=base.map(b=>({series_key:b.description,due_date:b.event_date,amount_brl:-b.signed_amount,closed:false,paid:false,complete:true}));
const cards={cards:original.rules.map(r=>({family:r.card_family,complete:true,cycles:cycles.filter(c=>c.series_key===r.series_key).map(c=>({due_date:c.due_date,amount:c.amount_brl,complete:true,items:[{source_id:`synthetic:${c.series_key}:${c.due_date}:general`,amount:'400.00',scope:'general'},{source_id:`synthetic:${c.series_key}:${c.due_date}:installment`,amount:'2000.00',scope:'existing_installment'}]}))}))};
for(const [name,value] of Object.entries({base,cycles,cards,history}))await db.query('INSERT INTO qa.fixture VALUES($1,$2)',[name,JSON.stringify(value)]);
await db.exec(read('baseline/build.sql'));
async function build(){return(await db.query('select lts_projection_private_v412.build($1,$2) result',[user,'2026-11-02'])).rows[0].result;}
const built=await build();
await test('Exact guarded migration replays idempotently against installed candidate definitions',async()=>{await db.exec(read('guarded_candidate.sql'));await db.exec(read('guarded_candidate.sql'));});
await test('Exact V438 build uses canonical due date once: February 6, not nominal February 3',async()=>{assert.equal(built.events.find(e=>e.series_key==='card_aeternum'&&e.event_date.startsWith('2027-02')).event_date,'2027-02-06');});
await test('Full build preserves all three cards installments while adding only one provision',async()=>{const febBase=base.filter(e=>e.event_date.startsWith('2027-02'));const febNew=built.events.filter(e=>e.event_date.startsWith('2027-02'));assert.equal(febBase.length,3);assert.equal(febNew.length,1);assert.equal(febBase.reduce((s,e)=>s+e.signed_amount,0)+febNew.reduce((s,e)=>s+e.signed_amount,0),-14700);});
await test('Full build historical pre-cutover events match exact predecessor',async()=>{await db.query('UPDATE public.legacy_namespace SET valor_bruto=$1',[JSON.stringify(original)]);await db.exec(read('baseline/calculate.sql'));const oldBuild=await build();await db.exec(read('candidate/calculate.sql'));await db.query('UPDATE public.legacy_namespace SET valor_bruto=$1',[JSON.stringify(proposed)]);assert.deepEqual(built.events.filter(e=>e.event_date<'2027-02-01'),oldBuild.events.filter(e=>e.event_date<'2027-02-01'));});
await test('Full build repeats without changing financial fixture inputs',async()=>{assert.deepEqual(await build(),built);assert.deepEqual((await db.query("SELECT value FROM qa.fixture WHERE name='base'")).rows[0].value,base);});
await test('Guarded code rollback restores exact predecessor and permits reinstallation',async()=>{await db.exec(read('rollback-code.sql'));assert.deepEqual(await calculate(original),old);await db.exec(read('guarded_candidate.sql'));assert.deepEqual(await calculate(),current);});
if(process.env.PROVISION_UI_FILE){
 const api=createRequire(import.meta.url)(process.env.PROVISION_UI_FILE);
 await test('Actual generated pre-cutover summary is accepted by final UI parser with cessation dates',async()=>{const m=api.build(current);assert.equal(m.series.find(x=>x.key==='card_aeternum').newSpendProvision.active,false);});
 await test('Actual generated post-cutover summary shows fixed amount without historical-average validation',async()=>{const m=api.build(await calculate(proposed,slots,[],'2027-03-10'));assert.equal(m.series.length,1);assert.equal(m.series[0].usesHistory,false);assert.equal(m.series[0].amount,750000);});
}
fs.writeFileSync(new URL('test-results.json',import.meta.url),JSON.stringify({pass:true,checks:results.length,runtime:(await db.query('select version()')).rows[0].version,scope:'Synthetic local PGlite, exact installed V438 build and calculator/adapter bodies plus candidate patch, with synthetic source adapters. No production mutation or UI acceptance.',tests:results},null,2));
console.log(JSON.stringify({pass:true,checks:results.length}));await db.close();
