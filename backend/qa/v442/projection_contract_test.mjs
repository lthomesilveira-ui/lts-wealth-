import {PGlite} from '@electric-sql/pglite';import fs from 'node:fs';import assert from 'node:assert/strict';
const db=new PGlite();await db.exec('CREATE SCHEMA lts_month_private_v393');
await db.exec(fs.readFileSync('backend/patches/v442/projection_contract.sql','utf8'));
const base=()=>({cards:[{family:'synthetic',cycles:[{month:'2026-12-01',amount:120,items:[{amount:100,provider_status:'PROJECTED'},{amount:20,provider_status:'POSTED'}]}]}]});
const run=async p=>(await db.query("select lts_month_private_v393.projection_contract_v442($1,'2026-12-01','2026-12-31') p",[p])).rows[0].p;
let n=0;async function test(name,fn){await fn();n++;console.log('PASS',name);}
await test('Missing split derived only from exact total',async()=>{let p=base(),q=await run(p);assert.equal(q.cards[0].cycles[0].projected_amount,100);assert.equal(q.cards[0].cycles[0].received_amount,20);assert.deepEqual(q.cards[0].cycles[0].items,p.cards[0].cycles[0].items);assert.equal(q.cards[0].cycles[0].amount,120)});
await test('Existing explicit projection mismatch remains for original guard',async()=>{let p=base();p.cards[0].cycles[0].projected_amount=0;assert.equal((await run(p)).cards[0].cycles[0].projected_amount,0)});
await test('Incomplete total rejected',async()=>{let p=base();p.cards[0].cycles[0].amount=130;await assert.rejects(()=>run(p),/incomplete cycle/)});
await test('Unknown amount rejected',async()=>{let p=base();p.cards[0].cycles[0].amount=null;await assert.rejects(()=>run(p),/incomplete cycle/)});
await test('Incomplete flag rejected',async()=>{let p=base();p.cards[0].cycles[0].complete=false;await assert.rejects(()=>run(p),/incomplete cycle/)});
await test('Duplicate family/month cannot double count',async()=>{let p=base();p.cards.push(p.cards[0]);await assert.rejects(()=>run(p),/Ambiguous/)});
await test('Outside selected period remains untouched',async()=>{let p=base();p.cards[0].cycles[0].month='2027-01-01';assert.deepEqual(await run(p),p)});
await test('Payment rows do not become expenses',async()=>{let p=base();p.cards[0].cycles[0].items.push({amount:120,provider_status:'PROJECTED',is_payment:true});assert.equal((await run(p)).cards[0].cycles[0].projected_amount,100)});
await test('Missing item amount rejected',async()=>{let p=base();delete p.cards[0].cycles[0].items[0].amount;await assert.rejects(()=>run(p),/Missing/)});
await test('Adapter is idempotent',async()=>{let q=await run(base());assert.deepEqual(await run(q),q)});
await test('Original guard/auth/epoch protections byte-preserved',async()=>{let b=fs.readFileSync('backend/patches/v442/month_overview_before.sql','utf8'),c=fs.readFileSync('backend/patches/v442/month_overview_candidate.sql','utf8');assert.equal(c.replace('\n cycles:=lts_month_private_v393.projection_contract_v442(cycles,p_from,p_to);',''),b)});

await test('Guarded installer supports predecessor and exact rerun',async()=>{
 await db.exec(fs.readFileSync('backend/patches/v442/month_overview_before.sql','utf8'));
 const install=fs.readFileSync('backend/patches/v442/month_projection_install.sql','utf8');
 await db.exec(install);await db.exec(install);
});
await test('Unknown concurrent predecessor rejected atomically',async()=>{
 await db.exec("COMMENT ON FUNCTION public.lts_browser_month_overview_v393(date,date) IS 'test'");
 const b=fs.readFileSync('backend/patches/v442/month_overview_before.sql','utf8').replace("revision text;","revision text;\n -- unexpected concurrent change\n");
 await db.exec(b);
 await assert.rejects(()=>db.exec(fs.readFileSync('backend/patches/v442/month_projection_install.sql','utf8')),/Unexpected month overview predecessor/);
 await db.exec('ROLLBACK');
});

await test('Existing received split disagreement rejected',async()=>{let p=base();p.cards[0].cycles[0].received_amount=21;await assert.rejects(()=>run(p),/Received split mismatch/)});
await test('Missing details rejected rather than discarded',async()=>{let p=base();delete p.cards[0].cycles[0].items;await assert.rejects(()=>run(p),/Missing cycle details/)});
console.log(n+' tests passed; synthetic; no production changes');await db.close();
