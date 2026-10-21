-- Administrator operation. Supply owner_id, expected_decisions and expected_visible
-- using lts.person_policy.* local settings. Run inside an explicit transaction;
-- use ROLLBACK for the first execution. No private IDs or financial rows are bundled.
DO $policy$
DECLARE
 u uuid:=current_setting('lts.person_policy.owner_id')::uuid;
 expected integer:=current_setting('lts.person_policy.expected_decisions')::integer;
 visible integer:=current_setting('lts.person_policy.expected_visible')::integer;
 originals jsonb;before_rows jsonb;after_rows jsonb;stable_before jsonb;stable_after jsonb;
 other_decisions_before jsonb;other_decisions_after jsonb;
 source_before text;source_after text;old_key text;new_key text;
 changed integer;remaining integer;originals_count integer;
BEGIN
 IF expected<=0 OR visible<=0 OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=u)
 THEN RAISE EXCEPTION 'Explicit owner and nonempty expected scope required';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.source_table,d.source_ref),'[]') INTO originals
 FROM(SELECT * FROM public.lts_v178_review_decision d WHERE d.user_id=u
 AND d.beneficiary='Lucas' AND d.category_label IS NULL
 AND d.decision_basis LIKE 'user_owner_default_2026_09_22%' FOR UPDATE)d;
 originals_count:=jsonb_array_length(originals);
 IF originals_count=0 THEN
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE user_id=u AND action='supersede_implicit_owner_beneficiaries'
   AND entity_type='expense_person_policy' AND entity_id='no_implicit_person_v294'
   AND details->>'version'='no-implicit-person-v294') THEN RETURN;END IF;
  RAISE EXCEPTION 'No eligible superseded default decisions';
 END IF;
 IF originals_count<>expected THEN RAISE EXCEPTION 'Legacy default decision count changed';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.row_key,to_jsonb(r)::text),'[]') INTO before_rows
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 IF (SELECT count(*) FROM jsonb_array_elements(before_rows)r WHERE EXISTS(
  SELECT 1 FROM jsonb_array_elements(originals)d WHERE d->>'source_table'=r->>'source_table'
  AND d->>'source_ref'=r->>'source_ref'))<>visible
 THEN RAISE EXCEPTION 'Visible default-decision scope changed';END IF;
 SELECT coalesce(jsonb_agg(r-'beneficiary'-'management_group'-'management_subgroup' ORDER BY r->>'row_key',r::text),'[]')
 INTO stable_before FROM jsonb_array_elements(before_rows)r;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.source_table,d.source_ref),'[]') INTO other_decisions_before
 FROM public.lts_v178_review_decision d WHERE d.user_id=u AND NOT EXISTS(
 SELECT 1 FROM jsonb_array_elements(originals)x WHERE x->>'source_table'=d.source_table AND x->>'source_ref'=d.source_ref);
 SELECT md5(coalesce(string_agg(x,'|' ORDER BY x),'')) INTO source_before FROM(
 SELECT 'event:'||to_jsonb(f)::text x FROM public.financial_events f WHERE f.user_id=u
 UNION ALL SELECT 'bank:'||to_jsonb(s)::text FROM public.lts_open_finance_staging s WHERE s.user_id=u)t;
 old_key:=public.lts_flow_read_key_engine_v243(u);
 UPDATE public.lts_v178_review_decision d SET beneficiary=NULL,
 decision_basis='no_implicit_beneficiary_v294; supersedes automatic policy: '||d.decision_basis,
 decided_at=clock_timestamp()
 WHERE d.user_id=u AND d.beneficiary='Lucas' AND d.category_label IS NULL
 AND d.decision_basis LIKE 'user_owner_default_2026_09_22%';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>expected THEN RAISE EXCEPTION 'Decision update scope changed';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.row_key,to_jsonb(r)::text),'[]') INTO after_rows
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 SELECT coalesce(jsonb_agg(r-'beneficiary'-'management_group'-'management_subgroup' ORDER BY r->>'row_key',r::text),'[]')
 INTO stable_after FROM jsonb_array_elements(after_rows)r;
 IF stable_before IS DISTINCT FROM stable_after
 THEN RAISE EXCEPTION 'Amounts, dates, categories, identities or review status changed';END IF;
 SELECT count(*) INTO remaining FROM jsonb_array_elements(after_rows)r WHERE r->>'beneficiary' IS NOT NULL
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(originals)d WHERE d->>'source_table'=r->>'source_table'
 AND d->>'source_ref'=r->>'source_ref');
 IF remaining<>0 THEN RAISE EXCEPTION 'A superseded default still resolves to a person';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(before_rows)b JOIN jsonb_array_elements(after_rows)a
 ON a->>'row_key'=b->>'row_key' WHERE a IS DISTINCT FROM b AND NOT EXISTS(
 SELECT 1 FROM jsonb_array_elements(originals)d WHERE d->>'source_table'=b->>'source_table' AND d->>'source_ref'=b->>'source_ref'))
 THEN RAISE EXCEPTION 'An unrelated expense changed';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.source_table,d.source_ref),'[]') INTO other_decisions_after
 FROM public.lts_v178_review_decision d WHERE d.user_id=u AND NOT EXISTS(
 SELECT 1 FROM jsonb_array_elements(originals)x WHERE x->>'source_table'=d.source_table AND x->>'source_ref'=d.source_ref);
 IF other_decisions_before IS DISTINCT FROM other_decisions_after
 THEN RAISE EXCEPTION 'A specific prior decision changed';END IF;
 SELECT md5(coalesce(string_agg(x,'|' ORDER BY x),'')) INTO source_after FROM(
 SELECT 'event:'||to_jsonb(f)::text x FROM public.financial_events f WHERE f.user_id=u
 UNION ALL SELECT 'bank:'||to_jsonb(s)::text FROM public.lts_open_finance_staging s WHERE s.user_id=u)t;
 IF source_before IS DISTINCT FROM source_after THEN RAISE EXCEPTION 'A financial source changed';END IF;
 new_key:=public.lts_flow_read_key_engine_v243(u);
 IF old_key IS NOT DISTINCT FROM new_key THEN RAISE EXCEPTION 'Financial read fingerprint did not invalidate';END IF;
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details) VALUES(u,
 'supersede_implicit_owner_beneficiaries','expense_person_policy','no_implicit_person_v294',
 jsonb_build_object('version','no-implicit-person-v294','basis','later_owner_instruction_no_implicit_lucas_or_larissa',
 'original_decisions',originals,'updated_decisions',changed,'visible_expenses',visible,
 'specific_decisions_preserved',true,'amounts_dates_categories_identities_preserved',true,
 'financial_sources_preserved',true,'does_not_reopen_known_generic_categories',true,
 'rule','A known expense without specific personal identification remains classified with no inferred beneficiary.'));
END $policy$;
