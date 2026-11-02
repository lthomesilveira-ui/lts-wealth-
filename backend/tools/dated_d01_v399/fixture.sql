-- Synthetic values only. A future confirmation must not route an earlier day through the old generic asset subtraction.
INSERT INTO public.lts_validated_lock_registry(lock_key,canonical_value)VALUES('itau_cofrinho_fixture_20300104','{"as_of":"2030-01-04","amount":750}');
INSERT INTO public.asset_positions VALUES('44444444-4444-4444-8444-444444444446','11111111-1111-4111-8111-111111111111','cash_investment','Cofrinho Itaú','2030-01-04',750,'D+0',true,'{"validated_lock_key":"itau_cofrinho_fixture_20300104"}');

CREATE FUNCTION public.lts_browser_flow_v228(p_from date,p_to date)RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';dt date:=p_from;d0 numeric:=1000;asset_net numeric;c jsonb:='{}';cofrinho jsonb:='{"as_of":"2030-01-04","amount":750}';added jsonb:='[{"event_date":"2030-01-02","signed_amount":100,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":200,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":1500,"asset_movement":true,"description":"FGTS"}]';
BEGIN
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
RETURN jsonb_build_object('fix86_columns',c||jsonb_build_object('saldo_final',77,'liq_d0_1_recurso',d0,'saldo_apos_d0_1',77+d0,'rsus_vested',10,'saldo_apos_rsu',77+d0+10,'fgts',500,'saldo_apos_fgts',77+d0+10+500));
END $function$;

CREATE FUNCTION public.lts_browser_flow_pre_v238(p_from date,p_to date)RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';dt date:=p_from;d0 numeric:=1000;asset_net numeric;c jsonb:='{}';cofrinho jsonb:='{"as_of":"2030-01-04","amount":750}';added jsonb:='[{"event_date":"2030-01-02","signed_amount":100,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":200,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":1500,"asset_movement":true,"description":"FGTS"}]';
BEGIN
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
RETURN jsonb_build_object('fix86_columns',c||jsonb_build_object('saldo_final',77,'liq_d0_1_recurso',d0,'saldo_apos_d0_1',77+d0,'rsus_vested',10,'saldo_apos_rsu',77+d0+10,'fgts',500,'saldo_apos_fgts',77+d0+10+500));
END $function$;

CREATE FUNCTION public.lts_flow_cache_pre_v240(p_user_id uuid,p_from date,p_to date)RETURNS jsonb LANGUAGE plpgsql AS $function$
DECLARE u uuid:='11111111-1111-4111-8111-111111111111';dt date:=p_from;d0 numeric:=1000;asset_net numeric;c jsonb:='{}';cofrinho jsonb:='{"as_of":"2030-01-04","amount":750}';added jsonb:='[{"event_date":"2030-01-02","signed_amount":100,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":200,"asset_movement":true},{"event_date":"2030-01-03","signed_amount":1500,"asset_movement":true,"description":"FGTS"}]';
BEGIN
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
RETURN jsonb_build_object('fix86_columns',c||jsonb_build_object('saldo_final',77,'liq_d0_1_recurso',d0,'saldo_apos_d0_1',77+d0,'rsus_vested',10,'saldo_apos_rsu',77+d0+10,'fgts',500,'saldo_apos_fgts',77+d0+10+500));
END $function$;
