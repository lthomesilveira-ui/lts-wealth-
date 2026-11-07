CREATE TEMP TABLE v419_predecessors(signature text PRIMARY KEY,expected_md5 text) ON COMMIT DROP;
INSERT INTO v419_predecessors VALUES
 ('public.lts_apply_current_liquidity_anchor_v1(uuid)','1e70168d1649f0a8c26782a59ef0d1b1'),
 ('public.lts_dashboard_cash_ladder_from_flow_v1(uuid,date,date,jsonb)','cc0f9a85bf357245e049dd4abada3e8e'),
 ('public.lts_refresh_dashboard_cockpit_v2(uuid)','4195f1048ae9cfa5565f2b86a8874493'),
 ('public.lts_browser_planning_ui_contract_v241()','b1248b2a29de03adcf138bd1b0bb6e31'),
 ('public.lts_browser_wealth_detail_v242()','0f104a232373d5cf7515052c364f43d1'),
 ('public.lts_planning_liquidity_ladder_from_flow_v1(uuid,date,date,jsonb)','7999719f196408dcced121472a054cdb'),
 ('public.lts_current_evidence_position_v2(uuid)','4a0d121c7c94a566cda4243496cb8e94');
CREATE TEMP TABLE v419_before ON COMMIT DROP AS
SELECT e.signature,e.expected_md5,p.oid,to_jsonb(p)-'prosrc' attributes,pg_get_functiondef(p.oid) definition
FROM v419_predecessors e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature);
DO $guard$ BEGIN
 IF EXISTS(SELECT 1 FROM v419_before WHERE oid IS NULL OR md5(definition) IS DISTINCT FROM expected_md5)
 THEN RAISE EXCEPTION 'Unexpected V419 predecessor'; END IF;
END $guard$;
CREATE TEMP TABLE v419_changes(n int,signature text,old text,new text) ON COMMIT DROP;
INSERT INTO v419_changes VALUES
(1,'public.lts_apply_current_liquidity_anchor_v1(uuid)',
 $o$ f:=public.lts_flow_cache_core_v240(p_user_id,current_date,horizon)->'flow';$o$,
 $n$ f:=public.lts_flow_cache_core_v240(p_user_id,current_date,horizon)->'flow';
 f:=lts_fgts_private_v419.align_flow(p_user_id,f,current_date);$n$),
(2,'public.lts_apply_current_liquidity_anchor_v1(uuid)',
 $o$'observed_bank_movements',f->'observed_bank_movements','projected_operational_anchor',f->'projected_operational_anchor');$o$,
 $n$'observed_bank_movements',f->'observed_bank_movements','projected_operational_anchor',f->'projected_operational_anchor',
 'fgts_projection_contract',f->'fgts_projection_contract','fgts_position',f->'fgts_position','fgts_reconciliation_version','v419');$n$),
(3,'public.lts_apply_current_liquidity_anchor_v1(uuid)',
 $o$ w:=public.lts_wealth_executive_report_v5(p_user_id);$o$,
 $n$ w:=public.lts_wealth_executive_report_v5(p_user_id);
 w:=lts_fgts_private_v419.wealth(w,f->'fgts_position',(today_day#>>'{fix86_columns,fgts}')::numeric);$n$),
(6,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$fgts:=coalesce((w#>>'{liquidity,fgts_contingency}')::numeric,0);$o$,
 $n$fgts:=(w#>>'{liquidity,fgts_contingency}')::numeric;$n$),
(7,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$headline:=case status when 'critical' then 'Há um gap de liquidez ainda não coberto no horizonte.' when 'attention' then 'Há um ponto de gestão de liquidez que pode ser coberto com a contingência documental disponível.' else 'Liquidez coberta no horizonte auditado.' end;$o$,
 $n$headline:=case status when 'critical' then 'Há insuficiência projetada de recursos.' when 'attention' then 'A cobertura depende do cenário estimado de FGTS.' else 'Liquidez coberta no período.' end;$n$),
(8,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$when 'critical' then 'Com o FGTS documental atual de R$ '||to_char(fgts_coverage,'FM999G999G990D00')||', sem estimar depósitos futuros, a contingência D+30 não cobre todo o horizonte. Primeiro saldo negativo mesmo após FGTS: '||to_char(uncovered_after_fgts,'DD/MM/YYYY')||'.'$o$,
 $n$when 'critical' then 'Primeiro saldo negativo no cenário com FGTS: '||to_char(uncovered_after_fgts,'DD/MM/YYYY')||'.'$n$),
(9,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$when 'attention' then 'O primeiro ponto de gestão é '||to_char(management_date,'DD/MM/YYYY')||'. A análise usa somente o FGTS documental atual, sem estimar depósitos futuros.'$o$,
 $n$when 'attention' then 'Recursos necessários em '||to_char(management_date,'DD/MM/YYYY')||'. FGTS sujeito à disponibilidade.'$n$),
(10,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$'fgts_future_accrual_estimated',false,$o$,
 $n$'fgts_future_accrual_estimated',coalesce((c.payload#>>'{flow,fgts_projection_contract,enabled}')::boolean,false),
 'fgts_documented_balance_available',fgts IS NOT NULL,$n$),
(11,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$'FGTS coverage uses only the latest documentary balance; future FGTS deposits/accrual are not estimated.',$o$,
 $n$'FGTS forecast follows the approved daily scenario; unknown documentary balance stays unknown.',$n$),
(12,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$'dashboard-cockpit-v2-documentary-fgts-no-projection'$o$,
 $n$'dashboard-cockpit-v2-current-fgts-scenario'$n$),
(13,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$'uncovered_liquidity_gap_after_documented_fgts_d30'$o$,
 $n$'uncovered_liquidity_gap_after_fgts_scenario'$n$),
(14,'public.lts_refresh_dashboard_cockpit_v2(uuid)',
 $o$'liquidity_management_point_covered_by_documented_fgts_d30'$o$,
 $n$'liquidity_management_point_covered_by_fgts_scenario'$n$),
(15,'public.lts_browser_planning_ui_contract_v241()',
 $o$j:=public.lts_browser_flow_v241(current_date,last_day);$o$,
 $n$j:=public.lts_browser_flow_v242(current_date,last_day);$n$),
(16,'public.lts_browser_planning_ui_contract_v241()',
 $o$'scenario_revision','v241'$o$,
 $n$'scenario_revision','v419'$n$),
(17,'public.lts_browser_planning_ui_contract_v241()',
 $o$'fgts_documented_first_negative',fg,'fgts_documented_minimum',fg_min,$o$,
 $n$'fgts_projected_first_negative',fg,'fgts_projected_minimum',fg_min,
 'fgts_documented_first_negative',CASE WHEN public.lts_fgts_position_evidence_v386(u,current_date)->>'balance_brl' IS NOT NULL THEN (SELECT min(dt) FROM d WHERE (c->>'saldo_apos_fgts_documental')::numeric<0) END,
 'fgts_documented_minimum',CASE WHEN public.lts_fgts_position_evidence_v386(u,current_date)->>'balance_brl' IS NOT NULL THEN (SELECT min((c->>'saldo_apos_fgts_documental')::numeric) FROM d) END,$n$),
(18,'public.lts_browser_planning_ui_contract_v241()',
 $o$'fgts','Com FGTS documental'||CASE$o$,
 $n$'fgts','Com FGTS '||CASE WHEN coalesce((j#>>'{flow,fgts_projection_contract,enabled}')::boolean,false) THEN 'estimado' ELSE 'documental' END||CASE$n$),
(19,'public.lts_browser_wealth_detail_v242()',
 $o$RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j||jsonb_build_object('brokerage_reference',public.lts_brokerage_reference_v352(u),'reader_revision','v242-settled-resource-transfers'));$o$,
 $n$j:=lts_fgts_private_v419.wealth_detail(j,public.lts_fgts_position_evidence_v386(u,current_date));
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j||jsonb_build_object('brokerage_reference',public.lts_brokerage_reference_v352(u),'reader_revision','v242-settled-resource-transfers'));$n$),
(20,'public.lts_planning_liquidity_ladder_from_flow_v1(uuid,date,date,jsonb)',
 $o$'version','planning-liquidity-ladder-v240-canonical-fgts-d30','from',p_from,'to',p_to,'flow_basis','canonical_operational_flow_v240',$o$,
 $n$'version','planning-liquidity-ladder-v240-canonical-fgts-d30','from',p_from,'to',p_to,'flow_basis','canonical_operational_flow_v240',
 'fgts_reconciliation_version','v419','fgts_projection_contract',p_flow->'fgts_projection_contract',
 'fgts_position',p_flow->'fgts_position',$n$),
(21,'public.lts_planning_liquidity_ladder_from_flow_v1(uuid,date,date,jsonb)',
 $o$'covers_horizon_if_available',case when$o$,
 $n$'covers_horizon_if_available',case when EXISTS(SELECT 1 FROM l WHERE fgts_projected IS NULL OR balance_with_fgts IS NULL) THEN NULL when$n$),
(22,'public.lts_browser_planning_ui_contract_v241()',
 $o$min((c->>'saldo_apos_fgts')::numeric) fg_min FROM d)$o$,
 $n$min((c->>'saldo_apos_fgts')::numeric) fg_min,count(*) FILTER(WHERE c->>'saldo_apos_fgts' IS NULL) missing_fgts FROM d)$n$),
(23,'public.lts_browser_planning_ui_contract_v241()',
 $o$'fgts_covers_horizon',fg IS NULL,$o$,
 $n$'fgts_covers_horizon',CASE WHEN missing_fgts>0 THEN NULL ELSE fg IS NULL END,$n$);
DO $replace$
DECLARE fn record;ch record;source text;count_found int;
BEGIN
 FOR fn IN SELECT * FROM v419_before WHERE signature<>'public.lts_dashboard_cash_ladder_from_flow_v1(uuid,date,date,jsonb)' ORDER BY signature LOOP
  source:=fn.definition;
  FOR ch IN SELECT * FROM v419_changes WHERE signature=fn.signature ORDER BY n LOOP
   count_found:=(length(source)-length(replace(source,ch.old,'')))/length(ch.old);
   IF count_found<>1 THEN RAISE EXCEPTION 'Unexpected snippet count for % change %',fn.signature,ch.n; END IF;
   source:=replace(source,ch.old,ch.new);
  END LOOP;
  IF fn.signature='public.lts_current_evidence_position_v2(uuid)' THEN
   IF (SELECT count(*) FROM regexp_matches(source,$r$'restricted_assets',[0-9.]+,$r$,'g'))<>1
   THEN RAISE EXCEPTION 'Unexpected restricted-position source'; END IF;
   source:=regexp_replace(source,$r$'restricted_assets',[0-9.]+,$r$,
    $n$'restricted_assets',(public.lts_fgts_position_evidence_v386(p_user_id,current_date)->>'balance_brl')::numeric,
 'restricted_assets_complete',public.lts_fgts_position_evidence_v386(p_user_id,current_date)->>'balance_brl' IS NOT NULL,$n$);
  END IF;
  IF source=fn.definition THEN RAISE EXCEPTION 'No changes prepared for %',fn.signature; END IF;
  EXECUTE source;
 END LOOP;
END $replace$;
