-- Source-specific owner confirmation; no provider, amount, date or person inference.
-- Caller supplies lts.v305.input and owns BEGIN/ROLLBACK or COMMIT.
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL lock_timeout='2s';SET LOCAL statement_timeout='25s';
DO $prepare$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();m jsonb:=current_setting('lts.v305.input')::jsonb;
 s jsonb;d public.lts_v178_review_decision%rowtype;fp jsonb;
BEGIN
 IF nullif(m->>'operation_id','') IS NULL OR nullif(m->>'owner_confirmation','') IS NULL
 OR m->>'category' IS DISTINCT FROM 'Reembolso plano de saúde'
 OR NOT coalesce((m->'source') ?& ARRAY['id','raw_hash','resource_type','signed_amount','posting_date','currency','institution_code'],false)
 OR m#>>'{source,raw_hash}' !~ '^[0-9a-f]{64}$'
 THEN RAISE EXCEPTION 'Exact source and explicit health-reimbursement confirmation required';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text||':'||(m#>>'{source,id}'),305));
 SELECT to_jsonb(x) INTO STRICT s FROM public.lts_open_finance_staging x
 WHERE x.user_id=u AND x.id=(m#>>'{source,id}')::uuid FOR SHARE;
 IF NOT(s @> (m->'source')) OR s->>'provider_deleted_at' IS NOT NULL
 OR s->>'resource_type'<>'transaction' OR s->>'currency'<>'BRL'
 OR s#>>'{normalized_payload,status}' IS DISTINCT FROM 'POSTED'
 OR s#>>'{normalized_payload,account_type}' IS DISTINCT FROM 'CHECKING_ACCOUNT'
 OR (s->>'signed_amount')::numeric>=0
 THEN RAISE EXCEPTION 'Original posted bank debit changed';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_category_catalog WHERE user_id=u AND active AND category=m->>'category')
 THEN RAISE EXCEPTION 'Use the existing shared category';END IF;
 SELECT * INTO d FROM public.lts_v178_review_decision WHERE user_id=u
 AND source_table='lts_open_finance_staging' AND source_ref=m#>>'{source,id}';
 IF FOUND AND d.category_label IS NOT NULL AND d.category_label IS DISTINCT FROM m->>'category'
 THEN RAISE EXCEPTION 'A different explicit decision already exists';END IF;
 PERFORM set_config('lts.v305.already_done',coalesce(d.category_label=m->>'category',false)::text,true);
 PERFORM set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=u),true);
 SELECT jsonb_build_object(
 'bank_sources',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY id)::text FROM public.lts_open_finance_staging x WHERE user_id=u),'[]')),
 'financial_events',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY id)::text FROM public.financial_events x WHERE user_id=u),'[]')),
 'other_decisions',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY source_table,source_ref)::text FROM public.lts_v178_review_decision x
 WHERE user_id=u AND NOT(source_table='lts_open_finance_staging' AND source_ref=m#>>'{source,id}')),'[]')),
 'categories',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY category)::text FROM public.lts_category_catalog x WHERE user_id=u),'[]')),
 'bank_cash',public.lts_open_finance_current_bank_position_v1(u)->'bank_cash',
 'other_expenses',(SELECT md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]'))
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x WHERE NOT(x.source_table='lts_open_finance_staging' AND x.source_ref=m#>>'{source,id}')),
 'expense_sum',(SELECT sum(amount) FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)),
 'target',(SELECT jsonb_agg(to_jsonb(x)) FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x
 WHERE x.source_table='lts_open_finance_staging' AND x.source_ref=m#>>'{source,id}')) INTO fp;
 PERFORM set_config('lts.v305.before',fp::text,true);
END $prepare$;
SET LOCAL ROLE authenticated;SET LOCAL statement_timeout='8s';
DO $write$
DECLARE m jsonb:=current_setting('lts.v305.input')::jsonb;r jsonb;
BEGIN
 IF current_setting('lts.v305.already_done')='true' THEN r:='{"ok":true,"already_classified":true}';
 ELSE r:=public.lts_browser_expense_review_decision_v229('lts_open_finance_staging',m#>>'{source,id}',NULL,NULL,m->>'category');END IF;
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Classification not applied';END IF;
 PERFORM set_config('lts.v305.writer_receipt',r::text,true);PERFORM set_config('lts.v305.writer_role',current_user::text,true);
END $write$;
RESET ROLE;SET LOCAL statement_timeout='25s';
DO $verify$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();m jsonb:=current_setting('lts.v305.input')::jsonb;
 b jsonb:=current_setting('lts.v305.before')::jsonb;a jsonb;t jsonb;
BEGIN
 SELECT jsonb_build_object(
 'bank_sources',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY id)::text FROM public.lts_open_finance_staging x WHERE user_id=u),'[]')),
 'financial_events',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY id)::text FROM public.financial_events x WHERE user_id=u),'[]')),
 'other_decisions',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY source_table,source_ref)::text FROM public.lts_v178_review_decision x
 WHERE user_id=u AND NOT(source_table='lts_open_finance_staging' AND source_ref=m#>>'{source,id}')),'[]')),
 'categories',md5(coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY category)::text FROM public.lts_category_catalog x WHERE user_id=u),'[]')),
 'bank_cash',public.lts_open_finance_current_bank_position_v1(u)->'bank_cash',
 'other_expenses',(SELECT md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]'))
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x WHERE NOT(x.source_table='lts_open_finance_staging' AND x.source_ref=m#>>'{source,id}')),
 'expense_sum',(SELECT sum(amount) FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)),
 'target',(SELECT jsonb_agg(to_jsonb(x)) FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)x
 WHERE x.source_table='lts_open_finance_staging' AND x.source_ref=m#>>'{source,id}')) INTO a;
 IF a-'target' IS DISTINCT FROM b-'target' THEN RAISE EXCEPTION 'Sources, totals or unrelated classifications changed';END IF;
 IF jsonb_array_length(a->'target') IS DISTINCT FROM 1 OR jsonb_array_length(b->'target') IS DISTINCT FROM 1
 OR a#>>'{target,0,category}' IS DISTINCT FROM m->>'category'
 OR a#>'{target,0,amount}' IS DISTINCT FROM b#>'{target,0,amount}'
 OR a#>'{target,0,event_date}' IS DISTINCT FROM b#>'{target,0,event_date}'
 OR a#>'{target,0,beneficiary}' IS DISTINCT FROM b#>'{target,0,beneficiary}'
 OR a#>'{target,0,property_code}' IS DISTINCT FROM b#>'{target,0,property_code}'
 THEN RAISE EXCEPTION 'Target amount/date/person identity changed or not resolved';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.audit_log WHERE user_id=u AND action='confirm_bank_expense_category'
 AND entity_id=m#>>'{source,id}' AND details->>'operation_id'=m->>'operation_id') THEN
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details)
 VALUES(u,'confirm_bank_expense_category','open_finance_transaction',m#>>'{source,id}',
 jsonb_build_object('version','owner-expense-category-v305','operation_id',m->>'operation_id',
 'owner_confirmation',m->>'owner_confirmation','source',m->'source','category',m->>'category',
 'scope','exact_source_only','beneficiary_inferred',false,'writer_role',current_setting('lts.v305.writer_role')));
 END IF;
 PERFORM set_config('lts.v305.receipt',jsonb_build_object('ok',true,'writer_role',current_setting('lts.v305.writer_role'),
 'writer',current_setting('lts.v305.writer_receipt')::jsonb,'sources_and_other_decisions_exact',true,
 'all_other_expenses_exact',true,'all_expense_amounts_unchanged',true,'no_person_inferred',true,
 'target',a->'target','bank_cash',a->'bank_cash')::text,true);
END $verify$;
SELECT current_setting('lts.v305.receipt')::jsonb receipt;
