CREATE TABLE public.lts_v229_card_recurring_commitment (
 user_id uuid NOT NULL REFERENCES auth.users(id),family text NOT NULL,description text NOT NULL,
 amount numeric NOT NULL CHECK(amount>0),category text NOT NULL,evidence jsonb NOT NULL,active boolean NOT NULL DEFAULT true,
 PRIMARY KEY(user_id,family,description)
);
ALTER TABLE public.lts_v229_card_recurring_commitment ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_commitments ON public.lts_v229_card_recurring_commitment FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
REVOKE ALL ON public.lts_v229_card_recurring_commitment FROM public,anon,authenticated;
GRANT SELECT ON public.lts_v229_card_recurring_commitment TO authenticated;
GRANT ALL ON public.lts_v229_card_recurring_commitment TO service_role;
CREATE FUNCTION public.lts_browser_card_cycles_v229() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); j jsonb; cards jsonb;
BEGIN
 j:=public.lts_browser_card_cycles_v226();
 SELECT jsonb_agg(c||CASE WHEN coalesce(jsonb_array_length(c->'cycles'),0)=0 AND hint.amount IS NOT NULL THEN jsonb_build_object(
 'cycles',jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',null,
 'amount',hint.amount,'basis','user_confirmed_recurring_estimate','items',hint.items))) ELSE '{}'::jsonb END ORDER BY ord) INTO cards
 FROM jsonb_array_elements(j->'cards') WITH ORDINALITY src(c,ord)
 LEFT JOIN LATERAL(SELECT sum(h.amount) amount,jsonb_agg(jsonb_build_object('description',h.description,'amount',h.amount,'last4',c->>'last4','category',h.category,'category_basis','user_confirmed_recurring_estimate')) items
 FROM public.lts_v229_card_recurring_commitment h WHERE h.user_id=u AND h.active AND h.family=c->>'family') hint ON true;
 RETURN j||jsonb_build_object('cards',cards,'recurring_estimates_separate',true);
END $$;
REVOKE ALL ON FUNCTION public.lts_browser_card_cycles_v229() FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_card_cycles_v229() TO authenticated,service_role;
