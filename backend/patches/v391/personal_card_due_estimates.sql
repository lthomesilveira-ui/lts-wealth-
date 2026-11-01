-- Explicit planning dates, separate from owner-confirmed cycle rules.
CREATE TABLE IF NOT EXISTS public.lts_card_due_estimate_v391 (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 family text NOT NULL CHECK(family='c6'),
 reference_month date NOT NULL CHECK(extract(day FROM reference_month)=1),
 nominal_due_date date NOT NULL,
 due_date date NOT NULL,
 evidence jsonb NOT NULL,
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,family,reference_month),
 CHECK(date_trunc('month',nominal_due_date)::date=reference_month),
 CHECK(due_date BETWEEN nominal_due_date AND nominal_due_date+7),
 CHECK(extract(isodow FROM due_date) BETWEEN 1 AND 5),
 CHECK(evidence->>'schema' IS NOT DISTINCT FROM 'personal-card-due-estimate-v391'),
 CHECK(CASE WHEN jsonb_typeof(evidence->'source_invoice_rows')='array'
  THEN jsonb_array_length(evidence->'source_invoice_rows') BETWEEN 3 AND 24 ELSE false END),
 CHECK(jsonb_typeof(evidence->'non_business_dates') IS NOT DISTINCT FROM 'array'),
 CHECK(NOT((evidence->'non_business_dates') ? due_date::text))
);
ALTER TABLE public.lts_card_due_estimate_v391 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_card_due_estimate_v391 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_card_due_estimate_v391 TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.lts_card_due_estimate_v391 TO service_role;
DO $policy$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='lts_card_due_estimate_v391' AND policyname='own_estimates') THEN
  CREATE POLICY own_estimates ON public.lts_card_due_estimate_v391 FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.lts_card_due_estimate_v391'::regclass AND tgname='due_estimate_changed_v391') THEN
  CREATE TRIGGER due_estimate_changed_v391 AFTER INSERT OR UPDATE OR DELETE ON public.lts_card_due_estimate_v391
   FOR EACH STATEMENT EXECUTE FUNCTION public.lts_card_due_rule_changed_v290();
 END IF;
END $policy$;

CREATE OR REPLACE FUNCTION public.lts_card_due_estimate_overlay_v391(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $function$
DECLARE result jsonb;
BEGIN
 IF jsonb_typeof(p_payload->'cards') IS DISTINCT FROM 'array' OR NOT EXISTS(
  SELECT 1 FROM public.lts_card_due_estimate_v391 WHERE user_id=p_user_id AND active)
 THEN RETURN p_payload;END IF;
 WITH estimates AS MATERIALIZED(
  SELECT * FROM public.lts_card_due_estimate_v391 WHERE user_id=p_user_id AND active
 ), source_checks AS MATERIALIZED(
  SELECT e.user_id,e.family,e.reference_month,count(s.id) found,count(DISTINCT s.id) distinct_sources,
   count(DISTINCT s.provider_account_ref) accounts,
   bool_and(CASE WHEN s.normalized_payload->>'due_date' ~ '^\d{4}-\d{2}-\d{2}$'
    AND pg_input_is_valid(s.normalized_payload->>'due_date','date')
    THEN s.normalized_payload->>'due_date'=x->>'due_date'
     AND extract(day FROM(s.normalized_payload->>'due_date')::date)=extract(day FROM e.nominal_due_date)
     AND s.provider_account_ref=e.evidence->>'provider_account_ref'
    ELSE false END) source_dates_match
  FROM estimates e CROSS JOIN LATERAL jsonb_array_elements(e.evidence->'source_invoice_rows')x
  LEFT JOIN public.lts_open_finance_staging s ON s.user_id=e.user_id AND s.id::text=x->>'source_id'
   AND s.resource_type='invoice' AND s.institution_code='336' AND s.currency='BRL' AND s.provider_deleted_at IS NULL
  GROUP BY e.user_id,e.family,e.reference_month
 ), checked AS MATERIALIZED(
  SELECT e.*,coalesce(s.found=jsonb_array_length(e.evidence->'source_invoice_rows')
   AND s.distinct_sources=s.found AND s.accounts=1 AND s.source_dates_match
   AND latest.due_date IS NOT NULL AND extract(day FROM latest.due_date)=extract(day FROM e.nominal_due_date)
   AND e.due_date=(SELECT min(d::date) FROM generate_series(e.nominal_due_date,e.nominal_due_date+7,interval '1 day')d
    WHERE extract(isodow FROM d) BETWEEN 1 AND 5 AND NOT((e.evidence->'non_business_dates') ? (d::date)::text)),false) valid,
   s.found source_count,latest.due_date latest_received_due_date
  FROM estimates e JOIN source_checks s USING(user_id,family,reference_month)
  LEFT JOIN LATERAL(SELECT CASE WHEN pg_input_is_valid(b.normalized_payload->>'due_date','date')
    THEN(b.normalized_payload->>'due_date')::date END due_date
   FROM public.lts_open_finance_staging b WHERE b.user_id=e.user_id AND b.resource_type='invoice'
    AND b.institution_code='336' AND b.currency='BRL' AND b.provider_deleted_at IS NULL
    AND b.provider_account_ref=e.evidence->>'provider_account_ref'
   ORDER BY due_date DESC NULLS LAST LIMIT 1)latest ON true
 ), cards AS(
  SELECT c.value card,c.ord,cy.cycles,cy.invalid
  FROM jsonb_array_elements(p_payload->'cards') WITH ORDINALITY c(value,ord)
  CROSS JOIN LATERAL(
   SELECT coalesce(jsonb_agg(y.value||CASE WHEN e.valid THEN jsonb_build_object(
    'due_date',e.due_date,'nominal_due_date',e.nominal_due_date,
    'due_date_basis','received_personal_invoice_estimate','due_estimate_owner_confirmed',false,
    'due_estimate_source_count',e.source_count,'due_estimate_latest_received_due',e.latest_received_due_date,
    'projection_only',true,'official_invoice_received',false)
    WHEN e.user_id IS NOT NULL THEN jsonb_build_object('due_estimate_source_changed',true)
    ELSE '{}'::jsonb END ORDER BY y.ord),'[]'::jsonb) cycles,
    coalesce(bool_or(e.user_id IS NOT NULL AND NOT e.valid),false) invalid
   FROM jsonb_array_elements(coalesce(c.value->'cycles','[]'::jsonb)) WITH ORDINALITY y(value,ord)
   LEFT JOIN checked e ON e.family=c.value->>'family' AND e.reference_month::text=y.value->>'month'
    AND y.value->>'basis'='derived_current_installments' AND y.value->>'due_date' IS NULL
    AND y.value->>'invoice_source_id' IS NULL
  )cy
 ), rebuilt AS(
  SELECT coalesce(jsonb_agg(card||jsonb_build_object('cycles',cycles)||CASE WHEN invalid THEN
   jsonb_build_object('complete',false,'due_estimate_source_changed',true) ELSE '{}'::jsonb END ORDER BY ord),'[]') cards,
   coalesce(bool_or(invalid),false) invalid FROM cards
 )SELECT p_payload||jsonb_build_object('cards',r.cards)||CASE WHEN r.invalid THEN
  jsonb_build_object('complete',false,'incomplete_families',(SELECT jsonb_agg(DISTINCT value)
   FROM jsonb_array_elements(coalesce(p_payload->'incomplete_families','[]'::jsonb)||'["c6"]'::jsonb)))
  ELSE '{}'::jsonb END INTO result FROM rebuilt r;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_card_due_estimate_overlay_v391(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_card_due_estimate_overlay_v391(uuid,jsonb) TO authenticated,service_role;

-- The wrapper change below is generated from the reviewed V370 definition.
DO $lease$ DECLARE original text:=pg_get_functiondef('public.lts_card_due_overlay_v290(uuid,jsonb)'::regprocedure); BEGIN
 IF md5(original)='a8a083f160fb6e2937dc96e165b2fbd8' THEN RETURN;END IF;
 IF md5(original)<>'0ed3c098458c38fe3f7d410b47b15d73' THEN RAISE EXCEPTION 'Card date wrapper changed';END IF;
 EXECUTE replace(replace(original,'SELECT public.lts_card_transition_overlay_v370(','SELECT public.lts_card_due_estimate_overlay_v391(p_user_id,public.lts_card_transition_overlay_v370('),'ELSE p_payload END)'||chr(10),'ELSE p_payload END))'||chr(10));
END $lease$;
