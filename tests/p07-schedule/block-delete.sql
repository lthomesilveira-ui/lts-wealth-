CREATE OR REPLACE FUNCTION public.block_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  raise exception 'DELETE is not allowed on append-only economic tables';
end;
$function$
