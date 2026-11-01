-- Reuse the owner's already canonical C6 invoice identity for derived cycles.
-- Provider labels remain unchanged in source data and in existing invoices.
DO $lease$
DECLARE original text:=pg_get_functiondef('public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure);
old_part text:=$old$ SELECT ca->>'name' card_name,cy FROM jsonb_array_elements(public.lts_prepared_card_cycles_v307(p_user_id)->'cards') ca$old$;
new_part text:=$new$ SELECT coalesce((SELECT i.card_name FROM public.card_invoices i
 WHERE i.user_id=p_user_id AND public.lts_card_family_v226(i.card_name,i.card_name)='c6'
 AND public.lts_forecast_series_key_v1('Fatura '||i.card_name)='card_c6'
 ORDER BY i.reference_month DESC,i.due_date DESC,i.id LIMIT 1),ca->>'name') card_name,cy
 FROM jsonb_array_elements(public.lts_prepared_card_cycles_v307(p_user_id)->'cards') ca$new$;
BEGIN
 IF md5(original)='5db62be42ab458431614f11172fb70bc' THEN RETURN;END IF;
 IF md5(original)<>'316bba0d2c608c0a11b77b3a76c8ef49' THEN RAISE EXCEPTION 'Invoice engine changed';END IF;
 IF position(old_part IN original)=0 THEN RAISE EXCEPTION 'Projection identity clause missing';END IF;
 EXECUTE replace(original,old_part,new_part);
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
END $lease$;
