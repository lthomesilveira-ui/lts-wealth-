-- Brokerage availability belongs to its own dated source. A day with no newly
-- imported bank transaction must receive the same validated position and totals.
DO $$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('public.lts_browser_flow_v229(date,date)'::regprocedure);
 definition:=replace(definition,'outdays:=outdays||jsonb_build_array(d);',
 $patch$IF dt<current_date AND dt>=(morgan->>'as_of')::date THEN
    c:=d->'fix86_columns';rsu:=(morgan->>'total_available_brl')::numeric;
    IF rsu IS NOT NULL THEN
     c:=c||jsonb_build_object('rsus_vested',rsu,
      'saldo_apos_rsu',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'disponivel_total',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'posicao_curto_prazo',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'saldo_apos_fgts',(c->>'saldo_apos_d0_1')::numeric+rsu+(c->>'fgts')::numeric,
      'historical_rsu_basis','dated_validated_brokerage_available');
     d:=d||jsonb_build_object('fix86_columns',c);
    END IF;
   END IF;
   outdays:=outdays||jsonb_build_array(d);$patch$);
 EXECUTE definition;
END $$;
