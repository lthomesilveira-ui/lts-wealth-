-- Preserve user-created category choices through canonical cache refreshes.
-- No financial source, amount, date, or account position is changed.
DO $patch$
DECLARE definition text; needle text; replacement text;
BEGIN
 definition:=pg_get_functiondef('public.lts_browser_card_category_options_v226()'::regprocedure);
 needle:=' )q;';
 replacement:=' UNION'||chr(10)||
  ' SELECT DISTINCT CASE WHEN public.lts_v178_norm(t.category) IN (''organon'',''organon despesas'',''despesas organon'') THEN public.lts_canonical_category_v1(u,t.category) ELSE t.category END FROM public.lts_category_catalog t'||chr(10)||
  ' WHERE t.user_id=u AND t.active AND public.lts_v178_norm(t.category) NOT IN (''a classificar'',''nao identificado'',''sem categoria'')'||chr(10)||needle;
 IF strpos(definition,'t.active AND public.lts_v178_norm(t.category)')=0 THEN
  IF (length(definition)-length(replace(definition,needle,'')))/length(needle)<>1 THEN
   RAISE EXCEPTION 'unexpected category options integration point';
  END IF;
  EXECUTE replace(definition,needle,replacement);
 END IF;

 definition:=pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure);
 needle:='  ) and not exists ('||chr(10)||'    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,current_date) r';
 replacement:='  ) and not exists ('||chr(10)||
  '    select 1 from public.lts_category_catalog allowed_category'||chr(10)||
  '    where allowed_category.user_id=v_uid and allowed_category.active and allowed_category.category=v_category'||chr(10)||
  needle;
 IF strpos(definition,'allowed_category')=0 THEN
  IF (length(definition)-length(replace(definition,needle,'')))/length(needle)<>1 THEN
   RAISE EXCEPTION 'unexpected review category allowlist integration point';
  END IF;
  EXECUTE replace(definition,needle,replacement);
 END IF;

 definition:=pg_get_functiondef('public.lts_apply_current_liquidity_anchor_v1(uuid)'::regprocedure);
 needle:='''card_classification_review'',jsonb_build_object(''version'',''canonical-review-v229''';
 replacement:='''card_classification_review'',jsonb_build_object(''category_options'',coalesce(c.payload#>''{card_classification_review,category_options}'',''[]''::jsonb),''version'',''canonical-review-v229''';
 IF strpos(definition,'''category_options'',coalesce(c.payload#>')=0 THEN
  IF (length(definition)-length(replace(definition,needle,'')))/length(needle)<>1 THEN
   RAISE EXCEPTION 'unexpected classification cache integration point';
  END IF;
  EXECUTE replace(definition,needle,replacement);
 END IF;
END $patch$;
