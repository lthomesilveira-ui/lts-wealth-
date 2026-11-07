-- Run only in a disposable database. All identifiers and amounts are invented.
CREATE ROLE authenticated;
CREATE SCHEMA lts_projection_private_v412;
CREATE SCHEMA lts_product_refresh_private_v415;
CREATE SCHEMA qa_v418;
CREATE TABLE public.lts_product_read_cache(user_id uuid PRIMARY KEY,payload jsonb);
CREATE TABLE public.legacy_namespace(usuario_id uuid,chave text,sha256 text);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
CREATE TABLE lts_product_refresh_private_v415.queue(user_id uuid,state text,request_version bigint,completed_version bigint);
CREATE TABLE qa_v418.results(name text PRIMARY KEY,pass boolean NOT NULL CHECK(pass));
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $f$
BEGIN
 IF current_setting('qa.identity',true)='denied' THEN RAISE EXCEPTION 'denied'; END IF;
 RETURN coalesce(nullif(current_setting('qa.identity',true),''),'11111111-1111-4111-8111-111111111111')::uuid;
END $f$;
CREATE FUNCTION lts_projection_private_v412.owner_policy(uuid) RETURNS jsonb LANGUAGE sql AS $f$
 SELECT CASE WHEN current_setting('qa.disabled',true)='true' THEN NULL ELSE '{"enabled":true}'::jsonb END
$f$;
CREATE FUNCTION lts_product_refresh_private_v415.card_source_key(uuid) RETURNS text LANGUAGE sql AS $f$
 SELECT coalesce(nullif(current_setting('qa.cards',true),''),'cards-a')
$f$;
CREATE FUNCTION lts_projection_private_v412.build(uuid,date) RETURNS jsonb LANGUAGE plpgsql AS $f$
BEGIN RAISE EXCEPTION 'browser must not invoke the heavy builder'; END $f$;
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,5);
INSERT INTO lts_product_refresh_private_v415.queue VALUES('11111111-1111-4111-8111-111111111111','ready',7,7);
INSERT INTO public.legacy_namespace VALUES
 ('11111111-1111-4111-8111-111111111111','lts_owner_projection_policy_v412','policy-a'),
 ('11111111-1111-4111-8111-111111111111','lts_projection_reference_v412','reference-a');
INSERT INTO public.lts_product_read_cache
SELECT '11111111-1111-4111-8111-111111111111',jsonb_build_object('projection_summary_v418',
 jsonb_build_object('user_id','11111111-1111-4111-8111-111111111111','as_of',current_date,
 'guard',jsonb_build_object('request_version','7','source_epoch','5','card_source_key','cards-a','policy_sha256','policy-a','reference_sha256','reference-a'),
 'summary','{"enabled":true,"series":[{"series_key":"invented","reference_amount_brl":123.45}],"horizon_end":"2032-12-31"}'::jsonb));

-- Mirror the installed reader attributes and private execution grant.
CREATE FUNCTION lts_projection_private_v412.read_policy()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 result:=lts_projection_private_v412.build(u,current_date);
 RETURN (result-'events'-'replacement_refs')||jsonb_build_object('read_at',clock_timestamp());
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.read_policy() FROM PUBLIC,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.read_policy() TO authenticated;
CREATE TABLE qa_v418.reader_attributes AS
SELECT to_jsonb(p)-'prosrc' AS attributes FROM pg_proc p
WHERE p.oid='lts_projection_private_v412.read_policy()'::regprocedure;
