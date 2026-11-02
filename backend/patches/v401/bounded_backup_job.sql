-- Bound this existing job connection only; keep its owner, schedule and state.
DO $bound$
DECLARE job record;job_count integer:=0;prefix text:='SET statement_timeout = ''90s''; ';
BEGIN
 FOR job IN SELECT jobid,command FROM cron.job WHERE jobname='lts_daily_backup_snapshot' LOOP
  job_count:=job_count+1;
  IF left(job.command,length(prefix))=prefix THEN CONTINUE;END IF;
  IF job.command !~* $regex$^select[[:space:]]+public\.lts_backup_snapshot_take_v380\('[0-9a-f-]{36}'(::uuid)?,[[:space:]]*current_date\);[[:space:]]*$regex$ THEN
   RAISE EXCEPTION 'Unexpected backup command; no job configuration changed';
  END IF;
  PERFORM cron.alter_job(job.jobid,command:=prefix||job.command);
 END LOOP;
 IF job_count<>1 THEN RAISE EXCEPTION 'Expected exactly one existing backup job';END IF;
END $bound$;
