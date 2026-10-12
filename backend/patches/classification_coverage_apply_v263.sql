-- Scoped source-identity corrections; original ACLs and raw financial evidence preserved.

DO $patch$
DECLARE d text; a aclitem[];
BEGIN
 SELECT pg_get_functiondef('public.lts_v229_new_bank_rows(uuid,date,date)'::regprocedure),proacl INTO d,a FROM pg_proc WHERE oid='public.lts_v229_new_bank_rows(uuid,date,date)'::regprocedure;
 IF md5(d)<>'16824145fec8ab2692b24b2155681928' THEN RAISE EXCEPTION 'V263 source lease changed: lts_v229_new_bank_rows'; END IF;
 IF strpos(d,$old$SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1$old$)=0 THEN RAISE EXCEPTION 'V263 patch anchor missing'; END IF;
 d:=replace(d,$old$SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1$old$,$new$SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1
 UNION SELECT debit_id,credit_id FROM public.lts_owner_confirmed_transfer_pairs_v263(p_user_id)$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_v229_new_bank_rows(uuid,date,date)'::regprocedure) IS DISTINCT FROM a THEN RAISE EXCEPTION 'V263 ACL changed'; END IF;
END $patch$;

DO $patch$
DECLARE d text; a aclitem[];
BEGIN
 SELECT pg_get_functiondef('public.lts_browser_flow_pre_v238(date,date)'::regprocedure),proacl INTO d,a FROM pg_proc WHERE oid='public.lts_browser_flow_pre_v238(date,date)'::regprocedure;
 IF md5(d)<>'2c90ef9392c5af85340057fcd877486c' THEN RAISE EXCEPTION 'V263 source lease changed: lts_browser_flow_pre_v238'; END IF;
 IF strpos(d,$old$SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1$old$)=0 THEN RAISE EXCEPTION 'V263 patch anchor missing'; END IF;
 d:=replace(d,$old$SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1$old$,$new$SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1
 UNION SELECT debit_id,credit_id FROM public.lts_owner_confirmed_transfer_pairs_v263(u)$new$);
 IF strpos(d,$old$'classification_basis','posted_pair_same_owner_cpf_and_bank_routing',$old$)=0 THEN RAISE EXCEPTION 'V263 patch anchor missing'; END IF;
 d:=replace(d,$old$'classification_basis','posted_pair_same_owner_cpf_and_bank_routing',$old$,$new$'classification_basis',CASE WHEN EXISTS(SELECT 1 FROM public.lts_owner_confirmed_transfer_pairs_v263(u) q WHERE q.debit_id=p.id OR q.credit_id=p.id) THEN 'owner_confirmed_exact_posted_pair' ELSE 'posted_pair_same_owner_cpf_and_bank_routing' END,$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_browser_flow_pre_v238(date,date)'::regprocedure) IS DISTINCT FROM a THEN RAISE EXCEPTION 'V263 ACL changed'; END IF;
END $patch$;

DO $patch$
DECLARE d text; a aclitem[];
BEGIN
 SELECT pg_get_functiondef('public.lts_pending_projections_v233(uuid)'::regprocedure),proacl INTO d,a FROM pg_proc WHERE oid='public.lts_pending_projections_v233(uuid)'::regprocedure;
 IF md5(d)<>'50ae19a6b37994e3c9b545533212308b' THEN RAISE EXCEPTION 'V263 source lease changed: lts_pending_projections_v233'; END IF;
 IF strpos(d,$old$AND NOT EXISTS(SELECT 1 FROM settled_fgts s WHERE s.projection_refs ? (c.x->>'source_ref'))$old$)=0 THEN RAISE EXCEPTION 'V263 patch anchor missing'; END IF;
 d:=replace(d,$old$AND NOT EXISTS(SELECT 1 FROM settled_fgts s WHERE s.projection_refs ? (c.x->>'source_ref'))$old$,$new$AND NOT EXISTS(SELECT 1 FROM settled_fgts s WHERE s.projection_refs ? (c.x->>'source_ref'))
AND NOT EXISTS(
 SELECT 1 FROM public.lts_v229_documentary_match dm
 JOIN posted s ON s.id=dm.staging_id AND s.signed_amount=dm.signed_amount
 JOIN positions p ON p.institution_code=s.institution_code
   AND p.account_id=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=p.observed_at
 WHERE dm.user_id=p_user_id AND dm.source_ref=c.x->>'source_ref'
 AND dm.bank=c.x->>'account' AND dm.signed_amount=(c.x->>'signed_amount')::numeric
 AND dm.canonical_date IN((c.x->>'event_date')::date,(c.x->>'original_date')::date)
 AND dm.evidence->>'basis'='owner_confirmed_exact_obligation'
 AND dm.evidence->>'raw_hash'=s.raw_hash
 AND s.posting_date=(dm.evidence->>'actual_posting_date')::date
)$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_pending_projections_v233(uuid)'::regprocedure) IS DISTINCT FROM a THEN RAISE EXCEPTION 'V263 ACL changed'; END IF;
END $patch$;

DO $patch$
DECLARE d text; a aclitem[];
BEGIN
 SELECT pg_get_functiondef('public.lts_v229_expense_rows(uuid,date,date)'::regprocedure),proacl INTO d,a FROM pg_proc WHERE oid='public.lts_v229_expense_rows(uuid,date,date)'::regprocedure;
 IF md5(d)<>'f445e5f5ac82227cffff8bc755bd3b09' THEN RAISE EXCEPTION 'V263 source lease changed: lts_v229_expense_rows'; END IF;
 IF strpos(d,$old$AND NOT EXISTS(SELECT 1 FROM covered_cycles k WHERE k.family=c.family AND k.competence_month=c.reference_month)$old$)=0 THEN RAISE EXCEPTION 'V263 patch anchor missing'; END IF;
 d:=replace(d,$old$AND NOT EXISTS(SELECT 1 FROM covered_cycles k WHERE k.family=c.family AND k.competence_month=c.reference_month)$old$,$new$AND NOT EXISTS(SELECT 1 FROM covered_cycles k WHERE k.family=c.family AND k.competence_month=c.reference_month
 -- New purchases after the proved statement closing are outside its composition.
 AND NOT EXISTS(SELECT 1 FROM public.card_invoices inv WHERE inv.user_id=p_user_id
  AND inv.reference_month=k.competence_month AND inv.status='closed'
  AND public.lts_card_family_v226(inv.card_name,inv.card_name)=k.family
  AND inv.metadata->>'bank_statement_closing_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND c.provider_status IN('PENDING','POSTED')
  AND c.bill_id IS NULL
  AND c.purchase_date>(inv.metadata->>'bank_statement_closing_date')::date
  AND c.purchase_date<=current_date))$new$);
 EXECUTE d;
 IF (SELECT proacl FROM pg_proc WHERE oid='public.lts_v229_expense_rows(uuid,date,date)'::regprocedure) IS DISTINCT FROM a THEN RAISE EXCEPTION 'V263 ACL changed'; END IF;
END $patch$;

UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
