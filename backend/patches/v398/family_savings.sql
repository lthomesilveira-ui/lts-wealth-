-- Indexed family loans: dated principal, completed savings periods and confirmed
-- repayments. Original cash forecasts remain a separate planning calendar.
CREATE TABLE IF NOT EXISTS public.lts_family_loan_v398 (
 user_id uuid NOT NULL, commitment_id text NOT NULL,
 original_principal numeric NOT NULL CHECK(original_principal>0),
 starts_on date NOT NULL CHECK(extract(day FROM starts_on)=1),
 contract_ref text NOT NULL, indexer text NOT NULL DEFAULT 'bcb_savings_new' CHECK(indexer='bcb_savings_new'),
 contractual_due_on date CHECK(contractual_due_on IS NULL),
 active boolean NOT NULL DEFAULT true, source_label text NOT NULL,
 metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,commitment_id)
);
ALTER TABLE public.lts_family_loan_v398 ENABLE ROW LEVEL SECURITY;
DO $policy$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='lts_family_loan_v398' AND policyname='owner_read') THEN
  CREATE POLICY owner_read ON public.lts_family_loan_v398 FOR SELECT TO authenticated USING((SELECT auth.uid())=user_id);
 END IF;
END $policy$;
REVOKE ALL ON public.lts_family_loan_v398 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_family_loan_v398 TO authenticated;
GRANT ALL ON public.lts_family_loan_v398 TO service_role;

CREATE TABLE IF NOT EXISTS public.lts_savings_rate_v398 (
 period_start date PRIMARY KEY CHECK(extract(day FROM period_start)=1),
 period_end date NOT NULL CHECK(period_end=(period_start+interval '1 month')::date),
 rate_pct numeric NOT NULL CHECK(rate_pct>=0 AND rate_pct<=10),
 source_url text NOT NULL CHECK(source_url LIKE 'https://api.bcb.gov.br/dados/serie/bcdata.sgs.195/%'),
 observed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.lts_savings_rate_v398 ENABLE ROW LEVEL SECURITY;
DO $policy$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='lts_savings_rate_v398' AND policyname='official_rates_read') THEN
  CREATE POLICY official_rates_read ON public.lts_savings_rate_v398 FOR SELECT TO authenticated USING(true);
 END IF;
END $policy$;
REVOKE ALL ON public.lts_savings_rate_v398 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_savings_rate_v398 TO authenticated;
GRANT ALL ON public.lts_savings_rate_v398 TO service_role;

CREATE OR REPLACE FUNCTION public.lts_family_savings_calculate_v398(
 p_principal numeric,p_start date,p_as_of date,p_rates jsonb,p_payments jsonb DEFAULT '[]')
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=''
AS $fn$
DECLARE balance numeric:=p_principal; paid numeric:=0;interest_total numeric:=0;
 d date:=p_start; finish date; rate numeric; matching integer; reduction numeric;
 cycles integer:=0;row_item jsonb;last_correction date:=p_start;
BEGIN
 IF p_principal IS NULL OR p_principal<=0 OR p_start IS NULL OR extract(day FROM p_start)<>1
  OR p_as_of IS NULL OR p_as_of<p_start OR jsonb_typeof(p_rates) IS DISTINCT FROM 'array' OR jsonb_typeof(p_payments) IS DISTINCT FROM 'array'
 THEN RETURN jsonb_build_object('status','invalid_inputs','balance_brl',NULL,'complete',false);END IF;
 -- Only typed, dated positive repayments supplied by the verified-bank reader.
 FOR row_item IN SELECT value FROM jsonb_array_elements(p_payments) LOOP
  IF NOT coalesce(jsonb_typeof(row_item->'amount')='number' AND row_item->>'date' ~ '^\d{4}-\d{2}-\d{2}$'
   AND pg_catalog.pg_input_is_valid(row_item->>'date','date'),false)
  THEN RETURN jsonb_build_object('status','invalid_payment','balance_brl',NULL,'complete',false);END IF;
  IF (row_item->>'amount')::numeric<=0 OR (row_item->>'date')::date<p_start OR (row_item->>'date')::date>p_as_of
  THEN RETURN jsonb_build_object('status','invalid_payment','balance_brl',NULL,'complete',false);END IF;
 END LOOP;
 LOOP
  finish:=(d+interval '1 month')::date;
  EXIT WHEN finish>p_as_of;
  SELECT count(*),min((x->>'rate_pct')::numeric) INTO matching,rate
  FROM jsonb_array_elements(p_rates)x
  WHERE x->>'period_start'=d::text AND x->>'period_end'=finish::text
   AND jsonb_typeof(x->'rate_pct')='number';
  IF balance<>0 AND (matching<>1 OR rate IS NULL OR rate<0 OR rate>10) THEN
   RETURN jsonb_build_object('status','rate_coverage_incomplete','balance_brl',NULL,'complete',false,
    'missing_period_start',d,'last_complete_balance_brl',round(balance,2),'corrected_through',last_correction);
  END IF;
  IF balance=0 THEN rate:=0;END IF;
  SELECT coalesce(sum((x->>'amount')::numeric),0) INTO reduction FROM jsonb_array_elements(p_payments)x
   WHERE (x->>'date')::date>=d AND (x->>'date')::date<finish;
  IF reduction>balance THEN RETURN jsonb_build_object('status','payment_exceeds_balance','balance_brl',NULL,'complete',false);END IF;
  balance:=balance-reduction;paid:=paid+reduction;
  interest_total:=interest_total+balance*rate/100;balance:=balance*(1+rate/100);
  cycles:=cycles+1;d:=finish;last_correction:=finish;
 END LOOP;
 SELECT coalesce(sum((x->>'amount')::numeric),0) INTO reduction FROM jsonb_array_elements(p_payments)x
  WHERE (x->>'date')::date>=d AND (x->>'date')::date<=p_as_of;
 IF reduction>balance THEN RETURN jsonb_build_object('status','payment_exceeds_balance','balance_brl',NULL,'complete',false);END IF;
 balance:=balance-reduction;paid:=paid+reduction;
 RETURN jsonb_build_object('version','family-savings-position-v398','status',CASE WHEN balance=0 THEN 'settled' ELSE 'indexed_owner_position' END,
  'complete',true,'original_principal_brl',p_principal,'starts_on',p_start,'as_of',p_as_of,
  'balance_brl',round(balance,2),'accrued_savings_brl',round(interest_total,2),'confirmed_repayments_brl',round(paid,2),
  'completed_periods',cycles,'corrected_through',last_correction,'contractual_due_date',NULL,
  'indexer','bcb_savings_new','forecasts_are_repayments',false,'future_rates_assumed',false);
END $fn$;
REVOKE ALL ON FUNCTION public.lts_family_savings_calculate_v398(numeric,date,date,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_family_savings_calculate_v398(numeric,date,date,jsonb,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_family_loan_position_v398(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $fn$
WITH loan AS MATERIALIZED(SELECT * FROM public.lts_family_loan_v398
 WHERE user_id=p_user_id AND commitment_id='pai_mae' AND active AND starts_on<=p_as_of),
 rates AS(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY period_start),'[]') j
  FROM public.lts_savings_rate_v398 r WHERE period_start>=(SELECT starts_on FROM loan) AND period_end<=p_as_of),
 proofs AS MATERIALIZED(
 SELECT b.financial_event_id,b.staging_id,b.event_date,-b.signed_amount amount
 FROM public.lts_realized_bank_sources_v238(p_user_id)b
 JOIN public.financial_events f ON f.id=b.financial_event_id AND f.user_id=p_user_id
 JOIN loan l ON f.metadata->>'contract_ref'=l.contract_ref
 WHERE f.status='confirmed' AND f.nature='expense' AND NOT f.is_internal_transfer AND NOT f.is_suppressed
  AND b.signed_amount<0 AND b.event_date BETWEEN l.starts_on AND p_as_of
), valid AS(
 SELECT * FROM proofs WHERE financial_event_id IN(SELECT financial_event_id FROM proofs GROUP BY financial_event_id HAVING count(*)=1)
  AND staging_id IN(SELECT staging_id FROM proofs GROUP BY staging_id HAVING count(*)=1)
),payments AS(SELECT coalesce(jsonb_agg(jsonb_build_object('date',event_date,'amount',amount) ORDER BY event_date,financial_event_id),'[]') j FROM valid)
SELECT CASE WHEN (SELECT count(*) FROM proofs)<>(SELECT count(*) FROM valid)
 THEN jsonb_build_object('status','payment_proof_ambiguous','balance_brl',NULL,'complete',false)
 ELSE public.lts_family_savings_calculate_v398(l.original_principal,l.starts_on,p_as_of,r.j,p.j) END
 ||jsonb_build_object('source_label',l.source_label,'metadata',l.metadata,
 'ambiguous_payment_proofs',(SELECT count(*) FROM proofs)-(SELECT count(*) FROM valid))
 FROM loan l CROSS JOIN rates r CROSS JOIN payments p;
$fn$;
REVOKE ALL ON FUNCTION public.lts_family_loan_position_v398(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_family_loan_position_v398(uuid,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_family_loan_summary_v398(p_user_id uuid,p_as_of date,p_base jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=''
AS $fn$
WITH position AS MATERIALIZED(SELECT public.lts_family_loan_position_v398(p_user_id,p_as_of) j)
SELECT CASE WHEN (SELECT j FROM position) IS NULL THEN p_base ELSE p_base||jsonb_build_object(
 'commitments',(SELECT jsonb_agg(CASE WHEN c->>'id'='pai_mae' THEN c||jsonb_build_object(
 'current_documentary_debt_balance',p.j->'balance_brl','current_debt_as_of',p_as_of,
 'documentary_source_label',p.j->'source_label','confidence','owner_confirmed_indexed_loan',
 'original_principal_brl',p.j->'original_principal_brl','indexation',p.j,
 'contractual_due_date',NULL,'has_fixed_maturity',false,'next_due',NULL,'next_amount',NULL,
 'last_date',NULL,'planned_next_payment_date',c->'next_due','planned_next_payment_amount',c->'next_amount',
 'planned_final_payment_date',c->'last_date','payment_calendar_kind','owner_estimate',
 'unconfirmed_past_events',0,'unconfirmed_past_amount',0,
 'schedule_rows',coalesce((SELECT jsonb_agg(r||jsonb_build_object('status','planned','contractual_due_date',NULL)
  ORDER BY ordinality) FROM jsonb_array_elements(coalesce(c->'schedule_rows','[]')) WITH ORDINALITY x(r,ordinality)),'[]'),
 'note','Sem vencimento definido. Saldo corrigido pela poupança nos aniversários completos. As parcelas no fluxo são planejamento; só pagamentos confirmados reduzem a dívida.'
 ) ELSE c END ORDER BY ordinal) FROM jsonb_array_elements(coalesce(p_base->'commitments','[]')) WITH ORDINALITY x(c,ordinal)
 CROSS JOIN position p)) END;
$fn$;
REVOKE ALL ON FUNCTION public.lts_family_loan_summary_v398(uuid,date,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_family_loan_summary_v398(uuid,date,jsonb) TO service_role;

DO $patch$
DECLARE original text;updated text;
BEGIN
 original:=pg_get_functiondef('public.lts_commitments_summary_v1(uuid,date)'::regprocedure);
 IF position('v398-family-savings' IN original)>0 THEN RETURN;END IF;
 IF position('SELECT public.lts_commitment_summary_overlay_v309(p_user_id,p_as_of,payload) FROM v309_previous;' IN original)=0 THEN
  RAISE EXCEPTION 'V398 summary anchor changed; inspect before patching';END IF;
 updated:=replace(original,
 'SELECT public.lts_commitment_summary_overlay_v309(p_user_id,p_as_of,payload) FROM v309_previous;',
 E'-- v398-family-savings\nSELECT public.lts_family_loan_summary_v398(p_user_id,p_as_of,public.lts_commitment_summary_overlay_v309(p_user_id,p_as_of,payload)) FROM v309_previous;');
 EXECUTE updated;
END $patch$;
