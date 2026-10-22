-- Reuse a previously confirmed incoming classification for an exact bank description.
-- Operator settings and source snapshots remain private; this file contains no user IDs.
DO $operation$
DECLARE
 u uuid:=current_setting('lts.income_sender.owner_id')::uuid;
 rule_id text:=current_setting('lts.income_sender.original_rule_id');
 description text:=current_setting('lts.income_sender.exact_description');
 cat text:=current_setting('lts.income_sender.category');
 expected jsonb:=current_setting('lts.income_sender.expected_sources')::jsonb;
 original public.lts_semantic_rule%rowtype;alias_id text;current_sources jsonb;
 before_expenses text;after_expenses text;before_bank text;after_bank text;before_events text;after_events text;
BEGIN
 SELECT * INTO STRICT original FROM public.lts_semantic_rule WHERE user_id=u AND id=rule_id FOR UPDATE;
 IF NOT original.active OR original.confidence<>'user_confirmed'
 OR public.lts_v178_norm(original.semantic_nature) NOT IN('income','receita','entrada')
 OR original.is_internal_transfer OR original.is_asset_movement
 OR length(description)<20 OR length(description)>200
 OR NOT EXISTS(SELECT 1 FROM public.lts_category_catalog WHERE user_id=u AND category=cat AND active)
 OR public.lts_v178_norm(coalesce(original.counterparty,original.category))<>public.lts_v178_norm(cat)
 THEN RAISE EXCEPTION 'The existing confirmation does not establish this incoming classification';END IF;
 alias_id:='income_sender_v296_'||md5(u::text||':'||public.lts_v178_norm(description));
 IF EXISTS(SELECT 1 FROM public.lts_semantic_rule r WHERE r.user_id=u AND r.id=alias_id
 AND r.active AND r.match_type='exact' AND r.match_value=description AND r.category=cat
 AND r.semantic_nature='income' AND r.center_cost IS NULL AND r.confidence='user_confirmed') THEN
  IF NOT EXISTS(SELECT 1 FROM public.audit_log WHERE user_id=u AND action='extend_confirmed_income_sender' AND entity_id=alias_id)
  THEN RAISE EXCEPTION 'A matching alias has no operation audit';END IF;
  RETURN;
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'hash',s.raw_hash,'date',s.posting_date,'amount',s.signed_amount) ORDER BY s.id),'[]')
 INTO current_sources FROM public.lts_bank_posted_rows_v231(u)s
 WHERE s.signed_amount>0 AND public.lts_v178_norm(s.description_raw)=public.lts_v178_norm(description);
 IF current_sources IS DISTINCT FROM expected OR jsonb_array_length(expected)=0
 THEN RAISE EXCEPTION 'Incoming bank snapshots changed';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text)::text,'[]')) INTO before_expenses
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id)::text,'[]')) INTO before_bank
 FROM public.lts_open_finance_staging s WHERE s.user_id=u;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text,'[]')) INTO before_events
 FROM public.financial_events f WHERE f.user_id=u;
 UPDATE public.lts_semantic_rule SET category=cat,updated_at=now()
 WHERE user_id=u AND id=rule_id;
 INSERT INTO public.lts_semantic_rule(id,user_id,match_type,match_value,category,counterparty,semantic_nature,
 confidence,center_cost,active,is_internal_transfer,is_asset_movement,exclude_from_spend,rationale)
 VALUES(alias_id,u,'exact',description,cat,original.counterparty,'income','user_confirmed',NULL,true,false,false,false,
 'Reuses an existing owner-confirmed incoming purpose for the exact bank sender description; no person inferred.');
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(expected)x
 WHERE public.lts_bank_known_classification_v231(u,(x->>'id')::uuid)->>'category' IS DISTINCT FROM cat)
 THEN RAISE EXCEPTION 'The confirmed sender classification is not reflected by the bank reader';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text)::text,'[]')) INTO after_expenses
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id)::text,'[]')) INTO after_bank
 FROM public.lts_open_finance_staging s WHERE s.user_id=u;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(f) ORDER BY f.id)::text,'[]')) INTO after_events
 FROM public.financial_events f WHERE f.user_id=u;
 IF before_expenses IS DISTINCT FROM after_expenses OR before_bank IS DISTINCT FROM after_bank
 OR before_events IS DISTINCT FROM after_events THEN RAISE EXCEPTION 'Unrelated expenses or original bank/financial rows changed';END IF;
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details)
 VALUES(u,'extend_confirmed_income_sender','income_sender_alias',alias_id,jsonb_build_object(
 'version','confirmed-income-sender-v296','original_rule',to_jsonb(original),
 'exact_description',description,'category',cat,'source_snapshots',expected,
 'future_matching_scope','exact_sender_description_positive_income_only',
 'person_inferred',false,'bank_sources_unchanged',true,'financial_events_unchanged',true,'expenses_unchanged',true));
END $operation$;
