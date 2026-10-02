-- Operational cash responses must follow the same source state as balances.
-- Keep older cached responses for audit; reuse only an exact source fingerprint.
ALTER TABLE public.lts_v229_read_cache ADD COLUMN IF NOT EXISTS source_fingerprint text;
CREATE OR REPLACE FUNCTION public.lts_operational_source_key_v238(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SET search_path=''
AS $function$
SELECT md5(jsonb_build_object(
 'financial_events',(SELECT md5(coalesce(string_agg(to_jsonb(f)::text,'|' ORDER BY f.id),'empty')) FROM public.financial_events f WHERE f.user_id=p_user_id),
 'accounts',(SELECT md5(coalesce(string_agg(to_jsonb(a)::text,'|' ORDER BY a.id),'empty')) FROM public.accounts a WHERE a.user_id=p_user_id),
 'semantic_rules',(SELECT md5(coalesce(string_agg(to_jsonb(r)::text,'|' ORDER BY r.id),'empty')) FROM public.lts_semantic_rule r WHERE r.user_id=p_user_id),
 'historical_rows',(SELECT md5(coalesce(string_agg(to_jsonb(h)::text,'|' ORDER BY to_jsonb(h)::text),'empty')) FROM public.historico_analitico h WHERE h.usuario_id=p_user_id),
 'legacy_rows',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY to_jsonb(e)::text),'empty')) FROM public.evento_base e WHERE e.usuario_id=p_user_id),
 'source_signs',(SELECT md5(coalesce(string_agg(to_jsonb(s)::text,'|' ORDER BY to_jsonb(s)::text),'empty')) FROM public.lts_card_history_source_audit_v235 s WHERE s.user_id=p_user_id)
)::text)
$function$;
REVOKE ALL ON FUNCTION public.lts_operational_source_key_v238(uuid) FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.lts_flow_operational_read_v229(p_user_id uuid,p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo'
AS $function$
DECLARE j jsonb; k text:=public.lts_operational_source_key_v238(p_user_id);
BEGIN
 SELECT payload INTO j FROM public.lts_v229_read_cache WHERE user_id=p_user_id AND kind='operational' AND as_of=current_date
 AND from_date<=p_from AND to_date>=p_to AND source_fingerprint=k ORDER BY refreshed_at DESC LIMIT 1;
 IF j IS NULL THEN
  SELECT coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('account_attribution',x.account_assignment,'excluded',x.excluded_from_spend,
  'direction',CASE WHEN x.signed_amount<0 THEN 'saida' ELSE 'entrada' END)),'[]') INTO j FROM public.lts_flow_past_operational_v2(p_user_id,p_from,p_to) x;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint) VALUES(p_user_id,'operational',current_date,p_from,p_to,j,k)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=now();
 END IF;
 RETURN coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(j) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]');
END
$function$;
