-- A generic historical Mastercard plan can surface again after the calculation day changes.
-- Match its exact owned source row to the one issuer cycle with fully reviewed settlement proof.
CREATE OR REPLACE FUNCTION public.lts_legacy_mastercard_settled_v291(p_user_id uuid,p_event jsonb)
RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $f$
WITH owned_plan AS MATERIALIZED(
 SELECT e.idx FROM public.evento_base e
 WHERE e.usuario_id=p_user_id AND p_event->>'source'='legacy_fix86'
 AND p_event->>'source_ref'='evento_base:'||e.idx::text
 AND public.lts_v178_norm(e.dados->>'desc')='mastercard'
 AND public.lts_v178_norm(p_event->>'description')='mastercard'
 AND public.lts_v178_norm(e.dados->>'conta')='itau'
 AND p_event->>'account'='Itaú' AND e.dados->>'dia'=p_event->>'event_date'
 AND CASE WHEN e.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$' THEN abs((e.dados->>'valor')::numeric) END
   =abs((p_event->>'signed_amount')::numeric)
 AND (p_event->>'signed_amount')::numeric<0
 AND NOT coalesce((p_event->>'internal_transfer')::boolean,false)
), proved_cycles AS MATERIALIZED(
 SELECT DISTINCT l.invoice_source_id
 FROM owned_plan s CROSS JOIN public.lts_card_documentary_payment_link_v272 l
 JOIN public.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
 JOIN public.lts_open_finance_staging pay ON pay.user_id=l.user_id AND pay.id=l.payment_source_id
 JOIN public.lts_card_settlement_expense_contract_v273 c ON c.user_id=l.user_id AND c.payment_source_id=l.payment_source_id AND c.active
 WHERE l.user_id=p_user_id AND l.active AND inv.institution_code='341'
 AND public.lts_card_family_v226(inv.normalized_payload->>'card_name',inv.institution_name)='itau_mastercard'
 AND l.expected_due_date=(p_event->>'event_date')::date
 AND public.lts_card_payment_refresh_annotation_v273(p_user_id,to_jsonb(l),to_jsonb(inv),to_jsonb(pay),c.payload,current_date) IS NOT NULL
)
SELECT count(*)=1 FROM proved_cycles
$f$;
REVOKE ALL ON FUNCTION public.lts_legacy_mastercard_settled_v291(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_legacy_mastercard_settled_v291(uuid,jsonb) TO service_role;
DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_pending_projections_v233(uuid)'::regprocedure) INTO d;
 IF md5(d)<>'dea4807a77e366c54c4c6e7577036703' THEN RAISE EXCEPTION 'Pending obligation reader changed'; END IF;
 IF strpos(d,'AND NOT (c.x->>''source''=''card_invoice''')=0 THEN RAISE EXCEPTION 'Pending settlement anchor missing';END IF;
 d:=replace(d,'AND NOT (c.x->>''source''=''card_invoice''',
 'AND NOT public.lts_legacy_mastercard_settled_v291(p_user_id,c.x)'||chr(10)||'AND NOT (c.x->>''source''=''card_invoice''');
 EXECUTE d;
END $patch$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;

