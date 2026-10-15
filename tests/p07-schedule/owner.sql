CREATE OR REPLACE FUNCTION public.lts_open_finance_pilot_owner_v1()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare ids uuid[];
begin
  select array_agg(u.id) into ids from public.usuario u
  join public.lts_allowed_users a on lower(a.email)=lower(u.email)
  where a.active and a.role='owner';
  if coalesce(cardinality(ids),0)<>1 then raise exception 'PILOT_OWNER_AMBIGUOUS'; end if;
  return ids[1];
end $function$
