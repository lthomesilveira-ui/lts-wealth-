-- Reviewed receipt identity only. Financial sources, user events and balances remain immutable.
CREATE TABLE IF NOT EXISTS lts_projection_private_v412.received_income_evidence_v443(
 user_id uuid NOT NULL REFERENCES auth.users(id),
 series_key text NOT NULL CHECK(series_key='salary_advance'),
 due_date date NOT NULL,receipt_source_id uuid NOT NULL,receipt_hash text NOT NULL CHECK(receipt_hash~'^[0-9a-f]{64}$'),
 receipt_date date NOT NULL,receipt_amount numeric(14,2) NOT NULL CHECK(receipt_amount>0),
 balance_source_id uuid NOT NULL,account_ref text NOT NULL,institution_code text NOT NULL,
 balance_as_of timestamptz NOT NULL,proof_ref text NOT NULL CHECK(length(btrim(proof_ref))>0),
 active boolean NOT NULL DEFAULT true,reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(user_id,series_key,due_date),UNIQUE(user_id,receipt_source_id),
 CHECK(receipt_date<=due_date));
ALTER TABLE lts_projection_private_v412.received_income_evidence_v443 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE lts_projection_private_v412.received_income_evidence_v443 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON TABLE lts_projection_private_v412.received_income_evidence_v443 TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.received_income_slot_v443(p_user uuid,p_rule jsonb,p_due date,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $fn$
DECLARE evidence lts_projection_private_v412.received_income_evidence_v443%ROWTYPE;receipt public.lts_open_finance_staging%ROWTYPE;
 position jsonb;expected_account text;
BEGIN
 IF p_user IS NULL OR p_rule->>'series_key' IS DISTINCT FROM 'salary_advance'
  OR p_rule->>'direction' IS DISTINCT FROM 'income' OR p_rule->>'method' IS DISTINCT FROM 'fixed'
  THEN RETURN jsonb_build_object('status','not_applicable');END IF;
 SELECT * INTO evidence FROM lts_projection_private_v412.received_income_evidence_v443
 WHERE user_id=p_user AND series_key=p_rule->>'series_key' AND due_date=p_due AND active;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','no_reviewed_receipt');END IF;
 SELECT * INTO receipt FROM public.lts_open_finance_staging
 WHERE user_id=p_user AND id=evidence.receipt_source_id;
 expected_account:=CASE evidence.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END;
 IF receipt.id IS NULL OR p_due IS NULL OR p_as_of IS NULL OR p_due<=p_as_of
  OR evidence.receipt_date>p_as_of OR evidence.receipt_date>p_due
  OR date_trunc('month',evidence.receipt_date)<>date_trunc('month',p_due)
  OR p_rule->>'account' IS DISTINCT FROM expected_account
  OR NOT coalesce(pg_input_is_valid(p_rule->>'amount_brl','numeric'),false)
  OR (p_rule->>'amount_brl')::numeric IS DISTINCT FROM evidence.receipt_amount
  OR receipt.resource_type IS DISTINCT FROM 'transaction' OR receipt.currency IS DISTINCT FROM 'BRL'
  OR receipt.provider_deleted_at IS NOT NULL OR receipt.normalized_payload->>'status' IS DISTINCT FROM 'POSTED'
  OR receipt.normalized_payload->>'account_type' IS DISTINCT FROM 'CHECKING_ACCOUNT'
  OR receipt.institution_code IS DISTINCT FROM evidence.institution_code
  OR receipt.provider_account_ref IS DISTINCT FROM evidence.account_ref
  OR receipt.posting_date IS DISTINCT FROM evidence.receipt_date
  OR receipt.signed_amount IS DISTINCT FROM evidence.receipt_amount
  OR receipt.raw_hash IS DISTINCT FROM evidence.receipt_hash
 THEN RETURN jsonb_build_object('status','receipt_requires_review');END IF;
 SELECT p INTO position FROM jsonb_array_elements(public.lts_open_finance_checking_positions_v1(p_user))p
 WHERE p->>'source_id'=evidence.balance_source_id::text AND p->>'account_ref'=evidence.account_ref
  AND p->>'institution_code'=evidence.institution_code;
 IF position IS NULL OR NOT coalesce(pg_input_is_valid(position->>'as_of','timestamptz'),false)
  OR (position->>'as_of')::timestamptz<evidence.balance_as_of
  OR (position->>'as_of')::timestamptz<receipt.occurred_at
  OR ((position->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date>p_as_of
 THEN RETURN jsonb_build_object('status','receipt_requires_review');END IF;
 RETURN jsonb_build_object('status','received_in_balance','amount_brl',evidence.receipt_amount,
  'source_refs',jsonb_build_array('lts_open_finance_staging:'||evidence.receipt_source_id));
END $fn$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.received_income_slot_v443(uuid,jsonb,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.received_income_slot_v443(uuid,jsonb,date,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.received_income_changed_v443()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $fn$
BEGIN
 IF TG_OP='UPDATE' AND OLD IS NOT DISTINCT FROM NEW THEN RETURN NEW;END IF;
 IF TG_OP IN('UPDATE','DELETE') THEN PERFORM lts_projection_private_v412.invalidate_reads(OLD.user_id);END IF;
 IF TG_OP='INSERT' OR TG_OP='UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id
 THEN PERFORM lts_projection_private_v412.invalidate_reads(NEW.user_id);END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.received_income_changed_v443() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE TRIGGER received_income_changed_v443
AFTER INSERT OR UPDATE OR DELETE ON lts_projection_private_v412.received_income_evidence_v443
FOR EACH ROW EXECUTE FUNCTION lts_projection_private_v412.received_income_changed_v443();

