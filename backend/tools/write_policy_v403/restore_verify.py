"""Independent database restore: exact source vectors and reader output."""
import json,os,subprocess

TABLES=['lts_open_finance_observation','lts_open_finance_staging','lts_open_finance_sync_run','lts_open_finance_connection','asset_positions','financial_events','lts_liquidity_movement','lts_validated_lock_registry']
def query(db,sql):
 env={**os.environ,'PGDATABASE':db}
 return subprocess.run(['psql','-XAt','-v','ON_ERROR_STOP=1','-c',sql],env=env,text=True,capture_output=True,check=True).stdout.strip()
source={};restored={}
for t in TABLES:
 order='lock_key'if t=='lts_validated_lock_registry'else'id'
 sql=f"SELECT jsonb_build_object('rows',count(*),'sha256',encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(t)ORDER BY {order}),'[]')::text,'UTF8')),'hex'))FROM public.{t} t;"
 source[t]=json.loads(query('postgres',sql));restored[t]=json.loads(query('v403_restore',sql))
 assert source[t]==restored[t],t
u='11111111-1111-4111-8111-111111111111'
sql=f"SELECT (public.lts_cofrinho_provider_position_v402('{u}',current_date)-'source_observed_at')::text;"
assert query('postgres',sql)==query('v403_restore',sql)
assert query('v403_restore',f"SELECT public.lts_cofrinho_provider_position_v402('{u}',current_date)->>'snapshot_brl'")=='1010'
print(json.dumps({'independent_database':'v403_restore','source_rows_exact':source,'daily_cofrinho_restored_brl':'1010','original_observation_history_restored':True,'private_production_full_restore':False}))
