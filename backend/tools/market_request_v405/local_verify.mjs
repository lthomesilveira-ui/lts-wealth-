import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const { PGlite } = await import(process.env.LTS_PGLITE_MODULE || '@electric-sql/pglite');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const fixture = spawnSync('python3', [path.join(root, 'backend/tools/market_request_v405/setup.py')], { encoding: 'utf8' });
if (fixture.status !== 0) throw new Error(fixture.stderr);
const migration = readFileSync(path.join(root, 'backend/patches/v405/market_request_generations.sql'), 'utf8');
const verify = readFileSync(path.join(root, 'backend/tools/market_request_v405/verify.sql'), 'utf8');
const db = new PGlite();
try {
  const version = (await db.query('SELECT version(),current_setting(\'server_version_num\')::int major')).rows[0];
  if (Math.floor(version.major / 10000) !== 17) throw new Error('This regression requires PostgreSQL 17');
  await db.exec(fixture.stdout);
  await db.transaction(tx => tx.exec(migration));
  await db.exec(verify);
  const snapshot = async () => (await db.query(`SELECT jsonb_build_object(
    'requests',(SELECT jsonb_agg(to_jsonb(r)ORDER BY request_generation,request_id)FROM public.lts_market_request_v290 r),
    'quotes',(SELECT jsonb_agg(to_jsonb(q)ORDER BY id)FROM public.lts_market_quote_v290 q),
    'heads',(SELECT jsonb_agg(to_jsonb(h)ORDER BY symbol)FROM public.lts_market_head_v290 h),
    'refresh',(SELECT jsonb_agg(to_jsonb(s)ORDER BY symbol)FROM public.lts_market_refresh_v290 s),
    'revision',(SELECT epoch FROM public.lts_read_cache_epoch_v242))::text AS snapshot`)).rows[0].snapshot;
  const beforeReplay = await snapshot();
  await db.transaction(tx => tx.exec(migration));
  if (await snapshot() !== beforeReplay) throw new Error('Migration replay changed request or quotation data');
  await db.query("SELECT public.qa_assert_v405('migration_replay_preserves_all_data',true)");
  let guardRejected = false;
  try {
    await db.transaction(async tx => {
      await tx.exec("CREATE OR REPLACE FUNCTION public.lts_market_request_quotes_v290()RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN RETURN '[]'::jsonb;END$$");
      await tx.exec(migration);
    });
  } catch (error) {
    if (!String(error).includes('predecessor changed')) throw error;
    guardRejected = true;
  }
  if (!guardRejected) throw new Error('Unexpected predecessor was not rejected');
  await db.query("SELECT public.qa_assert_v405('changed_predecessor_rejected_atomically',true)");
  if (await snapshot() !== beforeReplay) throw new Error('Rejected upgrade changed historical data');
  const result = {
    engine: version.version,
    proof_kind: 'isolated PostgreSQL 17 engine; synthetic transport and request-ID reset',
    checks: (await db.query('SELECT name FROM public.qa_result_v405 ORDER BY name')).rows.map(row => row.name),
    financial_data_used: false,
    actual_postmaster_crash_test: false,
  };
  if (process.env.LTS_QUOTE_PROOF_PATH) writeFileSync(process.env.LTS_QUOTE_PROOF_PATH, JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
} catch (error) {
  console.error(JSON.stringify({ error: error.message, detail: error.detail, where: error.where, position: error.position }, null, 2));
  process.exitCode = 1;
} finally {
  await db.close();
}
