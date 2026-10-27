-- The reviewed contract already pins both source UUIDs. Look them up by key.
-- Keep the original documentary validator and canonical card-document policy.
DO $patch$
DECLARE target regprocedure:='public.lts_previously_proved_transfer_pairs_v363(uuid)'::regprocedure;
 definition text;attributes jsonb;original text;
 old_part text:=$old$), posted AS MATERIALIZED(
 SELECT * FROM public.lts_bank_posted_rows_v231(p_user_id)
), eligible AS MATERIALIZED(
 SELECT d.id debit_id,c.id credit_id
 FROM proofs e
 JOIN posted d ON d.id::text=e.metadata->>'debit_id'
 JOIN posted c ON c.id::text=e.metadata->>'credit_id'$old$;
 new_part text:=$new$), eligible AS MATERIALIZED(
 SELECT d.id debit_id,c.id credit_id
 FROM proofs e
 JOIN public.lts_open_finance_staging d ON d.id=CASE WHEN e.metadata->>'debit_id'~'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'THEN(e.metadata->>'debit_id')::uuid END AND d.user_id=p_user_id
 JOIN public.lts_open_finance_staging c ON c.id=CASE WHEN e.metadata->>'credit_id'~'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'THEN(e.metadata->>'credit_id')::uuid END AND c.user_id=p_user_id$new$;
 old_check text:=$old$ AND public.lts_transfer_refresh_valid_v363(p_user_id,to_jsonb(d),to_jsonb(c),to_jsonb(old),to_jsonb(a),to_jsonb(o),to_jsonb(t),to_jsonb(ob),to_jsonb(tb),to_jsonb(e))$old$;
 new_check text:=$new$ AND CASE WHEN d.normalized_payload->>'operation_type'='CARTAO'AND d.description_raw~*' - DOCTO: [0-9]+$'
 THEN EXISTS(SELECT 1 FROM public.lts_bank_posted_rows_v231(p_user_id)chosen WHERE chosen.id=d.id)ELSE true END
 AND CASE WHEN c.normalized_payload->>'operation_type'='CARTAO'AND c.description_raw~*' - DOCTO: [0-9]+$'
 THEN EXISTS(SELECT 1 FROM public.lts_bank_posted_rows_v231(p_user_id)chosen WHERE chosen.id=c.id)ELSE true END
 AND public.lts_transfer_refresh_valid_v363(p_user_id,to_jsonb(d),to_jsonb(c),to_jsonb(old),to_jsonb(a),to_jsonb(o),to_jsonb(t),to_jsonb(ob),to_jsonb(tb),to_jsonb(e))$new$;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc'INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF strpos(definition,new_part)>0 THEN
  original:=replace(replace(definition,new_part,old_part),new_check,old_check);
  IF md5(original)<>'6d381f4964ee2e33ec38e79f0c170f93'THEN RAISE EXCEPTION 'V364_REPLAY_SOURCE_CHANGED';END IF;
  RETURN;
 END IF;
 IF md5(definition)<>'6d381f4964ee2e33ec38e79f0c170f93'
 OR(length(definition)-length(replace(definition,old_part,'')))/length(old_part)<>1
 OR(length(definition)-length(replace(definition,old_check,'')))/length(old_check)<>1
 THEN RAISE EXCEPTION 'V364_LOOKUP_SOURCE_CHANGED';END IF;
 EXECUTE replace(replace(definition,old_part,new_part),old_check,new_check);
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid=target)THEN RAISE EXCEPTION 'V364_LOOKUP_ATTRIBUTES_CHANGED';END IF;
END $patch$;
