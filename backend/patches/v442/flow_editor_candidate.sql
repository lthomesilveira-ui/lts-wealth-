CREATE OR REPLACE FUNCTION public.lts_browser_flow_event_editor_v1(p_source text, p_source_ref text, p_event_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 DECLARE u uuid:=public.lts_browser_assert_user_v1();r jsonb;original jsonb;parts jsonb;total numeric;
 BEGIN
  r:=public.lts_flow_event_editor_v1(u,p_source,p_source_ref,p_event_date);
  IF p_source='legacy_fix86' AND p_source_ref~'^evento_base:[0-9]+$' THEN
   SELECT jsonb_agg(dados)->0 INTO original FROM public.evento_base WHERE usuario_id=u AND 'evento_base:'||idx=p_source_ref HAVING count(*)=1;
   parts:=original->'composition';
   IF jsonb_typeof(parts)='array' AND jsonb_array_length(parts) BETWEEN 1 AND 12 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(parts)x WHERE NOT coalesce(jsonb_typeof(x->'amount')='number' AND x->>'amount'~'^[0-9]+([.][0-9]+)?$' AND nullif(trim(x->>'rubric'),'') IS NOT NULL,false)) THEN
    SELECT sum((x->>'amount')::numeric) INTO total FROM jsonb_array_elements(parts)x
    WHERE jsonb_typeof(x->'amount')='number' AND x->>'amount'~'^[0-9]+([.][0-9]+)?$';
    IF total=(r->>'amount')::numeric AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(parts)x
     WHERE nullif(trim(x->>'rubric'),'') IS NULL OR jsonb_typeof(x->'amount')<>'number') THEN
     r:=r||jsonb_build_object('composition',parts,'payroll_reference_date',original->>'payroll_reference_date',
      'composition_document_pending',coalesce(original#>'{evidence,statement_pending}'='true'::jsonb,false));
    END IF;
   END IF;
  END IF;
  RETURN r;
 END $function$
