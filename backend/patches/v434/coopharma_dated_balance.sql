-- Read the dated creditor balance separately from payroll installments.
DO $v434$
DECLARE
 reader regprocedure := 'public.lts_commitment_summary_overlay_v309(uuid,date,jsonb)'::regprocedure;
 previous_definition text;
 previous_attributes jsonb;
BEGIN
 SELECT pg_get_functiondef(reader), to_jsonb(p)-'prosrc' INTO STRICT previous_definition, previous_attributes
 FROM pg_proc p WHERE p.oid=reader;
 IF md5(previous_definition)='d72c6992b64891d64a2f255098a64b37' THEN RETURN; END IF;
 IF md5(previous_definition)<>'d98a4684b3801c2fcac4fce439a498ca' THEN
  RAISE EXCEPTION 'V434_PREDECESSOR_CHANGED: inspect the current commitment reader';
 END IF;
 EXECUTE $replacement$CREATE OR REPLACE FUNCTION public.lts_commitment_summary_overlay_v309(p_user_id uuid, p_as_of date, p_base jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH states AS MATERIALIZED(SELECT public.lts_commitment_read_state_v309(p_user_id,p_as_of) j),
positions AS MATERIALIZED(
 SELECT DISTINCT ON(commitment_id) commitment_id,to_jsonb(p) p,
  CASE WHEN p.status='documented' AND p.debt_balance>=0 AND p.debt_balance<'Infinity'::numeric
   THEN to_jsonb(p.debt_balance) END documented_balance
 FROM public.lts_debt_position p WHERE user_id=p_user_id AND as_of_date<=p_as_of
 ORDER BY commitment_id,as_of_date DESC,created_at DESC,id
), items AS (
 SELECT x.c,x.ordinality,s.j->(x.c->>'id') state,p.p doc_position,p.documented_balance
 FROM jsonb_array_elements(coalesce(p_base->'commitments','[]')) WITH ORDINALITY x(c,ordinality)
 CROSS JOIN states s LEFT JOIN positions p ON p.commitment_id=x.c->>'id'
), patched AS (
 SELECT ordinality,CASE WHEN c->>'id' IN('cipo_396','coopharma') THEN c||jsonb_build_object(
  'contract_ref',doc_position->'contract_ref','current_debt_as_of',doc_position->'as_of_date',
  'current_documentary_debt_balance',CASE WHEN c->>'id'='cipo_396' THEN doc_position->'debt_balance' ELSE documented_balance END,
  'remaining_events',CASE WHEN doc_position IS NOT NULL THEN state->'future_count' ELSE NULL END,
  'next_due',CASE WHEN doc_position IS NOT NULL THEN state->'next_due' ELSE NULL END,
  'next_amount',CASE WHEN doc_position IS NOT NULL THEN state->'next_amount' ELSE NULL END,
  'documentary_remaining_installments',doc_position#>'{metadata,remaining_installments}',
  'documentary_remaining_scheduled_outflow',doc_position#>'{metadata,remaining_schedule_current_terms}',
  'documentary_source_label',doc_position->'source_label',
  'final_due',CASE WHEN c->>'id'='cipo_396' THEN doc_position#>'{metadata,final_due}' ELSE c->'last_date' END,
  'unconfirmed_past_events',CASE WHEN doc_position IS NOT NULL THEN state->'unconfirmed_past_count' ELSE NULL END,
  'unconfirmed_past_amount',CASE WHEN doc_position IS NOT NULL THEN state->'unconfirmed_past_total' ELSE NULL END,
  'confirmed_loaded_paid_events',CASE WHEN doc_position IS NOT NULL THEN state->'confirmed_loaded_paid_count' ELSE NULL END,
  'confirmed_loaded_paid_amount',CASE WHEN doc_position IS NOT NULL THEN state->'confirmed_loaded_paid_total' ELSE NULL END,
  'confirmed_paid_installments',CASE WHEN doc_position IS NULL OR state IS NULL THEN NULL
   WHEN c->>'id'='coopharma' THEN state->'confirmed_loaded_paid_count'
   WHEN doc_position#>>'{metadata,installment_paid_through}' ~ '^[0-9]+$'
    AND (state->>'first_installment')::integer=(doc_position#>>'{metadata,installment_paid_through}')::integer+1
    AND (state->>'loaded_count')::integer=(state->>'distinct_installments')::integer
    AND (state->>'last_installment')::integer-(state->>'first_installment')::integer+1=(state->>'loaded_count')::integer
   THEN to_jsonb((doc_position#>>'{metadata,installment_paid_through}')::integer+(state->>'confirmed_loaded_paid_count')::integer)
   ELSE NULL END,
  'schedule_as_of',p_as_of,'schedule_coverage',CASE WHEN doc_position IS NULL THEN 'no_dated_position'
   WHEN state IS NULL THEN 'not_loaded' ELSE 'loaded_rows' END,
  'note',CASE WHEN c->>'id'='cipo_396' THEN 'Saldo documental com sua data de referência. Parcelas futuras seguem o cronograma recebido e estão sujeitas à TR; não são saldo para quitação.'
   WHEN documented_balance IS NOT NULL THEN 'Saldo devedor informado pela Coopharma na data da consulta. O total das parcelas futuras é apresentado separadamente.'
   ELSE c->>'note' END
 )||CASE WHEN c->>'id'='cipo_396' THEN jsonb_build_object('remaining_scheduled_outflow_current_terms',CASE WHEN doc_position IS NOT NULL THEN state->'future_total' ELSE NULL END)
 ELSE jsonb_build_object('remaining_economic_outflow',CASE WHEN doc_position IS NOT NULL THEN state->'future_total' ELSE NULL END,
 'total_paid',CASE WHEN doc_position IS NOT NULL THEN state->'confirmed_loaded_paid_total' ELSE NULL END) END
 WHEN c->>'id' IN('volvo','pai_mae') THEN c||jsonb_build_object(
  'remaining_events',state->'future_count','remaining_scheduled_outflow',state->'future_total',
  'next_due',state->'next_due','next_amount',state->'next_amount','schedule_as_of',p_as_of,
  'confirmed_paid_installments',state->'confirmed_loaded_paid_count',
  'schedule_rows',state->'rows','realized_rows',state->'realized_rows',
  'unconfirmed_past_events',state->'unconfirmed_past_count','unconfirmed_past_amount',state->'unconfirmed_past_total')
 ELSE c END c FROM items
)
SELECT p_base||jsonb_build_object('as_of',p_as_of,'commitments',coalesce((SELECT jsonb_agg(c ORDER BY ordinality) FROM patched),'[]'::jsonb),
 'schedule_revision','v309-dated-contract-state');
$function$
$replacement$;
 IF md5(pg_get_functiondef(reader))<>'d72c6992b64891d64a2f255098a64b37'
  OR (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=reader) IS DISTINCT FROM previous_attributes THEN
  RAISE EXCEPTION 'V434_READER_CONTRACT_CHANGED';
 END IF;
END $v434$;
