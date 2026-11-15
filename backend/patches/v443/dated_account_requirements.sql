-- Date-specific resource requirements. No financial writer, transfer, schedule or notification is executed.
DO $guard$
DECLARE target oid:='lts_account_reminder_private_v387.evaluate(jsonb,jsonb,date,integer)'::regprocedure;definition text;attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE oid=target;
 IF position('V443: cover this day' IN definition)>0 THEN RETURN;END IF;
 IF md5(definition)<>'90609c6a44cc8ead7b0b5284c9506709' THEN RAISE EXCEPTION 'Reviewed predecessor changed: lts_account_reminder_private_v387.evaluate(jsonb,jsonb,date,integer)';END IF;
 EXECUTE $candidate$
CREATE OR REPLACE FUNCTION lts_account_reminder_private_v387.evaluate(p_payload jsonb, p_schedules jsonb, p_as_of date, p_days integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE banks text[]:=ARRAY['Itaú','Bradesco','C6']; matrix numeric[][];original numeric[][];
 i integer;b integer;k integer;s integer;deadline_i integer;copies integer;bad integer;day_json jsonb;row_json jsonb;
 dates date[];current_date_row date;value numeric;minimum numeric;first_i integer;needed numeric;available numeric;take numeric;
 d0 numeric;d0_min numeric;d0_known boolean:=true;d0_initial numeric;d0_used numeric:=0;cofrinho_cap numeric;cofrinho_ref jsonb:=p_payload->'account_reminder_cofrinho_v387';
 accounts jsonb:='[]';actions jsonb:='[]';grouped_actions jsonb;unfunded jsonb:='[]';schedules jsonb:='[]';
 schedule jsonb;sid text;from_b text;to_b text;sdate date;samount numeric;represented integer;representation_keys integer;
 scheduled_uncertain boolean:=false;unfunded_reserve numeric[]:=ARRAY[0,0,0];post_min numeric;plan_complete boolean;after_days jsonb;
BEGIN
 IF p_as_of IS NULL OR p_days IS NULL OR p_days NOT BETWEEN 1 AND 30
 OR jsonb_typeof(p_schedules)IS DISTINCT FROM'array'
 OR jsonb_typeof(p_payload#>'{flow,current_future,days}')IS DISTINCT FROM'array'
 OR coalesce(p_payload->>'complete','true')='false'
 OR coalesce(p_payload#>>'{coverage,complete}','true')='false'
 OR coalesce(p_payload->>'currency','BRL')<>'BRL'
 THEN RETURN jsonb_build_object('version',387,'as_of',p_as_of,'days',p_days,'complete',false,'status','unknown','actions','[]'::jsonb,'scheduled_transfers','[]'::jsonb,'unfunded','[]'::jsonb,'reason','forecast_unavailable');END IF;
 SELECT count(*) INTO bad FROM jsonb_array_elements(p_payload#>'{flow,current_future,days}')x
 WHERE NOT coalesce(pg_input_is_valid(x->>'date','date'),false);
 IF bad>0 THEN RETURN jsonb_build_object('version',387,'as_of',p_as_of,'days',p_days,'complete',false,'status','unknown','actions','[]'::jsonb,'scheduled_transfers','[]'::jsonb,'unfunded','[]'::jsonb,'reason','invalid_dates');END IF;
 -- D0 may contain other investments: only this documented, available Cofrinho
 -- can fund a suggestion described as a Cofrinho redemption.
 IF jsonb_typeof(cofrinho_ref->'value_brl')='number'AND cofrinho_ref->>'available_now'='true'
 AND coalesce(pg_input_is_valid(cofrinho_ref->>'as_of','date'),false)THEN
  IF(cofrinho_ref->>'as_of')::date<=p_as_of AND(cofrinho_ref->>'value_brl')::numeric>=0
  THEN cofrinho_cap:=round((cofrinho_ref->>'value_brl')::numeric*100);END IF;
 END IF;
 IF cofrinho_cap IS NULL THEN d0_known:=false;END IF;
 matrix:=array_fill(NULL::numeric,ARRAY[p_days,3]);dates:=array_fill(NULL::date,ARRAY[p_days]);
 FOR i IN 1..p_days LOOP
  current_date_row:=p_as_of+i-1;dates[i]:=current_date_row;
  SELECT count(*),min(x::text)::jsonb INTO copies,day_json
  FROM jsonb_array_elements(p_payload#>'{flow,current_future,days}')x WHERE(x->>'date')::date=current_date_row;
  IF copies<>1 THEN RETURN jsonb_build_object('version',387,'as_of',p_as_of,'days',p_days,'complete',false,'status','unknown','actions','[]'::jsonb,'scheduled_transfers','[]'::jsonb,'unfunded','[]'::jsonb,'reason','missing_or_duplicate_days');END IF;
  FOR b IN 1..3 LOOP
   IF jsonb_typeof(day_json#>ARRAY[banks[b],'balance'])IS DISTINCT FROM'number'
   THEN RETURN jsonb_build_object('version',387,'as_of',p_as_of,'days',p_days,'complete',false,'status','unknown','actions','[]'::jsonb,'scheduled_transfers','[]'::jsonb,'unfunded','[]'::jsonb,'reason','unknown_account_balance');END IF;
   matrix[i][b]:=round((day_json#>>ARRAY[banks[b],'balance'])::numeric*100);
  END LOOP;
  IF jsonb_typeof(day_json#>'{fix86_columns,liq_d0_1_recurso}')IS DISTINCT FROM'number' THEN d0_known:=false;
  ELSE
   value:=round((day_json#>>'{fix86_columns,liq_d0_1_recurso}')::numeric*100);
   IF value<0 THEN d0_known:=false;END IF;
   IF i=1 AND value>=0 THEN d0_initial:=value;END IF;
   d0_min:=CASE WHEN d0_min IS NULL THEN value ELSE least(d0_min,value)END;
  END IF;
 END LOOP;
 original:=matrix;d0_min:=least(d0_min,cofrinho_cap);d0:=CASE WHEN d0_known THEN d0_min ELSE 0 END;
 -- A lower future Cofrinho balance reserves already planned asset movements.
 -- Future increases, estimated yield, shares and FGTS cannot fund this plan.
 FOR b IN 1..3 LOOP
  minimum:=NULL;first_i:=NULL;
  FOR i IN 1..p_days LOOP
   IF minimum IS NULL OR original[i][b]<minimum THEN minimum:=original[i][b];END IF;
   IF first_i IS NULL AND original[i][b]<0 THEN first_i:=i;END IF;
  END LOOP;
  accounts:=accounts||jsonb_build_array(jsonb_build_object('bank',banks[b],'first_negative_date',CASE WHEN first_i IS NOT NULL THEN dates[first_i]END,
   'first_negative_balance',CASE WHEN first_i IS NOT NULL THEN(original[first_i][b]/100)::text END,
   'worst_balance',(minimum/100)::text,'worst_date',(SELECT dates[q]FROM generate_series(1,p_days)q WHERE original[q][b]=minimum ORDER BY q LIMIT 1)));
 END LOOP;
 -- Existing bank schedules are reminders to check execution, never instructions
 -- to repeat a Pix. Pair only the same canonical source identity, not value/date.
 IF jsonb_typeof(p_schedules)='array' THEN
  FOR schedule IN SELECT x FROM jsonb_array_elements(p_schedules)x LOOP
   sid:=schedule->>'source_id';from_b:=schedule->>'from_bank';to_b:=schedule->>'to_bank';
   IF NOT coalesce(pg_input_is_valid(sid,'uuid'),false) OR from_b IS NULL OR to_b IS NULL OR from_b=to_b OR NOT(from_b=ANY(banks))OR NOT(to_b=ANY(banks))
   OR NOT coalesce(pg_input_is_valid(schedule->>'scheduled_date','date'),false)
   OR NOT coalesce(pg_input_is_valid(schedule->>'amount_brl','numeric'),false)
   THEN scheduled_uncertain:=true;CONTINUE;END IF;
   sdate:=(schedule->>'scheduled_date')::date;samount:=(schedule->>'amount_brl')::numeric;
   IF sdate NOT BETWEEN p_as_of AND p_as_of+p_days-1 THEN CONTINUE;END IF;
   IF samount<=0 THEN scheduled_uncertain:=true;CONTINUE;END IF;
   SELECT count(*),count(DISTINCT e->>'source_ref') INTO represented,representation_keys FROM jsonb_array_elements(coalesce(p_payload#>'{flow,current_future,events}','[]'))e
   WHERE e->>'source'='internal_transfer'AND e->>'is_projection'='true'AND e->>'event_date'=sdate::text
   AND jsonb_typeof(e->'signed_amount')='number'
   AND((e->>'source_ref'='bank_schedule:'||sid||':out'AND e->>'account'=from_b AND(e->>'signed_amount')::numeric=-samount)
    OR(e->>'source_ref'='bank_schedule:'||sid||':in'AND e->>'account'=to_b AND(e->>'signed_amount')::numeric=samount));
   IF represented<>2 OR representation_keys<>2 THEN scheduled_uncertain:=true;END IF;
   schedules:=schedules||jsonb_build_array(jsonb_build_object('kind','check_scheduled_transfer','source_id',sid,'date',sdate,'from_bank',from_b,'to_bank',to_b,'amount_brl',round(samount,2)::text,'already_scheduled',true,'represented_in_forecast',represented=2 AND representation_keys=2));
  END LOOP;
 END IF;
 IF scheduled_uncertain THEN RETURN jsonb_build_object('version',387,'as_of',p_as_of,'days',p_days,'complete',false,'status','unknown','accounts',accounts,'actions','[]'::jsonb,'scheduled_transfers',schedules,'unfunded','[]'::jsonb,'reason','scheduled_transfer_requires_reconciliation');END IF;
 FOR i IN 1..p_days LOOP
  FOR b IN 1..3 LOOP
   IF matrix[i][b]+unfunded_reserve[b]>=0 THEN CONTINUE;END IF;
   -- V443: cover this day's incremental shortfall, not the future horizon minimum.
   deadline_i:=greatest(1,i-1);
   needed:=greatest(0,-matrix[i][b]-unfunded_reserve[b]);
   FOR s IN 1..3 LOOP
    IF s=b THEN CONTINUE;END IF;
    available:=matrix[deadline_i][s];
    FOR k IN deadline_i..p_days LOOP available:=least(available,matrix[k][s]);END LOOP;
    take:=least(needed,greatest(available,0));
    IF take>0 THEN
     actions:=actions||jsonb_build_array(jsonb_build_object('kind','suggested_transfer','execute_by',dates[deadline_i],'risk_date',dates[i],'from_bank',banks[s],'to_bank',banks[b],'amount_brl',(take/100)::text,'rescue_before_transfer_brl','0'));
     FOR k IN deadline_i..p_days LOOP matrix[k][s]:=matrix[k][s]-take;matrix[k][b]:=matrix[k][b]+take;END LOOP;
     needed:=needed-take;
    END IF;
    EXIT WHEN needed<=0;
   END LOOP;
   take:=least(needed,d0);
   IF take>0 THEN
    actions:=actions||jsonb_build_array(jsonb_build_object('kind','suggested_redemption','execute_by',dates[deadline_i],'risk_date',dates[i],'from_bank','Cofrinho Itaú','to_bank','Itaú','amount_brl',(take/100)::text,'availability_confirmation_required',true));
    FOR k IN deadline_i..p_days LOOP matrix[k][1]:=matrix[k][1]+take;END LOOP;
    IF b<>1 THEN
     actions:=actions||jsonb_build_array(jsonb_build_object('kind','suggested_transfer','execute_by',dates[deadline_i],'risk_date',dates[i],'from_bank','Itaú','to_bank',banks[b],'amount_brl',(take/100)::text,'rescue_before_transfer_brl',(take/100)::text));
     FOR k IN deadline_i..p_days LOOP matrix[k][1]:=matrix[k][1]-take;matrix[k][b]:=matrix[k][b]+take;END LOOP;
    END IF;
    d0:=d0-take;d0_used:=d0_used+take;needed:=needed-take;
   END IF;
   IF needed>0 THEN
    unfunded_reserve[b]:=unfunded_reserve[b]+needed;
    unfunded:=unfunded||jsonb_build_array(jsonb_build_object('bank',banks[b],'risk_date',dates[i],'execute_by',dates[deadline_i],'amount_brl',(needed/100)::text,'reason',CASE WHEN NOT d0_known THEN'cofrinho_availability_unknown'ELSE'no_safe_source_identified'END));END IF;
  END LOOP;
 END LOOP;
 SELECT coalesce(jsonb_agg(j ORDER BY j->>'execute_by',CASE j->>'kind'WHEN'suggested_redemption'THEN 0 ELSE 1 END,j->>'to_bank'),'[]')INTO grouped_actions
 FROM(SELECT jsonb_build_object('kind',x->>'kind','execute_by',x->>'execute_by','risk_date',min(x->>'risk_date'),'from_bank',x->>'from_bank','to_bank',x->>'to_bank','amount_brl',sum((x->>'amount_brl')::numeric)::text,'rescue_before_transfer_brl',sum(coalesce((x->>'rescue_before_transfer_brl')::numeric,0))::text,'availability_confirmation_required',bool_or(coalesce((x->>'availability_confirmation_required')::boolean,false)))j
  FROM jsonb_array_elements(actions)x GROUP BY x->>'kind',x->>'execute_by',x->>'from_bank',x->>'to_bank')g;
 plan_complete:=jsonb_array_length(unfunded)=0;
 SELECT jsonb_agg(jsonb_build_object('date',dates[q],'Itaú',(matrix[q][1]/100)::text,'Bradesco',(matrix[q][2]/100)::text,'C6',(matrix[q][3]/100)::text)ORDER BY q)INTO after_days FROM generate_series(1,p_days)q;
 RETURN jsonb_build_object('version',387,'as_of',p_as_of,'days',p_days,'to',p_as_of+p_days-1,'complete',true,'plan_complete',plan_complete,
  'status',CASE WHEN NOT plan_complete THEN'partial_plan'WHEN jsonb_array_length(grouped_actions)>0 OR jsonb_array_length(schedules)>0 THEN'actions_needed'ELSE'clear'END,
  'requirement_basis','dated_incremental_shortfalls','accounts',accounts,'actions',grouped_actions,'scheduled_transfers',schedules,'unfunded',unfunded,'proposed_daily_balances',after_days,
  'cofrinho',jsonb_build_object('balance_known',cofrinho_cap IS NOT NULL,'planning_budget_known',d0_known,'reference_balance_brl',CASE WHEN cofrinho_cap IS NOT NULL THEN(cofrinho_cap/100)::text END,'projection_d0_resource_brl',CASE WHEN d0_initial IS NOT NULL THEN(d0_initial/100)::text END,'planning_budget_brl',CASE WHEN d0_known THEN(d0_min/100)::text END,'suggested_redemptions_brl',(d0_used/100)::text,'remaining_planning_budget_brl',CASE WHEN d0_known THEN(d0/100)::text END,'availability_confirmation_required',true),
  'assumption','Conditional suggestions only. Bank source remains nonnegative throughout the remaining forecast. Verify receipts and redemption availability before acting.');
END $function$

$candidate$;
 IF (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid=target) IS DISTINCT FROM attributes
 THEN RAISE EXCEPTION 'Protected function attributes changed';END IF;
END $guard$;
DO $guard$
DECLARE target oid:='lts_account_reminder_private_v387.render_email(jsonb,text)'::regprocedure;definition text;attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE oid=target;
 IF position('Cada linha mostra a necessidade adicional naquela data' IN definition)>0 THEN RETURN;END IF;
 IF md5(definition)<>'1e4f85f2dd7efe12e8b55a816fe02dd7' THEN RAISE EXCEPTION 'Reviewed predecessor changed: lts_account_reminder_private_v387.render_email(jsonb,text)';END IF;
 EXECUTE $candidate$
CREATE OR REPLACE FUNCTION lts_account_reminder_private_v387.render_email(p_report jsonb, p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
 html:='<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;background:#f3f6f9;font-family:Arial,sans-serif;color:#203b4d"><div style="max-width:680px;box-sizing:border-box;margin:20px auto;background:#fff;border-radius:12px;padding:28px 20px"><div style="font-size:12px;letter-spacing:1px;font-weight:bold;color:#12374a">LTS WEALTH · TRANSFERÊNCIAS E RESGATES</div><h1 style="font-size:25px;line-height:1.25;color:#12374a">Recursos a providenciar'||CASE WHEN deadline IS NOT NULL THEN' até '||to_char(deadline,'DD/MM')ELSE''END||'</h1><p style="line-height:1.5">Confira as ações por conta para os próximos '||coalesce(p_report->>'days','30')||' dias. Cada linha mostra a necessidade adicional naquela data. O pior saldo do período aparece separadamente abaixo.</p>'||
  CASE WHEN p_report->>'limited_to_seven_days'='true' THEN'<p style="padding:12px;background:#fff4df;color:#785419">Projeção limitada aos próximos 7 dias; o restante ainda precisa de dados completos.</p>'ELSE''END||
  CASE WHEN p_report->>'complete'<>'true' THEN'<p style="padding:12px;background:#fff4df;color:#785419">Há dados incompletos. Confira os saldos e os agendamentos no banco antes de tomar uma decisão.</p>'ELSE''END||gaps||
  CASE WHEN rows<>'' THEN'<h2 style="font-size:18px;color:#12374a">Transferências e resgates sugeridos</h2><table style="border-collapse:collapse;width:100%;font-size:13px"><thead><tr style="background:#edf3f5"><th style="padding:10px 6px;text-align:left">Até</th><th style="padding:10px 6px;text-align:left">Ação</th><th style="padding:10px 6px;text-align:right">Necessidade adicional</th></tr></thead><tbody>'||rows||'</tbody></table>'ELSE''END||
  CASE WHEN scheduled<>'' THEN'<h2 style="font-size:18px;color:#12374a;margin-top:24px">Pix já agendados</h2><table style="border-collapse:collapse;width:100%;font-size:13px"><thead><tr style="background:#edf3f5"><th style="padding:10px 6px;text-align:left">Data</th><th style="padding:10px 6px;text-align:left">Conferir</th><th style="padding:10px 6px;text-align:right">Valor</th></tr></thead><tbody>'||scheduled||'</tbody></table>'ELSE''END||
  CASE WHEN risks<>'' THEN'<h2 style="font-size:18px;color:#12374a;margin-top:24px">Risco antes dessas ações</h2><ul style="padding-left:20px;font-size:14px;line-height:1.5">'||risks||'</ul>'ELSE''END||
  '<p style="font-size:13px;line-height:1.5">As sugestões não movimentam dinheiro. Confirme os saldos, os créditos previstos e a disponibilidade de resgate antes de agir. A projeção de uma conta positiva não garante que as outras estejam cobertas.</p><a href="https://lthomesilveira-ui.github.io/lts-wealth-/mobile/" style="display:inline-block;background:#12374a;color:#fff;text-decoration:none;padding:12px 18px;border-radius:7px">Abrir LTS Wealth</a><p style="font-size:11px;color:#617381;line-height:1.5;margin-top:22px">Projeção de '||to_char((p_report->>'as_of')::date,'DD/MM/YYYY')||' a '||coalesce(to_char((p_report->>'to')::date,'DD/MM/YYYY'),'data a confirmar')||'. Consulta: '||coalesce(to_char((p_report->>'consulted_at')::timestamptz AT TIME ZONE'America/Sao_Paulo','DD/MM/YYYY HH24:MI'),'data a confirmar')||'. Cofrinho: referência '||coalesce(to_char((p_report#>>'{cofrinho,documented_as_of}')::date,'DD/MM/YYYY'),'a confirmar')||'.<br>Referência do aviso: TR-'||lts_account_reminder_private_v387.escape_html(p_token)||'</p></div></body></html>';
 RETURN jsonb_build_object('subject',subject,'html',html);
END $function$

$candidate$;
 IF (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid=target) IS DISTINCT FROM attributes
 THEN RAISE EXCEPTION 'Protected function attributes changed';END IF;
END $guard$;

