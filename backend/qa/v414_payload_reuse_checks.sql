-- Whole JSONB comparisons use deterministic synthetic dependencies with independent counters.
CREATE TABLE qa_v414.results(name text PRIMARY KEY,kind text,pass boolean NOT NULL CHECK(pass),old_calls jsonb,new_calls jsonb,error_code text,payload_md5 text);
CREATE FUNCTION qa_v414.source_hash() RETURNS text LANGUAGE plpgsql AS $f$
DECLARE t text;h text;parts text:='';BEGIN
 FOREACH t IN ARRAY ARRAY['public.asset_positions','public.accounts','public.lts_input_inbox','public.card_invoices','public.lts_card_invoice_detail_reconciliation','public.lts_manual_card_purchase','public.lts_card_purchase_detail','qa_v414.flow'] LOOP
  EXECUTE 'SELECT md5(coalesce(string_agg(to_jsonb(t)::text,''|'' ORDER BY to_jsonb(t)::text),'''')) FROM '||t||' t' INTO h;
  parts:=parts||t||h;
 END LOOP;
 RETURN md5(parts);
END $f$;
CREATE FUNCTION qa_v414.check_case(p_name text,p_kind text,p_owner uuid DEFAULT qa_v414.owner())
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE a jsonb;b jsonb;ac text;am text;bc text;bm text;oc jsonb;nc jsonb;h text;counts_ok boolean;BEGIN
 h:=qa_v414.source_hash();DELETE FROM qa_v414.calls;
 UPDATE qa_v414.config SET value='true' WHERE key='before_core';
 BEGIN
  IF p_kind='mvp' THEN a:=public.lts_mvp_product_payload_v1_before_v414(p_owner);
  ELSE a:=public.lts_product_payload_fix86_v2_before_v414(p_owner);END IF;
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS ac=RETURNED_SQLSTATE,am=MESSAGE_TEXT;END;
 oc:=qa_v414.counts();DELETE FROM qa_v414.calls;
 UPDATE qa_v414.config SET value='false' WHERE key='before_core';
 BEGIN
  IF p_kind='mvp' THEN b:=public.lts_mvp_product_payload_v1(p_owner);
  ELSE b:=public.lts_product_payload_fix86_v2(p_owner);END IF;
 EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS bc=RETURNED_SQLSTATE,bm=MESSAGE_TEXT;END;
 nc:=qa_v414.counts();
 IF ac IS DISTINCT FROM bc OR am IS DISTINCT FROM bm OR a IS DISTINCT FROM b OR h<>qa_v414.source_hash() THEN
  RAISE EXCEPTION 'V414 full payload differential failed: %, before % %, after % %',p_name,ac,am,bc,bm
    USING DETAIL=jsonb_build_object('before',a,'after',b,'old_calls',oc,'new_calls',nc)::text;
 END IF;
 IF ac IS NULL THEN
  IF p_kind='mvp' THEN
   counts_ok:=oc->>'position'='2' AND oc->>'audit'='2' AND nc->>'position'='1' AND nc->>'audit'='1'
    AND oc->>'corrected_flow'='1' AND nc->>'corrected_flow'='1'
    AND oc-ARRAY['position','audit']=nc-ARRAY['position','audit'];
  ELSIF p_kind='chain' THEN
   counts_ok:=oc->>'v10'='2' AND nc->>'v10'='1' AND oc->>'position'='4' AND nc->>'position'='1'
    AND oc->>'audit'='4' AND nc->>'audit'='1' AND oc->>'corrected_flow'='2' AND nc->>'corrected_flow'='1'
    AND NOT EXISTS(SELECT FROM jsonb_each_text(nc-ARRAY['v10','position','audit','corrected_flow'])e
      WHERE e.value<>'1' OR oc->>e.key<>'2');
  ELSE counts_ok:=oc='{"v10":2}' AND nc='{"v10":1}';END IF;
  IF counts_ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'V414 unexpected call counts: %, before %, after %',p_name,oc,nc;END IF;
 END IF;
 INSERT INTO qa_v414.results VALUES(p_name,p_kind,true,oc,nc,ac,md5(b::text));
END $f$;
CREATE TABLE qa_v414.config_original AS TABLE qa_v414.config;
SELECT qa_v414.check_case('populated full payload and fixed horizon boundaries','mvp');
DO $independent$ DECLARE j jsonb;BEGIN
 j:=public.lts_mvp_product_payload_v1(qa_v414.owner());
 IF jsonb_array_length(j#>'{expenses,cards,recent_purchases}')<>120
  OR j#>>'{dashboard,year_horizon,years,0,net_flow}'<>'-200.01'
  OR j#>>'{dashboard,year_horizon,first_modelled_rupture_year}'<>'2027'
  OR j#>>'{dashboard,year_horizon,first_decision_grade_rupture_year}'<>'2031'
  OR jsonb_array_length(j#>'{wealth,accounts}')<>2 THEN
  RAISE EXCEPTION 'V414 independent boundary expectations failed';
 END IF;
 INSERT INTO qa_v414.migration_checks VALUES('independent horizon boundaries and collection contract',true);
END $independent$;
UPDATE qa_v414.config SET value=NULL WHERE key='position';
SELECT qa_v414.check_case('SQL NULL position retains zero starting liquidity','mvp');
UPDATE qa_v414.config SET value='{}' WHERE key='position';
SELECT qa_v414.check_case('missing liquidity field retains zero starting liquidity','mvp');
UPDATE qa_v414.config SET value='{"liquidity_through_d3":-12.345}' WHERE key='position';
SELECT qa_v414.check_case('negative fractional initial liquidity and rounding','mvp');
UPDATE qa_v414.config SET value=(SELECT value FROM qa_v414.config_original WHERE key='position') WHERE key='position';
UPDATE qa_v414.config SET value='{"years":[]}' WHERE key='audit';
SELECT qa_v414.check_case('empty audit years keep six flow years and null confidence','mvp');
UPDATE qa_v414.config SET value=NULL WHERE key='audit';
SELECT qa_v414.check_case('SQL NULL audit retains horizon null fields','mvp');
UPDATE qa_v414.config SET value='{"years":[{"year":2026,"projection_confidence":"higher"},{"year":2026,"projection_confidence":"higher"},{"year":2031,"projection_confidence":null}]}' WHERE key='audit';
SELECT qa_v414.check_case('duplicate audit years preserve existing row multiplicity','mvp');
UPDATE qa_v414.config SET value=(SELECT value FROM qa_v414.config_original WHERE key='audit') WHERE key='audit';
SELECT qa_v414.check_case('other owner has separate filtered rows','mvp','33333333-3333-4333-8333-333333333333');
SELECT qa_v414.check_case('null owner retains empty collections','mvp',NULL);
SELECT qa_v414.check_case('existing product contract and unknown nested keys retained','v2');
UPDATE qa_v414.config SET value='{"unknown":{"retain":true}}' WHERE key='v10';
SELECT qa_v414.check_case('missing product contract','v2');
UPDATE qa_v414.config SET value='{"product_contract":null,"retained":[null,false]}' WHERE key='v10';
SELECT qa_v414.check_case('JSON null product contract preserves concatenation','v2');
UPDATE qa_v414.config SET value=NULL WHERE key='v10';
SELECT qa_v414.check_case('SQL NULL predecessor preserves SQL NULL result','v2');
UPDATE qa_v414.config SET value='true' WHERE key='v10_use_mvp';
SELECT qa_v414.check_case('composed payload reduces four audit and position calls to one','chain');
UPDATE qa_v414.config SET value='{"liquidity_through_d3":"invalid-number"}' WHERE key='position';
SELECT qa_v414.check_case('invalid numeric retains exact error state and message','mvp');
UPDATE qa_v414.config SET value=(SELECT value FROM qa_v414.config_original WHERE key='position') WHERE key='position';
UPDATE qa_v414.config SET value='{"years":null}' WHERE key='audit';
SELECT qa_v414.check_case('invalid scalar audit years retains exact error state and message','mvp');
SELECT jsonb_build_object(
 'pass',(SELECT bool_and(pass) FROM qa_v414.results) AND(SELECT bool_and(pass) FROM qa_v414.migration_checks),
 'runtime',version(),'scope','Disposable synthetic PostgreSQL; exact V414 migration, complete JSONB equality and independent call counters',
 'migration_checks',(SELECT count(*) FROM qa_v414.migration_checks),
 'equal_json_payload_cases',(SELECT count(*) FROM qa_v414.results WHERE error_code IS NULL),
 'equal_error_cases',(SELECT count(*) FROM qa_v414.results WHERE error_code IS NOT NULL),
 'installed',(SELECT jsonb_agg(jsonb_build_object('signature',signature,'before_md5',before_md5,'after_md5',after_md5) ORDER BY signature) FROM qa_v414.installed),
 'migration',(SELECT jsonb_agg(to_jsonb(r) ORDER BY name) FROM qa_v414.migration_checks r),
 'differential',(SELECT jsonb_agg(to_jsonb(r) ORDER BY name) FROM qa_v414.results r));
