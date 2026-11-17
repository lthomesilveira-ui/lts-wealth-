CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.card_source_key(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE fingerprint text; epoch bigint;
BEGIN
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true;
 -- Keep every semantic source field, including receipt and deletion evidence.
 -- Match V246: sync_run_id, last_seen_at and updated_at are bookkeeping only.
 -- Settlement links/contracts are also hashed because they have no epoch trigger.
 SELECT 'v307-card-state:'||epoch||':'||md5(
  coalesce((SELECT string_agg((to_jsonb(s)-ARRAY['sync_run_id','last_seen_at','updated_at'])::text,'' ORDER BY s.id)
   FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(i)::text,'' ORDER BY i.id)
   FROM public.card_invoices i WHERE i.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(d)::text,'' ORDER BY d.id)
   FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(l)::text,'' ORDER BY l.id)
   FROM public.lts_card_documentary_payment_link_v272 l WHERE l.user_id=p_user_id),'')
  ||coalesce((SELECT string_agg(to_jsonb(c)::text,'' ORDER BY c.payment_source_id)
   FROM public.lts_card_settlement_expense_contract_v273 c WHERE c.user_id=p_user_id),'')
 ) INTO fingerprint;

 RETURN fingerprint;
END $function$;
