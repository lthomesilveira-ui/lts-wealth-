CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),epoch bigint NOT NULL DEFAULT 1);
ALTER TABLE public.lts_read_cache_epoch_v242 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_read_cache_epoch_v242 FROM PUBLIC,anon,authenticated;
INSERT INTO public.lts_read_cache_epoch_v242(singleton,epoch) VALUES(true,1);
CREATE OR REPLACE FUNCTION public.lts_operational_source_key_pre_v242(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT md5(jsonb_build_object(
 'reader_revision','correlated-original-cash-days-v246',
 'financial_events',(SELECT md5(coalesce(string_agg(to_jsonb(f)::text,'|' ORDER BY f.id),'empty')) FROM public.financial_events f WHERE f.user_id=p_user_id),
 'accounts',(SELECT md5(coalesce(string_agg(to_jsonb(a)::text,'|' ORDER BY a.id),'empty')) FROM public.accounts a WHERE a.user_id=p_user_id),
 'semantic_rules',(SELECT md5(coalesce(string_agg(to_jsonb(r)::text,'|' ORDER BY r.id),'empty')) FROM public.lts_semantic_rule r WHERE r.user_id=p_user_id),
 'historical_rows',(SELECT md5(coalesce(string_agg(to_jsonb(h)::text,'|' ORDER BY to_jsonb(h)::text),'empty')) FROM public.historico_analitico h WHERE h.usuario_id=p_user_id),
 'legacy_rows',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY to_jsonb(e)::text),'empty')) FROM public.evento_base e WHERE e.usuario_id=p_user_id),
 'operations',(SELECT md5(coalesce(string_agg(to_jsonb(o)::text,'|' ORDER BY o.id),'empty')) FROM public.projecao_op o WHERE o.usuario_id=p_user_id),
 'historical_cash_evidence',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty')) FROM public.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.evidence_type LIKE 'historical_workbook_cash%'),
 'source_signs',(SELECT md5(coalesce(string_agg(to_jsonb(s)::text,'|' ORDER BY to_jsonb(s)::text),'empty')) FROM public.lts_card_history_source_audit_v235 s WHERE s.user_id=p_user_id)
)::text);
$function$;

CREATE OR REPLACE FUNCTION public.lts_v229_invalidate_read_cache()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
BEGIN
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
 DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
 RETURN NULL;
END $fn$;
CREATE OR REPLACE FUNCTION public.lts_operational_source_key_v238(p_user_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
DECLARE e bigint; result text;
BEGIN
 SELECT epoch INTO e FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 SELECT payload->>'value' INTO result FROM public.lts_v229_read_cache WHERE user_id=p_user_id AND kind='operational_key_v242' AND as_of=current_date AND from_date=current_date AND to_date=current_date AND source_fingerprint=e::text AND refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN result; END IF;
 result:=public.lts_operational_source_key_pre_v242(p_user_id);
 IF e<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read'; END IF;
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
 VALUES(p_user_id,'operational_key_v242',current_date,current_date,current_date,jsonb_build_object('value',result),clock_timestamp(),e::text)
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION public.lts_operational_source_key_pre_v242(uuid),public.lts_operational_source_key_v238(uuid),public.lts_v229_invalidate_read_cache() FROM PUBLIC,anon,authenticated;
DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
