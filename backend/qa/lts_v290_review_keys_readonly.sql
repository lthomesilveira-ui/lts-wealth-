-- Real review inputs reproduce the public queue's question-kind policy.
WITH pending AS MATERIALIZED(
 SELECT to_jsonb(r)||jsonb_build_object('question_kind',CASE
 WHEN r.beneficiary IS NULL AND r.category ~* 'saúde|saude|educa|vestu' THEN 'person'
 WHEN r.management_group='Moradia — imóvel a confirmar' THEN 'property'
 WHEN r.property_component='A revisar' THEN 'property_purpose' ELSE 'classification' END)j
 FROM public.lts_v229_review_rows(current_setting('lts.qa_user_id')::uuid,date '2013-10-10',current_date)r
 WHERE r.identity_status='pending'
), targets AS MATERIALIZED(SELECT coalesce(jsonb_agg(j),'[]')j FROM pending),
a AS MATERIALIZED(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.source_table,s.source_ref),'[]')j
 FROM targets CROSS JOIN LATERAL public.lts_review_suggestions_pre_keys_v290(current_setting('lts.qa_user_id')::uuid,targets.j)s),
b AS MATERIALIZED(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.source_table,s.source_ref),'[]')j
 FROM targets CROSS JOIN LATERAL public.lts_review_suggestions_v231(current_setting('lts.qa_user_id')::uuid,targets.j)s)
SELECT jsonb_build_object('targets',(SELECT count(*) FROM pending),'passed',a.j=b.j,'before_digest',md5(a.j::text),'after_digest',md5(b.j::text)) receipt FROM a,b;
