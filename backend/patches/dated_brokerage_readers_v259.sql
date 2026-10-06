-- V259: choose documentary brokerage anchors by date. No source values or new grants.
DO $patch$
DECLARE d text; prior_acl aclitem[];
BEGIN
 SELECT pg_get_functiondef('lts_browser_awards_v178()'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_browser_awards_v178()'::regprocedure;
 IF md5(d)<>'711c137002b843fdcce8ca13331f6834' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_browser_awards_v178()'; END IF;
 IF position($old$lock_key='morgan_available_20260922' and superseded_at is null$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$lock_key='morgan_available_20260922' and superseded_at is null$old$,$new$lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1$new$);
 IF position($old$institution='Morgan Stanley' order by$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$institution='Morgan Stanley' order by$old$,$new$institution='Morgan Stanley' AND as_of_date<=current_date order by$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_browser_awards_v178()'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_wealth_executive_report_v5(uuid)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_wealth_executive_report_v5(uuid)'::regprocedure;
 IF md5(d)<>'dd64d674331e81ee42f2c3106d448b76' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_wealth_executive_report_v5(uuid)'; END IF;
 IF position($old$lock_key='morgan_available_20260922' and superseded_at is null$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$lock_key='morgan_available_20260922' and superseded_at is null$old$,$new$lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1$new$);
 IF position($old$(select (canonical_value->>'amount')::numeric from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null)::numeric d0$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$(select (canonical_value->>'amount')::numeric from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null)::numeric d0$old$,$new$public.lts_cofrinho_effective_locked_v245(p_user_id,current_date)::numeric d0$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_wealth_executive_report_v5(uuid)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_dashboard_cash_ladder_from_flow_v1(uuid,date,date,jsonb)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_dashboard_cash_ladder_from_flow_v1(uuid,date,date,jsonb)'::regprocedure;
 IF md5(d)<>'fd7904ce0e738b4c1a2a797492360418' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_dashboard_cash_ladder_from_flow_v1(uuid,date,date,jsonb)'; END IF;
 IF position($old$lock_key='morgan_available_20260922' and superseded_at is null$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$lock_key='morgan_available_20260922' and superseded_at is null$old$,$new$lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_dashboard_cash_ladder_from_flow_v1(uuid,date,date,jsonb)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_dashboard_cash_ladder_from_flow_v2(uuid,date,date,jsonb)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_dashboard_cash_ladder_from_flow_v2(uuid,date,date,jsonb)'::regprocedure;
 IF md5(d)<>'01643fc23d18160028d903f3cfc64ded' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_dashboard_cash_ladder_from_flow_v2(uuid,date,date,jsonb)'; END IF;
 IF position($old$lock_key='morgan_available_20260922' and superseded_at is null$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$lock_key='morgan_available_20260922' and superseded_at is null$old$,$new$lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_dashboard_cash_ladder_from_flow_v2(uuid,date,date,jsonb)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)'::regprocedure;
 IF md5(d)<>'96adc8787e6cff28decb21e81dbd2a54' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)'; END IF;
 IF position($old$lock_key='morgan_available_20260922' and superseded_at is null$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$lock_key='morgan_available_20260922' and superseded_at is null$old$,$new$lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_browser_cash_today_v178()'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_browser_cash_today_v178()'::regprocedure;
 IF md5(d)<>'29867d534615141e6427496957121d15' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_browser_cash_today_v178()'; END IF;
 IF position($old$lock_key='morgan_available_20260922' AND superseded_at IS NULL$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$lock_key='morgan_available_20260922' AND superseded_at IS NULL$old$,$new$lock_key LIKE 'morgan_available_%' and superseded_at is null AND (canonical_value->>'as_of')::date<=current_date ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_browser_cash_today_v178()'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_refresh_dashboard_cockpit_v2(uuid)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_refresh_dashboard_cockpit_v2(uuid)'::regprocedure;
 IF md5(d)<>'a5418986f66b01b6cbc17f64ecc145b3' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_refresh_dashboard_cockpit_v2(uuid)'; END IF;
 IF position($old$d0:=coalesce((public.lts_current_evidence_position_v1(p_user_id)->>'liquid_d0_assets')::numeric,0);$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$d0:=coalesce((public.lts_current_evidence_position_v1(p_user_id)->>'liquid_d0_assets')::numeric,0);$old$,$new$d0:=public.lts_cofrinho_effective_locked_v245(p_user_id,current_date);$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_refresh_dashboard_cockpit_v2(uuid)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_liquidity_adjustments_v242(uuid,date)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_liquidity_adjustments_v242(uuid,date)'::regprocedure;
 IF md5(d)<>'834a25b484e66fcdae5647f1d6a019b1' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_liquidity_adjustments_v242(uuid,date)'; END IF;
 IF position($old$AND superseded_at IS NULL ORDER BY canonical_value->>'as_of' DESC LIMIT 1$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$AND superseded_at IS NULL ORDER BY canonical_value->>'as_of' DESC LIMIT 1$old$,$new$AND superseded_at IS NULL AND (canonical_value->>'as_of')::date<=p_as_of ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_liquidity_adjustments_v242(uuid,date)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_browser_flow_pre_v238(date,date)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_browser_flow_pre_v238(date,date)'::regprocedure;
 IF md5(d)<>'ec7fb4d2e439c358572059a64aff7cd6' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_browser_flow_pre_v238(date,date)'; END IF;
 IF position($old$dt:=(d->>'date')::date;$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$dt:=(d->>'date')::date;$old$,$new$dt:=(d->>'date')::date;
   -- A later primary position must never replace an earlier day's anchor.
   SELECT canonical_value INTO morgan FROM public.lts_validated_lock_registry
    WHERE superseded_at IS NULL AND lock_key LIKE 'morgan_available_%'
    AND (canonical_value->>'as_of')::date<=least(dt,current_date)
    ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1;$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_browser_flow_pre_v238(date,date)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure;
 IF md5(d)<>'d25735f74ad16e90fb3c2a21affda41a' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_flow_cache_pre_v240(uuid,date,date)'; END IF;
 IF position($old$dt:=(d->>'date')::date;$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$dt:=(d->>'date')::date;$old$,$new$dt:=(d->>'date')::date;
   -- A later primary position must never replace an earlier day's anchor.
   SELECT canonical_value INTO morgan FROM public.lts_validated_lock_registry
    WHERE superseded_at IS NULL AND lock_key LIKE 'morgan_available_%'
    AND (canonical_value->>'as_of')::date<=least(dt,current_date)
    ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1;$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_browser_flow_v228(date,date)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_browser_flow_v228(date,date)'::regprocedure;
 IF md5(d)<>'f8054ffb2301f8cb6c6bd0ccb283473a' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_browser_flow_v228(date,date)'; END IF;
 IF position($old$dt:=(d->>'date')::date;$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$dt:=(d->>'date')::date;$old$,$new$dt:=(d->>'date')::date;
   -- A later primary position must never replace an earlier day's anchor.
   SELECT canonical_value INTO morgan FROM public.lts_validated_lock_registry
    WHERE superseded_at IS NULL AND lock_key LIKE 'morgan_available_%'
    AND (canonical_value->>'as_of')::date<=least(dt,current_date)
    ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1;$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_browser_flow_v228(date,date)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_browser_cash_today_v242()'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_browser_cash_today_v242()'::regprocedure;
 IF md5(d)<>'bc52ef7fb6932c22b7b201c153f8ef3a' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_browser_cash_today_v242()'; END IF;
 IF position($old$'rsus_vested',r,'saldo_apos_rsu'$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$'rsus_vested',r,'saldo_apos_rsu'$old$,$new$'rsus_vested',r,'morgan_available_total_brl',r,'saldo_apos_rsu'$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_browser_cash_today_v242()'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_browser_wealth_detail_v4()'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_browser_wealth_detail_v4()'::regprocedure;
 IF md5(d)<>'f351bfbdace504b7c20e2e8595fde8de' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_browser_wealth_detail_v4()'; END IF;
 IF position($old$where user_id=v_uid and institution='Morgan Stanley'$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$where user_id=v_uid and institution='Morgan Stanley'$old$,$new$where user_id=v_uid and institution='Morgan Stanley' AND as_of_date<=current_date$new$);
 IF position($old$'source_label',v_snapshot.source_label,$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$'source_label',v_snapshot.source_label,$old$,$new$'source_label',v_snapshot.source_label,
      'statement_component_rounding_delta_brl',v_snapshot.metadata->'statement_component_rounding_delta_brl',
      'evidence_sha256',v_snapshot.metadata->'evidence_sha256',$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_browser_wealth_detail_v4()'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
 SELECT pg_get_functiondef('lts_flow_liquidity_adjustments_v242(uuid,jsonb,date)'::regprocedure),proacl INTO d,prior_acl FROM pg_proc WHERE oid='lts_flow_liquidity_adjustments_v242(uuid,jsonb,date)'::regprocedure;
 IF md5(d)<>'bfd3f746d7f510ffaa01bdbdc22cfbc0' THEN RAISE EXCEPTION 'V259 definition lease failed: lts_flow_liquidity_adjustments_v242(uuid,jsonb,date)'; END IF;
 IF position($old$'posicao_economica_total',(c->>'posicao_economica_total')::numeric-deductions-(c->>'fgts')::numeric+documented+accrual,$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 replacement absent'; END IF;
 d:=replace(d,$old$'posicao_economica_total',(c->>'posicao_economica_total')::numeric-deductions-(c->>'fgts')::numeric+documented+accrual,$old$,$new$'posicao_economica_total',(c->>'saldo_apos_rsu')::numeric-deductions+documented+accrual+(c->>'rsus_futuras')::numeric+(c->>'cash_awards_futuros')::numeric,
 'economic_position_basis','corrected_available_resources_plus_restricted_fgts_and_remaining_scheduled_awards',$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='lts_flow_liquidity_adjustments_v242(uuid,jsonb,date)'::regprocedure) THEN RAISE EXCEPTION 'V259 ACL changed'; END IF;
END $patch$;
