SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l-'expires_at',$t$apply/expiry missing$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}','null'),$t$apply/expiry null$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}','true'),$t$apply/expiry boolean$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}','1'),$t$apply/expiry numeric$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}','[]'),$t$apply/expiry array$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}',to_jsonb('not-a-timestamp'::text)),$t$apply/expiry invalid$t$,$t$lease expiry parse$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}',to_jsonb('infinity'::text)),$t$apply/expiry positive infinity$t$,$t$nonfinite$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}',to_jsonb('-infinity'::text)),$t$apply/expiry negative infinity$t$,$t$nonfinite$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{expires_at}',to_jsonb(clock_timestamp()-interval '1 second')),$t$apply/expiry past$t$,$t$expired$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{ready}','false'),$t$apply/ready false$t$,$t$held: not released$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{ready}','1'),$t$apply/ready numeric$t$,$t$held: not released$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l-'required_gates',$t$apply/gates absent$t$,$t$gates$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{required_gates}','{}'),$t$apply/gates empty$t$,$t$gates$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{current_epoch}','99'),$t$apply/epoch stale$t$,$t$epoch$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{catalog_contracts,functions}','[]'),$t$apply/catalog functions empty$t$,$t$coverage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{catalog_contracts,relations}','[]'),$t$apply/catalog relations empty$t$,$t$coverage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{source_full_beforeimages,0,raw_hash}',to_jsonb('edited'::text)),$t$apply/source lease edited$t$,$t$source lease$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{prior_decision,decision_basis}',to_jsonb('edited'::text)),$t$apply/prior lineage edited$t$,$t$lineage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/final injected failure$t$,$t$fixture final failure$t$,true);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
UPDATE public.lts_open_finance_staging SET raw_hash='later-source-edit' WHERE id='22222222-2222-4222-8222-222222222222';
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/source changed after lease$t$,$t$source lease$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
UPDATE public.lts_v178_review_decision SET decision_basis='later-prior-edit' WHERE source_ref='33333333-3333-4333-8333-333333333333';
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/prior changed after lease$t$,$t$lineage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
REVOKE EXECUTE ON FUNCTION public.lts_v229_expense_rows(uuid,date,date) FROM service_role;
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/consumer ACL changed after lease$t$,$t$catalog drift$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
ALTER FUNCTION public.lts_v229_expense_rows(uuid,date,date) SET TimeZone='Europe/London';
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/consumer config changed after lease$t$,$t$catalog drift$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
ALTER TABLE public.lts_reconciliation_evidence DISABLE ROW LEVEL SECURITY;
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/evidence RLS changed after lease$t$,$t$catalog drift$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
PERFORM public.fixture_atomic_competitor();
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/different id competitor$t$,$t$partial|conflicting$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l-'expires_at',$t$rollback/expiry missing$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}','null'),$t$rollback/expiry null$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}','true'),$t$rollback/expiry boolean$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}','1'),$t$rollback/expiry numeric$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}','[]'),$t$rollback/expiry array$t$,$t$lease expiry must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}',to_jsonb('not-a-timestamp'::text)),$t$rollback/expiry invalid$t$,$t$lease expiry parse$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}',to_jsonb('infinity'::text)),$t$rollback/expiry positive infinity$t$,$t$nonfinite$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}',to_jsonb('-infinity'::text)),$t$rollback/expiry negative infinity$t$,$t$nonfinite$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expires_at}',to_jsonb(clock_timestamp()-interval '1 second')),$t$rollback/expiry past$t$,$t$expired$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{ready}','false'),$t$rollback/ready false$t$,$t$held: not released$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{ready}','1'),$t$rollback/ready numeric$t$,$t$held: not released$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l-'required_gates',$t$rollback/gates absent$t$,$t$gates$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{required_gates}','{}'),$t$rollback/gates empty$t$,$t$gates$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{current_epoch}','99'),$t$rollback/epoch stale$t$,$t$epoch$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{catalog_contracts,functions}','[]'),$t$rollback/catalog functions empty$t$,$t$coverage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{catalog_contracts,relations}','[]'),$t$rollback/catalog relations empty$t$,$t$coverage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{source_full_beforeimages,0,raw_hash}',to_jsonb('edited'::text)),$t$rollback/source lease edited$t$,$t$source lease$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{prior_decision,decision_basis}',to_jsonb('edited'::text)),$t$rollback/prior lineage edited$t$,$t$lineage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/final injected failure$t$,$t$fixture final failure$t$,true);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
UPDATE public.lts_open_finance_staging SET raw_hash='later-source-edit' WHERE id='22222222-2222-4222-8222-222222222222';
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/source changed after lease$t$,$t$source lease$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
UPDATE public.lts_v178_review_decision SET decision_basis='later-prior-edit' WHERE source_ref='33333333-3333-4333-8333-333333333333';
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/prior changed after lease$t$,$t$lineage$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
REVOKE EXECUTE ON FUNCTION public.lts_v229_expense_rows(uuid,date,date) FROM service_role;
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/consumer ACL changed after lease$t$,$t$catalog drift$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
ALTER FUNCTION public.lts_v229_expense_rows(uuid,date,date) SET TimeZone='Europe/London';
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/consumer config changed after lease$t$,$t$catalog drift$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
ALTER TABLE public.lts_reconciliation_evidence DISABLE ROW LEVEL SECURITY;
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/evidence RLS changed after lease$t$,$t$catalog drift$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
PERFORM public.fixture_atomic_competitor();
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/different id competitor$t$,$t$partial|conflicting$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
INSERT INTO public.lts_reconciliation_evidence SELECT * FROM jsonb_populate_record(NULL::public.lts_reconciliation_evidence,l->'evidence_insert');
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/evidence only$t$,$t$partial$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
INSERT INTO public.lts_v178_review_decision SELECT * FROM jsonb_populate_record(NULL::public.lts_v178_review_decision,l->'representative_decision_insert');
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/decision only$t$,$t$partial$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
INSERT INTO public.lts_access_audit(user_id,action,meta) VALUES('11111111-1111-4111-8111-111111111111','option_a_nominal_apply_v1','{"operation_id":"55555555-5555-4555-8555-555555555555"}');
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/audit only$t$,$t$partial$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
EXECUTE (SELECT definition FROM public.fixture_atomic_bodies WHERE kind='candidate' AND signature LIKE '%expense_rows%');
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/one function already replaced$t$,$t$catalog drift$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);
INSERT INTO public.financial_events(id,user_id,legacy_id) VALUES('66666666-6666-4666-8666-666666666666','11111111-1111-4111-8111-111111111111','55555555-5555-4555-8555-555555555555');
 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,l,$t$apply/bridge legacy collision$t$,$t$bridge source_ref collision$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{representative_decision_insert,property_code}',to_jsonb('unapproved-property'::text)),$t$apply/property scope altered$t$,$t$scope$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{representative_decision_insert,decision_basis}',to_jsonb('arbitrary narrative'::text)),$t$apply/decision basis altered$t$,$t$basis$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{representative_decision_insert,extra}','true'),$t$apply/decision extra column$t$,$t$columns$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{representative_decision_insert,decided_at}',to_jsonb('infinity'::text)),$t$apply/decision infinite timestamp$t$,$t$nonfinite$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{evidence_insert,metadata,extra}','true'),$t$apply/metadata root extra key$t$,$t$metadata root keys$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{evidence_insert,metadata}','[]'),$t$apply/metadata root array$t$,$t$metadata root must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{evidence_insert,metadata}','null'),$t$apply/metadata root null$t$,$t$metadata root must$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{evidence_insert,metadata,state,active}','1'),$t$apply/metadata state numeric true$t$,$t$scope$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{evidence_insert,metadata,contract,amount}','99'),$t$apply/metadata contract changed$t$,$t$scope$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{immutable_fingerprint}',to_jsonb(repeat('0',64))),$t$apply/pin altered$t$,$t$pin$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{evidence_insert,amount}','99'),$t$apply/evidence economic scope altered$t$,$t$scope$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$apply$t$);

 PERFORM public.fixture_atomic_expect_fail($t$apply$t$,jsonb_set(l,'{consumer_replacements,0,reviewed_definition_sha256}',to_jsonb(repeat('0',64))),$t$apply/replacement bytes altered$t$,$t$replacement$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
UPDATE public.lts_v178_review_decision SET category_label='later legitimate category' WHERE source_ref='22222222-2222-4222-8222-222222222222';
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/representative later edit retained$t$,$t$rollback CAS$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
UPDATE public.lts_reconciliation_evidence SET description='later evidence edit';
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/evidence later edit retained$t$,$t$rollback CAS$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
UPDATE public.lts_access_audit SET meta=meta||'{"later":true}';
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/apply receipt edited retained$t$,$t$rollback CAS$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);
DELETE FROM public.lts_access_audit;
 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,l,$t$rollback/apply receipt missing$t$,$t$rollback CAS$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expected_revoked_evidence,metadata,state,active}','0'),$t$rollback/revocation numeric false$t$,$t$revocation$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expected_revoked_evidence,metadata,state,extra}','true'),$t$rollback/revocation extra state$t$,$t$revocation$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expected_revoked_evidence,metadata,state,revoked_at}',to_jsonb('infinity'::text)),$t$rollback/revocation infinity$t$,$t$nonfinite$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expected_revoked_evidence,metadata,state,revoked_at}',to_jsonb('invalid'::text)),$t$rollback/revocation parse$t$,$t$parse$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
DO $case$ DECLARE l jsonb;BEGIN
 l:=public.fixture_atomic_lease($t$rollback$t$);

 PERFORM public.fixture_atomic_expect_fail($t$rollback$t$,jsonb_set(l,'{expected_revoked_evidence,metadata,contract,amount}','99'),$t$rollback/immutable contract alteration$t$,$t$revocation$t$,false);
END $case$;
SELECT public.fixture_atomic_reset();
CREATE TABLE public.fixture_atomic_results(k text PRIMARY KEY,v jsonb);
INSERT INTO public.fixture_atomic_results VALUES('before',public.fixture_atomic_snapshot()),('consumer_before',public.fixture_capture());
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_lease('apply'));
INSERT INTO public.fixture_atomic_results VALUES('applied',public.fixture_atomic_snapshot()),('consumer_after',public.fixture_capture());
SELECT public.fixture_assert((SELECT epoch=102 FROM public.lts_read_cache_epoch_v242),$t$lifecycle/apply exactly two epochs$t$);
SELECT public.fixture_assert((SELECT count(*)=1 FROM public.lts_reconciliation_evidence),$t$lifecycle/exactly one evidence$t$);
SELECT public.fixture_assert((SELECT count(*)=2 FROM public.lts_v178_review_decision),$t$lifecycle/one inserted representative decision$t$);
SELECT public.fixture_assert((SELECT count(*)=1 FROM public.lts_access_audit WHERE action='option_a_nominal_apply_v1' AND meta->>'status'='pending_postcheck'),$t$lifecycle/minimal pending receipt$t$);
SELECT public.fixture_assert((SELECT count(*)=1 AND bool_and(user_id IS NULL) FROM public.lts_v229_read_cache),$t$lifecycle/global nonnull cache invalidated null sentinel preserved$t$);
SELECT public.fixture_assert((SELECT v->'lts_open_finance_staging' FROM public.fixture_atomic_results WHERE k='before')=(SELECT v->'lts_open_finance_staging' FROM public.fixture_atomic_results WHERE k='applied'),$t$lifecycle/all source rows intact$t$);
SELECT public.fixture_assert((SELECT v->'core' FROM public.fixture_atomic_results WHERE k='consumer_before')=(SELECT v->'core' FROM public.fixture_atomic_results WHERE k='consumer_after'),$t$lifecycle/core October and November unchanged$t$);
SELECT public.fixture_assert((SELECT v->'november' FROM public.fixture_atomic_results WHERE k='consumer_before')=(SELECT v->'november' FROM public.fixture_atomic_results WHERE k='consumer_after'),$t$lifecycle/legacy November empty unchanged$t$);
SELECT public.fixture_assert((SELECT (v#>>'{card,item_count}')::int=114 FROM public.fixture_atomic_results WHERE k='consumer_before') AND (SELECT (v#>>'{card,item_count}')::int=113 FROM public.fixture_atomic_results WHERE k='consumer_after'),$t$lifecycle/full detail 114 to 113$t$);
SELECT public.fixture_assert((SELECT v->'card' FROM public.fixture_atomic_results WHERE k='consumer_after')=public.fixture_expected_card((SELECT v->'card' FROM public.fixture_atomic_results WHERE k='consumer_before')),$t$lifecycle/full detail preserves 112 non targets$t$);
SELECT public.fixture_atomic_exec('apply',public.fixture_atomic_complete_lease('apply'));
SELECT public.fixture_assert(public.fixture_atomic_snapshot()=(SELECT v FROM public.fixture_atomic_results WHERE k='applied'),$t$lifecycle/exact apply repetition is zero DML$t$);
SELECT public.fixture_atomic_exec('rollback',public.fixture_atomic_lease('rollback'));
INSERT INTO public.fixture_atomic_results VALUES('compensated',public.fixture_atomic_snapshot());
SELECT public.fixture_assert((SELECT epoch=104 FROM public.lts_read_cache_epoch_v242),$t$lifecycle/rollback exactly two epochs$t$);
SELECT public.fixture_assert((SELECT count(*)=1 AND bool_and(metadata#>'{state,active}'='false'::jsonb) FROM public.lts_reconciliation_evidence),$t$lifecycle/evidence revoked and retained$t$);
SELECT public.fixture_assert((SELECT count(*)=1 AND bool_and(source_ref='33333333-3333-4333-8333-333333333333') FROM public.lts_v178_review_decision),$t$lifecycle/only original prior decision remains$t$);
SELECT public.fixture_assert((SELECT count(*)=2 FROM public.lts_access_audit),$t$lifecycle/apply and compensation receipts retained$t$);
SELECT public.fixture_assert(public.fixture_capture()=(SELECT v FROM public.fixture_atomic_results WHERE k='consumer_before'),$t$lifecycle/original complete consumer output restored$t$);
SELECT public.fixture_atomic_exec('rollback',public.fixture_atomic_complete_lease('rollback'));
SELECT public.fixture_assert(public.fixture_atomic_snapshot()=(SELECT v FROM public.fixture_atomic_results WHERE k='compensated'),$t$lifecycle/exact compensation repetition is zero DML$t$);
SELECT public.fixture_atomic_expect_fail('apply',public.fixture_atomic_lease('apply'),'lifecycle/revoked operation cannot reapply','partial');
DO $idem$ DECLARE l jsonb;BEGIN l:=public.fixture_atomic_complete_lease('rollback');PERFORM public.fixture_atomic_expect_fail('rollback',jsonb_set(l,'{expected_compensated_state,compensation_receipt_sha256}',to_jsonb(repeat('0',64))),'lifecycle/compensation receipt anchor cannot change','anchors');END $idem$;
SELECT public.fixture_assert((SELECT bool_and(NOT rolsuper) FROM pg_roles WHERE rolname IN('fixture_owner','service_role')),$t$roles/non superuser execution$t$);
SELECT public.fixture_assert((SELECT bool_and(rolbypassrls) FROM pg_roles WHERE rolname IN('fixture_owner','service_role')),$t$roles/bypass RLS explicitly modeled$t$);
SELECT jsonb_build_object('kind','atomic_functional_results','count',count(*),'labels',jsonb_agg(label ORDER BY label COLLATE "C")) FROM public.fixture_test_log;
SELECT jsonb_build_object('kind','compiled_definitions','definitions',jsonb_agg(to_jsonb(b) ORDER BY kind,signature)) FROM public.fixture_atomic_bodies b;
ROLLBACK;
