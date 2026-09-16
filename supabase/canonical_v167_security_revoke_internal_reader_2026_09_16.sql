-- V167: the user-id reader is internal. Browser access is only through the
-- authenticated wrappers that resolve the current user server-side.

revoke all on function public.lts_corrected_cashflow_fix86_v5(uuid,date,date)
  from public,anon,authenticated;

comment on function public.lts_corrected_cashflow_fix86_v5(uuid,date,date) is
'Internal cash-flow reader. Direct browser execution is intentionally revoked; use an authenticated lts_browser_* wrapper.';
