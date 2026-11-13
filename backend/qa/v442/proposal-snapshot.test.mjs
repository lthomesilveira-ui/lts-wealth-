import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite(),dir='backend/tools/strategic_budget_v442/review/';
await db.exec('CREATE SCHEMA lts_budget_private_v441; CREATE ROLE anon; CREATE ROLE authenticated;');
await db.exec(fs.readFileSync(dir+'reviewed-planning.sql','utf8'));
const meta=async()=> (await db.query("select proowner,proacl,prosecdef,provolatile,proconfig from pg_proc where oid='lts_budget_private_v441.reviewed_planning_v442(jsonb,bigint,integer)'::regprocedure")).rows[0];
const before=await meta(),install=fs.readFileSync(dir+'proposal-snapshot-install.sql','utf8');
await db.exec(install);await db.exec(install);assert.deepEqual(await meta(),before);
const p={source_epoch:10,reviewed_at:'2026-11-13',months:{'2027-01':{Food:{status:'reviewed_proposal',target:500,reason:'Synthetic reviewed alternative',evidence:['Synthetic needs and commitment review']}}}};
const read=async(v,e=10)=>(await db.query('select lts_budget_private_v441.reviewed_planning_v442($1,$2,2027) p',[v,e])).rows[0].p;
let r=await read(p);assert.equal(r.status,'current');assert.deepEqual(r.months,p.months);assert.equal(r.reviewed_at,p.reviewed_at);
r=await read(p,11);assert.equal(r.status,'review_required');assert.deepEqual(r.months,p.months);assert.deepEqual(r.payroll_withholding,[]);assert.deepEqual(r.source_links,[]);assert.equal(r.reviewed_source_epoch,10);
assert.equal((await read(null)).status,'missing');assert.deepEqual((await read({...p,source_epoch:'invalid'})).months,{});
for(const mutate of[x=>x.months['2027-01'].Food.status='owner',x=>x.months['2027-01'].Food.target=-1,x=>x.months['2027-01'].Food.evidence=[],x=>x.months['2027-01'].Food.reason='',x=>x.reviewed_at='2026-02-30']){
 const x=structuredClone(p);mutate(x);await assert.rejects(()=>read(x,11));
}
const denied=await db.query("select has_function_privilege('anon','lts_budget_private_v441.reviewed_planning_v442(jsonb,bigint,integer)','EXECUTE') a,has_function_privilege('authenticated','lts_budget_private_v441.reviewed_planning_v442(jsonb,bigint,integer)','EXECUTE') b");assert.deepEqual(denied.rows[0],{a:false,b:false});
await db.exec(fs.readFileSync(dir+'proposal-snapshot.sql','utf8').replace('BEGIN\n','BEGIN\n -- concurrent change\n'));
await assert.rejects(()=>db.exec(install),/Unexpected reviewed-proposal predecessor/);await db.exec('ROLLBACK');
console.log('PASS prior proposals remain explicitly unapproved and require review after source changes; source links and payroll proof stay suppressed; validation, ACLs, guards and idempotence preserved');
await db.close();
