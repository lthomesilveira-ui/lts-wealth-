CREATE FUNCTION public.lts_bank_description_key_v229(p_text text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT regexp_replace(public.lts_v178_norm(p_text),'^pagamento de seguro[[:space:]]+','','i')
$$;
REVOKE ALL ON FUNCTION public.lts_bank_description_key_v229(text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_bank_description_key_v229(text) TO authenticated,service_role;
DO $$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('public.lts_v229_new_bank_rows(uuid,date,date)'::regprocedure);
 definition:=replace(definition,'''user_confirmed'',''high'',''alta''','''user_confirmed'',''high'',''alta'',''system_high''');
 definition:=replace(definition,'public.lts_v178_norm(s.description_raw)','public.lts_bank_description_key_v229(s.description_raw)');
 EXECUTE definition;
 definition:=pg_get_functiondef('public.lts_flow_review_overlay_v229(uuid,jsonb)'::regprocedure);
 definition:=replace(definition,'d.source_ref IS NULL THEN','d.source_ref IS NULL AND n.id IS NULL THEN');
 definition:=replace(definition,'coalesce(d.category_label,e->>''category'')','coalesce(d.category_label,n.category,e->>''category'')');
 definition:=replace(definition,'''classification_confirmed'',true','''classification_confirmed'',d.source_ref IS NOT NULL OR n.category<>''A classificar''');
 definition:=replace(definition,'LEFT JOIN public.lts_v178_review_decision d ON',
 'LEFT JOIN public.lts_v229_new_bank_rows(p_user_id,current_date-30,current_date) n ON n.id::text=e->>''open_finance_id'' LEFT JOIN public.lts_v178_review_decision d ON');
 EXECUTE definition;
END $$;
