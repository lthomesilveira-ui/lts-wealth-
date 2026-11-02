-- Reversible configuration of the existing V401 job; no schema changes.
-- Keep its bounded command, owner and active state. A replay changes nothing.
WITH guarded AS MATERIALIZED(
 SELECT j.jobid,j.schedule FROM cron.job j
 WHERE j.jobname='lts_daily_backup_snapshot' AND j.username=current_user
 AND j.active AND j.schedule='15 6 * * *'
 AND j.command ~ $rx$^SET statement_timeout = '90s'; select public\.lts_backup_snapshot_take_v380\('[0-9a-f-]{36}'::uuid,current_date\);$rx$
 AND (SELECT count(*)FROM cron.job x WHERE x.jobname=j.jobname AND x.username=current_user)=1
)
SELECT jobid,schedule AS previous_schedule,
 cron.alter_job(jobid,schedule:='35 6 * * *')AS retimed
FROM guarded;
