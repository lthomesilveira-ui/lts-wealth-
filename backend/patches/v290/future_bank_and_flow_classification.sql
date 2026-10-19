CREATE OR REPLACE FUNCTION public.lts_browser_future_bank_v290(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1();
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>730 THEN RAISE EXCEPTION 'Período inválido.'; END IF;
 RETURN jsonb_build_object('version','future-bank-v290','from',p_from,'to',p_to,'consulted_at',clock_timestamp(),
 'rows',(SELECT coalesce(jsonb_agg(jsonb_build_object('source_id',s.id,'date',s.posting_date,
 'bank',CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END,
 'description',s.description_raw,'amount',s.signed_amount,'status','scheduled',
 'received_at',s.last_seen_at,'source_updated_at',s.normalized_payload->>'provider_updated_at',
 'included_in_realized',false,'included_in_flow_totals',false,'link_status','review_required')
 ORDER BY s.posting_date,s.id),'[]') FROM public.lts_open_finance_staging s
 WHERE s.user_id=u AND s.provider_deleted_at IS NULL AND s.currency='BRL'
 AND s.resource_type='transaction' AND s.institution_code IN('341','237','336')
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND s.normalized_payload->>'status'='PENDING'
 AND s.posting_date>current_date AND s.posting_date BETWEEN p_from AND p_to),
 'card_future_received',(SELECT count(*) FROM public.lts_open_finance_staging s WHERE s.user_id=u
 AND s.provider_deleted_at IS NULL AND s.resource_type='card_transaction' AND s.currency='BRL'
 AND s.normalized_payload->>'status'='PENDING' AND s.posting_date>current_date AND s.posting_date BETWEEN p_from AND p_to),
 'cash_effect','none_until_obligation_linked','source_limitation','An absent schedule means it was not received; bank availability is not inferred');
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_future_bank_v290(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_future_bank_v290(date,date) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_flow_classification_v290(
 p_source text,p_source_ref text,p_event_date date,p_category text,p_beneficiary text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); cat text:=public.lts_category_name_v290(u,p_category);
 st text; ref text; before_value jsonb; person text:=nullif(trim(p_beneficiary),''); sid uuid; found_target boolean:=false;
BEGIN
 IF p_event_date IS NULL OR p_event_date<date '2013-10-10' OR p_event_date>current_date+7300
 OR p_source_ref IS NULL OR length(p_source_ref)>180 THEN RAISE EXCEPTION 'Lançamento inválido.'; END IF;
 IF person IS NOT NULL AND person NOT IN('Lucas','Larissa','Benjamin','Rafiki') THEN RAISE EXCEPTION 'Pessoa inválida.'; END IF;
 IF cat IS NULL OR NOT EXISTS(SELECT 1 FROM public.lts_category_catalog WHERE user_id=u AND category=cat AND active)
 THEN RAISE EXCEPTION 'Escolha uma classificação do cadastro.'; END IF;
 ref:=regexp_replace(p_source_ref,'^(open_finance:|lts_open_finance_staging:)','');
 IF ref ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
  SELECT id INTO sid FROM public.lts_open_finance_staging WHERE user_id=u AND id=ref::uuid
  AND posting_date=p_event_date AND provider_deleted_at IS NULL AND resource_type='transaction'
  AND currency='BRL' AND signed_amount<0 AND normalized_payload->>'account_type'='CHECKING_ACCOUNT';
  IF FOUND THEN
   IF EXISTS(SELECT 1 FROM public.lts_card_settlement_expense_contract_v273 WHERE user_id=u AND payment_source_id=sid AND active)
   THEN RAISE EXCEPTION 'O pagamento da fatura não é uma segunda despesa. Classifique as compras do cartão.'; END IF;
   st:='lts_open_finance_staging';ref:=sid::text;found_target:=true;
  END IF;
 END IF;
 IF NOT found_target AND p_source IN('current_event','financial_events','confirmed_fact') THEN
  PERFORM 1 FROM public.financial_events WHERE user_id=u AND event_date=p_event_date
   AND p_source_ref IN(id::text,legacy_id,'financial_events:'||id::text)
   AND amount<0 AND NOT is_internal_transfer AND NOT is_suppressed;
  IF FOUND THEN st:=CASE WHEN p_source='current_event' THEN 'daily_flow_documentary_bridge' ELSE p_source END;
   ref:=p_source_ref;found_target:=true; END IF;
 END IF;
 IF NOT found_target AND p_source='legacy_fix86' AND p_source_ref ~ '^evento_base:[0-9]+$' THEN
  PERFORM 1 FROM public.evento_base WHERE usuario_id=u AND idx::text=split_part(p_source_ref,':',2)
   AND dados->>'dia'=p_event_date::text AND dados->>'efeito'='saida'
   AND public.lts_card_family_key_v181(dados->>'desc',dados->>'conta') IS NULL;
  IF FOUND THEN st:='evento_base';ref:=split_part(p_source_ref,':',2);found_target:=true; END IF;
 END IF;
 IF NOT found_target THEN RAISE EXCEPTION 'Não foi possível classificar este lançamento. Abra a composição ou tente novamente.'; END IF;
 SELECT to_jsonb(d) INTO before_value FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table=st AND d.source_ref=ref;
 INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
 VALUES(u,st,ref,cat,person,'authenticated_flow_v290')
 ON CONFLICT(user_id,source_table,source_ref) DO UPDATE SET category_label=excluded.category_label,
 beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),decision_basis=excluded.decision_basis,decided_at=now();
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,lower(coalesce(auth.jwt()->>'email','')),
 'flow_classification_v290',jsonb_build_object('source_table',st,'source_ref',ref,'date',p_event_date,
 'before',before_value,'after',jsonb_build_object('category',cat,'beneficiary',person),'financial_effect','none'));
 RETURN jsonb_build_object('ok',true,'category',cat,'source_table',st,'source_ref',ref);
END $f$;
REVOKE ALL ON FUNCTION public.lts_browser_flow_classification_v290(text,text,date,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_classification_v290(text,text,date,text,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.lts_flow_classifications_v290(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE section text; events jsonb;
BEGIN
 FOREACH section IN ARRAY ARRAY['historical','current_future'] LOOP
  IF jsonb_typeof(p_payload#>ARRAY['flow',section,'events'])='array' THEN
   SELECT coalesce(jsonb_agg(public.lts_flow_classification_decision_v1(p_user_id,x.value) ORDER BY ord),'[]')
   INTO events FROM jsonb_array_elements(p_payload#>ARRAY['flow',section,'events']) WITH ORDINALITY x(value,ord);
   p_payload:=jsonb_set(p_payload,ARRAY['flow',section,'events'],events,false);
  END IF;
 END LOOP;
 RETURN p_payload;
END $f$;
REVOKE ALL ON FUNCTION public.lts_flow_classifications_v290(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_classifications_v290(uuid,jsonb) TO service_role;
DO $flow$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_browser_flow_v242(date,date)'::regprocedure) INTO d;
 IF md5(d)<>'467607552e2d0783206ddc5ef197fec6'
 THEN RAISE EXCEPTION 'V290 flow presentation source changed'; END IF;
 d:=replace(d,'public.lts_flow_card_completeness_v269(public.lts_flow_slice_v242(cached,p_from,p_to),public.lts_card_cycles_v226(u))',
 'public.lts_flow_classifications_v290(u,public.lts_flow_card_completeness_v269(public.lts_flow_slice_v242(cached,p_from,p_to),public.lts_card_cycles_v226(u)))');
 d:=replace(d,'public.lts_flow_card_completeness_v269(j,public.lts_card_cycles_v226(u))',
 'public.lts_flow_classifications_v290(u,public.lts_flow_card_completeness_v269(j,public.lts_card_cycles_v226(u)))');
 EXECUTE d;
END $flow$;
