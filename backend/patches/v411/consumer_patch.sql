-- Exact predecessor and result guards; no copied live baseline functions.
DO $v411_consumers$
DECLARE spec jsonb; change jsonb; oid regprocedure; d text; actual_count integer;
BEGIN
 FOR spec IN SELECT value FROM jsonb_array_elements($v411_specs$[
  {
    "signature": "public.lts_flow_dynamic_layers_v1(uuid,date,date)",
    "before_md5": "593d09cd1d62fd85a90426bc42cc82fe",
    "after_md5": "aa359378ee4e509122fddbdd6e5e8756",
    "changes": [
      {
        "old": "case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl)\n             else coalesce(gross_value_brl,net_value_brl) end",
        "new": "lts_award_private.considered_value_v411(p_user_id,asset_type,gross_value_brl,net_value_brl,case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl)\n             else coalesce(gross_value_brl,net_value_brl) end)",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_daily_flow_fix86_v19(uuid,date,date)",
    "before_md5": "6a6c79df62e652a02a4bc084ccd45a17",
    "after_md5": "35ee002387ad56363da2f4ece823a0a8",
    "changes": [
      {
        "old": "coalesce(gross_value_brl,net_value_brl) rsu_value",
        "new": "lts_award_private.considered_value_v411(p_user_id,asset_type,gross_value_brl,net_value_brl,coalesce(gross_value_brl,net_value_brl)) rsu_value",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_daily_flow_fix86_v20(uuid,date,date)",
    "before_md5": "813da41a5361cfc459072203606fa5ab",
    "after_md5": "98d5682c394f481927cc2b29d8da6006",
    "changes": [
      {
        "old": "'signed_amount',coalesce(s.gross_value_brl,s.net_value_brl)",
        "new": "'signed_amount',lts_award_private.considered_value_v411(p_user_id,s.asset_type,s.gross_value_brl,s.net_value_brl,coalesce(s.gross_value_brl,s.net_value_brl)),\n      'gross_value_brl',s.gross_value_brl,'net_value_brl',s.net_value_brl,'amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_dashboard_cash_ladder_from_flow_v229(uuid,date,date,jsonb)",
    "before_md5": "f6b2988142f51a6a72e22b04abfdc007",
    "after_md5": "587ac22382c1ccb469dbce10c95a5d11",
    "changes": [
      {
        "old": "CASE WHEN lower(s.asset_type)LIKE'%cash%'THEN coalesce(s.net_value_brl,s.gross_value_brl)ELSE coalesce(s.gross_value_brl,s.net_value_brl)END value",
        "new": "lts_award_private.considered_value_v411(p_user_id,s.asset_type,s.gross_value_brl,s.net_value_brl,CASE WHEN lower(s.asset_type)LIKE'%cash%'THEN coalesce(s.net_value_brl,s.gross_value_brl)ELSE coalesce(s.gross_value_brl,s.net_value_brl)END) value",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_browser_wealth_detail_v2()",
    "before_md5": "44d8ceaab22eb59a172354e5440ff68f",
    "after_md5": "baa2c3e1ffb0f248f980a54be9683e8b",
    "changes": [
      {
        "old": "case when award_type = 'Cash RSU'\n        then sum(coalesce(net_value_brl, 0))\n        else sum(gross_value_brl)\n      end as considered_value_brl",
        "new": "sum(lts_award_private.considered_value_v411(v_uid,award_type,gross_value_brl,net_value_brl,case when award_type = 'Cash RSU' then coalesce(net_value_brl, 0) else gross_value_brl end)) as considered_value_brl",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_browser_wealth_detail_v3()",
    "before_md5": "2d8828b7e39007ae96983302a40c6e9f",
    "after_md5": "97fafb9996fdb4898c1eefadef513c6e",
    "changes": [
      {
        "old": "'future_cash_net_brl',",
        "new": "'future_regular_net_brl',case when lts_award_private.owner_policy_v411(v_uid) ? 'policy' then coalesce((select sum(coalesce(net_value_brl,gross_value_brl)) from public.lts_future_liquidity_effective_v290 where user_id=v_uid and active and upper(trim(asset_type))='RSU'),0) end,\n    'future_cash_net_brl',",
        "count": 1
      },
      {
        "old": "case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl) else coalesce(gross_value_brl,net_value_brl) end",
        "new": "lts_award_private.considered_value_v411(v_uid,asset_type,gross_value_brl,net_value_brl,case when lower(asset_type) like '%cash%' then coalesce(net_value_brl,gross_value_brl) else coalesce(gross_value_brl,net_value_brl) end)",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_browser_wealth_detail_v4()",
    "before_md5": "0d71b77d858864adb5a0f547cb05713a",
    "after_md5": "24d9bc9e1975865c3b889440964b15b9",
    "changes": [
      {
        "old": "v_cash_net:=round(v_snapshot.future_cash_rsu_gross_brl*0.70,2);",
        "new": "v_cash_net:=lts_award_private.net_value_v411(v_uid,'Cash RSU',v_snapshot.future_cash_rsu_gross_brl,round(v_snapshot.future_cash_rsu_gross_brl*0.70,2));",
        "count": 1
      },
      {
        "old": "v_future_net:=v_snapshot.future_rsu_gross_brl",
        "new": "v_future_net:=lts_award_private.net_value_v411(v_uid,'RSU',v_snapshot.future_rsu_gross_brl,v_snapshot.future_rsu_gross_brl)",
        "count": 1
      },
      {
        "old": "+v_snapshot.other_unavailable_brl;",
        "new": "+case when lts_award_private.owner_policy_v411(v_uid) ? 'policy' then 0 else v_snapshot.other_unavailable_brl end;",
        "count": 1
      },
      {
        "old": "'cash_rsu_after_reserve_brl',v_cash_net,",
        "new": "'regular_rsu_after_reserve_brl',case when lts_award_private.owner_policy_v411(v_uid) ? 'policy' then lts_award_private.net_value_v411(v_uid,'RSU',v_snapshot.future_rsu_gross_brl,v_snapshot.future_rsu_gross_brl) end,\n        'regular_rsu_reserve_brl',case when lts_award_private.owner_policy_v411(v_uid) ? 'policy' then v_snapshot.future_rsu_gross_brl-lts_award_private.net_value_v411(v_uid,'RSU',v_snapshot.future_rsu_gross_brl,v_snapshot.future_rsu_gross_brl) end,\n        'unallocated_net_brl',null,\n        'net_scope',case when lts_award_private.owner_policy_v411(v_uid) ? 'policy' then 'known_components_only' else 'legacy_basis' end,\n        'cash_rsu_after_reserve_brl',v_cash_net,",
        "count": 1
      }
    ]
  },
  {
    "signature": "lts_award_private.provenance_v183()",
    "before_md5": "a62d4027a7c58d69d83d219bfbd0f081",
    "after_md5": "167dfb6c7770acd483c925f4d57e119c",
    "changes": [
      {
        "old": "case when lower(s.asset_type) like '%cash%' then s.net_value_brl else s.gross_value_brl end as considered",
        "new": "lts_award_private.considered_value_v411(u,s.asset_type,s.gross_value_brl,s.net_value_brl,case when lower(s.asset_type) like '%cash%' then s.net_value_brl else s.gross_value_brl end) as considered",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_browser_save_award_assumption_v1(text,numeric,numeric)",
    "before_md5": "ea2de6666d19310e79fc5d959739512a",
    "after_md5": "fc209d0fbe8a171040922c45642089f3",
    "changes": [
      {
        "old": "net_value_brl=case when v_kind='cash_rsu' then round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate*0.70,2)\n                         else round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2) end,",
        "new": "net_value_brl=lts_award_private.net_value_v411(v_uid,s.asset_type,round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2),case when v_kind='cash_rsu' then round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate*0.70,2) else round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2) end),",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_browser_save_all_award_assumptions_v1(numeric,numeric)",
    "before_md5": "e7f62b7f354f8917ca65da689ae4ecea",
    "after_md5": "f81411d70b033e4298dfa8148e6003ae",
    "changes": [
      {
        "old": "net_value_brl=case\n        when lower(s.asset_type) like '%cash%'\n          then round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate*0.70,2)\n        else round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2)\n      end,",
        "new": "net_value_brl=lts_award_private.net_value_v411(v_uid,s.asset_type,round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2),case when lower(s.asset_type) like '%cash%' then round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate*0.70,2) else round(coalesce(s.quantity,0)*p_unit_price_usd*p_fx_rate,2) end),",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_browser_save_vesting_anticipation_v1(text,date)",
    "before_md5": "5f7ec9480300b8488b8668e7f3884c84",
    "after_md5": "5574141f10eb1f45579014fb717d2d27",
    "changes": [
      {
        "old": "  if p_anticipated_date is not null and p_anticipated_date < current_date then",
        "new": "  if p_anticipated_date is not null and lts_award_private.owner_policy_v411(v_uid) ? 'policy' and exists(\n    select 1 from public.lts_future_liquidity_schedule s where s.user_id=v_uid and s.id=any(v_award_ids)\n    and lts_award_private.grant_eligibility_v411(v_uid,s.metadata,s.asset_type) is distinct from true\n  ) then raise exception 'Antecipação exige concessão anterior a 2026 vinculada à fonte; o calendário está preservado.'; end if;\n  if p_anticipated_date is not null and p_anticipated_date < current_date then",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_cashflow_scenarios_v1(uuid,date,date)",
    "before_md5": "8df2e37bb480c5a560803840adbd77e6",
    "after_md5": "b9215a1ed89d8bf71a4d70cc4188c939",
    "changes": [
      {
        "old": "sum(gross_value_brl) gross_value",
        "new": "sum(gross_value_brl) gross_value,sum(lts_award_private.considered_value_v411(p_user_id,asset_type,gross_value_brl,net_value_brl,gross_value_brl)) net_value",
        "count": 1
      },
      {
        "old": "'gross_value_brl',gross_value)",
        "new": "'gross_value_brl',gross_value,'net_value_brl',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then net_value end,'amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end)",
        "count": 1
      },
      {
        "old": "coalesce((select gross_value from rsu where available_date=d),0) conditional_rsu_gross",
        "new": "coalesce((select gross_value from rsu where available_date=d),0) conditional_rsu_gross,\n         coalesce((select net_value from rsu where available_date=d),0) conditional_rsu_net",
        "count": 1
      },
      {
        "old": "+sum(operating_net+conditional_rsu_gross)",
        "new": "+sum(operating_net+conditional_rsu_net)",
        "count": 1
      },
      {
        "old": "'conditional_rsu_gross_in_horizon',(select conditional_rsu_gross from totals),",
        "new": "'conditional_rsu_gross_in_horizon',(select conditional_rsu_gross from totals),\n 'conditional_rsu_net_in_horizon',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then (select coalesce(sum(net_value),0) from rsu) end,'conditional_amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end,",
        "count": 1
      },
      {
        "old": "'Inclui RSUs 2026 após vesting + D+3, a valor bruto'",
        "new": "case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'Inclui RSUs após vesting + liquidação, pela estimativa líquida' else 'Inclui RSUs 2026 após vesting + D+3, a valor bruto' end",
        "count": 1
      },
      {
        "old": "'Valor bruto: preço, câmbio, tributação e efetiva liquidação podem alterar o valor disponível.'",
        "new": "case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'Estimativa líquida com a reserva do titular; preço, câmbio e liquidação podem alterar o valor realizado.' else 'Valor bruto: preço, câmbio, tributação e efetiva liquidação podem alterar o valor disponível.' end",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_cashflow_scenarios_v2(uuid,date,date)",
    "before_md5": "2d3dbc6293b627208dda309d93c0c391",
    "after_md5": "f9ebdb3c0acf171ebfd295f28bb62166",
    "changes": [
      {
        "old": "sum(gross_value_brl) gross_value",
        "new": "sum(gross_value_brl) gross_value,sum(lts_award_private.considered_value_v411(p_user_id,asset_type,gross_value_brl,net_value_brl,gross_value_brl)) net_value",
        "count": 1
      },
      {
        "old": "'gross_value_brl',gross_value)",
        "new": "'gross_value_brl',gross_value,'net_value_brl',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then net_value end,'amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end)",
        "count": 1
      },
      {
        "old": "'conditional_rsu_gross_in_horizon',greatest(coalesce((select future_rsu_delta from vals),0),0),",
        "new": "'conditional_rsu_gross_in_horizon',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then (select coalesce(sum(gross_value),0) from rsu) else greatest(coalesce((select future_rsu_delta from vals),0),0) end,\n  'conditional_rsu_net_in_horizon',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then greatest(coalesce((select future_rsu_delta from vals),0),0) end,'conditional_amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end,",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_cashflow_scenarios_from_flow_v1(uuid,date,date,jsonb)",
    "before_md5": "1b39115bbe50b795ed0207f2f0014b2e",
    "after_md5": "231e8f587c6c16132c62fca0ca4fa89a",
    "changes": [
      {
        "old": "sum(gross_value_brl) gross_value",
        "new": "sum(gross_value_brl) gross_value,sum(lts_award_private.considered_value_v411(p_user_id,asset_type,gross_value_brl,net_value_brl,gross_value_brl)) net_value",
        "count": 1
      },
      {
        "old": "'gross_value_brl',gross_value)",
        "new": "'gross_value_brl',gross_value,'net_value_brl',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then net_value end,'amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end)",
        "count": 1
      },
      {
        "old": "'conditional_rsu_gross_in_horizon',greatest(coalesce((select future_rsu_delta from vals),0),0),",
        "new": "'conditional_rsu_gross_in_horizon',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then (select coalesce(sum(gross_value),0) from rsu) else greatest(coalesce((select future_rsu_delta from vals),0),0) end,\n  'conditional_rsu_net_in_horizon',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then greatest(coalesce((select future_rsu_delta from vals),0),0) end,'conditional_amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end,",
        "count": 1
      }
    ]
  },
  {
    "signature": "public.lts_dashboard_executive_v2(uuid,date)",
    "before_md5": "ce244e8a11a76b7740ab3595e6ca5f1e",
    "after_md5": "000d93fe3346486c4456091c7339a59c",
    "changes": [
      {
        "old": "sum(gross_value_brl) from public.lts_future_liquidity_effective_v290",
        "new": "sum(lts_award_private.considered_value_v411(p_user_id,asset_type,gross_value_brl,net_value_brl,gross_value_brl)) from public.lts_future_liquidity_effective_v290",
        "count": 1
      },
      {
        "old": "'future_rsu_gross',(select future_rsu_gross from vals),'meaning'",
        "new": "'future_rsu_gross',(select future_rsu_gross from vals),'future_rsu_net',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then (select (j->>'conditional_rsu_net_in_horizon')::numeric from scen) end,'amount_basis',case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'net_estimate_once' else 'legacy_basis' end,'meaning'",
        "count": 1
      },
      {
        "old": "'Inclui RSUs somente após vesting + D+3, em valor bruto sujeito a preço, câmbio, impostos e efetiva liquidação.'",
        "new": "case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'Inclui RSUs somente após vesting + D+3, pela estimativa líquida com reserva do titular, sujeita a preço, câmbio e efetiva liquidação.' else 'Inclui RSUs somente após vesting + D+3, em valor bruto sujeito a preço, câmbio, impostos e efetiva liquidação.' end",
        "count": 1
      },
      {
        "old": "'RSU futura é mostrada em valor bruto e continua condicionada a preço, câmbio, impostos e liquidação.'",
        "new": "case when lts_award_private.owner_policy_v411(p_user_id) ? 'policy' then 'RSU futura conserva bruto e líquido separados; a cobertura usa a estimativa líquida e depende de preço, câmbio e liquidação.' else 'RSU futura é mostrada em valor bruto e continua condicionada a preço, câmbio, impostos e liquidação.' end",
        "count": 1
      }
    ]
  }
]$v411_specs$::jsonb) LOOP
  oid:=to_regprocedure(spec->>'signature');
  IF oid IS NULL THEN RAISE EXCEPTION 'V411 missing consumer: %',spec->>'signature'; END IF;
  d:=pg_get_functiondef(oid);
  IF md5(d)=spec->>'after_md5' THEN CONTINUE; END IF;
  IF md5(d)<>spec->>'before_md5' THEN RAISE EXCEPTION 'V411 consumer drift: %',spec->>'signature'; END IF;
  FOR change IN SELECT value FROM jsonb_array_elements(spec->'changes') LOOP
   actual_count:=(length(d)-length(replace(d,change->>'old','')))/length(change->>'old');
   IF actual_count<>(change->>'count')::integer THEN RAISE EXCEPTION 'V411 expression drift: %',spec->>'signature'; END IF;
   d:=replace(d,change->>'old',change->>'new');
  END LOOP;
  IF md5(d)<>spec->>'after_md5' THEN RAISE EXCEPTION 'V411 generated result mismatch: %',spec->>'signature'; END IF;
  EXECUTE d;
  PERFORM set_config('lts.v411.changed','true',true);
  IF md5(pg_get_functiondef(oid))<>spec->>'after_md5' THEN RAISE EXCEPTION 'V411 installed result mismatch: %',spec->>'signature'; END IF;
 END LOOP;
END $v411_consumers$;
