-- Keep one scheduled read per bank per hour. Only the Itaú read moves to
-- follow the publication minute of its most recent checking-account position.
DO $install$
DECLARE
  combined_name constant text := 'lts_open_finance_auto_sync_v1';
  itau_name constant text := 'lts_open_finance_itau_hourly';
  planner_name constant text := 'lts_open_finance_itau_daily_timing';
  itau_command constant text := $cmd$select public.lts_open_finance_enqueue_bank_v1('341','sync')$cmd$;
  others_command constant text := $cmd$select public.lts_open_finance_enqueue_bank_v1('237','sync'),public.lts_open_finance_enqueue_bank_v1('336','sync')$cmd$;
  original_command constant text := itau_command || ',' || substr(others_command, 8);
  combined cron.job%rowtype;
  itau cron.job%rowtype;
  planner cron.job%rowtype;
  -- This job only adjusts a cron schedule. It never enqueues a bank read.
  planner_command constant text := $plan$
DO $timing$
DECLARE
  source_at timestamptz;
  new_schedule text := '15 * * * *';
  target cron.job%rowtype;
BEGIN
  SELECT * INTO STRICT target FROM cron.job
    WHERE jobname = 'lts_open_finance_itau_hourly' AND username = current_user
      AND database = current_database()
      AND command = $cmd$select public.lts_open_finance_enqueue_bank_v1('341','sync')$cmd$;
  IF NOT target.active THEN RETURN; END IF;

  SELECT CASE WHEN count(*) = 1 THEN max(s.provider_updated_at) END INTO source_at
    FROM public.lts_open_finance_staging s
    WHERE s.user_id = public.lts_open_finance_pilot_owner_v1()
      AND s.provider = 'pluggy' AND s.institution_code = '341'
      AND s.resource_type = 'balance' AND s.currency = 'BRL'
      AND s.normalized_payload->>'account_type' = 'CHECKING_ACCOUNT'
      AND s.provider_deleted_at IS NULL;

  IF source_at BETWEEN now() - interval '36 hours' AND now() THEN
    -- Allow a small daily drift. Reserve minute zero for the schedule change
    -- so updating the phase cannot dispatch two jobs in the midnight hour.
    new_schedule := greatest(1, extract(minute FROM (source_at AT TIME ZONE 'UTC') + interval '5 minutes')::integer) || ' * * * *';
  END IF;
  IF target.schedule <> new_schedule THEN
    PERFORM cron.alter_job(target.jobid, schedule => new_schedule);
  END IF;
END
$timing$;
$plan$;
BEGIN
  SELECT * INTO STRICT combined FROM cron.job
    WHERE jobname = combined_name AND username = current_user AND database = current_database();
  SELECT * INTO itau FROM cron.job WHERE jobname = itau_name AND username = current_user;
  SELECT * INTO planner FROM cron.job WHERE jobname = planner_name AND username = current_user;

  IF combined.schedule <> '15 * * * *' OR NOT combined.active THEN
    RAISE EXCEPTION 'Unexpected hourly bank schedule';
  END IF;
  IF combined.command = original_command AND itau.jobid IS NULL AND planner.jobid IS NULL THEN
    PERFORM cron.alter_job(combined.jobid, command => others_command);
    PERFORM cron.schedule(itau_name, '15 * * * *', itau_command);
    -- Midnight in São Paulo (the installation uses UTC for cron).
    PERFORM cron.schedule(planner_name, '0 3 * * *', planner_command);
  ELSIF combined.command IS DISTINCT FROM others_command OR itau.command IS DISTINCT FROM itau_command
     OR itau.database IS DISTINCT FROM current_database() OR planner.database IS DISTINCT FROM current_database()
     OR planner.command IS DISTINCT FROM planner_command OR planner.schedule IS DISTINCT FROM '0 3 * * *' THEN
    RAISE EXCEPTION 'Unexpected bank scheduler configuration';
  END IF;
  EXECUTE planner_command;
END
$install$;
