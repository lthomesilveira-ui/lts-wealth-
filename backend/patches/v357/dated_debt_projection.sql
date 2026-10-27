-- Read-time projections. No source, installment, payment or asset value writes.
DO $initial_lease$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_catalog.pg_proc WHERE pronamespace='public'::regnamespace
  AND proname IN('lts_debt_evidence_projection_v357','lts_debt_evidence_read_v357',
   'lts_wealth_debt_projection_v357','lts_current_debt_overlay_v357'))
 THEN RAISE EXCEPTION 'V357_HELPERS_ALREADY_EXIST: inspect state before retry'; END IF;
END $initial_lease$;
CREATE OR REPLACE FUNCTION public.lts_debt_evidence_projection_v357(p_summary jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $function$
DECLARE ids text[]:=ARRAY['cipo_396','volvo','coopharma','pai_mae'];id text;c jsonb;
 rows jsonb:='[]';matches integer;balance numeric;position_date date;valid_source boolean;
 known_count integer:=0;missing_count integer:=0;subtotal numeric:=0;extra_count integer:=0;
BEGIN
 valid_source:=coalesce(jsonb_typeof(p_summary)='object'
  AND p_summary->>'version'='commitments-summary-v2-documentary'
  AND p_summary->>'as_of'=p_as_of::text
  AND jsonb_typeof(p_summary->'commitments')='array',false);
 IF valid_source THEN
  SELECT count(*) INTO extra_count FROM jsonb_array_elements(p_summary->'commitments')x
  WHERE NOT coalesce(x->>'id'=ANY(ids),false);
 END IF;
 FOREACH id IN ARRAY ids LOOP
  balance:=NULL;position_date:=NULL;matches:=0;c:=NULL;
  IF valid_source THEN
   SELECT count(*),jsonb_agg(x)->0 INTO matches,c
   FROM jsonb_array_elements(p_summary->'commitments')x WHERE x->>'id'=id;
   IF matches=1 AND jsonb_typeof(c->'current_documentary_debt_balance')='number'
    AND c->>'current_documentary_debt_balance'~'^[0-9]+([.][0-9]+)?$'
    AND c->>'current_debt_as_of'~'^\d{4}-\d{2}-\d{2}$'
    AND pg_catalog.pg_input_is_valid(c->>'current_debt_as_of','date') THEN
    position_date:=(c->>'current_debt_as_of')::date;
    IF position_date<=p_as_of THEN balance:=(c->>'current_documentary_debt_balance')::numeric;
    ELSE position_date:=NULL; END IF;
   END IF;
  END IF;
  IF balance IS NULL THEN missing_count:=missing_count+1;
  ELSE known_count:=known_count+1;subtotal:=subtotal+balance; END IF;
  rows:=rows||jsonb_build_array(jsonb_build_object('id',id,'balance',balance,'as_of',position_date,
   'status',CASE WHEN balance IS NOT NULL THEN 'dated_documentary_position'
    WHEN matches>1 THEN 'ambiguous_commitment' ELSE 'current_balance_unavailable' END,
   'source_label',CASE WHEN balance IS NOT NULL THEN c->'documentary_source_label' ELSE NULL END));
 END LOOP;
 RETURN jsonb_build_object('version','dated-debt-evidence-v357','as_of',p_as_of,
  'basis','dated_documentary_positions_not_payoff_quotes','complete',valid_source AND missing_count=0 AND extra_count=0,
  'documented_count',known_count,'missing_count',missing_count,'additional_unmodelled_commitments',extra_count,
  'documented_subtotal',CASE WHEN known_count>0 THEN subtotal ELSE NULL END,
  'total_debt',CASE WHEN valid_source AND missing_count=0 AND extra_count=0 THEN subtotal ELSE NULL END,
  'positions',rows,'source_valid',valid_source);
END $function$;

CREATE OR REPLACE FUNCTION public.lts_debt_evidence_read_v357(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE sql VOLATILE SET search_path TO '' AS $function$
 SELECT public.lts_debt_evidence_projection_v357(public.lts_commitments_summary_v1(p_user_id,p_as_of),p_as_of);
$function$;

CREATE OR REPLACE FUNCTION public.lts_wealth_debt_projection_v357(p_wealth jsonb,p_evidence jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $function$
DECLARE j jsonb:=coalesce(p_wealth,'{}');s jsonb:=coalesce(p_wealth->'summary','{}');
 old_debt numeric;debt numeric;balance numeric;v jsonb;k text;net numeric;
BEGIN
 IF jsonb_typeof(s->'known_debt_total')='number' THEN old_debt:=(s->>'known_debt_total')::numeric; END IF;
 IF p_evidence->'complete'='true'::jsonb THEN debt:=(p_evidence->>'total_debt')::numeric; END IF;
 FOREACH k IN ARRAY ARRAY['net_worth_low','net_worth_central','net_worth_high'] LOOP
  net:=NULL;
  IF debt IS NOT NULL THEN
   IF k='net_worth_central' AND jsonb_typeof(s->'assets_central')='number'
   THEN net:=(s->>'assets_central')::numeric-debt;
   ELSIF jsonb_typeof(s->k)='number' AND old_debt IS NOT NULL
   THEN net:=(s->>k)::numeric+old_debt-debt; END IF;
  END IF;
  s:=s||jsonb_build_object(k,net);
 END LOOP;
 s:=s||jsonb_build_object('known_debt_total',p_evidence->'documented_subtotal',
  'known_debt_to_assets_pct',CASE WHEN jsonb_typeof(p_evidence->'documented_subtotal')='number'
   AND (s->>'assets_central')::numeric>0
   THEN round((p_evidence->>'documented_subtotal')::numeric/(s->>'assets_central')::numeric*100,1) ELSE NULL END,
  'net_worth_status',CASE WHEN p_evidence->'complete'='true'::jsonb THEN 'estimate_using_dated_debts' ELSE 'incomplete_debt_evidence' END,
  'debt_total_complete',p_evidence->'complete','debt_basis',p_evidence->'basis');
 j:=j||jsonb_build_object('summary',s,'debt_coverage',p_evidence);
 IF jsonb_typeof(j#>'{assets,volvo_xc40}')='object' THEN
  SELECT x INTO v FROM jsonb_array_elements(p_evidence->'positions')x WHERE x->>'id'='volvo';
  balance:=(v->>'balance')::numeric;
  v:=coalesce(j#>'{assets,volvo_xc40}','{}')||jsonb_build_object(
   'current_documentary_debt_balance',balance,
   'current_debt_as_of',(SELECT x->'as_of' FROM jsonb_array_elements(p_evidence->'positions')x WHERE x->>'id'='volvo'),
   'initial_financed_amount',j#>'{assets,volvo_xc40,documented_financed_balance}',
   'documented_financed_balance_basis','initial_contract_amount_not_current_debt');
  FOREACH k IN ARRAY ARRAY['low','central','high'] LOOP
   v:=v||jsonb_build_object('equity_'||k,CASE WHEN balance IS NOT NULL
    AND jsonb_typeof(v->('market_'||k))='number' THEN (v->>('market_'||k))::numeric-balance ELSE NULL END);
  END LOOP;
  j:=jsonb_set(j,'{assets,volvo_xc40}',v);
 END IF;
 RETURN j;
END $function$;

CREATE OR REPLACE FUNCTION public.lts_current_debt_overlay_v357(p_payload jsonb,p_evidence jsonb,p_kind text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO '' AS $function$
DECLARE j jsonb:=p_payload;w jsonb;x jsonb;q jsonb;debt numeric;key text;
BEGIN
 IF p_kind='wealth' THEN
  w:=public.lts_wealth_debt_projection_v357(j->'wealth',p_evidence);
  j:=jsonb_set(j,'{wealth}',w);
  IF p_evidence->'complete'='true'::jsonb THEN debt:=(p_evidence->>'total_debt')::numeric; END IF;
  FOREACH key IN ARRAY ARRAY['wealth_v167','wealth_v168'] LOOP
   x:=j->key;
   IF jsonb_typeof(x)='object' THEN
    j:=jsonb_set(j,ARRAY[key],x||jsonb_build_object('net_worth_central_including_pensions',
     CASE WHEN debt IS NOT NULL AND jsonb_typeof(x->'assets_central_including_pensions')='number'
      THEN (x->>'assets_central_including_pensions')::numeric-debt ELSE NULL END));
   END IF;
  END LOOP;
 ELSIF p_kind='product' THEN
  w:=public.lts_wealth_debt_projection_v357(j->'wealth_executive',p_evidence);
  j:=jsonb_set(j,'{wealth_executive}',w);
  x:=coalesce(j->'dashboard_cockpit','{}');
  q:=public.lts_wealth_debt_projection_v357(jsonb_build_object('summary',coalesce(x->'wealth','{}')),p_evidence);
  x:=x||jsonb_build_object('wealth',q->'summary'||jsonb_build_object('debt_coverage',p_evidence));
  j:=jsonb_set(j,'{dashboard_cockpit}',x);
 ELSIF p_kind='cockpit' THEN
  w:=public.lts_wealth_debt_projection_v357(jsonb_build_object('summary',j->'wealth'),p_evidence);
  j:=jsonb_set(j,'{wealth}',w->'summary'||jsonb_build_object('debt_coverage',p_evidence));
 ELSE RAISE EXCEPTION 'V357_UNKNOWN_PAYLOAD_KIND'; END IF;
 RETURN j;
END $function$;

REVOKE ALL ON FUNCTION public.lts_debt_evidence_projection_v357(jsonb,date),
 public.lts_debt_evidence_read_v357(uuid,date),public.lts_wealth_debt_projection_v357(jsonb,jsonb),
 public.lts_current_debt_overlay_v357(jsonb,jsonb,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_debt_evidence_projection_v357(jsonb,date),
 public.lts_debt_evidence_read_v357(uuid,date),public.lts_wealth_debt_projection_v357(jsonb,jsonb),
 public.lts_current_debt_overlay_v357(jsonb,jsonb,text) TO service_role;
