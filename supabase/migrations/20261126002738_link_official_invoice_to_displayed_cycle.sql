-- Attach bank evidence to the matching displayed cycle without altering its amount or settlement.
DO $migration$
DECLARE
 definition text := pg_get_functiondef('public.lts_card_cycles_presentation_v355(uuid)'::regprocedure);
 anchor text := 'RETURN public.lts_card_documentary_payment_presentation_v272(u,j||jsonb_build_object(''cards'',cards,''recurring_estimates_separate'',true));';
 replacement text := $body$
 WITH marked_cards AS (
   SELECT card_order, card || jsonb_build_object('cycles', annotated.cycles) AS value
   FROM jsonb_array_elements(cards) WITH ORDINALITY AS listing(card,card_order)
   CROSS JOIN LATERAL (
     SELECT coalesce(jsonb_agg(
       CASE WHEN c->>'basis' = 'documented_snapshot'
                 AND jsonb_typeof(c->'amount') = 'number'
                 AND bank.matches = 1 AND bank.amount = (c->>'amount')::numeric
            THEN c || jsonb_build_object('official_invoice_received',true)
            ELSE c END ORDER BY cycle_order
     ),'[]'::jsonb) AS cycles
     FROM jsonb_array_elements(card->'cycles') WITH ORDINALITY AS scheduled(c,cycle_order)
     LEFT JOIN LATERAL (
       SELECT count(*) AS matches, max(s.signed_amount) AS amount
       FROM public.lts_open_finance_staging s
       WHERE c->>'basis' = 'documented_snapshot' AND s.user_id = u
         AND s.resource_type = 'invoice' AND s.provider_deleted_at IS NULL
         AND s.posting_date = CASE WHEN c->>'due_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (c->>'due_date')::date END
         AND s.normalized_payload->>'due_date' = c->>'due_date'
         AND s.normalized_payload->>'currency' = 'BRL'
         AND nullif(s.normalized_payload->>'provider_id','') IS NOT NULL
         AND nullif(card->>'last4','') = s.normalized_payload->>'last4'
         AND public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) = card->>'family'
     ) bank ON true
   ) annotated
 ) SELECT jsonb_agg(value ORDER BY card_order) INTO cards FROM marked_cards;
 $body$;
BEGIN
 IF strpos(definition,'''official_invoice_received''')>0 THEN RETURN; END IF;
 IF strpos(definition,anchor)=0 THEN RAISE EXCEPTION 'Unexpected card presentation definition'; END IF;
 EXECUTE replace(definition,anchor,replacement||anchor);
END
$migration$;
