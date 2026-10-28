-- Receipt facts are suggestions only. No mailbox integration or classification decision.
CREATE FUNCTION public.lts_card_suggestion_evidence_v367(p_user_id uuid,p_source_ref text,p_prior jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT coalesce((SELECT jsonb_build_object('category',c.category,'beneficiary',NULL,'property_code',NULL,
 'basis',a.details->>'basis','confidence',a.details->>'confidence','requires_confirmation',true,
 'note',a.details->>'note','evidence',a.details->'evidence')
 FROM public.audit_log a JOIN public.lts_open_finance_staging s ON s.user_id=a.user_id AND s.id::text=a.entity_id
 JOIN public.lts_category_catalog c ON c.user_id=a.user_id AND c.active AND c.category=a.details->>'category'
 WHERE a.user_id=p_user_id AND a.entity_type='card_transaction' AND a.action='classification_evidence_v367'
 AND a.entity_id=p_source_ref AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
 AND a.id=(SELECT max(latest.id) FROM public.audit_log latest WHERE latest.user_id=p_user_id AND latest.entity_type='card_transaction' AND latest.action='classification_evidence_v367' AND latest.entity_id=p_source_ref)
 AND a.details->>'expected_raw_hash'=s.raw_hash
 AND a.details->>'basis' IN('documentary_receipt','public_mcc_reference')
 AND a.details->>'confidence' IN('moderate','limited') AND a.details->>'active'='true'
 AND length(a.details->>'note') BETWEEN 10 AND 1500
 ORDER BY a.id DESC LIMIT 1),p_prior);
$$;
REVOKE ALL ON FUNCTION public.lts_card_suggestion_evidence_v367(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;

DO $$
DECLARE definition text;BEGIN
 definition:=pg_get_functiondef('public.lts_card_review_suggestions_v312(uuid,jsonb)'::regprocedure);
 IF md5(definition)<>'1960751e64de825dd72498a66c97712d' THEN RAISE EXCEPTION 'Card suggestion source changed; inspect before applying';END IF;
 IF strpos(definition,'SELECT c.source_ref,jsonb_build_object(')=0 OR strpos(definition,'FROM choices c')=0 THEN RAISE EXCEPTION 'Suggestion expression missing';END IF;
 definition:=replace(definition,'SELECT c.source_ref,jsonb_build_object(','SELECT c.source_ref,public.lts_card_suggestion_evidence_v367(p_user_id,c.source_ref,jsonb_build_object(');
 definition:=replace(definition,'FROM choices c',') FROM choices c');
 EXECUTE definition;
END $$;
