BEGIN;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
DO $test$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';j jsonb;k text;before_hash text;
BEGIN
 SELECT md5(jsonb_agg(to_jsonb(t)ORDER BY id)::text)INTO before_hash FROM public.lts_open_finance_staging t;
 j:=public.lts_cofrinho_composition_v399(u,'2030-01-03');
 IF (j->>'available_brl')::numeric<>700 OR (j->>'recorded_movement_delta_brl')::numeric<>-100 OR (j->>'unrepresented_redemption_delta_brl')::numeric<>-200 THEN RAISE EXCEPTION 'distinct movement composition failed';END IF;
 IF j->>'snapshot_date'<>'2030-01-01' OR (j->>'fgts_included')::boolean THEN RAISE EXCEPTION 'future anchor or FGTS contaminated the Cofrinho';END IF;
 IF (public.lts_cofrinho_composition_v399(u,'2030-01-04')->>'available_brl')::numeric<>750 THEN RAISE EXCEPTION 'new primary position repeated old receipts';END IF;
 IF (public.lts_cofrinho_composition_v399(u,'2030-01-03')->>'available_brl')::numeric<>700 THEN RAISE EXCEPTION 'later snapshot changed an earlier date';END IF;
 IF (public.lts_cofrinho_composition_v399(u,'2029-12-31')->>'has_anchor')::boolean THEN RAISE EXCEPTION 'unknown earlier date fabricated';END IF;
 IF (public.lts_cofrinho_composition_v399('22222222-2222-4222-8222-222222222222','2030-01-03')->>'has_anchor')::boolean THEN RAISE EXCEPTION 'other owner borrowed a global lock';END IF;
 FOREACH k IN ARRAY ARRAY['lts_browser_flow_v228','lts_browser_flow_pre_v238','lts_flow_cache_pre_v240']LOOP
  IF k='lts_flow_cache_pre_v240'THEN EXECUTE format('select public.%I($1,$2,$2)',k)INTO j USING u,'2030-01-03'::date;
  ELSE EXECUTE format('select public.%I($1,$1)',k)INTO j USING '2030-01-03'::date;END IF;
  IF (j#>>'{fix86_columns,liq_d0_1_recurso}')::numeric<>700 OR(j#>>'{fix86_columns,saldo_apos_d0_1}')::numeric<>777 THEN RAISE EXCEPTION 'D0 branch regression: %',k;END IF;
  IF (j#>>'{fix86_columns,saldo_final}')::numeric<>77 OR(j#>>'{fix86_columns,rsus_vested}')::numeric<>10 OR(j#>>'{fix86_columns,fgts}')::numeric<>500 THEN RAISE EXCEPTION 'independent resource changed: %',k;END IF;
  IF (j#>>'{fix86_columns,saldo_apos_rsu}')::numeric<>787 OR(j#>>'{fix86_columns,saldo_apos_fgts}')::numeric<>1287 THEN RAISE EXCEPTION 'dependent total did not recompose: %',k;END IF;
 END LOOP;
 IF has_function_privilege('anon','public.lts_cofrinho_composition_v399(uuid,date)','execute') OR has_function_privilege('authenticated','public.lts_cofrinho_composition_v399(uuid,date)','execute') THEN RAISE EXCEPTION 'private composition helper exposed';END IF;
 IF before_hash<>(SELECT md5(jsonb_agg(to_jsonb(t)ORDER BY id)::text)FROM public.lts_open_finance_staging t) THEN RAISE EXCEPTION 'read changed financial facts';END IF;
END $test$;
ROLLBACK;
SELECT 'V399 dated anchor, FGTS separation, three paths and dependent totals passed' result;
