-- The mobile UI does not read these internal build/audit objects. All fields
-- used by financial screens, plus the complete authorization/refresh envelope,
-- come from the same canonical product reader.
create or replace function public.lts_browser_product_v1(p_mobile_version integer)
returns jsonb
language plpgsql
security invoker
set search_path to ''
as $$
declare
  response jsonb;
begin
  if p_mobile_version is distinct from 483 then
    raise exception 'Unsupported mobile product version' using errcode = '22023';
  end if;
  response := public.lts_browser_product_v1();
  if jsonb_typeof(response->'mvp') = 'object' then
    response := jsonb_set(response, '{mvp}', (response->'mvp') - array[
      'projection_build_v438', 'financial_audit', 'recurring_audit_v442', 'projection_summary_v418'
    ]);
  end if;
  return response;
end;
$$;
revoke all on function public.lts_browser_product_v1(integer) from public, anon;
grant execute on function public.lts_browser_product_v1(integer) to authenticated, service_role;
notify pgrst, 'reload schema';
