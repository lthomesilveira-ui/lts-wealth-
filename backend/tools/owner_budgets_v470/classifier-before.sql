CREATE OR REPLACE FUNCTION lts_recurring_private_v469.classification(u uuid, e jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE plan jsonb;id text;cat text;
BEGIN
 IF e->>'source' IS DISTINCT FROM 'planning_projection_v412' OR e->>'source_ref' NOT LIKE 'projection:v469:%' THEN RETURN NULL;END IF;
 plan:=lts_recurring_private_v469.owner_plan(u);IF plan IS NULL THEN RETURN NULL;END IF;
 id:=split_part(e->>'source_ref',':',3);
 cat:=CASE WHEN id IN('school_food','school_tuition') THEN plan->>'school_category'
  WHEN id='pharmacy' THEN 'Farmácia' WHEN id='hair' THEN 'Cabelereiro' WHEN id='membership' THEN 'Sócio Rei'
  WHEN id='prime_2990' THEN 'Assinaturas' WHEN id LIKE 'sub_apple_%' THEN 'Apple'
  WHEN id='sub_google_ai_plus' THEN 'Armazenamento' WHEN id='sub_spotify' THEN 'Spotify' WHEN id='sub_amazon_prime' THEN 'Amazon' END;
 IF cat IS NULL THEN RETURN NULL;END IF;
 RETURN e||jsonb_build_object('category',cat,'classification_confirmed',true,'center_cost',CASE WHEN id IN('school_food','school_tuition') THEN plan->>'school_beneficiary' ELSE NULL END);
END $function$
