-- The daily total must equal its explicit components where all are supplied.
-- Preserve the legacy non-FGTS subtotal only when those components are absent.
DO $identity$
DECLARE s text;old text:=$o$'posicao_economica_total',(c.old->>'posicao_economica_total')::numeric-(c.old->>'fgts')::numeric+(c.new->>'fgts')::numeric,$o$;
BEGIN
 s:=pg_get_functiondef('lts_fgts_private_v419.merge_flow(jsonb,jsonb,jsonb)'::regprocedure);
 IF (length(s)-length(replace(s,old,'')))/length(old)<>1 THEN RAISE EXCEPTION 'Unexpected FGTS merge predecessor'; END IF;
 s:=replace(s,old,$n$'posicao_economica_total',CASE WHEN c.old ?& ARRAY['rsus_futuras','cash_awards_futuros']
   THEN (c.old->>'saldo_apos_rsu')::numeric+(c.new->>'fgts')::numeric+(c.old->>'rsus_futuras')::numeric+(c.old->>'cash_awards_futuros')::numeric
   ELSE (c.old->>'posicao_economica_total')::numeric-(c.old->>'fgts')::numeric+(c.new->>'fgts')::numeric END,$n$);
 EXECUTE s;
END $identity$;
