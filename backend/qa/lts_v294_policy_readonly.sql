-- Administrative QA for the authorized owner; set lts.qa_user_id explicitly.
BEGIN READ ONLY;
SET LOCAL timezone='America/Sao_Paulo';
WITH rows AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows(current_setting('lts.qa_user_id')::uuid,'2013-10-10',current_date)),
receipt AS(SELECT details FROM public.audit_log WHERE user_id=current_setting('lts.qa_user_id')::uuid
 AND action='supersede_implicit_owner_beneficiaries' AND entity_id='no_implicit_person_v294'),
superseded AS(SELECT d.* FROM public.lts_v178_review_decision d WHERE d.user_id=current_setting('lts.qa_user_id')::uuid
 AND d.decision_basis LIKE 'no_implicit_beneficiary_v294; supersedes automatic policy: user_owner_default_2026_09_22%')
SELECT jsonb_build_object(
 'rows',(SELECT count(*) FROM rows),'duplicate_keys',(SELECT count(*)-count(DISTINCT row_key) FROM rows),
 'null_categories',(SELECT count(*) FROM rows WHERE nullif(trim(category),'') IS NULL),
 'pending_classifications',(SELECT count(*) FROM rows WHERE identity_status='pending'),
 'receipt_count',(SELECT count(*) FROM receipt),
 'superseded_decisions',(SELECT count(*) FROM superseded),
 'superseded_decisions_still_named',(SELECT count(*) FROM superseded WHERE beneficiary IS NOT NULL),
 'superseded_expenses_still_named',(SELECT count(*) FROM rows r JOIN superseded d USING(source_table,source_ref) WHERE r.beneficiary IS NOT NULL),
 'original_decisions_preserved',(SELECT coalesce(bool_and(jsonb_array_length(details->'original_decisions')=(details->>'updated_decisions')::int),false) FROM receipt)
) verification;
ROLLBACK;
