CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_input_changed_v465() RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
BEGIN
 UPDATE lts_product_refresh_private_v415.review_input_epoch_v465 SET revision=revision+1 WHERE singleton;
 IF NOT FOUND THEN RAISE EXCEPTION 'review input revision unavailable';END IF;
 RETURN NULL;
END
$function$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.review_input_changed_v465() FROM PUBLIC,anon,authenticated,service_role;
