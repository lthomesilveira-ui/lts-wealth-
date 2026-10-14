-- Generic review patch only. Production installation requires a separately reviewed transaction.
BEGIN;
CREATE OR REPLACE FUNCTION public.lts_flow_read_key_engine_v243(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$
SELECT md5(jsonb_build_object(
 'reader_revision','correlated-cash-and-calendar-coverage-v269-c6',
 'c6_invoice_composition',(SELECT md5(coalesce(jsonb_agg(to_jsonb(i) ORDER BY to_jsonb(i)::text)::text,'[]'))
  FROM public.lts_card_invoice_amounts_v230(p_user_id) i WHERE public.lts_card_family_v226(i.card_name,i.card_name)='c6'),
 'canonical',public.lts_dashboard_source_key_v240(p_user_id),
 'other_evidence',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM public.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.evidence_type NOT LIKE 'historical_workbook_cash%'),
 'user_events',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM public.evento_usuario e WHERE e.usuario_id=p_user_id),
 'displacements',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM public.deslocamento e WHERE e.usuario_id=p_user_id),
 'replacement_rules',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty'))
  FROM public.lts_projection_replacement_rule e WHERE e.user_id=p_user_id)
)::text)
$function$;
ROLLBACK;
