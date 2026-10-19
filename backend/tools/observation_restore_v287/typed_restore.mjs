import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import crypto from 'node:crypto';

const FIELDS = ['id','user_id','connection_id','sync_run_id','resource_type','provider_record_id','raw_hash','raw_payload','normalized_payload','reconciliation','ingest_action','observed_at'];
const CASTS = {id:'uuid',user_id:'uuid',connection_id:'uuid',sync_run_id:'uuid',raw_payload:'jsonb',normalized_payload:'jsonb',reconciliation:'jsonb',observed_at:'timestamptz'};
const args = {};
for (let i=2;i<process.argv.length;i+=2) {
  if (!process.argv[i]?.startsWith('--') || process.argv[i+1]===undefined) throw new Error('Invalid CLI arguments');
  args[process.argv[i].slice(2)] = process.argv[i+1];
}
const requireValue=(condition,message)=>{if(!condition)throw new Error(message)};
const uid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
requireValue(uid.test(args.owner??''),'Explicit owner UUID required');
requireValue(/^[a-z0-9]+$/.test(args.project??''),'Explicit project reference required');
requireValue(/^[0-9a-f]{64}$/.test(args['inventory-sha256']??''),'Trusted inventory hash required');
const expectedRows=Number(args['expected-rows']), expectedRuns=Number(args['expected-runs']);
requireValue(Number.isSafeInteger(expectedRows)&&expectedRows>=0&&Number.isSafeInteger(expectedRuns)&&expectedRuns>0,'Explicit inventory counts required');
const dataDir=path.resolve(args['data-dir']??'');
requireValue(args['data-dir']&&dataDir!==path.parse(dataDir).root&&!fs.existsSync(dataDir),'Database target must be a new local directory');
requireValue(args.report&&!fs.existsSync(args.report),'Report target must be new');
fs.mkdirSync(dataDir,{mode:0o700});
let db;
let phase='initialization',runs=0,total=0,headerSeen=false,footerSeen=false;
const started=Date.now(),digests=[],seenRuns=new Set();
const insertSql="INSERT INTO recovery.observations ("+FIELDS.join(',')+") SELECT "+FIELDS.map(f=>'r.'+f+(CASTS[f]?'::'+CASTS[f]:'')).join(',')+" FROM jsonb_to_recordset($1::jsonb) AS r("+FIELDS.map(f=>f+' text').join(',')+")";
const vector="array_to_json(ARRAY["+FIELDS.map(f=>'o.'+f+'::text').join(',')+"])::text";
const hashSql="SELECT count(*)::int AS rows, encode(pg_catalog.sha256(convert_to(coalesce(string_agg("+vector+",E'\\n' ORDER BY o.id),''),'UTF8')),'hex') AS sha256 FROM recovery.observations o WHERE sync_run_id=$1::uuid";
async function verifyRun(conn,entry) {
  const got=(await conn.query(hashSql,[entry.run_id])).rows[0];
  requireValue(got.rows===entry.row_count && got.sha256===entry.source_vectors_sha256,'Typed SQL source vector mismatch');
  const meta=(await conn.query("SELECT source_metadata::text AS metadata FROM recovery.runs WHERE id=$1::uuid",[entry.run_id])).rows[0];
  requireValue(meta?.metadata===entry.metadata,'Typed SQL run metadata mismatch');
}
try {
  db=await PGlite.create(dataDir);
  const engine=(await db.query("SELECT version() AS version,current_setting('server_version_num') AS version_num")).rows[0];
  await db.exec("SET timezone='UTC'; SET datestyle='ISO,YMD'; CREATE SCHEMA recovery; REVOKE ALL ON SCHEMA recovery FROM PUBLIC;");
  await db.exec("CREATE TABLE recovery.owner_reference(id uuid PRIMARY KEY); CREATE TABLE recovery.connection_reference(id uuid PRIMARY KEY,user_id uuid NOT NULL REFERENCES recovery.owner_reference(id)); CREATE TABLE recovery.runs(id uuid PRIMARY KEY,user_id uuid NOT NULL REFERENCES recovery.owner_reference(id),connection_id uuid NOT NULL REFERENCES recovery.connection_reference(id),source_metadata jsonb NOT NULL); CREATE TABLE recovery.observations(id uuid PRIMARY KEY,user_id uuid NOT NULL REFERENCES recovery.owner_reference(id),connection_id uuid NOT NULL REFERENCES recovery.connection_reference(id),sync_run_id uuid NOT NULL REFERENCES recovery.runs(id),resource_type text NOT NULL,provider_record_id text NOT NULL,raw_hash text NOT NULL,raw_payload jsonb NOT NULL,normalized_payload jsonb NOT NULL,reconciliation jsonb NOT NULL,ingest_action text NOT NULL CHECK(ingest_action IN('inserted','updated','unchanged','stale')),observed_at timestamptz NOT NULL,UNIQUE(sync_run_id,resource_type,provider_record_id)); ALTER TABLE recovery.observations ENABLE ROW LEVEL SECURITY; REVOKE ALL ON ALL TABLES IN SCHEMA recovery FROM PUBLIC;");
  await db.query("INSERT INTO recovery.owner_reference VALUES($1::uuid)",[args.owner]);
  phase='restore';
  const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
  for await (const line of input) {
    input.pause();
    requireValue(Buffer.byteLength(line)<=64*1024*1024,'Input frame exceeds bounded size');
    const frame=JSON.parse(line);
    requireValue(frame&&typeof frame==='object'&&!Array.isArray(frame),'Invalid frame');
    if(frame.type==='inventory') {
      requireValue(!headerSeen&&runs===0,'Repeated inventory frame');
      requireValue(frame.owner_id===args.owner&&frame.source_project===args.project&&frame.inventory_sha256===args['inventory-sha256'],'Inventory scope/hash mismatch');
      requireValue(frame.rows===expectedRows&&frame.runs===expectedRuns,'Inventory count mismatch');
      headerSeen=true;input.resume();continue;
    }
    requireValue(headerSeen&&!footerSeen,'Frame outside inventory boundaries');
    if(frame.type==='verified_collection') {
      requireValue(frame.rows===total&&frame.runs===runs&&frame.all_12_fields_equal===true&&frame.independent_sql_source_hashes_verified===true&&frame.full_inventory_covered===true,'Independent decoder did not verify full collection');
      footerSeen=true;input.resume();continue;
    }
    requireValue(frame.type==='run'&&uid.test(frame.run_id??'')&&!seenRuns.has(frame.run_id),'Unknown/repeated run frame');
    requireValue(Array.isArray(frame.rows)&&frame.rows.length===frame.row_count&&frame.rows.length<=100000&&/^[0-9a-f]{64}$/.test(frame.source_vectors_sha256??''),'Invalid run coverage/hash');
    requireValue(typeof frame.metadata==='string','Run metadata must remain PostgreSQL text');
    const meta=JSON.parse(frame.metadata);
    requireValue(meta.id===frame.run_id&&meta.user_id===args.owner&&uid.test(meta.connection_id??'')&&['success','partial','failed','cancelled'].includes(meta.status)&&meta.finished_at!==null,'Run scope/status mismatch');
    for(const row of frame.rows) {
      requireValue(Object.keys(row).length===FIELDS.length&&FIELDS.every(k=>typeof row[k]==='string'),'Observation schema/text drift');
      requireValue(row.user_id===args.owner&&row.connection_id===meta.connection_id&&row.sync_run_id===frame.run_id&&uid.test(row.id),'Observation scope mismatch');
    }
    await db.transaction(async tx=>{
      await tx.query("INSERT INTO recovery.connection_reference VALUES($1::uuid,$2::uuid) ON CONFLICT(id) DO NOTHING",[meta.connection_id,args.owner]);
      await tx.query("INSERT INTO recovery.runs VALUES($1::uuid,$2::uuid,$3::uuid,$4::jsonb)",[frame.run_id,args.owner,meta.connection_id,frame.metadata]);
      for(let i=0;i<frame.rows.length;i+=256)await tx.query(insertSql,[JSON.stringify(frame.rows.slice(i,i+256))]);
      await verifyRun(tx,{run_id:frame.run_id,row_count:frame.row_count,source_vectors_sha256:frame.source_vectors_sha256,metadata:frame.metadata});
    });
    seenRuns.add(frame.run_id);runs++;total+=frame.row_count;
    digests.push({run_id:frame.run_id,row_count:frame.row_count,source_vectors_sha256:frame.source_vectors_sha256,metadata:frame.metadata});
    if(runs%25===0)console.log(JSON.stringify({phase:'typed_restore_progress',runs,rows:total,elapsed_ms:Date.now()-started}));
    input.resume();
  }
  requireValue(headerSeen&&footerSeen&&runs===expectedRuns&&total===expectedRows,'Incomplete collection');
  const before=(await db.query("SELECT count(*)::int AS rows,count(DISTINCT sync_run_id)::int AS nonempty_runs FROM recovery.observations")).rows[0];
  requireValue(before.rows===expectedRows,'Whole-table row count mismatch');
  phase='rollback_test';
  const first=(await db.query("SELECT id::text,sync_run_id::text,ingest_action FROM recovery.observations ORDER BY id LIMIT 1")).rows[0];
  let rollbackPassed=false,duplicateRejected=false;
  if(first) {
    const entry=digests.find(x=>x.run_id===first.sync_run_id);
    await db.exec('BEGIN');
    await db.query("UPDATE recovery.observations SET ingest_action=CASE WHEN ingest_action='stale' THEN 'unchanged' ELSE 'stale' END WHERE id=$1::uuid",[first.id]);
    const changed=(await db.query(hashSql,[first.sync_run_id])).rows[0];
    requireValue(changed.sha256!==entry.source_vectors_sha256,'Rollback probe did not alter local test row');
    await db.exec('ROLLBACK');
    await verifyRun(db,entry);rollbackPassed=true;
    await db.exec('BEGIN');
    try {
      await db.query("INSERT INTO recovery.observations SELECT * FROM recovery.observations WHERE id=$1::uuid",[first.id]);
    } catch(e) {duplicateRejected=e.code==='23505';}
    await db.exec('ROLLBACK');
    requireValue(duplicateRejected,'Duplicate-key protection missing');
    await verifyRun(db,entry);
  }
  phase='reopen';
  await db.exec('CHECKPOINT');
  await db.syncToFs();
  await db.close();
  db=await PGlite.create(dataDir);
  await db.exec("SET timezone='UTC'; SET datestyle='ISO,YMD'");
  const reopenedCount=(await db.query('SELECT count(*)::int AS rows FROM recovery.observations')).rows[0].rows;
  requireValue(reopenedCount===expectedRows,'Reopened row count mismatch');
  for(const entry of digests)await verifyRun(db,entry);
  const rebuilt=(await db.query("SELECT pg_database_size(current_database())::text AS database_bytes,pg_total_relation_size('recovery.observations')::text AS observation_table_bytes")).rows[0];
  const metadataDigest=crypto.createHash('sha256').update(JSON.stringify(digests)).digest('hex');
  const report={pass:true,scope:'Typed historical observation table and exact run metadata in isolated PostgreSQL WebAssembly engine',engine,package:'@electric-sql/pglite@0.3.16',source_project:args.project,owner_id:args.owner,inventory_sha256:args['inventory-sha256'],restored_rows:total,restored_runs:runs,all_12_sql_text_fields_equal:true,all_run_metadata_equal:true,independent_source_vectors_verified:true,reopen_and_all_hashes_verified:true,local_mutation_rollback_verified:rollbackPassed,duplicate_observation_key_rejected:duplicateRejected,parent_rows:'Reference IDs only, not restored connection/user records',restored_collection_digest:metadataDigest,rebuilt,elapsed_ms:Date.now()-started,production_modified:false,originals_removed:false,native_server_restore:false,full_database_restore:false,storage_binary_restore:false,eight_application_consumers_verified:false,current_production_snapshot:false};
  fs.writeFileSync(args.report,JSON.stringify(report,null,2)+'\n',{flag:'wx',mode:0o600});
  console.log(JSON.stringify({phase:'complete',pass:true,rows:total,runs,elapsed_ms:report.elapsed_ms}));
  await db.close();db=undefined;
} catch(e) {
  console.error(JSON.stringify({pass:false,phase,error:e.code??e.message,integrity_detail:e.code==='XX002'?e.message:undefined,runs,rows:total}));
  if(db)await db.close().catch(()=>{});
  process.exitCode=1;
}
