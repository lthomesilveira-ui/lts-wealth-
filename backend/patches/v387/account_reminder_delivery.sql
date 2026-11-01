CREATE TABLE IF NOT EXISTS lts_account_reminder_private_v387.delivery(
 token text PRIMARY KEY CHECK(token~'^[0-9a-f]{32}$'),
 user_id uuid NOT NULL REFERENCES auth.users(id),
 message_id text NOT NULL UNIQUE CHECK(length(message_id)BETWEEN 1 AND 200),
 sent_at timestamptz NOT NULL DEFAULT clock_timestamp(),report jsonb NOT NULL
);
ALTER TABLE lts_account_reminder_private_v387.delivery ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON lts_account_reminder_private_v387.delivery FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT,INSERT ON lts_account_reminder_private_v387.delivery TO service_role;
DO $policy$BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='lts_account_reminder_private_v387'AND tablename='delivery'AND policyname='service_delivery')THEN
  CREATE POLICY service_delivery ON lts_account_reminder_private_v387.delivery TO service_role USING(true)WITH CHECK(true);
 END IF;
END $policy$;
CREATE INDEX IF NOT EXISTS delivery_user_sent_v387 ON lts_account_reminder_private_v387.delivery(user_id,sent_at DESC);

CREATE OR REPLACE FUNCTION lts_account_reminder_private_v387.fingerprint(p_report jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT md5(jsonb_build_object('version',p_report->'version','as_of',p_report->>'as_of','recipient',lower(p_report->>'recipient'),
 'complete',p_report->'complete','days',p_report->'days','accounts',p_report->'accounts','actions',p_report->'actions',
 'scheduled_transfers',p_report->'scheduled_transfers','unfunded',p_report->'unfunded','cofrinho_planning_budget',p_report#>'{cofrinho,planning_budget_brl}')::text);
$fn$;
CREATE OR REPLACE FUNCTION lts_account_reminder_private_v387.decision(p_current jsonb,p_previous jsonb,p_last_sent timestamptz,p_now timestamptz)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE c jsonb;p jsonb;reason text;current_count integer;
BEGIN
 current_count:=jsonb_array_length(coalesce(p_current->'actions','[]'))+jsonb_array_length(coalesce(p_current->'scheduled_transfers','[]'))+jsonb_array_length(coalesce(p_current->'unfunded','[]'));
 IF current_count=0 THEN RETURN jsonb_build_object('send',false,'reason','no_account_action');END IF;
 IF p_previous IS NULL OR p_previous->>'status'='clear' THEN reason:='new_account_plan';
 ELSE
  FOR c IN SELECT x FROM jsonb_array_elements(coalesce(p_current->'accounts','[]'))x WHERE x->>'first_negative_date'IS NOT NULL LOOP
   SELECT x INTO p FROM jsonb_array_elements(coalesce(p_previous->'accounts','[]'))x WHERE x->>'bank'=c->>'bank';
   IF p IS NULL OR p->>'first_negative_date'IS NULL THEN reason:='new_account_risk';EXIT;
   ELSIF(c->>'first_negative_date')::date<(p->>'first_negative_date')::date THEN reason:='earlier_account_risk';EXIT;
   ELSIF(c->>'worst_balance')::numeric<=(p->>'worst_balance')::numeric-100 THEN reason:='account_deficit_increased_at_least_100';EXIT;
   ELSIF(c->>'first_negative_date')::date=(p_current->>'as_of')::date AND(p_previous->>'as_of')::date<(p_current->>'as_of')::date THEN reason:='account_risk_today';EXIT;END IF;
  END LOOP;
  IF reason IS NULL THEN
   FOR c IN SELECT x FROM jsonb_array_elements(coalesce(p_current->'actions','[]'))x LOOP
    SELECT x INTO p FROM jsonb_array_elements(coalesce(p_previous->'actions','[]'))x
    WHERE x->>'kind'=c->>'kind'AND x->>'from_bank'=c->>'from_bank'AND x->>'to_bank'=c->>'to_bank'LIMIT 1;
    IF p IS NULL THEN reason:='new_action_or_funding_source';EXIT;
    ELSIF(c->>'execute_by')::date<(p->>'execute_by')::date THEN reason:='earlier_action_deadline';EXIT;
    ELSIF(c->>'amount_brl')::numeric>=(p->>'amount_brl')::numeric+100 THEN reason:='action_increased_at_least_100';EXIT;
    ELSIF(c->>'execute_by')::date<=(p_current->>'as_of')::date+6 AND(p->>'execute_by')::date>(p_previous->>'as_of')::date+6 THEN reason:='action_due_within_seven_days';EXIT;END IF;
   END LOOP;
  END IF;
  IF reason IS NULL THEN
   FOR c IN SELECT x FROM jsonb_array_elements(coalesce(p_current->'scheduled_transfers','[]'))x LOOP
    SELECT x INTO p FROM jsonb_array_elements(coalesce(p_previous->'scheduled_transfers','[]'))x WHERE x->>'source_id'=c->>'source_id';
    IF p IS NULL THEN reason:='new_confirmed_bank_schedule';EXIT;
    ELSIF(c->>'date')::date<(p->>'date')::date OR(c->>'amount_brl')::numeric>=(p->>'amount_brl')::numeric+100 THEN reason:='scheduled_transfer_changed';EXIT;
    ELSIF(c->>'date')::date<=(p_current->>'as_of')::date+6 AND(p->>'date')::date>(p_previous->>'as_of')::date+6 THEN reason:='scheduled_transfer_due_within_seven_days';EXIT;END IF;
   END LOOP;
  END IF;
  IF reason IS NULL AND jsonb_array_length(coalesce(p_current->'unfunded','[]'))>0
  AND jsonb_array_length(coalesce(p_previous->'unfunded','[]'))=0 THEN reason:='funding_gap';END IF;
  IF reason IS NULL AND(
   p_current->'actions'IS DISTINCT FROM p_previous->'actions'
   OR p_current->'scheduled_transfers'IS DISTINCT FROM p_previous->'scheduled_transfers'
   OR p_current->'unfunded'IS DISTINCT FROM p_previous->'unfunded'
   OR p_current#>'{cofrinho,planning_budget_brl}'IS DISTINCT FROM p_previous#>'{cofrinho,planning_budget_brl}')THEN reason:='updated_account_plan';END IF;
  IF reason IS NULL AND(p_last_sent IS NULL OR(p_last_sent AT TIME ZONE'America/Sao_Paulo')::date<(p_current->>'as_of')::date)
  AND(EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_current->'actions','[]'))x WHERE(x->>'execute_by')::date<=(p_current->>'as_of')::date+6)
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_current->'scheduled_transfers','[]'))x WHERE(x->>'date')::date<=(p_current->>'as_of')::date+6))THEN reason:='daily_action_reminder';END IF;
  IF reason IS NULL AND(p_last_sent IS NULL OR p_now-p_last_sent>=interval'7 days')THEN reason:='weekly_plan_review';END IF;
 END IF;
 RETURN jsonb_build_object('send',reason IS NOT NULL,'reason',coalesce(reason,'no_material_change'));
END $fn$;

CREATE OR REPLACE FUNCTION lts_account_reminder_private_v387.escape_html(p_text text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT replace(replace(replace(replace(replace(coalesce(p_text,''),'&','&amp;'),'<','&lt;'),'>','&gt;'),'"','&quot;'),'''','&#39;');
$fn$;
CREATE OR REPLACE FUNCTION lts_account_reminder_private_v387.money(p_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT CASE WHEN p_value IS NULL THEN'—'ELSE CASE WHEN p_value::numeric<0 THEN'−'ELSE''END||'R$ '||translate(to_char(abs(p_value::numeric),'FM999,999,999,990.00'),',.','.,')END;
$fn$;
CREATE OR REPLACE FUNCTION lts_account_reminder_private_v387.render_email(p_report jsonb,p_token text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $fn$
DECLARE html text;rows text:='';scheduled text:='';risks text:='';gaps text:='';x jsonb;label text;note text;deadline date;subject text;
BEGIN
 SELECT min(d)INTO deadline FROM(
  SELECT(a.value->>'execute_by')::date d FROM jsonb_array_elements(coalesce(p_report->'actions','[]')) AS a(value)
  UNION ALL SELECT(a.value->>'date')::date FROM jsonb_array_elements(coalesce(p_report->'scheduled_transfers','[]')) AS a(value)
  UNION ALL SELECT(a.value->>'execute_by')::date FROM jsonb_array_elements(coalesce(p_report->'unfunded','[]')) AS a(value))q;
 subject:='LTS Wealth | Transferências e resgates'||CASE WHEN deadline IS NOT NULL THEN' até '||to_char(deadline,'DD/MM')ELSE' a conferir'END;
 FOR x IN SELECT a FROM jsonb_array_elements(coalesce(p_report->'actions','[]'))a LOOP
  IF x->>'kind'='suggested_redemption' THEN label:='Resgatar do Cofrinho para a conta Itaú';note:='Confirme o valor liberado e o prazo de resgate no Itaú.';
  ELSE label:='Transferir de '||(x->>'from_bank')||' para '||(x->>'to_bank');note:=CASE WHEN coalesce((x->>'rescue_before_transfer_brl')::numeric,0)>0 THEN'Após o resgate de '||lts_account_reminder_private_v387.money(x->>'rescue_before_transfer_brl')||' cair no Itaú.'ELSE'Confirme o saldo disponível antes de transferir.'END;END IF;
  rows:=rows||'<tr><td style="padding:12px 6px;border-bottom:1px solid #dae3e8;vertical-align:top;white-space:nowrap">'||to_char((x->>'execute_by')::date,'DD/MM')||'</td><td style="padding:12px 6px;border-bottom:1px solid #dae3e8"><b>'||lts_account_reminder_private_v387.escape_html(label)||'</b><br><span style="font-size:12px;color:#617381">'||lts_account_reminder_private_v387.escape_html(note)||'</span></td><td style="padding:12px 6px;border-bottom:1px solid #dae3e8;text-align:right;vertical-align:top;white-space:nowrap">'||lts_account_reminder_private_v387.money(x->>'amount_brl')||'</td></tr>';
 END LOOP;
 FOR x IN SELECT a FROM jsonb_array_elements(coalesce(p_report->'scheduled_transfers','[]'))a ORDER BY a->>'date',a->>'to_bank' LOOP
  scheduled:=scheduled||'<tr><td style="padding:12px 6px;border-bottom:1px solid #dae3e8;vertical-align:top;white-space:nowrap">'||to_char((x->>'date')::date,'DD/MM')||'</td><td style="padding:12px 6px;border-bottom:1px solid #dae3e8"><b>'||lts_account_reminder_private_v387.escape_html(x->>'from_bank')||' → '||lts_account_reminder_private_v387.escape_html(x->>'to_bank')||'</b><br><span style="font-size:12px;color:#617381">Já agendado no banco. Conferir a execução; não repetir a transferência.</span></td><td style="padding:12px 6px;border-bottom:1px solid #dae3e8;text-align:right;vertical-align:top;white-space:nowrap">'||lts_account_reminder_private_v387.money(x->>'amount_brl')||'</td></tr>';
 END LOOP;
 FOR x IN SELECT a FROM jsonb_array_elements(coalesce(p_report->'accounts','[]'))a WHERE a->>'first_negative_date'IS NOT NULL LOOP
  risks:=risks||'<li style="margin:10px 0"><b>'||lts_account_reminder_private_v387.escape_html(x->>'bank')||':</b> primeiro saldo negativo em '||to_char((x->>'first_negative_date')::date,'DD/MM')||' ('||lts_account_reminder_private_v387.money(x->>'first_negative_balance')||'). Pior saldo: '||lts_account_reminder_private_v387.money(x->>'worst_balance')||' em '||to_char((x->>'worst_date')::date,'DD/MM')||'.</li>';
 END LOOP;
 FOR x IN SELECT a FROM jsonb_array_elements(coalesce(p_report->'unfunded','[]'))a LOOP
  gaps:=gaps||'<p style="padding:12px;background:#fff4df;color:#785419;border-radius:8px">Ainda falta definir uma origem segura para '||lts_account_reminder_private_v387.money(x->>'amount_brl')||' em '||lts_account_reminder_private_v387.escape_html(x->>'bank')||', até '||to_char((x->>'execute_by')::date,'DD/MM')||'.</p>';
 END LOOP;
 html:='<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;background:#f3f6f9;font-family:Arial,sans-serif;color:#203b4d"><div style="max-width:680px;box-sizing:border-box;margin:20px auto;background:#fff;border-radius:12px;padding:28px 20px"><div style="font-size:12px;letter-spacing:1px;font-weight:bold;color:#12374a">LTS WEALTH · TRANSFERÊNCIAS E RESGATES</div><h1 style="font-size:25px;line-height:1.25;color:#12374a">Recursos a providenciar'||CASE WHEN deadline IS NOT NULL THEN' até '||to_char(deadline,'DD/MM')ELSE''END||'</h1><p style="line-height:1.5">Confira as ações por conta para os próximos '||coalesce(p_report->>'days','30')||' dias. São sugestões baseadas na projeção, para você executar e conferir no banco.</p>'||
  CASE WHEN p_report->>'limited_to_seven_days'='true' THEN'<p style="padding:12px;background:#fff4df;color:#785419">Projeção limitada aos próximos 7 dias; o restante ainda precisa de dados completos.</p>'ELSE''END||
  CASE WHEN p_report->>'complete'<>'true' THEN'<p style="padding:12px;background:#fff4df;color:#785419">Há dados incompletos. Confira os saldos e os agendamentos no banco antes de tomar uma decisão.</p>'ELSE''END||gaps||
  CASE WHEN rows<>'' THEN'<h2 style="font-size:18px;color:#12374a">Transferências e resgates sugeridos</h2><table style="border-collapse:collapse;width:100%;font-size:13px"><thead><tr style="background:#edf3f5"><th style="padding:10px 6px;text-align:left">Até</th><th style="padding:10px 6px;text-align:left">Ação</th><th style="padding:10px 6px;text-align:right">Valor</th></tr></thead><tbody>'||rows||'</tbody></table>'ELSE''END||
  CASE WHEN scheduled<>'' THEN'<h2 style="font-size:18px;color:#12374a;margin-top:24px">Pix já agendados</h2><table style="border-collapse:collapse;width:100%;font-size:13px"><thead><tr style="background:#edf3f5"><th style="padding:10px 6px;text-align:left">Data</th><th style="padding:10px 6px;text-align:left">Conferir</th><th style="padding:10px 6px;text-align:right">Valor</th></tr></thead><tbody>'||scheduled||'</tbody></table>'ELSE''END||
  CASE WHEN risks<>'' THEN'<h2 style="font-size:18px;color:#12374a;margin-top:24px">Risco antes dessas ações</h2><ul style="padding-left:20px;font-size:14px;line-height:1.5">'||risks||'</ul>'ELSE''END||
  '<p style="font-size:13px;line-height:1.5">As sugestões não movimentam dinheiro. Confirme os saldos, os créditos previstos e a disponibilidade de resgate antes de agir. A projeção de uma conta positiva não garante que as outras estejam cobertas.</p><a href="https://lthomesilveira-ui.github.io/lts-wealth-/mobile/" style="display:inline-block;background:#12374a;color:#fff;text-decoration:none;padding:12px 18px;border-radius:7px">Abrir LTS Wealth</a><p style="font-size:11px;color:#617381;line-height:1.5;margin-top:22px">Projeção de '||to_char((p_report->>'as_of')::date,'DD/MM/YYYY')||' a '||coalesce(to_char((p_report->>'to')::date,'DD/MM/YYYY'),'data a confirmar')||'. Consulta: '||coalesce(to_char((p_report->>'consulted_at')::timestamptz AT TIME ZONE'America/Sao_Paulo','DD/MM/YYYY HH24:MI'),'data a confirmar')||'. Cofrinho: referência '||coalesce(to_char((p_report#>>'{cofrinho,documented_as_of}')::date,'DD/MM/YYYY'),'a confirmar')||'.<br>Referência do aviso: TR-'||lts_account_reminder_private_v387.escape_html(p_token)||'</p></div></body></html>';
 RETURN jsonb_build_object('subject',subject,'html',html);
END $fn$;

CREATE OR REPLACE FUNCTION public.lts_account_reminder_snapshot_v387()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET "TimeZone"='America/Sao_Paulo' SET statement_timeout='60s' AS $fn$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();mail text;cached jsonb;j jsonb;schedules jsonb;report jsonb;short_report jsonb;previous jsonb;last_sent timestamptz;
 epoch_before bigint;freshness text;consulted timestamptz:=clock_timestamp();token text;decision jsonb;doc_date date;
BEGIN
 mail:=lts_cash_alert_private_v377.owner_email();IF mail IS NULL THEN RAISE EXCEPTION'Configured reminder recipient unavailable';END IF;
 PERFORM public.lts_warm_flow_cache_v245();
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 freshness:=public.lts_flow_bank_freshness_key_v246(u);
 SELECT payload INTO cached FROM public.lts_v229_read_cache WHERE user_id=u AND kind='flow_v242'AND as_of=current_date
 AND from_date<=current_date AND to_date>=current_date+29 AND source_fingerprint='v246.1:'||epoch_before||':'||freshness
 AND refreshed_at>clock_timestamp()-interval'30 minutes'ORDER BY refreshed_at DESC LIMIT 1;
 IF cached IS NULL THEN RAISE EXCEPTION'Fresh owner forecast unavailable';END IF;
 j:=public.lts_flow_classifications_v290(u,public.lts_flow_card_completeness_v269(public.lts_flow_slice_v242(cached,current_date,current_date+29),public.lts_prepared_card_cycles_v307(u)));
 SELECT coalesce(jsonb_agg(jsonb_build_object('source_id',s.source_id,'scheduled_date',s.scheduled_date,'from_bank',s.from_bank,'to_bank',s.to_bank,'amount_brl',abs(s.signed_amount)::text)ORDER BY s.scheduled_date,s.source_id),'[]')INTO schedules
 FROM public.lts_confirmed_bank_transfer_schedules_v293(u)s WHERE s.scheduled_date BETWEEN current_date AND current_date+29;
 report:=lts_account_reminder_private_v387.evaluate(j,schedules,current_date,30);
 IF report->>'complete'<>'true' THEN
  short_report:=lts_account_reminder_private_v387.evaluate(j,schedules,current_date,7);
  IF short_report->>'complete'='true'THEN report:=short_report||jsonb_build_object('limited_to_seven_days',true);END IF;
 END IF;
 SELECT as_of_date INTO doc_date FROM public.asset_positions WHERE user_id=u AND asset_name='Cofrinho Itaú'AND asset_type='cash_investment'AND as_of_date<=current_date ORDER BY as_of_date DESC,created_at DESC,id DESC LIMIT 1;
 report:=report||jsonb_build_object('recipient',mail,'consulted_at',consulted,'bank_sources',public.lts_open_finance_current_bank_position_v1(u),'source_epoch',epoch_before,'source_freshness',freshness,'reader','same_canonical_v242','scheduled_transfer_basis','bank_pending_and_owner_confirmed_destination');
 report:=jsonb_set(report,'{cofrinho}',coalesce(report->'cofrinho','{}')||jsonb_build_object('documented_as_of',doc_date));
 IF epoch_before<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)OR freshness<>public.lts_flow_bank_freshness_key_v246(u)
 THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Forecast sources changed during reminder read';END IF;
 SELECT d.report,d.sent_at INTO previous,last_sent FROM lts_account_reminder_private_v387.delivery d WHERE user_id=u ORDER BY sent_at DESC LIMIT 1;
 token:=lts_account_reminder_private_v387.fingerprint(report);decision:=lts_account_reminder_private_v387.decision(report,previous,last_sent,consulted);
 RETURN jsonb_build_object('report',report,'delivery_token',token,'decision',decision,'previous_sent_at',last_sent,'email',lts_account_reminder_private_v387.render_email(report,token));
END $fn$;

CREATE OR REPLACE FUNCTION public.lts_account_reminder_record_sent_v387(p_snapshot jsonb,p_message_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $fn$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();mail text:=lts_cash_alert_private_v377.owner_email();v_token text:=p_snapshot->>'delivery_token';previous_id text;
BEGIN
 IF mail IS NULL OR v_token IS DISTINCT FROM lts_account_reminder_private_v387.fingerprint(p_snapshot->'report')
 OR lower(p_snapshot#>>'{report,recipient}')IS DISTINCT FROM lower(mail)OR p_snapshot#>>'{decision,send}'IS DISTINCT FROM'true'
 OR p_snapshot->'email'IS DISTINCT FROM lts_account_reminder_private_v387.render_email(p_snapshot->'report',v_token)
 OR p_message_id IS NULL OR length(p_message_id)NOT BETWEEN 1 AND 200 OR p_message_id~'[[:cntrl:]]'
 THEN RAISE EXCEPTION'Invalid confirmed account reminder delivery';END IF;
 SELECT d.message_id INTO previous_id FROM lts_account_reminder_private_v387.delivery d WHERE d.token=v_token;
 IF FOUND THEN IF previous_id IS DISTINCT FROM p_message_id THEN RAISE EXCEPTION'Reminder token already recorded for a different message';END IF;RETURN jsonb_build_object('recorded',true,'already_recorded',true);END IF;
 INSERT INTO lts_account_reminder_private_v387.delivery(token,user_id,message_id,report)VALUES(v_token,u,p_message_id,p_snapshot->'report');
 RETURN jsonb_build_object('recorded',true,'already_recorded',false);
END $fn$;
REVOKE ALL ON FUNCTION lts_account_reminder_private_v387.fingerprint(jsonb),lts_account_reminder_private_v387.decision(jsonb,jsonb,timestamptz,timestamptz),
 lts_account_reminder_private_v387.escape_html(text),lts_account_reminder_private_v387.money(text),lts_account_reminder_private_v387.render_email(jsonb,text),
 public.lts_account_reminder_snapshot_v387(),public.lts_account_reminder_record_sent_v387(jsonb,text)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_account_reminder_private_v387.fingerprint(jsonb),lts_account_reminder_private_v387.decision(jsonb,jsonb,timestamptz,timestamptz),
 lts_account_reminder_private_v387.escape_html(text),lts_account_reminder_private_v387.money(text),lts_account_reminder_private_v387.render_email(jsonb,text),
 public.lts_account_reminder_snapshot_v387(),public.lts_account_reminder_record_sent_v387(jsonb,text)TO service_role;
