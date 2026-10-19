import {test} from 'node:test';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
const OWNER='00000000-0000-4000-8000-000000000001',CONN='00000000-0000-4000-8000-000000000002',PROJECT='syntheticfixture',HASH='1'.repeat(64);
const RUN1='00000000-0000-4000-8000-000000000003',RUN2='00000000-0000-4000-8000-000000000004';
const fields=['id','user_id','connection_id','sync_run_id','resource_type','provider_record_id','raw_hash','raw_payload','normalized_payload','reconciliation','ingest_action','observed_at'];
const vectorHash=rows=>crypto.createHash('sha256').update(rows.slice().sort((a,b)=>a.id.localeCompare(b.id)).map(r=>JSON.stringify(fields.map(k=>r[k]))).join('\n')).digest('hex');
const precise='{"amount": 12345678901234567890.1234567890123456789}';
const fixture=await PGlite.create();
async function metadata(id,status,n){return(await fixture.query('SELECT $1::jsonb::text AS value',[JSON.stringify({id,status,raw_count:n,user_id:OWNER,connection_id:CONN,finished_at:'2026-01-01T00:00:00+00:00'})])).rows[0].value;}
const rows=[{id:'00000000-0000-4000-8000-000000000011',user_id:OWNER,connection_id:CONN,sync_run_id:RUN1,resource_type:'transaction',provider_record_id:'synthetic-one',raw_hash:'synthetic-hash',raw_payload:precise,normalized_payload:'{"description": "ação — café"}',reconciliation:'null',ingest_action:'unchanged',observed_at:'2026-01-01 12:34:56.123456+00'},{id:'00000000-0000-4000-8000-000000000012',user_id:OWNER,connection_id:CONN,sync_run_id:RUN1,resource_type:'transaction',provider_record_id:'synthetic-two',raw_hash:'synthetic-hash-2',raw_payload:'{"amount": 0.00000000000000000000000000001}',normalized_payload:'{}',reconciliation:'{}',ingest_action:'stale',observed_at:'2026-01-01 00:00:00+00'}];
const run1={type:'run',run_id:RUN1,metadata:await metadata(RUN1,'failed',999),row_count:2,source_vectors_sha256:vectorHash(rows),rows};
const run2={type:'run',run_id:RUN2,metadata:await metadata(RUN2,'cancelled',88),row_count:0,source_vectors_sha256:vectorHash([]),rows:[]};
await fixture.close();
const frames=()=>structuredClone([{type:'inventory',owner_id:OWNER,source_project:PROJECT,inventory_sha256:HASH,rows:2,runs:2},run1,run2,{type:'verified_collection',rows:2,runs:2,all_12_fields_equal:true,independent_sql_source_hashes_verified:true,full_inventory_covered:true}]);
const cli=fileURLToPath(new URL('./typed_restore.mjs',import.meta.url));
function execute(input,existing=false){
const root=fs.mkdtempSync(path.join(os.tmpdir(),'lts-restore-synthetic-')),database=path.join(root,'database'),report=path.join(root,'report.json');
if(existing){fs.mkdirSync(database);fs.writeFileSync(path.join(database,'sentinel'),'existing synthetic fixture');}
const child=spawnSync(process.execPath,[cli,'--data-dir',database,'--report',report,'--owner',OWNER,'--project',PROJECT,'--inventory-sha256',HASH,'--expected-rows','2','--expected-runs','2'],{input:input.map(x=>JSON.stringify(x)).join('\n')+'\n',encoding:'utf8',maxBuffer:1024*1024,timeout:120000});
assert.ifError(child.error);
return{root,database,report,child};
}
test('typed recovery preserves precision, Unicode, null, metadata, empty runs, rollback and reopening',async()=>{
const x=execute(frames());assert.equal(x.child.status,0,x.child.stderr);
const result=JSON.parse(fs.readFileSync(x.report,'utf8'));
assert.equal(result.restored_rows,2);assert.equal(result.restored_runs,2);
for(const k of ['all_12_sql_text_fields_equal','all_run_metadata_equal','reopen_and_all_hashes_verified','local_mutation_rollback_verified','duplicate_observation_key_rejected'])assert.equal(result[k],true,k);
for(const k of ['full_database_restore','native_server_restore','storage_binary_restore','eight_application_consumers_verified','production_modified'])assert.equal(result[k],false,k);
const db=await PGlite.create(x.database);await db.exec("SET timezone='UTC'");
assert.equal((await db.query('SELECT raw_payload::text AS value FROM recovery.observations WHERE id=$1::uuid',[rows[0].id])).rows[0].value,precise);
assert.equal((await db.query("SELECT source_metadata->>'raw_count' AS value FROM recovery.runs WHERE id=$1::uuid",[RUN1])).rows[0].value,'999');
await db.close();
});
const negatives=[
['wrong owner',f=>{f[1].rows[0].user_id=CONN;},/scope mismatch/],
['wrong trusted inventory hash',f=>{f[0].inventory_sha256='2'.repeat(64);},/scope\/hash mismatch/],
['corrupt independent source checksum',f=>{f[1].source_vectors_sha256='2'.repeat(64);},/source vector mismatch/],
['duplicate observation UUID',f=>{f[1].rows[1].id=f[1].rows[0].id;f[1].source_vectors_sha256=vectorHash(f[1].rows);},/23505/],
['impossible calendar date',f=>{f[1].rows[0].observed_at='2026-02-30 00:00:00+00';f[1].source_vectors_sha256=vectorHash(f[1].rows);},/22008/],
['missing run',f=>{f.splice(2,1);},/verify full collection|Incomplete/],
['noncanonical metadata text',f=>{f[1].metadata=JSON.stringify(JSON.parse(f[1].metadata));},/metadata mismatch/],
['unverified decoder end',f=>{f.at(-1).independent_sql_source_hashes_verified=false;},/verify full collection/]
];
for(const[name,change,reason]of negatives)test(name+' fails without a successful receipt',async()=>{
const f=frames();change(f);const x=execute(f);assert.notEqual(x.child.status,0);assert.equal(fs.existsSync(x.report),false);assert.match(x.child.stderr,reason);
if(name==='corrupt independent source checksum'){const db=await PGlite.create(x.database);assert.equal((await db.query('SELECT count(*)::int AS n FROM recovery.observations')).rows[0].n,0);await db.close();}
});
test('existing database directory is refused and preserved',()=>{const x=execute(frames(),true);assert.notEqual(x.child.status,0);assert.equal(fs.existsSync(x.report),false);assert.equal(fs.readFileSync(path.join(x.database,'sentinel'),'utf8'),'existing synthetic fixture');});
test('extra frame after verified end is rejected',()=>{const f=frames();f.push(structuredClone(f[1]));const x=execute(f);assert.notEqual(x.child.status,0);assert.equal(fs.existsSync(x.report),false);});
