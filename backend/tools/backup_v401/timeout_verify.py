"""Execute the stored scheduler command through libpq with a scaled deadline."""
import json
import subprocess

def psql(query, check=True):
    return subprocess.run(['psql','-X','-A','-t','-v','ON_ERROR_STOP=1','-c',query],capture_output=True,text=True,check=check)

command=psql("SELECT command FROM cron.job WHERE jobname='lts_daily_backup_snapshot'").stdout.strip()
assert command.startswith("SET statement_timeout = '90s'; ")
psql("CREATE OR REPLACE FUNCTION public.lts_backup_snapshot_take_v380(p_user_id uuid,p_snapshot_date date DEFAULT NULL)RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN PERFORM pg_sleep(1);RETURN '{}'::jsonb;END$$")
result=psql(command.replace("'90s'","'150ms'",1),check=False)
assert result.returncode!=0 and 'canceling statement due to statement timeout' in result.stderr,result
print(json.dumps({'stored_scheduler_command_cancels':True,'scaled_timeout_ms':150,'sleep_ms':1000,'database_or_role_timeout_changed':False}))
