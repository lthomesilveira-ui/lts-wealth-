CREATE SCHEMA lts_fgts_private_v419 AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA lts_fgts_private_v419 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_fgts_private_v419 TO service_role;

-- Copy only the restricted-resource scenario. Do not copy brokerage changes.
CREATE FUNCTION lts_fgts_private_v419.merge_flow(p_original jsonb,p_adjusted jsonb,p_evidence jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE result jsonb; days jsonb; invalid boolean;
BEGIN
 IF jsonb_typeof(p_original#>'{current_future,days}') IS DISTINCT FROM 'array'
  OR jsonb_typeof(p_adjusted#>'{current_future,days}') IS DISTINCT FROM 'array'
  OR jsonb_array_length(p_original#>'{current_future,days}')<>jsonb_array_length(p_adjusted#>'{current_future,days}')
 THEN RAISE EXCEPTION 'Incompatible daily resource data'; END IF;
 SELECT coalesce(bool_or(a.value->>'date' IS DISTINCT FROM b.value->>'date'
  OR jsonb_typeof(a.value->'fix86_columns') IS DISTINCT FROM 'object'
  OR jsonb_typeof(b.value->'fix86_columns') IS DISTINCT FROM 'object'),false)
 INTO invalid
 FROM jsonb_array_elements(p_original#>'{current_future,days}') WITH ORDINALITY a(value,n)
 JOIN jsonb_array_elements(p_adjusted#>'{current_future,days}') WITH ORDINALITY b(value,n) USING(n);
 IF invalid THEN RAISE EXCEPTION 'Daily resource identities differ'; END IF;
 SELECT coalesce(jsonb_agg(a.value||jsonb_build_object('fix86_columns',c.old||jsonb_build_object(
  'fgts',c.new->'fgts','fgts_documental',c.new->'fgts_documental',
  'fgts_aportes_projetados',c.new->'fgts_aportes_projetados',
  'fgts_projection_basis',c.new->'fgts_projection_basis',
  'saldo_apos_fgts',(c.old->>'saldo_apos_rsu')::numeric+(c.new->>'fgts')::numeric,
  'saldo_apos_fgts_documental',(c.old->>'saldo_apos_rsu')::numeric+(c.new->>'fgts_documental')::numeric,
  'posicao_economica_total',(c.old->>'posicao_economica_total')::numeric-(c.old->>'fgts')::numeric+(c.new->>'fgts')::numeric,
  'fgts_documented_balance_brl',p_evidence->'balance_brl',
  'fgts_documented_balance_as_of',p_evidence->'balance_as_of',
  'fgts_documented_balance_available',p_evidence->>'status'='dated_documentary_position'
 )) ORDER BY a.n),'[]'::jsonb) INTO days
 FROM jsonb_array_elements(p_original#>'{current_future,days}') WITH ORDINALITY a(value,n)
 JOIN jsonb_array_elements(p_adjusted#>'{current_future,days}') WITH ORDINALITY b(value,n) USING(n)
 CROSS JOIN LATERAL(SELECT a.value->'fix86_columns' old,b.value->'fix86_columns' new)c;
 result:=jsonb_set(p_original,'{current_future,days}',days);
 RETURN result||jsonb_build_object('fgts_projection_contract',p_adjusted->'fgts_projection_contract',
  'fgts_position',p_evidence,'fgts_reconciliation_version','v419');
END $f$;
CREATE FUNCTION lts_fgts_private_v419.align_flow(p_user_id uuid,p_flow jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
BEGIN
 RETURN lts_fgts_private_v419.merge_flow(p_flow,
  public.lts_flow_liquidity_adjustments_v242(p_user_id,p_flow,p_as_of),
  public.lts_fgts_position_evidence_v386(p_user_id,p_as_of));
END $f$;

-- Unknown documentary FGTS is not zero. Known subtotals exclude the unknown
-- component; the optional planning estimate is kept as a separate field.
CREATE FUNCTION lts_fgts_private_v419.wealth(p_wealth jsonb,p_evidence jsonb,p_estimate numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE j jsonb:=p_wealth;s jsonb:=p_wealth->'summary'; old numeric; doc numeric; delta numeric;k text; complete boolean;
BEGIN
 IF jsonb_typeof(j->'liquidity') IS DISTINCT FROM 'object' OR jsonb_typeof(s) IS DISTINCT FROM 'object'
  OR NOT ((j->'liquidity')?'fgts_contingency') THEN RAISE EXCEPTION 'Incompatible wealth resource data'; END IF;
 complete:=coalesce(p_evidence->>'status'='dated_documentary_position' AND p_evidence->>'balance_brl' IS NOT NULL,false);
 doc:=CASE WHEN complete THEN (p_evidence->>'balance_brl')::numeric END;
 old:=coalesce((j#>>'{liquidity,fgts_contingency}')::numeric,0);
 delta:=coalesce(doc,0)-old;
 FOREACH k IN ARRAY ARRAY['assets_central','net_worth_central','net_worth_low','net_worth_high'] LOOP
  IF s ? k THEN s:=jsonb_set(s,ARRAY[k],coalesce(to_jsonb((s->>k)::numeric+delta),'null'::jsonb)); END IF;
 END LOOP;
 s:=s||jsonb_build_object('restricted_contingency',doc,'fgts_balance_confirmed',complete,
  'fgts_component_missing',NOT complete,'fgts_component_excluded_from_known_subtotal',NOT complete,
  'known_assets_central',s->'assets_central','known_net_worth_central',s->'net_worth_central');
 IF (s->>'assets_central')::numeric>0 THEN
  s:=s||jsonb_build_object('known_debt_to_assets_pct',round(100*(s->>'known_debt_total')::numeric/(s->>'assets_central')::numeric,1),
   'cipo_share_of_assets_pct',round(100*(j#>>'{assets,cipo_396,market_central}')::numeric/(s->>'assets_central')::numeric,1));
 END IF;
 j:=jsonb_set(j,'{summary}',s);
 j:=jsonb_set(j,'{liquidity}',(j->'liquidity')||jsonb_build_object('fgts_contingency',doc,
  'fgts_documented_balance_available',complete,'fgts_scenario_estimate_brl',p_estimate));
 IF jsonb_typeof(j->'distribution')='array' THEN
  j:=jsonb_set(j,'{distribution}',coalesce((SELECT jsonb_agg(x||CASE WHEN x->>'name'='FGTS'
   THEN jsonb_build_object('value',doc,'detail',CASE WHEN complete THEN 'Saldo restrito documentado' ELSE 'Saldo atual a confirmar' END)
   ELSE '{}'::jsonb END ORDER BY n)
   FROM jsonb_array_elements(j->'distribution') WITH ORDINALITY a(x,n)),'[]'::jsonb));
 END IF;
 RETURN j||jsonb_build_object('fgts_position',p_evidence,'fgts_reconciliation_version','v419');
END $f$;
CREATE FUNCTION lts_fgts_private_v419.wealth_detail(p_detail jsonb,p_evidence jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE j jsonb:=p_detail; w jsonb; delta numeric; k text;
BEGIN
 w:=lts_fgts_private_v419.wealth(j->'wealth',p_evidence,(j#>>'{current_liquidity,fgts}')::numeric);
 delta:=(w#>>'{summary,assets_central}')::numeric-(j#>>'{wealth,summary,assets_central}')::numeric;
 j:=jsonb_set(j,'{wealth}',w);
 FOREACH k IN ARRAY ARRAY['assets_central_including_pensions','net_worth_central_including_pensions'] LOOP
  IF j#>ARRAY['wealth_v167',k] IS NOT NULL THEN
   j:=jsonb_set(j,ARRAY['wealth_v167',k],coalesce(to_jsonb((j#>>ARRAY['wealth_v167',k])::numeric+delta),'null'::jsonb));
  END IF;
 END LOOP;
 RETURN j||jsonb_build_object('fgts_position',p_evidence,'fgts_reconciliation_version','v419');
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA lts_fgts_private_v419 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lts_fgts_private_v419 TO service_role;
