"""Test the actual suggestion evidence gate, including stale receipts and owners."""
from pathlib import Path
R=Path(__file__).resolve().parents[2]
patch=(R/'backend/patches/v367/classification_evidence.sql').read_text().split('\nDO $$')[0].replace('public.','v367_fixture.')
print(r'''
BEGIN;CREATE SCHEMA v367_fixture;
CREATE TABLE v367_fixture.audit_log(id bigint GENERATED ALWAYS AS IDENTITY,user_id uuid,entity_id text,entity_type text,action text,details jsonb);
CREATE TABLE v367_fixture.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,provider_deleted_at timestamptz,raw_hash text);
CREATE TABLE v367_fixture.lts_category_catalog(user_id uuid,category text,active boolean);
''')
print(patch)
print(r'''
INSERT INTO v367_fixture.lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000001','card_transaction',NULL,repeat('a',64));
INSERT INTO v367_fixture.lts_category_catalog VALUES('00000000-0000-4000-8000-000000000001','Saúde',true);
INSERT INTO v367_fixture.audit_log(user_id,entity_id,entity_type,action,details) VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000011','card_transaction','classification_evidence_v367',jsonb_build_object('expected_raw_hash',repeat('a',64),'category','Saúde','basis','documentary_receipt','confidence','moderate','active',true,'note','Recibo sintético, ainda sujeito à confirmação.','evidence',jsonb_build_object('reference_date','2026-10-22')));
DO $test$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';ref text:='00000000-0000-4000-8000-000000000011';j jsonb;prior jsonb:='{"category":null,"basis":"insufficient_evidence"}';
BEGIN
 j:=v367_fixture.lts_card_suggestion_evidence_v367(u,ref,prior);IF j->>'category'<>'Saúde'OR j->>'confidence'<>'moderate'OR j->>'requires_confirmation'<>'true'OR j->>'beneficiary'IS NOT NULL THEN RAISE EXCEPTION 'Evidence changed a decision or person';END IF;
 IF v367_fixture.lts_card_suggestion_evidence_v367('00000000-0000-4000-8000-000000000002',ref,prior)<>prior THEN RAISE EXCEPTION 'Other owner evidence';END IF;
 UPDATE v367_fixture.lts_open_finance_staging SET raw_hash=repeat('b',64);IF v367_fixture.lts_card_suggestion_evidence_v367(u,ref,prior)<>prior THEN RAISE EXCEPTION 'Stale raw evidence';END IF;
 UPDATE v367_fixture.lts_open_finance_staging SET raw_hash=repeat('a',64),provider_deleted_at=now();IF v367_fixture.lts_card_suggestion_evidence_v367(u,ref,prior)<>prior THEN RAISE EXCEPTION 'Deleted source evidence';END IF;
 UPDATE v367_fixture.lts_open_finance_staging SET provider_deleted_at=NULL;UPDATE v367_fixture.lts_category_catalog SET active=false;IF v367_fixture.lts_card_suggestion_evidence_v367(u,ref,prior)<>prior THEN RAISE EXCEPTION 'Inactive category';END IF;
 UPDATE v367_fixture.lts_category_catalog SET active=true;UPDATE v367_fixture.audit_log SET details=details||'{"active":false}';IF v367_fixture.lts_card_suggestion_evidence_v367(u,ref,prior)<>prior THEN RAISE EXCEPTION 'Disabled evidence';END IF;
 IF has_function_privilege('authenticated','v367_fixture.lts_card_suggestion_evidence_v367(uuid,text,jsonb)','EXECUTE')THEN RAISE EXCEPTION 'Private helper exposed';END IF;
END $test$;
SELECT jsonb_build_object('version',367,'pass',true,'stale_source_rejected',true,'owner_isolation',true,'source_deletion_respected',true,'inactive_category_rejected',true,'suggestion_only',true,'beneficiary_not_inferred',true,'private_helper',true);
ROLLBACK;
''')
