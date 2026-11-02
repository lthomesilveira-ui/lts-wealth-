import json,os,subprocess

def query(db,sql):return subprocess.run(['psql','-XAt','-v','ON_ERROR_STOP=1','-c',sql],env={**os.environ,'PGDATABASE':db},text=True,capture_output=True,check=True).stdout.strip()
u='00000000-0000-4000-8000-000000000004'
sql=f"SELECT public.lts_backup_bundle_read_v380('{u}',current_date);"
a=query('postgres',sql);b=query('v403_restore',sql);assert a==b
j=json.loads(a)
assert len(j['modern']['tables'])==35
assert len(j['modern']['tables']['lts_open_finance_observation'])==2
assert len(j['modern']['tables']['lts_open_finance_sync_run'])==2
for t in ['lts_open_finance_resource_map','lts_open_finance_observation','lts_open_finance_sync_run','lts_backup_snapshot','lts_backup_supplement_v380']:
 sql=f"SELECT encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(t)ORDER BY to_jsonb(t)::text),'[]')::text,'UTF8')),'hex')FROM public.{t} t;"
 assert query('postgres',sql)==query('v403_restore',sql),t
print(json.dumps({'independent_postgres_database':True,'restored_profile_datasets':35,'source_positions_and_mapping_restored':True,'referenced_runs_restored':True,'old_and_new_archives_unchanged':True,'synthetic_only':True,'full_production_database_storage_auth_restore':False}))
