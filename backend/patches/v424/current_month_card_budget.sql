-- Opt-in owner policy: known amounts only for current-month card due dates.
-- No source financial records, existing obligations, grants or schedules change.
BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='8s';
DO $patch$
DECLARE original text; baseline text; updated text; attrs jsonb;
 validate_anchor text:=$v$ IF p_as_of IS NULL OR NOT pg_catalog.isfinite(p_as_of)$v$;
 validation text:=$v$ IF p_policy ? 'current_month_card_budget'
  AND p_policy->>'current_month_card_budget' IS DISTINCT FROM 'known_only' THEN
  RAISE EXCEPTION 'A regra do orçamento de cartões precisa ser conferida.';
 END IF;
$v$;
 slot_anchor text:=$s$   target:=NULL;$s$;
 slot_rule text:=$s$   -- Keep confirmed/known obligations; never fill the current due month
   -- to a spending average. Future months retain the approved scoped budgets.
   IF method='history_total_budget' AND r->>'source_kind'='card_invoice'
    AND p_policy->>'current_month_card_budget'='known_only'
    AND date_trunc('month',effective_date::timestamp)=date_trunc('month',p_as_of::timestamp) THEN
    skipped:=skipped+1;
    results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'budget_total_brl',known,'additional_brl',0,'known_amount_brl',known,
     'basis','current_month_known_only'));
    CONTINUE;
   END IF;
$s$;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO original,attrs
 FROM pg_proc p WHERE oid='lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'::regprocedure;
 baseline:=replace(replace(original,validation,''),slot_rule,'');
 IF md5(baseline)<>'452a922083bf29ab6209dffcf679e66b'
  OR (length(baseline)-length(replace(baseline,validate_anchor,'')))/length(validate_anchor)<>1
  OR (length(baseline)-length(replace(baseline,slot_anchor,'')))/length(slot_anchor)<>1 THEN
  RAISE EXCEPTION 'Unexpected projection predecessor; review before applying';
 END IF;
 updated:=replace(replace(baseline,validate_anchor,validation||validate_anchor),slot_anchor,slot_rule||slot_anchor);
 IF updated IS DISTINCT FROM original THEN EXECUTE updated;END IF;
 IF attrs IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p
   WHERE oid='lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)'::regprocedure) THEN
  RAISE EXCEPTION 'Unexpected projection attributes, owner or privileges';
 END IF;
END $patch$;
COMMIT;
