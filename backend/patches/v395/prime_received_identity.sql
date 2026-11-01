-- Retain received Prime card identity when no promoted card_invoices row exists.
-- The amount still comes from current non-payment card rows; an explicit day rule
-- is required, and current received bills retain precedence. No source is promoted.
DO $patch$
DECLARE d text:=pg_get_functiondef('public.lts_card_projection_rows_v290(uuid)'::regprocedure);
 old_part text:=$old$FROM grouped g JOIN LATERAL(SELECT i.card_name FROM public.card_invoices i
 WHERE i.user_id=p_user_id AND public.lts_card_family_v226(i.card_name,i.card_name)=g.family
 ORDER BY i.reference_month DESC,i.due_date DESC LIMIT 1)ci ON true$old$;
 new_part text:=$new$FROM grouped g JOIN LATERAL(
 SELECT candidates.card_name FROM(
  SELECT i.card_name,0 priority,i.due_date
  FROM public.card_invoices i
  WHERE i.user_id=p_user_id AND public.lts_card_family_v226(i.card_name,i.card_name)=g.family
  UNION ALL
  SELECT s.normalized_payload->>'card_name',1,
   CASE WHEN pg_input_is_valid(s.normalized_payload->>'due_date','date')
    THEN(s.normalized_payload->>'due_date')::date END
  FROM public.lts_open_finance_staging s
  WHERE g.family='bradesco_prime' AND s.user_id=p_user_id
   AND s.resource_type='invoice' AND s.institution_code='237' AND s.currency='BRL'
   AND s.provider_deleted_at IS NULL AND nullif(s.provider_account_ref,'') IS NOT NULL
   AND public.lts_card_family_v226(s.normalized_payload->>'card_name',s.normalized_payload->>'card_name')=g.family
   AND CASE WHEN pg_input_is_valid(s.normalized_payload->>'due_date','date')
    THEN(s.normalized_payload->>'due_date')::date<=current_date ELSE false END
   AND EXISTS(SELECT 1 FROM rows r JOIN public.lts_open_finance_staging t
    ON t.id=r.source_id AND t.user_id=p_user_id AND t.resource_type='card_transaction'
     AND t.institution_code='237' AND t.currency='BRL' AND t.provider_deleted_at IS NULL
    WHERE r.family=g.family AND r.reference_month=g.reference_month AND r.bank='Bradesco'
     AND t.provider_account_ref=s.provider_account_ref)
 )candidates ORDER BY candidates.priority,candidates.due_date DESC NULLS LAST,candidates.card_name LIMIT 1
)ci ON true$new$;
BEGIN
 IF position(new_part IN d)>0 THEN RETURN;END IF;
 IF md5(d)<>'bfa2be163823e710c2af7b3e6079e34a' OR position(old_part IN d)=0
 THEN RAISE EXCEPTION 'Card projection source changed';END IF;
 EXECUTE replace(d,old_part,new_part);
END $patch$;

