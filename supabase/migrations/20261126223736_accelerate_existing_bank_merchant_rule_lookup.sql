-- Index the existing normalized merchant lookup. Prefix rules still match
-- against the full bank description and use the existing classification priority.
CREATE INDEX IF NOT EXISTS lts_semantic_rule_active_merchant_key
  ON public.lts_semantic_rule (user_id, public.lts_bank_merchant_key_v231(match_value))
  WHERE active AND match_type IN ('exact','prefix')
    AND confidence IN ('user_confirmed','high','alta','system_high');

DO $migration$
DECLARE
 definition text:=pg_get_functiondef('public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure);
 previous text:=$old$FROM public.lts_semantic_rule r CROSS JOIN target t WHERE r.user_id=p_user_id AND r.active
   AND r.confidence IN ('user_confirmed','high','alta','system_high')
   AND (lower(btrim(coalesce(r.semantic_nature,''))) NOT IN('income','receita','entrada') OR t.signed_amount>0)
   AND ((r.match_type IN ('exact','prefix') AND public.lts_bank_merchant_key_v231(r.match_value)=t.merchant_key)
    OR (r.match_type='prefix' AND starts_with(t.normalized_description,public.lts_v178_norm(r.match_value))))$old$;
 replacement text:=$new$FROM target t
  CROSS JOIN LATERAL (
   SELECT rule.id,rule.category,rule.center_cost,rule.confidence,rule.semantic_nature
   FROM public.lts_semantic_rule rule
   WHERE rule.user_id=p_user_id AND rule.active
    AND rule.confidence IN ('user_confirmed','high','alta','system_high')
    AND rule.match_type IN ('exact','prefix')
    AND public.lts_bank_merchant_key_v231(rule.match_value)=t.merchant_key
   UNION
   SELECT rule.id,rule.category,rule.center_cost,rule.confidence,rule.semantic_nature
   FROM public.lts_semantic_rule rule
   WHERE rule.user_id=p_user_id AND rule.active
    AND rule.confidence IN ('user_confirmed','high','alta','system_high')
    AND rule.match_type='prefix'
    AND starts_with(t.normalized_description,public.lts_v178_norm(rule.match_value))
  ) r
  WHERE lower(btrim(coalesce(r.semantic_nature,''))) NOT IN('income','receita','entrada') OR t.signed_amount>0$new$;
BEGIN
 IF strpos(definition,replacement)>0 THEN RETURN; END IF;
 IF strpos(definition,previous)=0 THEN RAISE EXCEPTION 'Unexpected classification query'; END IF;
 EXECUTE replace(definition,previous,replacement);
END
$migration$;
