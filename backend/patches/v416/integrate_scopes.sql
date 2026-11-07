-- Wire the private adapter into the already-guarded V416 definitions.
DO $wire$
DECLARE d text;old text;replacement text;sig text;
BEGIN
 d:=pg_get_functiondef('lts_projection_private_v412.build(uuid,date)'::regprocedure);
 old:=' RETURN lts_projection_private_v412.calculate(policy,history,slots,p_as_of);';
 IF strpos(d,old)=0 OR strpos(d,'scope_history_read_v416')>0 THEN RAISE EXCEPTION 'Unexpected scoped builder predecessor';END IF;
 replacement:=' IF EXISTS(SELECT 1 FROM jsonb_array_elements(policy->''rules'')scope_rule WHERE scope_rule->>''card_budget_mode''=''scoped'') THEN
  history:=lts_projection_private_v412.scope_history_read_v416(p_user_id,policy,history,p_as_of);
  slots:=lts_projection_private_v412.scope_slots_v416(policy,slots,public.lts_card_cycles_v226(p_user_id));
 END IF;
 RETURN lts_projection_private_v412.calculate(policy,history,slots,p_as_of);';
 d:=replace(d,old,replacement);
 old:='''source_refs'',jsonb_agg(n.source_ref ORDER BY n.source_ref),';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Missing baseline budget bucket';END IF;
 d:=replace(d,old,old||E'\n    ''legacy_estimate_brl'',coalesce(sum(n.amount_brl) FILTER(WHERE n.source=''legacy_fix86'' AND n.confidence=''legacy_projection_adjusted''),0),');
 old:='''base_amount_brl'',base_amount,''known_amount_brl'',known,''known_complete'',known_complete,';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Missing slot budget fields';END IF;
 d:=replace(d,old,old||E'\n     ''legacy_estimate_brl'',coalesce((monthly_bucket->>''legacy_estimate_brl'')::numeric,0),');
 EXECUTE d;
 d:=pg_get_functiondef('lts_projection_private_v412.refresh_reference(uuid,date)'::regprocedure);
 old:=' IF EXISTS(SELECT 1 FROM jsonb_array_elements(facts)x';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Missing reference coverage guard';END IF;
 d:=replace(d,old,' facts:=lts_projection_private_v412.scope_history_read_v416(p_user_id,policy,facts,p_as_of);'||E'\n'||old);
 old:='  IF EXISTS(SELECT 1 FROM jsonb_array_elements(next_series)x WHERE x=candidate)THEN CONTINUE;END IF;';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Missing reference identity guard';END IF;
 d:=replace(d,old,'  IF r->>''card_budget_mode''=''scoped'' THEN candidate:=candidate||jsonb_build_object(''scope_digest'',md5((r->''budget_definition'')::text));END IF;'||E'\n'||old);
 EXECUTE d;
 d:=pg_get_functiondef('lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'::regprocedure);
 old:='    WHERE v->>''series_key''=key';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Missing fallback identity check';END IF;
 d:=replace(d,old,old||E'\n     AND (r->>''card_budget_mode'' IS DISTINCT FROM ''scoped'' OR v->>''scope_digest''=md5((r->''budget_definition'')::text))');
 old:='''reference_amount_brl'',CASE WHEN uses_history THEN mean_amount';
 IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Missing presentation reference';END IF;
 d:=replace(d,old,'''reference_base_brl'',CASE WHEN uses_history THEN mean_amount END,'||E'\n   '||
  '''reference_amount_brl'',CASE WHEN uses_history THEN mean_amount+CASE WHEN r->>''card_budget_mode''=''scoped'' THEN coalesce((SELECT sum((a->>''amount_brl'')::numeric) FROM jsonb_array_elements(r#>''{budget_definition,allowances}'')a WHERE a->>''funded_by_series''=key),0) ELSE 0 END');
 EXECUTE d;
 FOREACH sig IN ARRAY ARRAY['lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)',
  'lts_projection_private_v412.refresh_reference(uuid,date)'] LOOP
  d:=pg_get_functiondef(to_regprocedure(sig));
  old:='r->>''source_kind''=''card_invoice'' THEN';
  IF strpos(d,old)=0 THEN RAISE EXCEPTION 'Missing rolling-window activation guard';END IF;
  EXECUTE replace(d,old,'r->>''source_kind''=''card_invoice'' AND r->>''history_window_months''=''3'' THEN');
 END LOOP;
END $wire$;
