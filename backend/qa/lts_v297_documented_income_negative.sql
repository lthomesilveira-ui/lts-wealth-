-- Supply the same private manifest/owner/evidence settings as the operation and
-- set lts.income_purpose.operation_sql to that complete generic SQL file.
-- Execute only inside a rolled-back transaction. No financial fixture is made.
DO $negative$
DECLARE good jsonb:=current_setting('lts.income_purpose.manifest')::jsonb;
 operation text:=current_setting('lts.income_purpose.operation_sql');
 caught boolean;message text;cases integer:=0;
BEGIN
 -- Corrupt source snapshots, amounts and duplicate identities fail before edits.
 FOR cases IN 1..3 LOOP
  PERFORM set_config('lts.income_purpose.manifest',CASE cases
   WHEN 1 THEN jsonb_set(good,'{0,source_hash}',to_jsonb(repeat('0',32)))
   WHEN 2 THEN jsonb_set(good,'{0,amount}',to_jsonb((good#>>'{0,amount}')::numeric+1))
   ELSE jsonb_set(good,'{1}',good->0) END::text,true);
  caught:=false;
  BEGIN
   EXECUTE operation;
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS message=MESSAGE_TEXT;
   IF message NOT IN('A documentary source no longer matches its exact snapshot','Duplicate or missing source identity')
   THEN RAISE EXCEPTION 'Unexpected negative-test failure: %',message;END IF;
   caught:=true;
  END;
  IF NOT caught THEN RAISE EXCEPTION 'An invalid manifest was accepted';END IF;
 END LOOP;
 PERFORM set_config('lts.income_purpose.manifest',good::text,true);
 -- A real prior explicit category or person is never replaced by this batch.
 FOR cases IN 1..2 LOOP
  caught:=false;
  BEGIN
   INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
   VALUES(current_setting('lts.income_purpose.owner_id')::uuid,'evento_base',good#>>'{0,source_ref}',
    CASE WHEN cases=1 THEN good#>>'{0,category}' END,CASE WHEN cases=2 THEN 'Larissa' END,'rollback_negative_v297')
   ON CONFLICT(user_id,source_table,source_ref) DO UPDATE SET category_label=excluded.category_label,
    beneficiary=excluded.beneficiary,decision_basis=excluded.decision_basis;
   EXECUTE operation;
   RAISE EXCEPTION 'A prior category or beneficiary was overwritten';
  EXCEPTION WHEN OTHERS THEN
   GET STACKED DIAGNOSTICS message=MESSAGE_TEXT;
   IF message NOT IN('A prior explicit category must not be overwritten','An existing personal or property decision must be reviewed separately')
   THEN RAISE EXCEPTION 'Unexpected prior-decision failure: %',message;END IF;
   caught:=true;
  END;
  IF NOT caught THEN RAISE EXCEPTION 'A prior source decision was accepted';END IF;
 END LOOP;
 PERFORM set_config('lts.income_purpose.negative_result',jsonb_build_object('pass',true,'cases',5,
  'rejected',jsonb_build_array('stale source hash','changed amount','duplicate source','prior category','prior beneficiary'),
  'no_financial_fixture',true,'must_rollback',true)::text,true);
END $negative$;
