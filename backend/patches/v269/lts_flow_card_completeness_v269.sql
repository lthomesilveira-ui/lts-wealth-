-- Pure presentation guard: no financial source, position or other-bank mutation.
CREATE OR REPLACE FUNCTION public.lts_flow_card_completeness_v269(p_payload jsonb,p_cycles jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo'
AS $function$
DECLARE result jsonb:=p_payload; flow_part jsonb; days jsonb; events jsonb; d jsonb; v jsonb; f jsonb; e jsonb; key text; dt date;
BEGIN
 IF p_cycles->>'complete' IS DISTINCT FROM 'false' THEN RETURN p_payload; END IF;
 flow_part:=p_payload#>'{flow,current_future}';
 IF flow_part IS NULL THEN RETURN p_payload||jsonb_build_object('complete',false,'incomplete_families',p_cycles->'incomplete_families'); END IF;
 days:='[]'::jsonb;
 FOR d IN SELECT value FROM jsonb_array_elements(coalesce(flow_part->'days','[]'::jsonb)) LOOP
  dt:=(d->>'date')::date; v:=d; f:=coalesce(d->'fix86_columns','{}'::jsonb);
  IF dt>=current_date THEN
   -- No reliable due date is assigned to unresolved purchases. Conservatively
   -- invalidate future projections, retaining the independently observed cash today.
   v:=v||jsonb_build_object('projection_complete',false,'incomplete_families',jsonb_build_array('c6'));
   f:=f||jsonb_build_object('liq_d30',NULL);
   IF dt>current_date THEN
    v:=v||jsonb_build_object('C6',coalesce(d->'C6','{}'::jsonb)||jsonb_build_object(
     'projection_complete',false,'balance_certified',false,'arithmetic',coalesce(d#>'{C6,arithmetic}','{}'::jsonb)||jsonb_build_object('balanced',false),'balance',NULL,'operational_balance',NULL,'opening_balance',NULL,'net',NULL,'cash_exits',NULL),
     'Consolidado',coalesce(d->'Consolidado','{}'::jsonb)||jsonb_build_object(
     'projection_complete',false,'balance_certified',false,'arithmetic',coalesce(d#>'{Consolidado,arithmetic}','{}'::jsonb)||jsonb_build_object('balanced',false),'bank_balance',NULL,'balance',NULL,'opening_balance',NULL,'net',NULL,'economic_net',NULL),
     'balance_certified',false,'v170_cash_arithmetic',coalesce(d->'v170_cash_arithmetic','{}'::jsonb)||jsonb_build_object('balanced',false),'arithmetic',coalesce(d->'arithmetic','{}'::jsonb)||jsonb_build_object('balanced',false),
     'summary',coalesce(d->'summary','{}'::jsonb)||jsonb_build_object('exits',NULL,'net',NULL,'complete',false,'Consolidado',coalesce(d#>'{summary,Consolidado}','{}'::jsonb)||jsonb_build_object('exits',NULL,'net',NULL,'complete',false)));
    FOREACH key IN ARRAY ARRAY['saidas','saidas_operacionais','saldo_final','saldo_final_operacional','saldo_anterior','saldo_anterior_operacional',
     'saldo_apos_d0_1','liq_d0_1','saldo_apos_rsu','saldo_apos_fgts','saldo_apos_fgts_documental','disponivel_total',
     'posicao_antes_rsus','posicao_curto_prazo','posicao_economica_total'] LOOP
      IF f ? key THEN f:=jsonb_set(f,ARRAY[key],'null'::jsonb); END IF;
    END LOOP;
   END IF;
   v:=v||jsonb_build_object('fix86_columns',f);
  END IF;
  days:=days||jsonb_build_array(v);
 END LOOP;
 events:='[]'::jsonb;
 FOR e IN SELECT value FROM jsonb_array_elements(coalesce(flow_part->'events','[]'::jsonb)) LOOP
  IF e->>'source'='card_invoice' AND e->>'account'='C6' AND (e->>'event_date')::date>=current_date THEN
   e:=e||jsonb_build_object('observed_unreconciled_signed_amount',CASE WHEN e ? 'observed_unreconciled_signed_amount' THEN e->'observed_unreconciled_signed_amount' ELSE e->'signed_amount' END,'signed_amount',NULL,'complete',false,'uncertainty_reason','card_cycle_identity');
  END IF;
  events:=events||jsonb_build_array(e);
 END LOOP;
 result:=jsonb_set(result,'{flow,current_future}',flow_part||jsonb_build_object('days',days,'events',events,'complete',false));
 RETURN result||jsonb_build_object('complete',false,'incomplete_families',p_cycles->'incomplete_families',
  'completeness_note','C6 com ciclo ou parcela em conferência. Projeções consolidadas incompletas; posições observadas e demais bancos preservados.');
END
$function$;
REVOKE ALL ON FUNCTION public.lts_flow_card_completeness_v269(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_card_completeness_v269(jsonb,jsonb) TO service_role;
