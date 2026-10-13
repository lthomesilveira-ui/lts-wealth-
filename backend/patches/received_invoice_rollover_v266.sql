-- Preserve the last received bill after its due date while its matching
-- recorded cycle is still open/projected. Crossing midnight does not prove
-- payment and must not revive an older snapshot or lose received composition.
DO $patch$
DECLARE d text; prior_acl aclitem[]; target regprocedure;
BEGIN
 FOR target IN SELECT unnest(ARRAY[
  'public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure,
  'public.lts_card_cycles_v226(uuid)'::regprocedure
 ]) LOOP
  SELECT pg_get_functiondef(target),proacl INTO d,prior_acl FROM pg_proc WHERE oid=target;
  IF md5(d)<>(CASE WHEN target='public.lts_card_cycles_v226(uuid)'::regprocedure
   THEN '5c7b96cc0f57d5d4fa98e3a572d6cffd'
   ELSE '465781f4ab7dd439aaef7b8098cbad57' END)
   THEN RAISE EXCEPTION 'received bill definition lease changed: %',target; END IF;
  IF (length(d)-length(replace(d,$old$WHERE b.due_date>=current_date
 AND NOT EXISTS$old$,'')))/length($old$WHERE b.due_date>=current_date
 AND NOT EXISTS$old$)<>1 THEN RAISE EXCEPTION 'unique eligibility anchor missing: %',target; END IF;
  d:=replace(d,$old$WHERE b.due_date>=current_date
 AND NOT EXISTS$old$,$new$WHERE (b.due_date>=current_date OR EXISTS(
 SELECT 1 FROM public.card_invoices open_cycle
 WHERE open_cycle.user_id=p_user_id
 AND open_cycle.status IN('open','projected')
 AND open_cycle.reference_month=b.reference_month
 AND open_cycle.due_date=b.due_date
 AND public.lts_card_family_v226(open_cycle.card_name,open_cycle.card_name)=b.family))
 AND NOT EXISTS$new$);
  EXECUTE d;
  IF (SELECT proacl FROM pg_proc WHERE oid=target) IS DISTINCT FROM prior_acl
   THEN RAISE EXCEPTION 'received bill ACL changed: %',target; END IF;
  IF has_function_privilege('anon',target,'EXECUTE') OR has_function_privilege('authenticated',target,'EXECUTE')
   THEN RAISE EXCEPTION 'received bill helper exposed: %',target; END IF;
 END LOOP;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END;
$patch$;
