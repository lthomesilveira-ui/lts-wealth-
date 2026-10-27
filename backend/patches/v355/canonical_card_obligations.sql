-- Read-only projection of the same cycles used by the invoice composition screen.
CREATE FUNCTION public.lts_card_obligations_v355(p_cards jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE card jsonb;cycle jsonb;item jsonb;ordered jsonb;targets jsonb:='[]';following jsonb:='[]';
 paid jsonb:='[]';credits jsonb:='[]';future_rows jsonb:='[]';open_rows jsonb;closed_rows jsonb;
 family text;month_date date;due date;value numeric;valid boolean;complete boolean:=true;
 next_row jsonb;targets_total numeric;open_total numeric;closed_total numeric;following_total numeric;
BEGIN
 IF p_as_of IS NULL OR jsonb_typeof(p_cards)IS DISTINCT FROM'object'
 OR p_cards->>'version'IS DISTINCT FROM'card-cycles-v226'
 OR jsonb_typeof(p_cards->'cards')IS DISTINCT FROM'array'THEN
 RETURN jsonb_build_object('version','card-obligations-v355','complete',false,'status','source_unavailable',
 'next_due',NULL,'open_cycles_total',NULL,'closed_or_due_total',NULL,'next_obligations_total',NULL,
 'following_cycles_total',NULL,'open_cycles','[]'::jsonb,'closed_or_due','[]'::jsonb,'targets','[]'::jsonb);
 END IF;
 complete:=p_cards->'complete'='true'::jsonb;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_cards->'cards')c GROUP BY c->>'family' HAVING count(*)<>1)THEN complete:=false;END IF;
 FOR card IN SELECT c FROM jsonb_array_elements(p_cards->'cards')c LOOP
  family:=nullif(card->>'family','');future_rows:='[]';
  IF family IS NULL OR jsonb_typeof(card->'cycles')IS DISTINCT FROM'array'THEN complete:=false;CONTINUE;END IF;
  IF card->'complete'='false'::jsonb THEN complete:=false;END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(card->'cycles')c GROUP BY coalesce(c->>'month',c->>'reference_month')HAVING count(*)<>1)THEN complete:=false;CONTINUE;END IF;
  FOR cycle IN SELECT c FROM jsonb_array_elements(card->'cycles')c LOOP
   valid:=true;month_date:=NULL;due:=NULL;value:=NULL;
   IF jsonb_typeof(cycle)IS DISTINCT FROM'object'
   OR(cycle?'settlement_confirmed'AND jsonb_typeof(cycle->'settlement_confirmed')NOT IN('boolean','null'))
   OR(cycle?'family'AND cycle->>'family'IS DISTINCT FROM family)THEN complete:=false;CONTINUE;END IF;
   BEGIN
    IF coalesce(cycle->>'month',cycle->>'reference_month','')!~'^[0-9]{4}-(0[1-9]|1[0-2])-01$'THEN valid:=false;
    ELSE month_date:=coalesce(cycle->>'month',cycle->>'reference_month')::date;END IF;
    IF cycle?'month'AND cycle?'reference_month'AND cycle->>'month'IS DISTINCT FROM cycle->>'reference_month'THEN valid:=false;END IF;
    IF nullif(cycle->>'due_date','')IS NOT NULL THEN
     IF cycle->>'due_date'!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'THEN valid:=false;ELSE due:=(cycle->>'due_date')::date;END IF;
    END IF;
    IF jsonb_typeof(cycle->'amount')='number'THEN value:=(cycle->>'amount')::numeric;
    ELSIF cycle->'amount'IS DISTINCT FROM'null'::jsonb AND cycle?'amount'THEN valid:=false;END IF;
   EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN valid:=false;END;
   IF NOT valid THEN complete:=false;CONTINUE;END IF;
   item:=jsonb_build_object('family',family,'card_name',coalesce(card->>'name',card->>'card_name',family),
    'bank',card->'bank','account',card->'bank','reference_month',month_date,'month',month_date,
    'due_date',due,'amount',value,'basis',cycle->'basis','payment_status',cycle->'payment_status',
    'settlement_confirmed',cycle->'settlement_confirmed','amount_kind','invoice_or_cycle_total');
   IF cycle->'settlement_confirmed'='true'::jsonb THEN paid:=paid||jsonb_build_array(item);CONTINUE;END IF;
   IF cycle->'complete'='false'::jsonb OR value IS NULL THEN complete:=false;END IF;
   IF value<=0 THEN credits:=credits||jsonb_build_array(item);CONTINUE;END IF;
   item:=item||jsonb_build_object('state',CASE WHEN due IS NULL THEN'due_date_unconfirmed'
    WHEN due<p_as_of THEN'payment_evidence_needed'WHEN due=p_as_of THEN'due_today'ELSE'open_cycle'END);
   future_rows:=future_rows||jsonb_build_array(item);
  END LOOP;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'month',x->>'due_date'),'[]')INTO ordered FROM jsonb_array_elements(future_rows)x;
  IF jsonb_array_length(ordered)>0 THEN
   targets:=targets||jsonb_build_array(ordered->0);
   SELECT following||coalesce(jsonb_agg(x),'[]')INTO following FROM jsonb_array_elements(ordered)WITH ORDINALITY t(x,n)WHERE n>1;
  END IF;
 END LOOP;
 SELECT coalesce(jsonb_agg(x ORDER BY coalesce(x->>'due_date',x->>'month'),x->>'month',x->>'family'),'[]')INTO targets FROM jsonb_array_elements(targets)x;
 SELECT coalesce(jsonb_agg(x)FILTER(WHERE x->>'state'<>'payment_evidence_needed'),'[]'),
 coalesce(jsonb_agg(x)FILTER(WHERE x->>'state'='payment_evidence_needed'),'[]'),
 coalesce(sum((x->>'amount')::numeric),0),
 coalesce(sum((x->>'amount')::numeric)FILTER(WHERE x->>'state'<>'payment_evidence_needed'),0),
 coalesce(sum((x->>'amount')::numeric)FILTER(WHERE x->>'state'='payment_evidence_needed'),0)
 INTO open_rows,closed_rows,targets_total,open_total,closed_total FROM jsonb_array_elements(targets)x;
 SELECT coalesce(sum((x->>'amount')::numeric),0)INTO following_total FROM jsonb_array_elements(following)x;
 next_row:=CASE WHEN complete THEN coalesce(targets->0,'{}')ELSE NULL END;
 RETURN jsonb_build_object('version','card-obligations-v355','as_of',p_as_of,'complete',coalesce(complete,false),
 'status',CASE WHEN complete THEN'ready'ELSE'source_incomplete'END,'next_due',next_row,'targets',targets,
 'open_cycles',open_rows,'closed_or_due',closed_rows,'canonical_paid_cycles',paid,'nonpayable_cycles',credits,
 'open_cycles_total',CASE WHEN complete THEN open_total END,
 'closed_or_due_total',CASE WHEN complete THEN closed_total END,
 'next_obligations_total',CASE WHEN complete THEN targets_total END,
 'following_cycles_total',CASE WHEN complete THEN following_total END,
 'selection_basis','oldest_unsettled_cycle_per_card_then_oldest_due_or_unconfirmed_month',
 'payment_rule','only_settlement_confirmed_closes_a_cycle',
 'amount_rule','cycle_total_is_not_an_inferred_remaining_balance');
END $fn$;

CREATE FUNCTION public.lts_card_operating_overlay_v355(p_legacy jsonb,p_cards jsonb,p_as_of date)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path=''AS $fn$
 SELECT coalesce(p_legacy,'{}')||public.lts_card_obligations_v355(p_cards,p_as_of)
$fn$;

CREATE FUNCTION public.lts_product_card_operating_overlay_v355(p_payload jsonb,p_cards jsonb,p_as_of date)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path=''AS $fn$
 WITH projection AS(SELECT public.lts_card_obligations_v355(p_cards,p_as_of)j)
 SELECT p_payload||jsonb_build_object('card_operating',coalesce(p_payload->'card_operating','{}')||projection.j,
 'dashboard_cockpit',coalesce(p_payload->'dashboard_cockpit','{}')||jsonb_build_object('cards',coalesce(p_payload#>'{dashboard_cockpit,cards}','{}')||projection.j))FROM projection
$fn$;

REVOKE ALL ON FUNCTION public.lts_card_obligations_v355(jsonb,date),public.lts_card_operating_overlay_v355(jsonb,jsonb,date),public.lts_product_card_operating_overlay_v355(jsonb,jsonb,date)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_obligations_v355(jsonb,date),public.lts_card_operating_overlay_v355(jsonb,jsonb,date),public.lts_product_card_operating_overlay_v355(jsonb,jsonb,date)TO service_role;
