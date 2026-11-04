-- Keep the exact installed, withholding-aware reader as a private predecessor.
-- No data is copied and no caller gains access to another owner's rows.
DO $guard$
DECLARE original oid:=to_regprocedure('public.lts_corrected_cashflow_operational_v1(uuid,date,date)');
 saved oid:=to_regprocedure('lts_projection_private_v412.base_flow(uuid,date,date)');definition text;
BEGIN
 IF original IS NULL THEN RAISE EXCEPTION 'V412 requires the installed operational reader';END IF;
 IF saved IS NULL THEN
  IF md5(pg_get_functiondef(original))<>'0a687b1bf642ab20cdadfb96ec0f0bed'
   THEN RAISE EXCEPTION 'V412 operational predecessor differs; review before applying';END IF;
  definition:=replace(pg_get_functiondef(original),
   'FUNCTION public.lts_corrected_cashflow_operational_v1(',
   'FUNCTION lts_projection_private_v412.base_flow(');
  EXECUTE definition;
 ELSE
  definition:=replace(pg_get_functiondef(saved),
   'FUNCTION lts_projection_private_v412.base_flow(',
   'FUNCTION public.lts_corrected_cashflow_operational_v1(');
  IF md5(definition)<>'0a687b1bf642ab20cdadfb96ec0f0bed'
   THEN RAISE EXCEPTION 'V412 saved predecessor differs';END IF;
 END IF;
END $guard$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.base_flow(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.base_flow(uuid,date,date) TO service_role;

