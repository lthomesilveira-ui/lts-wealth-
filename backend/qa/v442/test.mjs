import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';
const db=new PGlite(),results=[],u='11111111-1111-4111-8111-111111111111',v='22222222-2222-4222-8222-222222222222';
const one=async q=>(await db.query(q)).rows[0];
async function test(name,f){await f();results.push(name);console.log('PASS',name);}
function patch(s){return execFileSync('python3',['-c',`import importlib.util,sys;s=importlib.util.spec_from_file_location('p','backend/tools/card_statement_memo_v442/patch.py');p=importlib.util.module_from_spec(s);s.loader.exec_module(p);print(p.patch(sys.stdin.read()),end='')`],{input:s,encoding:'utf8'});}
const source=`CREATE OR REPLACE FUNCTION public.lts_card_cycles_v226(p_user_id uuid)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE result jsonb; c6_contract_uncertain boolean; c6_unresolved jsonb; c6_document_ambiguous jsonb;
BEGIN
 PERFORM set_config('qa.calls',(coalesce(nullif(current_setting('qa.calls',true),''),'0')::int+1)::text,true);
 result:=jsonb_build_object('owner',p_user_id,'auth',auth.uid(),'role',current_user,'computed_at',clock_timestamp(),'amount',(SELECT amount FROM qa.source),'installment','2027-02-03','category','Presente Benjamin');
 RETURN public.lts_card_settlement_overlay_v290(p_user_id,public.lts_card_due_overlay_v290(p_user_id,public.lts_card_forecast_overlay_v311(p_user_id,result)));
END;
$function$;
`;
await db.exec(`CREATE SCHEMA auth;CREATE SCHEMA qa;CREATE SCHEMA lts_product_refresh_private_v415;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('qa.user',true),'')::uuid$$;
 CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,100);
 CREATE TABLE qa.source(amount numeric);INSERT INTO qa.source VALUES(15000);
 CREATE FUNCTION lts_product_refresh_private_v415.card_source_key(uuid) RETURNS text LANGUAGE sql STABLE AS $$SELECT 'source:'||$1::text$$;
 CREATE FUNCTION public.lts_card_forecast_overlay_v311(uuid,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT $2||'{"forecast":true}'::jsonb$$;
 CREATE FUNCTION public.lts_card_due_overlay_v290(uuid,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT $2||'{"due":true}'::jsonb$$;
 CREATE FUNCTION public.lts_card_settlement_overlay_v290(uuid,jsonb) RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT $2||'{"settlement":true}'::jsonb$$;
 SELECT set_config('qa.user','${u}',false);`);
await db.exec(source);const baseline=(await one(`SELECT public.lts_card_cycles_v226('${u}') x`)).x;
const attrs=await one("SELECT provolatile,prosecdef,proconfig FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure");
await db.exec(patch(source));
const pair=(tail=`public.lts_card_cycles_v226('${u}')`)=>one(`WITH reset AS MATERIALIZED(SELECT set_config('qa.calls','0',true)),a AS MATERIALIZED(SELECT public.lts_card_cycles_v226('${u}') x FROM reset),b AS MATERIALIZED(SELECT ${tail} y FROM a) SELECT a.x,b.y,current_setting('qa.calls')::int calls FROM a,b`);
const strip=x=>{const{computed_at,...rest}=x;return rest;};
await test('Actual candidate retains the entire original financial source',async()=>{const a=fs.readFileSync('backend/patches/v442/card_cycles_before.sql','utf8'),b=fs.readFileSync('backend/patches/v442/card_cycles_candidate.sql','utf8');assert.equal(patch(a),b);});
await test('Repeated same-statement card reads compute once with exact financial output',async()=>{const r=await pair();assert.equal(r.calls,1);assert.deepEqual(r.x,r.y);assert.deepEqual(strip(r.x),strip(baseline));});
await test('Distinct owners never share a card result',async()=>{const r=await pair(`public.lts_card_cycles_v226('${v}')`);assert.equal(r.calls,2);assert.equal(r.y.owner,v);});
await test('Invalid memo representations fall back to the original computation',async()=>{for(const m of ['{','[]','{}','{"payload":[]}']){await db.query('SELECT set_config(\'lts.card_cycles_memo_v442\',$1,false)',[m]);const r=await pair();assert.equal(r.calls,1);assert.equal(r.x.amount,15000);}});
await test('Tampering with a memo payload is rejected inside the same statement',async()=>{const r=await one(`WITH reset AS MATERIALIZED(SELECT set_config('qa.calls','0',true)),a AS MATERIALIZED(SELECT public.lts_card_cycles_v226('${u}') x FROM reset),tamper AS MATERIALIZED(SELECT set_config('lts.card_cycles_memo_v442',jsonb_set(current_setting('lts.card_cycles_memo_v442')::jsonb,'{payload,amount}','1')::text,true) FROM a),b AS MATERIALIZED(SELECT public.lts_card_cycles_v226('${u}') y FROM tamper) SELECT y,current_setting('qa.calls')::int calls FROM b`);assert.equal(r.calls,2);assert.equal(r.y.amount,15000);});
await test('Transaction-local memo does not persist as a completed-response cache',async()=>{await db.exec("SELECT set_config('lts.card_cycles_memo_v442','',false)");await pair();assert.equal((await one("SELECT current_setting('lts.card_cycles_memo_v442',true) x")).x,'');});
await test('Changed source and epoch appear on the next statement',async()=>{await db.exec('UPDATE qa.source SET amount=16000;UPDATE public.lts_read_cache_epoch_v242 SET epoch=101;');const r=await pair();assert.equal(r.x.amount,16000);assert.equal(r.calls,1);});
await test('A changed authenticated identity cannot reuse the prior identity',async()=>{await db.exec(`SELECT set_config('qa.user','${v}',false)`);const r=await pair();assert.equal(r.x.auth,v);assert.equal(r.calls,1);});
await test('Function volatility, invoker rights and configuration remain identical',async()=>{assert.deepEqual(await one("SELECT provolatile,prosecdef,proconfig FROM pg_proc WHERE oid='public.lts_card_cycles_v226(uuid)'::regprocedure"),attrs);});
fs.mkdirSync('qa/v442',{recursive:true});fs.writeFileSync('qa/v442/sql-result.json',JSON.stringify({pass:true,tests:results.length,results,synthetic:true,private_owner_data:false},null,2));await db.close();
