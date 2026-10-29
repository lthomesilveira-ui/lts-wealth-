-- A reviewed issuer settlement identifies the exact owned legacy card cycle.
-- This metadata reader never creates a payment or changes cash/consumption.
CREATE SCHEMA IF NOT EXISTS lts_receipt_private_v375;
REVOKE ALL ON SCHEMA lts_receipt_private_v375 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_receipt_private_v375 TO service_role;

CREATE OR REPLACE FUNCTION lts_receipt_private_v375.legacy_aeternum_receipt(p_user_id uuid,p_event jsonb,p_as_of date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH owned_plan AS MATERIALIZED(
 SELECT e.idx,e.dados FROM public.evento_base e
 WHERE e.usuario_id=p_user_id AND jsonb_typeof(p_event)='object'
 AND p_event->>'source'='legacy_fix86' AND p_event->>'source_ref'='evento_base:'||e.idx::text
 AND public.lts_v178_norm(e.dados->>'desc')='visa aeternum'
 AND public.lts_v178_norm(p_event->>'description')='visa aeternum'
 AND public.lts_v178_norm(e.dados->>'conta')='bradesco' AND p_event->>'account'='Bradesco'
 AND e.dados->>'efeito'='saida' AND e.dados->>'dia'=p_event->>'event_date'
 AND e.dados->>'dia'~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 AND CASE WHEN e.dados->>'valor'~'^[0-9]+([.][0-9]+)?$'AND p_event->>'signed_amount'~'^-[0-9]+([.][0-9]+)?$'
 THEN(e.dados->>'valor')::numeric>0 AND(e.dados->>'valor')::numeric=-(p_event->>'signed_amount')::numeric ELSE false END
 AND coalesce(p_event->'internal_transfer','false'::jsonb)IN('false'::jsonb,'null'::jsonb)
 AND NOT EXISTS(SELECT 1 FROM public.evento_base other WHERE other.usuario_id=e.usuario_id AND other.idx<>e.idx
  AND other.dados->>'dia'=e.dados->>'dia' AND other.dados->>'efeito'='saida'
  AND public.lts_v178_norm(other.dados->>'desc')='visa aeternum'
  AND public.lts_v178_norm(other.dados->>'conta')='bradesco')
), candidates AS MATERIALIZED(
 SELECT jsonb_build_object('staging_id',pay.id,'projection_ref','evento_base:'||e.idx::text,
  'projection_date',l.expected_due_date,'description',e.dados->>'desc','series_key','card_aeternum',
  'direction','expense','actual_date',pay.posting_date,'actual_amount',pay.signed_amount,
  'projection_amount',(e.dados->>'valor')::numeric,'invoice_source_id',inv.id,
  'basis','reviewed_aeternum_legacy_cycle_and_posted_full_payment_v375')j
 FROM owned_plan e
 JOIN public.lts_card_documentary_payment_link_v272 l ON l.user_id=p_user_id AND l.active AND l.expected_due_date::text=e.dados->>'dia'
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 WHERE l.institution_code='237' AND inv.institution_code='237' AND pay.institution_code='237'
 AND public.lts_card_family_v226(inv.normalized_payload->>'card_name',inv.institution_name)='aeternum'
 AND pay.posting_date<=p_as_of AND l.expected_due_date<=p_as_of
 AND c.payload->>'coverage_mode'='card_bank_closed_complete'
 AND jsonb_typeof(c.payload->'consumption_manifest')='array'
 AND jsonb_array_length(c.payload->'consumption_manifest')>0
 AND public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,p_as_of)IS NOT NULL
)
SELECT CASE WHEN count(*)=1 THEN jsonb_agg(j)->0 END FROM candidates;
$fn$;
REVOKE ALL ON FUNCTION lts_receipt_private_v375.legacy_aeternum_receipt(uuid,jsonb,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_receipt_private_v375.legacy_aeternum_receipt(uuid,jsonb,date) TO service_role;

DO $patch$
DECLARE definition text;restored text;changed boolean:=false;
 anchor text:=$old$), candidates AS (SELECT * FROM payroll UNION ALL SELECT * FROM cards), unambiguous AS ($old$;
BEGIN
 SELECT pg_get_functiondef('public.lts_recurring_receipt_identities_v303(uuid,date)'::regprocedure)INTO definition;
 IF strpos(definition,'/* v375-reviewed-aeternum-receipt */')=0 THEN
  IF md5(definition)<>'acf90fee46a4f1c4a24ab1d8ec8448c2'OR strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'V375 recurring identity reader changed';END IF;
  restored:=replace(definition,anchor,$new$), aeternum AS MATERIALIZED (
 /* v375-reviewed-aeternum-receipt */
 SELECT(receipt->>'staging_id')::uuid,receipt->>'projection_ref',(receipt->>'projection_date')::date,
 receipt->>'description',receipt->>'series_key',receipt->>'direction',(receipt->>'actual_date')::date,
 (receipt->>'actual_amount')::numeric,receipt->>'basis'
 FROM public.evento_base e
 CROSS JOIN LATERAL(SELECT lts_receipt_private_v375.legacy_aeternum_receipt(p_user_id,jsonb_build_object(
  'source','legacy_fix86','source_ref','evento_base:'||e.idx::text,'description',e.dados->>'desc',
  'account','Bradesco','event_date',e.dados->>'dia','signed_amount',CASE WHEN e.dados->>'valor'~'^[0-9]+([.][0-9]+)?$'THEN-(e.dados->>'valor')::numeric END,
  'internal_transfer',false),p_as_of)receipt OFFSET 0)proof
 WHERE e.usuario_id=p_user_id AND public.lts_v178_norm(e.dados->>'desc')='visa aeternum'
 AND e.dados->>'dia'>=date_trunc('month',p_as_of)::date::text AND e.dados->>'dia'<=p_as_of::text
 AND receipt IS NOT NULL AND(receipt->>'actual_date')::date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of
), candidates AS (SELECT * FROM payroll UNION ALL SELECT * FROM cards UNION ALL SELECT * FROM aeternum), unambiguous AS ($new$);
  IF restored=definition THEN RAISE EXCEPTION 'V375 recurring patch not applied';END IF;
  EXECUTE restored;changed:=true;
 END IF;
 SELECT pg_get_functiondef('public.lts_pending_projections_v233(uuid)'::regprocedure)INTO definition;
 IF strpos(definition,'/* v375-reviewed-aeternum-pending */')=0 THEN
  IF md5(definition)<>'36e3321d535eb10a5e04a376d635a2a6'OR strpos(definition,'AND NOT public.lts_legacy_mastercard_settled_v291(p_user_id,c.x)')=0 THEN RAISE EXCEPTION 'V375 pending projection reader changed';END IF;
  restored:=replace(definition,'AND NOT public.lts_legacy_mastercard_settled_v291(p_user_id,c.x)',
   'AND NOT public.lts_legacy_mastercard_settled_v291(p_user_id,c.x)'||chr(10)||
   '/* v375-reviewed-aeternum-pending */ AND lts_receipt_private_v375.legacy_aeternum_receipt(p_user_id,c.x,current_date) IS NULL');
  EXECUTE restored;changed:=true;
 END IF;
 IF changed THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;END IF;
END $patch$;
