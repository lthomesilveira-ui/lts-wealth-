import {test} from 'node:test';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';
const probe=fs.readFileSync(new URL('./rls_role_probe.sql',import.meta.url),'utf8');
async function run(protectedTable) {
const db=await PGlite.create();
try{
await db.exec("CREATE ROLE anon NOLOGIN;CREATE ROLE authenticated NOLOGIN;GRANT USAGE ON SCHEMA public TO anon,authenticated;CREATE TABLE public.owned_fixture(user_id uuid NOT NULL,value text);INSERT INTO public.owned_fixture VALUES('00000000-0000-4000-8000-000000000001','synthetic-one'),('00000000-0000-4000-8000-000000000002','synthetic-two');GRANT SELECT ON public.owned_fixture TO anon,authenticated;");
if(protectedTable)await db.exec("ALTER TABLE public.owned_fixture ENABLE ROW LEVEL SECURITY;CREATE POLICY own_rows ON public.owned_fixture TO authenticated USING(user_id=nullif(current_setting('request.jwt.claim.sub',true),'')::uuid);");
const results=await db.exec(probe);
return results.flatMap(x=>x.rows).find(x=>x.result)?.result;
}finally{await db.close();}
}
test('role probe accepts owner-isolated tables for all three foreign/anonymous cases',async()=>{
const r=await run(true);assert.equal(r.pass,true);assert.equal(r.owner_tables_tested,1);assert.equal(r.cases,3);assert.equal(r.results.every(x=>x.outcome==='zero_foreign_rows'&&x.foreign_rows===0),true);assert.equal(r.production_rows_written,false);
});
test('role probe detects a table with unrestricted foreign-owner reads',async()=>{
const r=await run(false);assert.equal(r.pass,false);assert.equal(r.cases,3);assert.equal(r.results.every(x=>x.outcome==='FAIL_visible_foreign_rows'&&x.foreign_rows===2),true);
});
