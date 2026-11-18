-- Only confirmed recurring expenses use these rules. Existing payment and invoice rows are read-only.
CREATE OR REPLACE FUNCTION lts_recurring_private_v469.open_cash_end_v479(cards jsonb, asof date)
RETURNS date LANGUAGE sql IMMUTABLE SET search_path='' AS $sql$
 SELECT (date_trunc('month',coalesce(max((cy->>'due_date')::date),
     (date_trunc('month',asof)+interval '1 month')::date))+interval '1 month - 1 day')::date
 FROM jsonb_array_elements(coalesce(cards->'cards','[]')) c
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(c->'cycles','[]')) cy
 WHERE c->>'family'='aeternum' AND (cy->>'month')::date=date_trunc('month',asof)::date
   AND (cy->>'due_date')::date>=asof
$sql$;

-- A posted charge covers the occurrence, including when its actual price differs.
-- Unbilled commitments use the original issuer near cash settlement. Later months keep the chosen planning card.
CREATE OR REPLACE FUNCTION lts_recurring_private_v469.card_commitments_v479(
 result jsonb, cards jsonb, asof date, policy jsonb
) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE
 stop_date date:=lts_recurring_private_v469.open_cash_end_v479(cards,asof);
 m date; d date; target numeric; known numeric; seen numeric; extra numeric; trusted boolean; official boolean;
 cfg jsonb; s jsonb; c jsonb; cycle jsonb; row0 jsonb; row1 jsonb; period jsonb; annual jsonb;
 periods jsonb; series_out jsonb:='[]'; events jsonb:=result->'events'; revised jsonb; card_count int; cycle_count int;
BEGIN
 IF policy->'card_commitments' IS NULL THEN RETURN result; END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(result->'series') LOOP
  SELECT x INTO cfg FROM jsonb_array_elements(policy->'card_commitments') x WHERE x->>'series'=s->>'series_key';
  IF cfg IS NULL THEN series_out:=series_out||jsonb_build_array(s); CONTINUE; END IF;
  target:=(s->>'reference_amount_brl')::numeric; periods:=coalesce(s->'coverage','[]');
  SELECT count(*),min(x::text)::jsonb INTO card_count,c FROM jsonb_array_elements(cards->'cards')x WHERE x->>'family'=cfg->>'family';
  FOR m IN SELECT mon::date FROM generate_series(greatest((cfg->>'starts_on')::date,date_trunc('month',asof)::date),stop_date,interval '1 month') mon LOOP
   SELECT x INTO row0 FROM jsonb_array_elements(periods)x WHERE date_trunc('month',(x->>'event_date')::date)::date=m;
   SELECT count(*),min(x::text)::jsonb INTO cycle_count,cycle FROM jsonb_array_elements(coalesce(c->'cycles','[]'))x
     WHERE date_trunc('month',(x->>'due_date')::date)::date=m;
   d:=coalesce((cycle->>'due_date')::date,m+least((cfg->>'due_day')::int,extract(day from m+interval '1 month - 1 day')::int)-1);
   IF d<=asof OR d>(result->>'horizon_end')::date THEN CONTINUE; END IF;
   trusted:=coalesce(cards->>'complete','false')='true' AND card_count=1 AND cycle_count<=1 AND coalesce(c->>'complete','true')='true'
     AND coalesce((row0->>'trusted')::boolean,true);
   official:=coalesce((cycle->>'official_invoice_received')::boolean,false) OR cycle->>'invoice_source_id' IS NOT NULL
          OR coalesce(cycle->>'basis','')='open_finance_invoice_v263';
   SELECT coalesce(sum((i->>'amount')::numeric),0) INTO seen FROM jsonb_array_elements(coalesce(cycle->'items','[]'))i
     WHERE coalesce(i->>'is_payment','false')<>'true' AND (i->>'amount')::numeric>0
       AND nullif(i->>'source_id','') IS NOT NULL AND i->>'last4'=cfg->>'last4'
       AND i->>'description'~*(cfg->>'merchant_pattern');
   known:=CASE WHEN seen>0 THEN seen WHEN official THEN coalesce((row0->>'known_brl')::numeric,0) ELSE 0 END;
   extra:=CASE WHEN NOT trusted THEN NULL WHEN official OR known>0 THEN 0 ELSE target END;
   row1:=jsonb_build_object('event_date',d,'account',cfg->>'account','known_brl',CASE WHEN trusted THEN known END,
     'additional_brl',extra,'trusted',trusted,'budget_total_brl',CASE WHEN extra=0 THEN known ELSE target END,
     'status',CASE WHEN NOT trusted THEN 'requires_review' WHEN extra=0 THEN 'open_cycle_known_only' ELSE 'confirmed_recurring_forecast' END);
   SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]') INTO periods FROM jsonb_array_elements(periods) WITH ORDINALITY a(x,ord)
    WHERE date_trunc('month',(x->>'event_date')::date)::date<>m;
   periods:=periods||jsonb_build_array(row1);
   SELECT coalesce(jsonb_agg(e ORDER BY ord),'[]') INTO events FROM jsonb_array_elements(events) WITH ORDINALITY a(e,ord)
    WHERE NOT coalesce((e->>'source'='planning_projection_v412' AND e->>'source_ref'=ANY(ARRAY[
      'projection:v469:'||(cfg->>'id')||':'||(m+2)::text,
      'projection:v479:'||(cfg->>'id')||':'||d::text])),false);
   IF extra>0 THEN
    revised:=lts_recurring_private_v469.forecast(cfg->>'id',cfg->>'description',cfg->>'account',extra,d)
      ||jsonb_build_object('source_ref','projection:v479:'||(cfg->>'id')||':'||d::text,'series_key',s->>'series_key',
         'confidence','owner_confirmed_specific_subscription','card_family',cfg->>'family',
         'category',cfg->>'category','classification_confirmed',true);
    events:=events||jsonb_build_array(revised);
   END IF;
  END LOOP;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'event_date'),'[]') INTO periods FROM jsonb_array_elements(periods)x;
  SELECT coalesce(jsonb_agg(jsonb_build_object('year',y,'partial_year',y=extract(year from asof)::int,
   'budget_total_brl',CASE WHEN ok THEN total END,'additional_brl',CASE WHEN ok THEN more END) ORDER BY y),'[]') INTO annual
   FROM (SELECT extract(year FROM (x->>'event_date')::date)::int y,bool_and((x->>'trusted')::boolean) ok,
   sum(greatest((x->>'known_brl')::numeric,(x->>'budget_total_brl')::numeric)) total,
   sum((x->>'additional_brl')::numeric) more FROM jsonb_array_elements(periods)x GROUP BY 1) z;
  IF EXISTS(SELECT FROM jsonb_array_elements(periods)x WHERE x->>'trusted'='false') AND NOT (s->'warnings' ? 'unreconciled_periods') THEN
   s:=jsonb_set(s,'{warnings}',s->'warnings'||'["unreconciled_periods"]'::jsonb);
  END IF;
  series_out:=series_out||jsonb_build_array(s||jsonb_build_object('coverage',periods,'annual_totals',annual));
 END LOOP;
 RETURN result||jsonb_build_object('series',series_out,'events',events);
END $f$;

-- Only posted checking-account debits can settle a direct recurring obligation.
CREATE OR REPLACE FUNCTION lts_recurring_private_v469.posted_bank_v479(u uuid, asof date, policy jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $sql$
 WITH bills AS MATERIALIZED (SELECT x FROM jsonb_array_elements(policy->'bank_commitments') x),
 receipts AS (
  SELECT DISTINCT ON (r.x->>'id',b.provider,b.provider_record_id)
   r.x->>'id' AS bill, b.posting_date AS paid_on,b.provider||':'||b.provider_record_id AS receipt
  FROM public.lts_open_finance_staging b JOIN bills r
    ON public.lts_v178_norm(b.institution_name)=public.lts_v178_norm(r.x->>'institution')
    AND b.description_raw ~* (r.x->>'merchant_pattern')
    AND (NOT (r.x ? 'accepted_amounts') OR EXISTS (
      SELECT FROM jsonb_array_elements_text(r.x->'accepted_amounts') a WHERE a::numeric=-b.signed_amount))
  WHERE b.user_id=u AND b.resource_type='transaction' AND b.currency='BRL' AND b.signed_amount<0
    AND b.posting_date BETWEEN (r.x->>'starts_on')::date AND asof
    AND b.provider_deleted_at IS NULL AND b.normalized_payload->>'status'='POSTED'
    AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND b.provider_record_id IS NOT NULL
  ORDER BY r.x->>'id',b.provider,b.provider_record_id,b.last_seen_at DESC,b.id
 ) SELECT coalesce(jsonb_agg(to_jsonb(receipts) ORDER BY bill,paid_on,receipt),'[]') FROM receipts
$sql$;

-- A confirmed occurrence survives its estimated due date until an actual payment arrives.
-- Keep the original month even if its unpaid cash row moves past a month boundary.
CREATE OR REPLACE FUNCTION lts_recurring_private_v469.bank_commitments_v479(
 result jsonb, baseline jsonb, posted jsonb, asof date, policy jsonb
) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE
 cfg jsonb; p jsonb; existing jsonb; known jsonb; applicable jsonb; document_refs jsonb; prices jsonb;
 used_receipts text[]:='{}'; settled text; original date; cash_day date; m date; horizon date:=(result->>'horizon_end')::date;
 planned jsonb:=coalesce(result->'events','[]'); replacements jsonb:=coalesce(result->'replacement_refs','[]');
 remove_refs text[]:='{}'; appended jsonb:='[]'; bill text; prefix text; vref text; amount numeric; carried jsonb;
BEGIN
 FOR cfg IN SELECT value FROM jsonb_array_elements(policy->'bank_commitments') LOOP
  bill:=cfg->>'id'; prefix:='projection:v479:bank_'||bill||':';
  SELECT coalesce(jsonb_agg(x),'[]') INTO existing FROM jsonb_array_elements(planned)x
   WHERE x->>'account'=cfg->>'account' AND x->>'source'='planning_projection_v412'
     AND ((x->>'source_ref')^@prefix OR (x->>'source_ref')^@(cfg->>'source_prefix'));
  SELECT coalesce(jsonb_agg(x),'[]') INTO known FROM jsonb_array_elements(baseline)x
   WHERE (x->>'signed_amount')::numeric<0 AND x->>'account'=cfg->>'account' AND x->>'description'=cfg->>'source_description'
     AND x->>'source'='legacy_fix86' AND NOT(replacements ? (x->>'source_ref'));
  FOR m IN SELECT d::date FROM generate_series(date_trunc('month',(cfg->>'starts_on')::date),
      least(horizon,coalesce((cfg->>'ends_on')::date,horizon)),interval '1 month') d LOOP
   original:=CASE WHEN cfg->>'timing'='third_business_day' THEN lts_recurring_private_v469.third_business_day(m)
       ELSE m+least((cfg->>'due_day')::int,extract(day FROM m+interval '1 month -1 day')::int)-1 END;
   SELECT coalesce(jsonb_agg(x),'[]') INTO applicable FROM jsonb_array_elements(existing)x
    WHERE date_trunc('month',coalesce((x->>'original_date')::date,(x->>'event_date')::date))::date=m;
   SELECT coalesce(jsonb_agg(x),'[]') INTO document_refs FROM jsonb_array_elements(known)x
    WHERE date_trunc('month',(x->>'event_date')::date)::date=m;
   original:=coalesce((document_refs->0->>'event_date')::date,(applicable->0->>'original_date')::date,original);
   IF original NOT BETWEEN (cfg->>'starts_on')::date AND least(horizon,coalesce((cfg->>'ends_on')::date,horizon)) THEN CONTINUE; END IF;
   SELECT x->>'receipt' INTO settled FROM jsonb_array_elements(posted)x
    WHERE x->>'bill'=bill AND x->>'receipt'<>ALL(used_receipts)
     AND (x->>'paid_on')::date BETWEEN original-coalesce((cfg->>'early_days')::int,7) AND asof
    ORDER BY x->>'paid_on',x->>'receipt' LIMIT 1;
   IF settled IS NOT NULL THEN
    used_receipts:=array_append(used_receipts,settled);
    FOR p IN SELECT value FROM jsonb_array_elements(applicable) LOOP
     remove_refs:=array_append(remove_refs,p->>'source_ref');
    END LOOP;
    FOR p IN SELECT value FROM jsonb_array_elements(document_refs) WHERE (value->>'event_date')::date>asof LOOP
     replacements:=replacements||jsonb_build_array(p->>'source_ref');
    END LOOP;
    CONTINUE;
   END IF;
   IF original>asof AND jsonb_array_length(document_refs)>0 THEN
    FOR p IN SELECT value FROM jsonb_array_elements(applicable) LOOP remove_refs:=array_append(remove_refs,p->>'source_ref'); END LOOP;
    CONTINUE;
   END IF;
   IF original>asof AND jsonb_array_length(applicable)>0 THEN CONTINUE; END IF;
   cash_day:=greatest(original,asof+1);
   IF cash_day>horizon THEN CONTINUE; END IF;
   FOR p IN SELECT value FROM jsonb_array_elements(applicable) LOOP
    remove_refs:=array_append(remove_refs,p->>'source_ref');
   END LOOP;
   SELECT x INTO prices FROM jsonb_array_elements(cfg->'prices')x WHERE (x->>'from')::date<=original
    ORDER BY x->>'from' DESC LIMIT 1;
   amount:=coalesce(-(document_refs->0->>'signed_amount')::numeric,-(applicable->0->>'signed_amount')::numeric,
    round((prices->>'amount')::numeric*power(1+coalesce((prices->>'annual_rate')::numeric,0),
      extract(year FROM original)::int-extract(year FROM (prices->>'from')::date)::int),2));
   IF amount IS NULL OR amount<=0 THEN RAISE EXCEPTION 'Confira o valor do compromisso recorrente.'; END IF;
   vref:=prefix||original::text;
   carried:=lts_recurring_private_v469.forecast('bank_'||bill,cfg->>'description'||
     CASE WHEN original<=asof THEN ' · pagamento a confirmar' ELSE '' END,cfg->>'account',amount,cash_day)
     ||jsonb_build_object('source_ref',vref,'original_date',original,'series_key',cfg->>'series_key',
      'confidence',CASE WHEN original<=asof THEN 'confirmed_recurring_overdue' ELSE 'owner_confirmed_recurring' END,
      'category',cfg->>'category','center_cost',cfg->>'center_cost','classification_confirmed',true);
   appended:=appended||jsonb_build_array(carried);
  END LOOP;
 END LOOP;
 SELECT coalesce(jsonb_agg(x ORDER BY n),'[]') INTO planned FROM jsonb_array_elements(planned) WITH ORDINALITY a(x,n)
  WHERE coalesce(x->>'source_ref','')<>ALL(remove_refs);
 RETURN result||jsonb_build_object('events',planned||appended,'replacement_refs',replacements);
END $f$;

-- A price can be estimated for a confirmed bill. Only purely statistical occurrences skip the current month.
CREATE OR REPLACE FUNCTION lts_recurring_private_v469.skip_current_estimate_v479(policy jsonb, rule jsonb, d date, asof date)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $sql$
 SELECT coalesce(policy->>'skip_unconfirmed_current_expense_estimates'='true' AND rule->>'direction'='expense'
   AND rule->>'method'='history_total_budget' AND coalesce(rule->>'occurrence_confirmed','false')<>'true'
   AND date_trunc('month',d)=date_trunc('month',asof),false)
$sql$;

REVOKE ALL ON FUNCTION lts_recurring_private_v469.open_cash_end_v479(jsonb,date),
 lts_recurring_private_v469.card_commitments_v479(jsonb,jsonb,date,jsonb),
 lts_recurring_private_v469.bank_commitments_v479(jsonb,jsonb,jsonb,date,jsonb),
 lts_recurring_private_v469.posted_bank_v479(uuid,date,jsonb),
 lts_recurring_private_v469.skip_current_estimate_v479(jsonb,jsonb,date,date)
 FROM PUBLIC,anon,authenticated,service_role;
