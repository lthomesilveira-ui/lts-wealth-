-- The source family helper expects the institution in its second argument.
-- Preserve the original received name while adding the issuer to the cash identity.
DO $patch$
DECLARE d text:=pg_get_functiondef('public.lts_card_projection_rows_v290(uuid)'::regprocedure);
BEGIN
 IF position('SELECT ''Bradesco ''||(s.normalized_payload' IN d)>0 THEN RETURN;END IF;
 IF md5(d)<>'8a8297d1237d6f5729b15258717b022b' THEN RAISE EXCEPTION 'Prime identity reader changed';END IF;
 d:=replace(d,'SELECT s.normalized_payload->>''card_name'',1,','SELECT ''Bradesco ''||(s.normalized_payload->>''card_name''),1,');
 d:=replace(d,'public.lts_card_family_v226(s.normalized_payload->>''card_name'',s.normalized_payload->>''card_name'')=g.family',
 'public.lts_card_family_v226(s.normalized_payload->>''card_name'',''Bradesco'')=g.family');
 EXECUTE d;
END $patch$;

