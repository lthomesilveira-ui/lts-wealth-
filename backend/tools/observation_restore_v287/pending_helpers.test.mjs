import{test}from'node:test';import assert from'node:assert/strict';import{PGlite}from'@electric-sql/pglite';import fs from'node:fs';
const fixture=fs.readFileSync(new URL('./pending_helpers_fixture.sql',import.meta.url),'utf8');
const patch=fs.readFileSync(new URL('../../patches/v287/pending_helpers_private.sql',import.meta.url),'utf8');
const names=['lts_open_finance_card_pending_v1','lts_open_finance_pending_card_expense_v1'];
async function state(db){return(await db.query("SELECT oid::regprocedure::text AS signature,to_jsonb(p)-'proacl' AS identity,has_function_privilege('anon',oid,'EXECUTE') AS anon,has_function_privilege('authenticated',oid,'EXECUTE') AS authenticated,has_function_privilege('service_role',oid,'EXECUTE') AS service FROM pg_proc p WHERE proname IN('lts_open_finance_card_pending_v1','lts_open_finance_pending_card_expense_v1') ORDER BY proname")).rows;}
test('pending helper hardening preserves source/identity/service and denies both browser roles',async()=>{
const db=await PGlite.create();try{
await db.exec(fixture);const before=await state(db);assert.equal(before.every(x=>x.anon&&x.authenticated&&x.service),true);
await db.exec(patch);const after=await state(db);assert.deepEqual(after.map(x=>x.identity),before.map(x=>x.identity));assert.equal(after.every(x=>!x.anon&&!x.authenticated&&x.service),true);
for(const role of ['anon','authenticated','service_role'])for(const name of names){
await db.exec('SET ROLE '+role);try{
if(role==='service_role'){const r=(await db.query('SELECT public.'+name+'($1) AS result',['__synthetic_missing_institution__'])).rows[0].result;assert.equal(r.transaction_count,0);assert.equal(r.promotion_enabled,false);}
else await assert.rejects(db.query('SELECT public.'+name+'($1)',['__synthetic_missing_institution__']),e=>e.code==='42501');
}finally{await db.exec('RESET ROLE');}}
}finally{await db.close();}
});
test('pending helper patch is idempotent',async()=>{const db=await PGlite.create();try{await db.exec(fixture);await db.exec(patch);const once=await state(db);await db.exec(patch);assert.deepEqual(await state(db),once);}finally{await db.close();}});
test('definition drift aborts both helper permission changes atomically',async()=>{const db=await PGlite.create();try{await db.exec(fixture);await db.exec("ALTER FUNCTION public.lts_open_finance_pending_card_expense_v1(text) SET timezone='UTC'");const before=await state(db);await assert.rejects(db.exec(patch),/definition mismatch/);assert.deepEqual(await state(db),before);}finally{await db.close();}});
