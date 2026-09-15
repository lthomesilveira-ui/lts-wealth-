-- Preserve documentary bank anchors without discarding user-adjusted movements
-- that became historical after their projection date passed.

create or replace function public.lts_flow_documentary_close_overlay_v1(
  p_user_id uuid,
  p_flow jsonb
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
set "TimeZone" to 'America/Sao_Paulo'
as $function$
declare
  snaps jsonb;
  ev jsonb;
  days jsonb := coalesce(p_flow#>'{historical,days}', '[]'::jsonb);
  outdays jsonb := '[]'::jsonb;
  d jsonb;
  dt date;
  b text;
  a jsonb;
  oldv numeric;
  v numeric;
  change numeric;
  anchor_date date;
  lo date;
  hi date;
  c jsonb;
  fin numeric;
  d0 numeric;
  rsu numeric;
  fgts numeric;
  previous_day jsonb;
  gap numeric;
  gaps jsonb;
  op numeric;
  net numeric;
begin
  if jsonb_array_length(days) = 0 then
    return p_flow;
  end if;

  select min((x->>'date')::date), max((x->>'date')::date)
  into lo, hi
  from jsonb_array_elements(days) x;

  with allsnap as (
    select
      case when s.dados->>'conta' = 'Itau' then 'Itaú' else s.dados->>'conta' end as bank,
      (s.dados->>'data')::date as d,
      (s.dados->>'saldo')::numeric as balance,
      coalesce(nullif(s.dados->>'observed_at', '')::timestamptz, s.importado_em) as observed,
      s.dados->>'source_sha256' as sha
    from public.saldo_snapshot s
    where s.usuario_id = p_user_id
      and s.dados->>'status' = 'ativo'
      and s.dados->>'source_sha256' is not null
      and s.dados->>'data' is not null
      and s.dados->>'saldo' is not null
      and (s.dados->>'data')::date <= hi

    union all

    select
      institution,
      (metadata->>'balance_as_of')::date,
      (metadata->>'balance')::numeric,
      now(),
      metadata->>'evidence_sha256'
    from public.accounts
    where user_id = p_user_id
      and is_active
      and metadata->>'evidence_sha256' is not null
      and (metadata->>'balance_as_of')::date <= hi
  ), ranked as (
    select distinct on (z.bank, z.d) z.*
    from allsnap z
    order by z.bank, z.d, z.observed desc
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bank', z.bank,
        'date', z.d,
        'balance', z.balance,
        'source_sha256', z.sha
      )
      order by z.d
    ),
    '[]'::jsonb
  )
  into snaps
  from ranked z;

  if jsonb_array_length(snaps) = 0 then
    return p_flow;
  end if;

  -- Use the effective historical reader, not the certified-only reader.  It
  -- includes edits, moves and splits whose projection date has already passed.
  -- Therefore a documentary close remains the absolute anchor and every later
  -- user-adjusted cash movement is rolled forward exactly once.
  select least(lo, min((x->>'date')::date))
  into lo
  from jsonb_array_elements(snaps) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into ev
  from public.lts_flow_past_operational_v2(p_user_id, lo, hi) x;

  for d in
    select value
    from jsonb_array_elements(days)
    order by value->>'date'
  loop
    dt := (d->>'date')::date;
    change := 0;
    gaps := '{}'::jsonb;

    foreach b in array array['Itaú', 'Bradesco', 'C6']
    loop
      select x
      into a
      from jsonb_array_elements(snaps) x
      where x->>'bank' = b
        and (x->>'date')::date <= dt
      order by (x->>'date')::date desc
      limit 1;

      if a is null then
        continue;
      end if;

      anchor_date := (a->>'date')::date;
      oldv := nullif(d#>>array[b, 'balance'], '')::numeric;

      if oldv is null then
        continue;
      end if;

      select
        (a->>'balance')::numeric
          + coalesce(sum((x->>'signed_amount')::numeric), 0)
      into v
      from jsonb_array_elements(ev) x
      where x->>'account' = b
        and (x->>'event_date')::date > anchor_date
        and (x->>'event_date')::date <= dt;
      net := coalesce(nullif(d#>>array[b, 'net'], '')::numeric, 0);
      gap := case
        when previous_day is not null
          and previous_day#>>array[b, 'balance'] is not null
        then v - ((previous_day#>>array[b, 'balance'])::numeric + net)
        else 0
      end;

      if abs(gap) > 0.005 then
        gaps := gaps || jsonb_build_object(b, gap);
      end if;

      d := jsonb_set(
        d,
        array[b],
        coalesce(d->b, '{}'::jsonb) || jsonb_build_object(
          'balance', v,
          'documentary_anchor_date', anchor_date,
          'balance_basis', case
            when anchor_date = dt then 'documentary_close'
            else 'documentary_close_plus_effective_movements'
          end,
          'documentary_source_sha256', a->>'source_sha256',
          'prior_legacy_calculation', oldv,
          'reconciliation_gap', gap
        ),
        true
      );

      if d#>array[b, 'operational_balance'] is not null then
        d := jsonb_set(d, array[b, 'operational_balance'], to_jsonb(v), true);
      end if;

      change := change + v - oldv;
    end loop;

    fin := coalesce((d#>>'{Consolidado,bank_balance}')::numeric, 0) + change;
    d := jsonb_set(d, '{Consolidado,bank_balance}', to_jsonb(fin), true);

    c := coalesce(d->'fix86_columns', '{}'::jsonb);
    d0 := nullif(c->>'liq_d0_1_recurso', '')::numeric;
    rsu := nullif(c->>'rsus_vested', '')::numeric;
    fgts := nullif(c->>'fgts', '')::numeric;
    op := coalesce(
      (previous_day#>>'{Consolidado,bank_balance}')::numeric,
      fin - coalesce(
        (d#>>'{Consolidado,economic_net}')::numeric,
        (d#>>'{Consolidado,net}')::numeric,
        0
      )
    );

    c := c || jsonb_build_object(
      'saldo_final', fin,
      'saldo_final_operacional', fin,
      'saldo_anterior', op,
      'saldo_anterior_operacional', op,
      'saldo_apos_d0_1', fin + d0,
      'liq_d0_1', fin + d0,
      'saldo_apos_rsu', fin + d0 + coalesce(rsu, 0),
      'disponivel_total', fin + d0 + coalesce(rsu, 0),
      'posicao_curto_prazo', fin + d0 + coalesce(rsu, 0),
      'saldo_apos_fgts', fin + d0 + coalesce(rsu, 0) + coalesce(fgts, 0)
    );

    d := jsonb_set(d, '{fix86_columns}', c, true)
      || jsonb_build_object(
        'documentary_close_contract', 'asof-anchor-plus-effective-rollforward-v2',
        'reconciliation_gaps', gaps
      );
    outdays := outdays || jsonb_build_array(d);
    previous_day := d;
  end loop;

  return jsonb_set(p_flow, '{historical,days}', outdays, true)
    || jsonb_build_object(
      'documentary_close_contract', 'asof-anchor-plus-effective-rollforward-v2'
    );
end
$function$;

revoke execute on function public.lts_flow_documentary_close_overlay_v1(uuid,jsonb)
from public, anon, authenticated;
