"""Exercise the actual queue wrapper across future billing months and shared source identities."""
from pathlib import Path
R=Path(__file__).resolve().parents[2]
print(r'''
BEGIN;
CREATE SCHEMA v362_fixture;
CREATE TABLE v362_fixture.pending(user_id uuid,item jsonb);
CREATE TABLE v362_fixture.review(user_id uuid,source_table text,source_ref text,identity_status text);
CREATE TABLE v362_fixture.lts_open_finance_staging(user_id uuid,resource_type text,created_at timestamptz);
CREATE TABLE v362_fixture.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
CREATE TABLE v362_fixture.lts_category_catalog(user_id uuid,category text,active boolean);
INSERT INTO v362_fixture.lts_read_cache_epoch_v242 VALUES(true,1);
SELECT set_config('test.v362_owner','00000000-0000-4000-8000-000000000001',true);
CREATE FUNCTION v362_fixture.lts_browser_assert_user_v1()RETURNS uuid LANGUAGE sql AS $$SELECT current_setting('test.v362_owner')::uuid$$;
CREATE FUNCTION v362_fixture.lts_v178_norm(text)RETURNS text LANGUAGE sql AS $$SELECT lower(trim($1))$$;
CREATE FUNCTION v362_fixture.lts_card_pending_sources_v312(uuid)RETURNS TABLE(item jsonb)LANGUAGE sql AS $$SELECT item FROM v362_fixture.pending WHERE user_id=$1$$;
CREATE FUNCTION v362_fixture.lts_v229_review_rows(uuid,date,date)RETURNS TABLE(source_table text,source_ref text,identity_status text)LANGUAGE sql AS $$SELECT source_table,source_ref,identity_status FROM v362_fixture.review WHERE user_id=$1$$;
CREATE FUNCTION v362_fixture.lts_card_review_suggestions_v312(uuid,jsonb)RETURNS TABLE(source_ref text,suggestion jsonb)LANGUAGE sql AS $$SELECT null::text,null::jsonb WHERE false$$;
INSERT INTO v362_fixture.pending
SELECT '00000000-0000-4000-8000-000000000001',jsonb_build_object('source_ref',ref,'source_table','lts_open_finance_staging','event_date',current_date-1,'reference_month',date_trunc('month',current_date)+interval'1 month','description',description,'last4','0001','amount',10)
FROM(VALUES('shared-a','Known A'),('shared-b','Known B'),('card-only','Unmatched'))x(ref,description);
INSERT INTO v362_fixture.pending VALUES
('00000000-0000-4000-8000-000000000001',jsonb_build_object('source_ref','future-purchase','event_date',current_date+1,'reference_month',date_trunc('month',current_date)+interval'2 months','description','Not yet purchased')),
('00000000-0000-4000-8000-000000000002',jsonb_build_object('source_ref','shared-a','event_date',current_date-1,'reference_month',date_trunc('month',current_date)+interval'1 month','description','Other owner'));
INSERT INTO v362_fixture.review VALUES
('00000000-0000-4000-8000-000000000001','lts_open_finance_staging','shared-a','pending'),
('00000000-0000-4000-8000-000000000001','lts_open_finance_staging','shared-b','pending'),
('00000000-0000-4000-8000-000000000001','other_source','card-only','pending');
INSERT INTO v362_fixture.lts_open_finance_staging VALUES('00000000-0000-4000-8000-000000000001','card_transaction',date_trunc('month',current_date)-interval'2 months');
INSERT INTO v362_fixture.lts_category_catalog VALUES('00000000-0000-4000-8000-000000000001','Restaurantes',true);
''')

print("SET LOCAL TIME ZONE 'America/Sao_Paulo';")
print((R/'backend/qa/fixtures/v369_card_queue.sql').read_text().replace('public.','v362_fixture.')+';')
print(r'''
CREATE TEMP TABLE queue_before AS SELECT v362_fixture.lts_browser_card_review_queue_v312(current_date-5,current_date,0,10,null)j;
CREATE TEMP TABLE attrs_before AS SELECT to_jsonb(p)-'prosrc'j FROM pg_proc p WHERE oid='v362_fixture.lts_browser_card_review_queue_v312(date,date,integer,integer,text)'::regprocedure;
''')
patch=(R/'backend/patches/v369/review_surface_identity.sql').read_text().replace('public.','v362_fixture.').replace('md5(definition)',"md5(replace(definition,'v362_fixture.','public.'))")
print(patch)
print(r'''
DO $test$DECLARE j jsonb;k jsonb;BEGIN
 j:=v362_fixture.lts_browser_card_review_queue_v312(current_date-5,current_date,0,10,null);
 IF jsonb_array_length(j->'review_source_refs')<>3 THEN RAISE EXCEPTION 'Incomplete source identity index';END IF;
 IF(j-'review_source_refs'-'checked_at')IS DISTINCT FROM(SELECT b.j-'checked_at'FROM queue_before b)THEN RAISE EXCEPTION 'Existing queue contract changed';END IF;
 k:=v362_fixture.lts_browser_card_review_queue_v312(current_date-5,current_date,0,1,'Unmatched');
 IF k->'review_source_refs'<>j->'review_source_refs'OR jsonb_array_length(k->'rows')<>1 THEN RAISE EXCEPTION 'Search changed identity scope';END IF;
 k:=v362_fixture.lts_browser_card_review_queue_v312(current_date-5,current_date,1,1,null);
 IF k->'review_source_refs'<>j->'review_source_refs'OR jsonb_array_length(k->'rows')<>1 THEN RAISE EXCEPTION 'Pagination changed identity scope';END IF;
 PERFORM set_config('test.v362_owner','00000000-0000-4000-8000-000000000002',true);
 k:=v362_fixture.lts_browser_card_review_queue_v312(current_date-5,current_date,0,10,null);
 IF jsonb_array_length(k->'review_source_refs')<>1 OR k->'review_source_refs'<>jsonb_build_array('shared-a')THEN RAISE EXCEPTION 'Other owner identities leaked';END IF;
 IF(SELECT j FROM attrs_before)IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid='v362_fixture.lts_browser_card_review_queue_v312(date,date,integer,integer,text)'::regprocedure)THEN RAISE EXCEPTION 'ACL attributes changed';END IF;
END $test$;
''')
print(patch)
print(r'''
SELECT jsonb_build_object('version',369,'pass',true,'complete_source_identities',true,'search_pagination_invariant',true,'owner_isolation',true,'counts_content_preserved',true,'acl_preserved',true,'replay_noop',true);
ROLLBACK;
''')
