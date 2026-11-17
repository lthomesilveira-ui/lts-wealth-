BEGIN;
SET LOCAL search_path TO '';
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $check$DECLARE u uuid;BEGIN
 IF md5(pg_get_functiondef('lts_product_refresh_private_v415.review_guard_v450(uuid)'::regprocedure))<>'47af1960816e108d7fa90e3c8917de44' OR md5(lts_product_refresh_private_v415.review_profile_v450()::text)<>'3344fae485b34b6cf29a939801ab492e' THEN RAISE EXCEPTION 'V465 original source contract changed';END IF;
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state IN('pending','running')) THEN RAISE EXCEPTION 'Existing refresh must finish first';END IF;
 FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V465 worker lock busy';END IF;END LOOP;
END $check$;
CREATE TABLE lts_product_refresh_private_v415.review_input_epoch_v465(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),revision bigint NOT NULL);
INSERT INTO lts_product_refresh_private_v415.review_input_epoch_v465 VALUES(true,0);
CREATE TABLE lts_product_refresh_private_v415.review_input_contract_v465(schema_name text,table_name text,relation_oid oid NOT NULL,shape_hash text NOT NULL,trigger_name text NOT NULL,trigger_hash text NOT NULL,PRIMARY KEY(schema_name,table_name));
CREATE TABLE lts_product_refresh_private_v415.review_input_hash_cache_v465(user_id uuid PRIMARY KEY,source_revision bigint NOT NULL,financial_epoch bigint NOT NULL,as_of date NOT NULL,profile_hash text NOT NULL,hashes jsonb NOT NULL,digest text NOT NULL);
REVOKE ALL ON lts_product_refresh_private_v415.review_input_epoch_v465,lts_product_refresh_private_v415.review_input_contract_v465,lts_product_refresh_private_v415.review_input_hash_cache_v465 FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
 UPDATE lts_product_refresh_private_v415.review_input_epoch_v465 SET revision=revision+1 WHERE singleton;
 IF NOT FOUND THEN RAISE EXCEPTION 'review input revision unavailable';END IF;
 RETURN NULL;
END
$function$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.review_input_changed_v465() FROM PUBLIC,anon,authenticated,service_role;

CREATE TRIGGER lts_review_input_v465_8a9422ecbf5b AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.audit_log FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.audit_log ENABLE ALWAYS TRIGGER lts_review_input_v465_8a9422ecbf5b;
DO $capture$DECLARE target_oid oid:='public.audit_log'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','audit_log',target_oid,actual,'lts_review_input_v465_8a9422ecbf5b',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_8a9422ecbf5b'));END $capture$;
CREATE TRIGGER lts_review_input_v465_2b29f94c35c7 AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_product_read_cache FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_product_read_cache ENABLE ALWAYS TRIGGER lts_review_input_v465_2b29f94c35c7;
DO $capture$DECLARE target_oid oid:='public.lts_product_read_cache'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_product_read_cache',target_oid,actual,'lts_review_input_v465_2b29f94c35c7',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_2b29f94c35c7'));END $capture$;
CREATE TRIGGER lts_review_input_v465_9fad0bc3b99b AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_category_catalog FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_category_catalog ENABLE ALWAYS TRIGGER lts_review_input_v465_9fad0bc3b99b;
DO $capture$DECLARE target_oid oid:='public.lts_category_catalog'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_category_catalog',target_oid,actual,'lts_review_input_v465_9fad0bc3b99b',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_9fad0bc3b99b'));END $capture$;
CREATE TRIGGER lts_review_input_v465_25e6e9ba3e70 AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_external_reference_fact FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_external_reference_fact ENABLE ALWAYS TRIGGER lts_review_input_v465_25e6e9ba3e70;
DO $capture$DECLARE target_oid oid:='public.lts_external_reference_fact'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_external_reference_fact',target_oid,actual,'lts_review_input_v465_25e6e9ba3e70',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_25e6e9ba3e70'));END $capture$;
CREATE TRIGGER lts_review_input_v465_1072b201addd AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_open_finance_sync_run FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_open_finance_sync_run ENABLE ALWAYS TRIGGER lts_review_input_v465_1072b201addd;
DO $capture$DECLARE target_oid oid:='public.lts_open_finance_sync_run'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_open_finance_sync_run',target_oid,actual,'lts_review_input_v465_1072b201addd',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_1072b201addd'));END $capture$;
CREATE TRIGGER lts_review_input_v465_c807bf87fda3 AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_expense_effective_read_cache FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_expense_effective_read_cache ENABLE ALWAYS TRIGGER lts_review_input_v465_c807bf87fda3;
DO $capture$DECLARE target_oid oid:='public.lts_expense_effective_read_cache'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_expense_effective_read_cache',target_oid,actual,'lts_review_input_v465_c807bf87fda3',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_c807bf87fda3'));END $capture$;
CREATE TRIGGER lts_review_input_v465_38c9b3032dc8 AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_open_finance_resource_map FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_open_finance_resource_map ENABLE ALWAYS TRIGGER lts_review_input_v465_38c9b3032dc8;
DO $capture$DECLARE target_oid oid:='public.lts_open_finance_resource_map'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_open_finance_resource_map',target_oid,actual,'lts_review_input_v465_38c9b3032dc8',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_38c9b3032dc8'));END $capture$;
CREATE TRIGGER lts_review_input_v465_fdf581f11b31 AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_v229_documentary_match FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_v229_documentary_match ENABLE ALWAYS TRIGGER lts_review_input_v465_fdf581f11b31;
DO $capture$DECLARE target_oid oid:='public.lts_v229_documentary_match'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_v229_documentary_match',target_oid,actual,'lts_review_input_v465_fdf581f11b31',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_fdf581f11b31'));END $capture$;
CREATE TRIGGER lts_review_input_v465_d599010d244e AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_workbook_identity_evidence_v232 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_workbook_identity_evidence_v232 ENABLE ALWAYS TRIGGER lts_review_input_v465_d599010d244e;
DO $capture$DECLARE target_oid oid:='public.lts_workbook_identity_evidence_v232'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_workbook_identity_evidence_v232',target_oid,actual,'lts_review_input_v465_d599010d244e',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_d599010d244e'));END $capture$;
CREATE TRIGGER lts_review_input_v465_ea7e1de2ee7d AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_card_formula_resolution_v237 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_card_formula_resolution_v237 ENABLE ALWAYS TRIGGER lts_review_input_v465_ea7e1de2ee7d;
DO $capture$DECLARE target_oid oid:='public.lts_card_formula_resolution_v237'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_card_formula_resolution_v237',target_oid,actual,'lts_review_input_v465_ea7e1de2ee7d',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_ea7e1de2ee7d'));END $capture$;
CREATE TRIGGER lts_review_input_v465_28b093856d08 AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_card_documentary_payment_link_v272 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_card_documentary_payment_link_v272 ENABLE ALWAYS TRIGGER lts_review_input_v465_28b093856d08;
DO $capture$DECLARE target_oid oid:='public.lts_card_documentary_payment_link_v272'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_card_documentary_payment_link_v272',target_oid,actual,'lts_review_input_v465_28b093856d08',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_28b093856d08'));END $capture$;
CREATE TRIGGER lts_review_input_v465_4417f605769e AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_card_settlement_expense_contract_v273 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_card_settlement_expense_contract_v273 ENABLE ALWAYS TRIGGER lts_review_input_v465_4417f605769e;
DO $capture$DECLARE target_oid oid:='public.lts_card_settlement_expense_contract_v273'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_card_settlement_expense_contract_v273',target_oid,actual,'lts_review_input_v465_4417f605769e',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_4417f605769e'));END $capture$;
CREATE TRIGGER lts_review_input_v465_dab77b4a684f AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_category_binding_v290 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_category_binding_v290 ENABLE ALWAYS TRIGGER lts_review_input_v465_dab77b4a684f;
DO $capture$DECLARE target_oid oid:='public.lts_category_binding_v290'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_category_binding_v290',target_oid,actual,'lts_review_input_v465_dab77b4a684f',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_dab77b4a684f'));END $capture$;
CREATE TRIGGER lts_review_input_v465_97f5bd34090d AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_card_due_rule_v290 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_card_due_rule_v290 ENABLE ALWAYS TRIGGER lts_review_input_v465_97f5bd34090d;
DO $capture$DECLARE target_oid oid:='public.lts_card_due_rule_v290'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_card_due_rule_v290',target_oid,actual,'lts_review_input_v465_97f5bd34090d',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_97f5bd34090d'));END $capture$;
CREATE TRIGGER lts_review_input_v465_c85849c8528b AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_recurring_plan_v366 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_recurring_plan_v366 ENABLE ALWAYS TRIGGER lts_review_input_v465_c85849c8528b;
DO $capture$DECLARE target_oid oid:='public.lts_recurring_plan_v366'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_recurring_plan_v366',target_oid,actual,'lts_review_input_v465_c85849c8528b',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_c85849c8528b'));END $capture$;
CREATE TRIGGER lts_review_input_v465_ac593f6bbc3f AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_card_due_transition_v370 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_card_due_transition_v370 ENABLE ALWAYS TRIGGER lts_review_input_v465_ac593f6bbc3f;
DO $capture$DECLARE target_oid oid:='public.lts_card_due_transition_v370'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_card_due_transition_v370',target_oid,actual,'lts_review_input_v465_ac593f6bbc3f',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_ac593f6bbc3f'));END $capture$;
CREATE TRIGGER lts_review_input_v465_fc8e2fc1a10d AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON public.lts_card_due_estimate_v391 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE public.lts_card_due_estimate_v391 ENABLE ALWAYS TRIGGER lts_review_input_v465_fc8e2fc1a10d;
DO $capture$DECLARE target_oid oid:='public.lts_card_due_estimate_v391'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('public','lts_card_due_estimate_v391',target_oid,actual,'lts_review_input_v465_fc8e2fc1a10d',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_fc8e2fc1a10d'));END $capture$;
CREATE TRIGGER lts_review_input_v465_e327cda32e48 AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON lts_product_refresh_private_v415.queue FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE lts_product_refresh_private_v415.queue ENABLE ALWAYS TRIGGER lts_review_input_v465_e327cda32e48;
DO $capture$DECLARE target_oid oid:='lts_product_refresh_private_v415.queue'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('lts_product_refresh_private_v415','queue',target_oid,actual,'lts_review_input_v465_e327cda32e48',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_e327cda32e48'));END $capture$;
CREATE TRIGGER lts_review_input_v465_3b2e4316d2ec AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON lts_projection_private_v412.received_income_evidence_v443 FOR EACH STATEMENT EXECUTE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465();
ALTER TABLE lts_projection_private_v412.received_income_evidence_v443 ENABLE ALWAYS TRIGGER lts_review_input_v465_3b2e4316d2ec;
DO $capture$DECLARE target_oid oid:='lts_projection_private_v412.received_income_evidence_v443'::regclass; actual text;BEGIN SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;INSERT INTO lts_product_refresh_private_v415.review_input_contract_v465 VALUES('lts_projection_private_v412','received_income_evidence_v443',target_oid,actual,'lts_review_input_v465_3b2e4316d2ec',(SELECT md5(oid::text||':'||xmin::text||':'||pg_get_triggerdef(oid)) FROM pg_trigger WHERE tgrelid=target_oid AND tgname='lts_review_input_v465_3b2e4316d2ec'));END $capture$;
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_input_contract_ok_v465(p_profile jsonb) RETURNS boolean
 LANGUAGE plpgsql STABLE SET search_path TO '' AS $function$
DECLARE item jsonb; c record; target_oid oid; actual text; seen integer:=0;
BEGIN
 IF current_user<>'postgres' OR current_setting('session_replication_role')<>'origin' THEN RETURN false;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
  WHERE p.oid=to_regprocedure('lts_product_refresh_private_v415.review_input_changed_v465()')
  AND md5(p.prosrc)='887587427da6715909959eab38bcd412' AND p.prosecdef AND p.provolatile='v'
  AND pg_get_userbyid(p.proowner)='postgres' AND l.lanname='plpgsql'
  AND p.proconfig=ARRAY['search_path=""']::text[]) THEN RETURN false;END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_profile->'tables') LOOP
  SELECT * INTO c FROM lts_product_refresh_private_v415.review_input_contract_v465 x
   WHERE x.schema_name=item->>'schema' AND x.table_name=item->>'name';
  IF NOT FOUND OR item->>'kind'<>'r' OR (item->>'epoch')::boolean IS DISTINCT FROM false THEN RETURN false;END IF;
  target_oid:=to_regclass(format('%I.%I',c.schema_name,c.table_name));
  IF target_oid IS DISTINCT FROM c.relation_oid THEN RETURN false;END IF;
  IF EXISTS(SELECT 1 FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid) THEN RETURN false;END IF;
  SELECT md5(jsonb_build_object(
 'class',(SELECT jsonb_build_array(relkind,relowner,relrowsecurity,relforcerowsecurity,relispartition) FROM pg_class WHERE oid=target_oid),
 'attributes',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attname,a.atttypid,a.atttypmod,a.attnotnull,a.attisdropped,a.attgenerated,a.attidentity,a.xmin::text,d.xmin::text,pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
 FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=target_oid AND a.attnum>0),
 'inheritance',(SELECT jsonb_agg(jsonb_build_array(inhrelid,inhparent,inhseqno,inhdetachpending) ORDER BY inhrelid,inhparent,inhseqno) FROM pg_inherits WHERE inhrelid=target_oid OR inhparent=target_oid))::text) INTO actual;
  IF actual IS DISTINCT FROM c.shape_hash THEN RETURN false;END IF;
  SELECT md5(t.oid::text||':'||t.xmin::text||':'||pg_get_triggerdef(t.oid)) INTO actual FROM pg_trigger t
   WHERE t.tgrelid=target_oid AND t.tgname=c.trigger_name AND t.tgenabled='A' AND NOT t.tgisinternal;
  IF actual IS DISTINCT FROM c.trigger_hash THEN RETURN false;END IF;
  seen:=seen+1;
 END LOOP;
 RETURN seen=19 AND seen=(SELECT count(*) FROM lts_product_refresh_private_v415.review_input_contract_v465)
  AND EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton);
EXCEPTION WHEN undefined_table OR undefined_column OR undefined_function OR insufficient_privilege THEN RETURN false;
END
$function$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.review_input_contract_ok_v465(jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_guard_v450(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE profile jsonb:=lts_product_refresh_private_v415.review_profile_v450(); item jsonb; actual text; primary_hashes jsonb:='{}'; rel regclass; owner_column text; reuse boolean:=false; cache_hit boolean:=false; input_revision bigint; input_epoch bigint; found_hashes jsonb; old_lock text;
BEGIN
 -- Unknown producer, view or invalidation rules disable reuse, including new
 -- dependencies. They never convert unavailable information into an empty list.
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'producers') LOOP
  SELECT md5(pg_get_functiondef(to_regprocedure(item->>'signature'))) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'views') LOOP
  SELECT md5(pg_get_viewdef(to_regclass(item->>'signature'),true)) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'epoch_tables') LOOP
  SELECT md5(string_agg(t.tgname::text||t.tgenabled::text||pg_get_triggerdef(t.oid),'|' ORDER BY t.tgname)) INTO actual
   FROM pg_trigger t WHERE t.tgrelid=to_regclass(item->>'signature') AND NOT t.tgisinternal;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL;END IF;
 END LOOP;
 -- Reuse only exact full-row hashes, under a pinned producer profile and a
 -- complete statement-trigger/schema contract. All original checks above run.
 IF current_user='postgres' AND md5(profile::text)='3344fae485b34b6cf29a939801ab492e' AND EXISTS(
  SELECT 1 FROM pg_proc p JOIN pg_language l ON l.oid=p.prolang
  WHERE p.oid=to_regprocedure('lts_product_refresh_private_v415.review_input_contract_ok_v465(jsonb)')
  AND md5(p.prosrc)='3dc2fac111a28c643aa3d38511bda88c' AND NOT p.prosecdef AND p.provolatile='s'
  AND pg_get_userbyid(p.proowner)='postgres' AND l.lanname='plpgsql'
  AND p.proconfig=ARRAY['search_path=""']::text[]) THEN
  reuse:=lts_product_refresh_private_v415.review_input_contract_ok_v465(profile);
 END IF;
 IF reuse THEN
  SELECT revision INTO input_revision FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton;
  SELECT epoch INTO input_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  SELECT c.hashes INTO found_hashes FROM lts_product_refresh_private_v415.review_input_hash_cache_v465 c
   WHERE c.user_id=p_user_id AND c.source_revision=input_revision AND c.financial_epoch=input_epoch
   AND c.as_of=current_date AND c.profile_hash=md5(profile::text)
   AND jsonb_typeof(c.hashes)='object' AND c.digest=md5(c.hashes::text);
  IF FOUND AND (SELECT count(*) FROM jsonb_object_keys(found_hashes))=jsonb_array_length(profile->'tables')
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(profile->'tables') x
    WHERE NOT coalesce((found_hashes->>(x->>'schema'||'.'||(x->>'name'))) ~ '^[0-9a-f]{32}$',false)) THEN
   primary_hashes:=found_hashes;cache_hit:=true;
  END IF;
 END IF;
 IF NOT cache_hit THEN
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'tables') LOOP
  -- Relations and owner-column names come only from the pinned private profile.
  rel:=to_regclass(format('%I.%I',item->>'schema',item->>'name'));owner_column:=item->>'owner';
  IF rel IS NULL THEN RETURN NULL;END IF;
  EXECUTE format('WITH row_hashes AS MATERIALIZED (SELECT md5(to_jsonb(s)::text) h FROM %s s%s) SELECT md5(coalesce(string_agg(h,'''' ORDER BY h),'''')) FROM row_hashes',
   rel,CASE WHEN owner_column IS NULL THEN '' ELSE format(' WHERE %I=$1',owner_column) END) INTO actual USING p_user_id;
  primary_hashes:=primary_hashes||jsonb_build_object(item->>'schema'||'.'||(item->>'name'),actual);
 END LOOP;
  IF reuse AND NOT current_setting('transaction_read_only')::boolean
   AND input_revision=(SELECT revision FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton)
   AND input_epoch=(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
   old_lock:=current_setting('lock_timeout');
   BEGIN
    IF old_lock::interval=interval '0' OR old_lock::interval>interval '100 milliseconds' THEN PERFORM set_config('lock_timeout','100ms',true);END IF;
    INSERT INTO lts_product_refresh_private_v415.review_input_hash_cache_v465(user_id,source_revision,financial_epoch,as_of,profile_hash,hashes,digest)
    VALUES(p_user_id,input_revision,input_epoch,current_date,md5(profile::text),primary_hashes,md5(primary_hashes::text))
    ON CONFLICT(user_id) DO UPDATE SET source_revision=excluded.source_revision,financial_epoch=excluded.financial_epoch,
     as_of=excluded.as_of,profile_hash=excluded.profile_hash,hashes=excluded.hashes,digest=excluded.digest;
    PERFORM set_config('lock_timeout',old_lock,true);
   EXCEPTION WHEN lock_not_available OR read_only_sql_transaction THEN NULL;END;
  END IF;
 END IF;
 IF cache_hit AND (input_revision IS DISTINCT FROM (SELECT revision FROM lts_product_refresh_private_v415.review_input_epoch_v465 WHERE singleton)
  OR input_epoch IS DISTINCT FROM(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Review sources changed during read';
 END IF;
 RETURN jsonb_build_object('owner',p_user_id,'as_of',current_date,
  'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
  'card_source_key',lts_product_refresh_private_v415.card_source_key(p_user_id),'primary_hashes',primary_hashes,'profile',md5(profile::text));
END $function$

COMMIT;
