CREATE OR REPLACE FUNCTION public.lts_browser_open_finance_status_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid;
begin
  v_uid:=public.lts_browser_assert_user_v1();
  return jsonb_build_object(
    'version','open-finance-status-v1-provider-neutral',
    'architecture_ready',true,
    'provider_activated',exists(select 1 from public.lts_open_finance_connection c where c.user_id=v_uid and c.status not in ('disabled','revoked')),
    'connections',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',c.id,'provider',c.provider,'institution_code',c.institution_code,'institution_name',c.institution_name,
        'connection_mode',c.connection_mode,'scopes',c.scopes,'status',c.status,'consent_expires_at',c.consent_expires_at,
        'last_success_at',c.last_success_at,'last_attempt_at',c.last_attempt_at,'last_error_code',c.last_error_code,
        'last_error_summary',c.last_error_summary,
        'pending_records',(select count(*) from public.lts_open_finance_staging s where s.connection_id=c.id and s.promotion_status='pending'),
        'blocked_records',(select count(*) from public.lts_open_finance_staging s where s.connection_id=c.id and s.promotion_status='blocked')
      ) order by c.institution_name,c.provider)
      from public.lts_open_finance_connection c where c.user_id=v_uid
    ),'[]'::jsonb),
    'last_syncs',coalesce((
      select jsonb_agg(x.j order by x.started_at desc)
      from (
        select r.started_at,jsonb_build_object('id',r.id,'connection_id',r.connection_id,'status',r.status,'trigger_type',r.trigger_type,
          'started_at',r.started_at,'finished_at',r.finished_at,'raw_count',r.raw_count,'normalized_count',r.normalized_count,
          'exact_match_count',r.exact_match_count,'candidate_match_count',r.candidate_match_count,'promoted_count',r.promoted_count,
          'blocked_count',r.blocked_count,'error_code',r.error_code,'error_summary',r.error_summary) j
        from public.lts_open_finance_sync_run r where r.user_id=v_uid order by r.started_at desc limit 10
      ) x
    ),'[]'::jsonb),
    'guardrail','Provider data is staged and reconciled before any canonical financial effect. LTS tables never store bank credentials or provider API secrets/tokens.'
  );
end
$function$
