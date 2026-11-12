import{PGlite}from'@electric-sql/pglite';import fs from'node:fs';import assert from'node:assert/strict';
const db=new PGlite(),u='11111111-1111-4111-8111-111111111111',v='22222222-2222-4222-8222-222222222222',results=[];
const one=async q=>(await db.query(q)).rows[0];async function test(n,f){await f();results.push(n);console.log('PASS',n);}
await db.exec(`CREATE SCHEMA auth;CREATE SCHEMA qa;CREATE SCHEMA lts_product_refresh_private_v415;CREATE SCHEMA lts_read_private_v430;
 CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('qa.user',true),'')::uuid$$;
 CREATE FUNCTION lts_product_refresh_private_v415.card_source_key(uuid)RETURNS text LANGUAGE sql STABLE AS $$SELECT 'source:'||$1::text$$;
 CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,100);
 CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,source_fingerprint text,refreshed_at timestamptz,UNIQUE(user_id,kind,as_of,from_date,to_date));
 CREATE FUNCTION lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
 CREATE TABLE qa.history(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text,account_assignment text,legacy_index integer,original_date date,displaced boolean,internal_transfer boolean,category text,counterparty text,center_cost text,excluded_from_spend boolean);
 INSERT INTO qa.history VALUES('2026-11-01','Banco fictício','Linha original',-123.45,'fixture','row1','actual','exact',1,'2026-11-01',false,false,'Mercado','Fictício',NULL,false);
 CREATE TABLE qa.payroll(projection_ref text,projection_date date,projection_amount numeric,staging_id uuid,actual_date date,actual_amount numeric,bank text);
 INSERT INTO qa.payroll VALUES('fixture:1','2026-11-01',3000,'33333333-3333-4333-8333-333333333333','2026-11-01',3000,'Banco fictício');
 CREATE FUNCTION public.lts_historical_cash_engine_v243(uuid,date,date)RETURNS SETOF qa.history LANGUAGE plpgsql AS $$BEGIN PERFORM set_config('qa.calls',(coalesce(nullif(current_setting('qa.calls',true),''),'0')::int+1)::text,true);RETURN QUERY SELECT * FROM qa.history WHERE event_date BETWEEN $2 AND $3 ORDER BY source_ref;END$$;
 CREATE FUNCTION public.lts_payroll_bank_matches_v231_engine_v243(uuid)RETURNS SETOF qa.payroll LANGUAGE plpgsql AS $$BEGIN PERFORM set_config('qa.calls',(coalesce(nullif(current_setting('qa.calls',true),''),'0')::int+1)::text,true);RETURN QUERY SELECT * FROM qa.payroll ORDER BY projection_ref;END$$;
 SELECT set_config('qa.user','${u}',false);`);
for(const name of['history','payroll']){
 const call=(who=u,from='2026-01-01')=>name==='history'?`public.lts_historical_effective_cash_v4('${who}','${from}','2026-12-31')`:`public.lts_payroll_bank_matches_v231('${who}')`;
 await db.exec(fs.readFileSync('backend/patches/v442/'+name+'_before.sql','utf8'));
 const baseline=(await one('SELECT coalesce(jsonb_agg(r),\'[]\')x FROM '+call()+'r')).x;
 const sig=name==='history'?'public.lts_historical_effective_cash_v4(uuid,date,date)':'public.lts_payroll_bank_matches_v231(uuid)';
 const attrs=await one(`SELECT provolatile,prosecdef,proconfig,proacl FROM pg_proc WHERE oid='${sig}'::regprocedure`);
 await db.exec('TRUNCATE public.lts_v229_read_cache');
 const pair=async(second=call())=>{await db.exec("BEGIN READ ONLY;SELECT set_config('qa.calls','0',true)");try{return await one(`WITH a AS MATERIALIZED(SELECT coalesce(jsonb_agg(r),'[]')x FROM ${call()}r),b AS MATERIALIZED(SELECT coalesce(jsonb_agg(r),'[]')y FROM a,LATERAL ${second}r) SELECT x,y,current_setting('qa.calls')::int calls FROM a,b`);}finally{await db.exec('ROLLBACK');}};
 await test(name+' predecessor repeats its original engine on a cold read-only statement',async()=>{assert.equal((await pair()).calls,2);});
 await db.exec(fs.readFileSync('backend/patches/v442/'+name+'_candidate.sql','utf8'));
 await test(name+' memo computes once with identical ordered financial rows',async()=>{const x=await pair();assert.equal(x.calls,1);assert.deepEqual(x.x,baseline);assert.deepEqual(x.x,x.y);});
 await test(name+' memo is isolated by owner'+(name==='history'?' and range':''),async()=>{assert.equal((await pair(call(v))).calls,2);if(name==='history')assert.equal((await pair(call(u,'2026-11-02'))).calls,2);});
 await test(name+' retains earlier inputs after an intervening owner or range',async()=>{await db.exec("BEGIN READ ONLY;SELECT set_config('qa.calls','0',true)");try{const second=name==='history'?call(u,'2026-11-02'):call(v),r=await one(`WITH a AS MATERIALIZED(SELECT jsonb_agg(r)x FROM ${call()}r),b AS MATERIALIZED(SELECT jsonb_agg(r)y FROM a,LATERAL ${second}r),c AS MATERIALIZED(SELECT jsonb_agg(r)z FROM b,LATERAL ${call()}r)SELECT current_setting('qa.calls')::int calls FROM c`);assert.equal(r.calls,2);}finally{await db.exec('ROLLBACK');}});
 await test(name+' malformed memo representations fall back safely',async()=>{for(const m of['{','[]','{}','{"payload":{}}']){await db.query("SELECT set_config($1,$2,false)",['lts.'+name+'_memo_v442',m]);assert.equal((await pair()).calls,1);}});
 await test(name+' memo is not a completed-response or persistent financial cache',async()=>{await db.query("SELECT set_config($1,'',false)",['lts.'+name+'_memo_v442']);await pair();assert.equal((await db.query("SELECT current_setting($1,true)x",['lts.'+name+'_memo_v442'])).rows[0].x,'');assert.equal((await one('SELECT count(*)n FROM public.lts_v229_read_cache')).n,0);});
 await test(name+' privileges, owner execution mode and configuration remain unchanged',async()=>{assert.deepEqual(await one(`SELECT provolatile,prosecdef,proconfig,proacl FROM pg_proc WHERE oid='${sig}'::regprocedure`),attrs);});
}
await test('An unavailable optional history cache never blocks a valid freshly computed result',async()=>{const r=(await one(`SELECT jsonb_agg(r)x FROM public.lts_historical_effective_cash_v4('${u}','2026-01-01','2026-12-31')r`)).x;assert.equal(r[0].signed_amount,-123.45);assert.equal((await one('SELECT count(*)n FROM public.lts_v229_read_cache')).n,0);});
fs.mkdirSync('qa/v442',{recursive:true});fs.writeFileSync('qa/v442/auxiliary-result.json',JSON.stringify({pass:true,tests:results.length,results,synthetic:true},null,2));await db.close();
