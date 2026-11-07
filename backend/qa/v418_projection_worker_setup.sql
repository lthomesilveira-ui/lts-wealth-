-- Integration with the exact existing queue worker and synthetic heavy dependencies.
ALTER TABLE public.legacy_namespace ADD COLUMN sha256 text DEFAULT 'synthetic-hash';
CREATE FUNCTION lts_projection_private_v412.owner_policy(uuid) RETURNS jsonb LANGUAGE sql AS $f$ SELECT '{"enabled":true}'::jsonb $f$;
CREATE FUNCTION lts_projection_private_v412.build(p_user uuid,p_day date) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb:='{"enabled":true,"series":[{"reference_amount_brl":123.45}]}';
BEGIN
 IF current_setting('qa.summary_fail',true)='true' THEN RAISE EXCEPTION 'synthetic summary failure'; END IF;
 PERFORM set_config('lts.projection_summary_v418',jsonb_build_object('user_id',p_user,'as_of',p_day,'summary',j)::text,true);
 RETURN j;
END $f$;
CREATE OR REPLACE FUNCTION public.lts_dashboard_payload_key_v240(p_payload jsonb) RETURNS text LANGUAGE sql IMMUTABLE AS $f$
 SELECT md5((p_payload-'canonical_summary'-'projection_summary_v418')::text)
$f$;
