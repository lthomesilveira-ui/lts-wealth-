import fs from'node:fs';import{execFileSync}from'node:child_process';import assert from'node:assert/strict';
// Keep all 17 original budget SQL, writer, isolation and authorization checks.
// Execute the real new builder on the same synthetic source rows before them.
const file='backend/qa/v441/.v442-builder-validation.mjs';let s=fs.readFileSync('backend/qa/v441/test.mjs','utf8');
const needle="await db.exec(fs.readFileSync(new URL('../../patches/v441/budget.sql',import.meta.url),'utf8'));";
assert.equal(s.split(needle).length,2);s=s.replace(needle,needle+"\nawait db.exec(\"CREATE TABLE public.lts_category_catalog(user_id uuid,category_key text,category text);CREATE TABLE public.lts_category_binding_v290(user_id uuid,category_key text,raw_category text);\");\nawait db.exec(fs.readFileSync(new URL('../../patches/v442/budget_builder_candidate.sql',import.meta.url),'utf8'));\n");
const at='let original=await build();';assert.equal(s.split(at).length,2);
s=s.replace(at,at+`
await test('Planning aliases use only unambiguous owner category bindings',async()=>{
 await db.exec(\`INSERT INTO public.lts_category_catalog VALUES('\${user}','clothes','Vestuário'),('\${user}','health','Saúde'),('22222222-2222-4222-8222-222222222222','private','Outra pessoa');INSERT INTO public.lts_category_binding_v290 VALUES('\${user}','health','Pessoa — Saúde'),('\${user}','health','Ambígua'),('\${user}','clothes','Ambígua'),('22222222-2222-4222-8222-222222222222','private','Somente outra pessoa');\`);
 const b=await build();assert.deepEqual(b.category_aliases,{'Pessoa — Saúde':'Saúde'});
});
await test('Recorded card consumption is exposed as a subset, never a second expense',async()=>{const x=original.rows.find(x=>x.category==='Mercado').months[10];assert.equal(x.actual,50);assert.equal(x.card_actual,50);assert.deepEqual(original.income_approvals,{year:false,months:{}});});
await test('Thirteenth salary without an ordinal stays outside regular pay and the salary reference',async()=>{
 await db.exec(\`INSERT INTO qa.income VALUES('\${user}','{"event_date":"2026-10-20","signed_amount":10000,"category":"Salário","description":"Adiantamento 13 Salário"}')\`);
 const b=await build();assert.equal(b.months[9].income_regular,3000);assert.equal(b.months[9].income_thirteenth,10000);assert.equal(b.months[9].income_extraordinary,30200);assert.equal(b.reference.salary_monthly,3000);
 await db.exec("DELETE FROM qa.income WHERE x->>'description'='Adiantamento 13 Salário'");
});
await test('Future-year thirteenth actuals remain zero and approval flags remain unknown-to-owner',async()=>{const b=await build(2027);assert(b.months.every(x=>x.income_thirteenth===0));assert.deepEqual(b.income_approvals,{year:false,months:{}});});
`);
const incomeTest="await test('Zero is a valid explicit target'";assert.equal(s.split(incomeTest).length,2);
s=s.replace(incomeTest,"await test('Saved owner income approval is exposed without changing it',async()=>{const b=await build();assert.equal(b.income_approvals.months['2026-11'],true);assert.equal(b.income_approvals.year,false);assert.equal(b.months[10].income_target,2500);});\n"+incomeTest);
try{fs.writeFileSync(file,s);execFileSync('node',[file],{stdio:'inherit'});}finally{fs.rmSync(file,{force:true});}
