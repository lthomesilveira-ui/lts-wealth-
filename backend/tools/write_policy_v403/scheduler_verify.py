"""Existing-job configuration and later upgrade; synthetic jobs only."""
import json,subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[3]
retime=(root/'backend/patches/v403/schedule_only.sql').read_text()
upgrade=(root/'backend/patches/v403/backup_exclusion.sql').read_text()
uid='11111111-1111-4111-8111-111111111111'
command=f"SET statement_timeout = '90s'; select public.lts_backup_snapshot_take_v380('{uid}'::uuid,current_date);"
literal="'"+command.replace("'","''")+"'"
reset=f"UPDATE cron.job SET schedule='15 6 * * *',command={literal},active=true,username=current_user,jobname='lts_daily_backup_snapshot'WHERE jobid=1;"
checks=[]
def run(sql):
 return subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
def scenario(name,setup,action,predicate,expected_error=None):
 sql='BEGIN;'+reset+setup+'CREATE TEMP TABLE prior_job ON COMMIT DROP AS SELECT *FROM cron.job;'+action
 sql+="SELECT jsonb_build_object('ok',("+predicate+")AND(SELECT jsonb_agg(to_jsonb(t)-'schedule'ORDER BY jobid)FROM cron.job t)=(SELECT jsonb_agg(to_jsonb(t)-'schedule'ORDER BY jobid)FROM prior_job t)AND(SELECT jsonb_agg(to_jsonb(t)ORDER BY jobid)FROM cron.job t WHERE jobid<>1)=(SELECT jsonb_agg(to_jsonb(t)ORDER BY jobid)FROM prior_job t WHERE jobid<>1));ROLLBACK;"
 result=run(sql)
 if expected_error:
  assert result.returncode!=0 and expected_error in result.stderr,(name,result.stderr)
 else:
  assert result.returncode==0,(name,result.stderr)
  proof=json.loads(next(x for x in result.stdout.splitlines()if x.startswith('{')))
  assert proof['ok'],(name,result.stdout)
 checks.append(name)

schedule="(SELECT schedule FROM cron.job WHERE jobid=1)"
scenario('original job retimed through supported API','',retime,schedule+"='35 6 * * *'")
scenario('retimed job replay changes nothing',"UPDATE cron.job SET schedule='35 6 * * *'WHERE jobid=1;",retime,schedule+"='35 6 * * *'")
scenario('unrelated schedule is preserved',"UPDATE cron.job SET schedule='5 6 * * *'WHERE jobid=1;",retime,schedule+"='5 6 * * *'")
scenario('unexpected command is preserved',"UPDATE cron.job SET command='select 1'WHERE jobid=1;",retime,schedule+"='15 6 * * *'")
scenario('foreign owner is preserved',"UPDATE cron.job SET username='synthetic_other_owner'WHERE jobid=1;",retime,schedule+"='15 6 * * *'")
scenario('inactive job is preserved',"UPDATE cron.job SET active=false WHERE jobid=1;",retime,schedule+"='15 6 * * *'")
scenario('ambiguous target changes nothing',"INSERT INTO cron.job SELECT 999,schedule,command,active,jobname,username FROM cron.job WHERE jobid=1;",retime,schedule+"='15 6 * * *'")
# The full migration necessarily replaces the target command, so test its
# schedule separately while verifying that all other jobs stay unchanged.
sql='BEGIN;'+reset+"UPDATE cron.job SET schedule='35 6 * * *'WHERE jobid=1;CREATE TEMP TABLE prior_job ON COMMIT DROP AS SELECT *FROM cron.job;"+upgrade
sql+="SELECT jsonb_build_object('ok',(SELECT schedule='35,40,50,55 6 * * *'AND command LIKE '%lts_backup_scheduled_v403(%'AND command LIKE 'BEGIN ISOLATION LEVEL REPEATABLE READ;%'FROM cron.job WHERE jobid=1)AND(SELECT jsonb_agg(to_jsonb(t)ORDER BY jobid)FROM cron.job t WHERE jobid<>1)=(SELECT jsonb_agg(to_jsonb(t)ORDER BY jobid)FROM prior_job t WHERE jobid<>1));ROLLBACK;"
r=run(sql);assert r.returncode==0,r.stderr
assert json.loads(next(x for x in r.stdout.splitlines()if x.startswith('{')))['ok']
checks.append('full V403 accepts unchanged V401 command at03:35')
scenario('full V403 rejects unrelated drift',"UPDATE cron.job SET schedule='5 6 * * *'WHERE jobid=1;",upgrade,'true','Unexpected backup job; no schedule changed')
print(json.dumps({'scheduler_checks':len(checks),'results':checks,'synthetic_only':True}))
