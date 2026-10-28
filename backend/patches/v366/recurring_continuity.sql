-- Only explicitly confirmed planning rules generate future occurrences.
CREATE SCHEMA lts_recurring_private_v366;
REVOKE ALL ON SCHEMA lts_recurring_private_v366 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_recurring_private_v366 TO authenticated;
CREATE TABLE public.lts_recurring_plan_v366 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id),
 series_key text NOT NULL, description text NOT NULL, direction text NOT NULL CHECK(direction IN('entrada','saida')),
 account text NOT NULL CHECK(account IN('Itaú','Bradesco','C6')), category text,
 value_kind text NOT NULL CHECK(value_kind IN('fixed','variable')), amount numeric,
 cadence_months integer NOT NULL CHECK(cadence_months IN(1,12)), due_day integer NOT NULL CHECK(due_day BETWEEN 1 AND 31),
 starts_on date NOT NULL, ends_on date, active boolean NOT NULL DEFAULT true,
 revision integer NOT NULL DEFAULT 1, content_hash text NOT NULL, confirmed_at timestamptz NOT NULL DEFAULT now(),
 last_generated_through date, UNIQUE(user_id,series_key,direction),
 CHECK(ends_on IS NULL OR ends_on>=starts_on),CHECK((value_kind='fixed' AND amount IS NOT NULL AND amount>0 AND amount<=100000000)OR(value_kind='variable' AND amount IS NULL))
);
CREATE TABLE public.lts_recurring_occurrence_v366 (
 plan_id uuid NOT NULL REFERENCES public.lts_recurring_plan_v366(id), revision integer NOT NULL,
 event_date date NOT NULL, source_id bigint NOT NULL, source_index integer NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(plan_id,revision,event_date)
);
ALTER TABLE public.lts_recurring_plan_v366 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lts_recurring_occurrence_v366 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_recurring_plan_v366,public.lts_recurring_occurrence_v366 FROM PUBLIC,anon,authenticated;
CREATE POLICY owner_read ON public.lts_recurring_plan_v366 FOR SELECT TO authenticated USING(user_id=(select auth.uid()));
CREATE POLICY owner_read ON public.lts_recurring_occurrence_v366 FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.lts_recurring_plan_v366 p WHERE p.id=plan_id AND p.user_id=(select auth.uid())));
GRANT SELECT ON public.lts_recurring_plan_v366,public.lts_recurring_occurrence_v366 TO authenticated;

CREATE FUNCTION public.lts_recurring_materialize_v366(p_user_id uuid,p_as_of date DEFAULT CURRENT_DATE)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $$
DECLARE p record; g record; d date; horizon date; base_rows jsonb; idx integer; source_id bigint; added integer:=0; skipped integer:=0;
BEGIN
 IF p_user_id IS NULL OR p_as_of IS NULL OR p_as_of<current_date THEN RAISE EXCEPTION 'Invalid recurrence scope';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text,166));
 horizon:=(date_trunc('year',p_as_of)+interval '5 years'-interval '1 day')::date;
 IF NOT EXISTS(SELECT 1 FROM public.lts_recurring_plan_v366 WHERE user_id=p_user_id AND active AND value_kind='fixed' AND(ends_on IS NULL OR ends_on>p_as_of))THEN RETURN jsonb_build_object('created',0,'horizon_end',horizon);END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO base_rows FROM public.lts_corrected_cashflow_operational_v1(p_user_id,p_as_of+1,horizon)x;
 SELECT coalesce(max(b.idx),0) INTO idx FROM public.evento_base b WHERE b.usuario_id=p_user_id;
 FOR p IN SELECT * FROM public.lts_recurring_plan_v366 WHERE user_id=p_user_id AND active AND value_kind='fixed' AND(ends_on IS NULL OR ends_on>p_as_of) ORDER BY series_key,direction LOOP
  FOR g IN SELECT m::date month_start FROM generate_series(date_trunc('month',greatest(p.starts_on,p_as_of+1)),date_trunc('month',least(coalesce(p.ends_on,horizon),horizon)),interval '1 month')m LOOP
   IF p.cadence_months=12 AND extract(month FROM g.month_start)<>extract(month FROM p.starts_on)THEN CONTINUE;END IF;
   d:=g.month_start+least(p.due_day,extract(day FROM g.month_start+interval '1 month'-interval '1 day')::integer)-1;
   IF d<=p_as_of OR d<p.starts_on OR d>coalesce(p.ends_on,horizon) OR d>horizon THEN CONTINUE;END IF;
   IF EXISTS(SELECT 1 FROM public.lts_recurring_occurrence_v366 o WHERE o.plan_id=p.id AND o.revision=p.revision AND o.event_date=d)
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(base_rows)x WHERE public.lts_forecast_series_key_v1(x->>'description')=p.series_key AND ((x->>'signed_amount')::numeric>0)=(p.direction='entrada') AND date_trunc('month',(x->>'event_date')::date)=date_trunc('month',d))
    OR EXISTS(SELECT 1 FROM public.lts_projection_replacement_rule r WHERE r.user_id=p_user_id AND r.active AND r.action='suppress_legacy' AND r.replacement_source='owner_confirmation' AND r.date_from<=d AND r.date_to>=d AND public.lts_forecast_series_key_v1(r.description_exact)=p.series_key AND coalesce(r.evidence->>'policy_action','')<>'revise')
   THEN skipped:=skipped+1;CONTINUE;END IF;
   idx:=idx+1;
   INSERT INTO public.evento_base(usuario_id,idx,dados) VALUES(p_user_id,idx,jsonb_strip_nulls(jsonb_build_object('dia',d,'desc',p.description,'conta',p.account,'valor',p.amount,'efeito',p.direction,'categoria',p.category,'v166_suggested_confirmation',true,'v366_plan',p.id,'v366_revision',p.revision,'value_basis','owner_confirmed_fixed_planning_amount')))
   RETURNING id INTO source_id;
   INSERT INTO public.lts_recurring_occurrence_v366(plan_id,revision,event_date,source_id,source_index)VALUES(p.id,p.revision,d,source_id,idx);
   added:=added+1;
  END LOOP;
  UPDATE public.lts_recurring_plan_v366 SET last_generated_through=least(coalesce(ends_on,horizon),horizon) WHERE id=p.id;
 END LOOP;
 IF added>0 THEN
  INSERT INTO public.audit_log(user_id,action,entity_type,details)VALUES(p_user_id,'recurring_horizon_extended_v366','recurring_plan',jsonb_build_object('as_of',p_as_of,'horizon_end',horizon,'created',added,'existing_or_cancelled',skipped));
  DELETE FROM public.lts_flow_future_read_cache WHERE user_id=p_user_id;
  DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=p_user_id;
 END IF;
 RETURN jsonb_build_object('created',added,'existing_or_cancelled',skipped,'horizon_end',horizon);
END $$;
REVOKE ALL ON FUNCTION public.lts_recurring_materialize_v366(uuid,date) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION lts_recurring_private_v366.save_plan(p_expected_revision integer,p_input jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $$
#variable_conflict use_column
<<args>>
DECLARE u uuid:=public.lts_browser_assert_user_v1(); p public.lts_recurring_plan_v366%rowtype; key text; content jsonb; digest text; result jsonb;
 description text:=nullif(trim(p_input->>'description'),'');direction text:=p_input->>'direction';account text:=p_input->>'account';kind text:=p_input->>'value_kind';
 value numeric;cadence integer;day integer;start_date date;end_date date;category text;is_active boolean;
BEGIN
 IF p_input IS NULL OR jsonb_typeof(p_input)<>'object' OR p_expected_revision IS NULL OR p_expected_revision<0 THEN RAISE EXCEPTION 'Configuração inválida.';END IF;
 IF length(description) NOT BETWEEN 2 AND 180 OR description IS NULL OR direction NOT IN('entrada','saida') OR direction IS NULL OR account NOT IN('Itaú','Bradesco','C6') OR account IS NULL OR kind NOT IN('fixed','variable') OR kind IS NULL THEN RAISE EXCEPTION 'Confira descrição, conta, tipo e valor.';END IF;
 value:=CASE WHEN kind='fixed' THEN (p_input->>'amount')::numeric END;cadence:=(p_input->>'cadence_months')::integer;day:=(p_input->>'due_day')::integer;start_date:=(p_input->>'starts_on')::date;end_date:=nullif(p_input->>'ends_on','')::date;is_active:=coalesce((p_input->>'active')::boolean,true);
 IF (kind='fixed' AND(value IS NULL OR value<=0 OR value>100000000 OR value<>round(value,2)))OR cadence IS NULL OR cadence NOT IN(1,12) OR day IS NULL OR day NOT BETWEEN 1 AND 31 OR start_date IS NULL OR start_date<=current_date OR start_date>(current_date+interval '15 years')::date OR(end_date IS NOT NULL AND(end_date<start_date OR end_date>(current_date+interval '15 years')::date))THEN RAISE EXCEPTION 'Informe valor, frequência e vigência futuros válidos.';END IF;
 category:=public.lts_category_name_v290(u,nullif(trim(p_input->>'category'),''));
 IF category IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.lts_category_catalog c WHERE c.user_id=u AND c.active AND c.category=args.category)THEN RAISE EXCEPTION 'Escolha uma classificação existente.';END IF;
 key:=public.lts_forecast_series_key_v1(description);
 IF key ~ 'transfer|internal_transfer' OR public.lts_v178_norm(category) ~ 'transfer' THEN RAISE EXCEPTION 'Transferências próprias exigem as duas contas e não podem gerar uma entrada ou saída isolada.';END IF;
 IF kind='fixed' AND(key ~ '^card_' OR key IN('salary','salary_advance','bonus','13o salario','vehicle_tax','property_tax_cipo'))THEN RAISE EXCEPTION 'Esta série exige valores por competência; revise as ocorrências e a fonte antes de fixar um valor.';END IF;
 content:=jsonb_build_object('description',description,'direction',direction,'account',account,'value_kind',kind,'amount',value,'cadence_months',cadence,'due_day',day,'starts_on',start_date,'ends_on',end_date,'category',category,'active',is_active);digest:=md5(content::text);
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text,166));
 SELECT * INTO p FROM public.lts_recurring_plan_v366 WHERE user_id=u AND series_key=key AND lts_recurring_plan_v366.direction=args.direction FOR UPDATE;
 IF FOUND AND p.content_hash=digest THEN RETURN jsonb_build_object('ok',true,'already_saved',true,'revision',p.revision,'created',0);END IF;
 IF coalesce(p.revision,0)<>p_expected_revision THEN RAISE EXCEPTION 'A série foi atualizada. Reabra para conferir antes de salvar.';END IF;
 IF p.id IS NOT NULL THEN
  INSERT INTO public.lts_projection_replacement_rule(id,user_id,source_table,description_exact,account_exact,date_from,date_to,action,replacement_source,replacement_ref,reason,evidence,active)
  SELECT 'v366:'||p.id||':'||o.revision||':'||o.event_date,u,'evento_base',b.dados->>'desc',b.dados->>'conta',o.event_date,o.event_date,'suppress_legacy','owner_confirmation','evento_base:'||o.source_index,'Recorrência revisada pelo usuário',jsonb_build_object('scope','one_original_occurrence','legacy_ref','evento_base:'||o.source_index,'plan_id',p.id,'policy_action',CASE WHEN is_active THEN 'revise' ELSE 'cancel' END),true
  FROM public.lts_recurring_occurrence_v366 o JOIN public.evento_base b ON b.id=o.source_id AND b.usuario_id=u AND b.idx=o.source_index
  WHERE o.plan_id=p.id AND o.event_date>=start_date AND o.event_date>current_date
  ON CONFLICT(id)DO NOTHING;
 END IF;
 INSERT INTO public.lts_recurring_plan_v366(user_id,series_key,description,direction,account,category,value_kind,amount,cadence_months,due_day,starts_on,ends_on,active,content_hash)
 VALUES(u,key,description,direction,account,category,kind,value,cadence,day,start_date,end_date,is_active,digest)
 ON CONFLICT(user_id,series_key,direction)DO UPDATE SET description=excluded.description,account=excluded.account,category=excluded.category,value_kind=excluded.value_kind,amount=excluded.amount,cadence_months=excluded.cadence_months,due_day=excluded.due_day,starts_on=excluded.starts_on,ends_on=excluded.ends_on,active=excluded.active,revision=lts_recurring_plan_v366.revision+1,content_hash=excluded.content_hash,confirmed_at=clock_timestamp(),last_generated_through=NULL RETURNING * INTO p;
 result:=public.lts_recurring_materialize_v366(u,current_date);
 INSERT INTO public.audit_log(user_id,action,entity_type,entity_id,details)VALUES(u,'recurring_plan_confirmed_v366','recurring_plan',p.id::text,content||jsonb_build_object('revision',p.revision,'created',result->'created'));
 DELETE FROM public.lts_flow_future_read_cache WHERE user_id=u;DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=u;
 RETURN result||jsonb_build_object('ok',true,'revision',p.revision,'plan_id',p.id);
END $$;
REVOKE ALL ON FUNCTION lts_recurring_private_v366.save_plan(integer,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_recurring_private_v366.save_plan(integer,jsonb) TO authenticated;
CREATE FUNCTION public.lts_browser_recurring_plan_save_v366(p_expected_revision integer,p_input jsonb)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT lts_recurring_private_v366.save_plan(p_expected_revision,p_input);
$$;
REVOKE ALL ON FUNCTION public.lts_browser_recurring_plan_save_v366(integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_recurring_plan_save_v366(integer,jsonb) TO authenticated;

CREATE FUNCTION lts_recurring_private_v366.read_plans() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1();BEGIN RETURN jsonb_build_object('ok',true,'rules',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY description)FROM public.lts_recurring_plan_v366 p WHERE user_id=u),'[]'));END $$;
REVOKE ALL ON FUNCTION lts_recurring_private_v366.read_plans() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_recurring_private_v366.read_plans() TO authenticated;
CREATE FUNCTION public.lts_browser_recurring_plans_v366() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT lts_recurring_private_v366.read_plans();
$$;
REVOKE ALL ON FUNCTION public.lts_browser_recurring_plans_v366() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_recurring_plans_v366() TO authenticated;

CREATE FUNCTION public.lts_recurring_maintenance_v366() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $$
DECLARE u uuid;results jsonb:='[]';BEGIN FOR u IN SELECT DISTINCT user_id FROM public.lts_recurring_plan_v366 WHERE active AND value_kind='fixed' LOOP results:=results||jsonb_build_array(public.lts_recurring_materialize_v366(u,current_date));END LOOP;RETURN results;END $$;
REVOKE ALL ON FUNCTION public.lts_recurring_maintenance_v366() FROM PUBLIC,anon,authenticated;
SELECT cron.schedule('lts_recurring_horizon_daily_v366','1 3 * * *','select public.lts_recurring_maintenance_v366();');
