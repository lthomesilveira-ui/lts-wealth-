"""Synthetic-only integration in a newly created loopback PostgreSQL 16 database."""
from pathlib import Path
import os,uuid
from connection_config import local_connection_options
P=Path(__file__).parent
if os.environ.get('P16_QA_ALLOW_DISPOSABLE')!='1':raise SystemExit('Explicit disposable QA flag required')
import psycopg
from psycopg import sql
opts=local_connection_options()
admin=psycopg.connect(**opts,dbname='postgres',autocommit=True)
assert admin.execute('show server_version_num').fetchone()[0].startswith('16'), 'PostgreSQL 16 required'
name='p16_freshness_'+uuid.uuid4().hex
admin.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
conn=None
try:
 conn=psycopg.connect(**opts,dbname=name,autocommit=True)
 conn.execute("""
 CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $$
 DECLARE u text:=current_setting('qa.owner',true); BEGIN
 IF u IS NULL OR u='' THEN RAISE EXCEPTION 'Unauthenticated'; END IF;
 RETURN u::uuid; END $$;
 CREATE TABLE public.lts_open_finance_connection (
 id uuid PRIMARY KEY,user_id uuid NOT NULL,provider text,institution_code text,institution_name text,
 connection_mode text,scopes jsonb,status text,consent_expires_at timestamptz,last_success_at timestamptz,
 last_attempt_at timestamptz,last_error_code text,last_error_summary text);
 CREATE TABLE public.lts_open_finance_staging (connection_id uuid,promotion_status text);
 CREATE TABLE public.lts_open_finance_sync_run (
 id uuid PRIMARY KEY,user_id uuid,connection_id uuid,status text,trigger_type text,started_at timestamptz,
 finished_at timestamptz,raw_count integer,normalized_count integer,exact_match_count integer,
 candidate_match_count integer,promoted_count integer,blocked_count integer,error_code text,error_summary text,metadata jsonb);
 """)
 owners=[uuid.UUID(int=1),uuid.UUID(int=2)]
 for i,u in enumerate(owners,1):
  cid=uuid.UUID(int=100+i);rid=uuid.UUID(int=200+i)
  conn.execute("INSERT INTO public.lts_open_finance_connection VALUES (%s,%s,'synthetic','900','Synthetic institution','synthetic','[]','connected',NULL,'2020-10-15T03:18:00Z','2020-10-15T03:15:00Z',NULL,NULL)",(cid,u))
  conn.execute("INSERT INTO public.lts_open_finance_sync_run (id,user_id,connection_id,status,started_at,finished_at,metadata) VALUES (%s,%s,%s,'success','2020-10-15T03:15:00Z','2020-10-15T03:18:00Z',%s::jsonb)",(rid,u,cid,'{"item":{"lastUpdatedAt":"2020-10-14T18:00:00Z","id":"never-expose-synthetic-item"},"secret":"never-expose-synthetic-secret"}'))
 conn.execute((P/'baseline.sql').read_text())
 conn.execute('REVOKE ALL ON FUNCTION public.lts_browser_open_finance_status_v1() FROM PUBLIC')
 def metadata():return conn.execute("SELECT proowner,proacl,proconfig,prosecdef,prorettype FROM pg_proc WHERE oid='public.lts_browser_open_finance_status_v1()'::regprocedure").fetchone()
 before_meta=metadata();assert before_meta[1] is not None,'Non-default ACL fixture required';before={}
 def run(u):
  conn.execute("SELECT set_config('qa.owner',%s,false)",(str(u),))
  return conn.execute('SELECT public.lts_browser_open_finance_status_v1()').fetchone()[0]
 for u in owners:before[str(u)]=run(u)
 conn.execute((P/'candidate.sql').read_text())
 assert metadata()==before_meta,'Function owner/ACL/config/type altered'
 for u in owners:
  result=run(u);assert len(result['connections'])==1 and len(result['last_syncs'])==1
  for c in result['connections']:assert c.pop('provider_item_updated_at')=='2020-10-14T18:00:00Z'
  assert result==before[str(u)],'Prior contract changed'
  assert 'never-expose' not in str(result)
 print('PASS complete RPC compiles; two owners isolated; additive output; owner/ACL/config preserved; no raw metadata')
 conn.execute("SELECT set_config('qa.owner','',false)")
 try:conn.execute('SELECT public.lts_browser_open_finance_status_v1()');raise AssertionError('Unauthenticated call accepted')
 except psycopg.errors.RaiseException:pass
 print('PASS unauthenticated rejected')
 cur=conn.cursor();cur.execute((P/'fixtures.sql').read_text());rows=[]
 while True:
  if cur.description:rows.extend(cur.fetchall())
  if not cur.nextset():break
 assert len(rows)==32,(len(rows),rows)
 assert all(r[-1] is True for r in rows),[r for r in rows if r[-1] is not True]
 for row in rows:print('PASS '+row[0])
 # Restore baseline in the disposable database and prove exact previous behavior.
 conn.execute((P/'baseline.sql').read_text());assert metadata()==before_meta
 for u in owners:assert run(u)==before[str(u)]
 print('PASS rollback restores prior contract; 32 timestamp fixtures passed')
finally:
 if conn:conn.close()
 admin.execute(sql.SQL('DROP DATABASE {}').format(sql.Identifier(name)));admin.close()
