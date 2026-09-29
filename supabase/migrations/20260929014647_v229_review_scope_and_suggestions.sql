-- Preserve established historical classifications; only unconsumed future cycles
-- supplement the expense review queue. Historic source gaps are not new decisions.
DO $$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('public.lts_v229_review_rows(uuid,date,date)'::regprocedure);
 definition:=replace(definition,'WHERE NOT is_payment AND amount>0','WHERE NOT is_payment AND amount>0 AND reference_month>date_trunc(''month'',current_date)::date');
 EXECUTE definition;
END $$;
CREATE TABLE public.lts_v229_review_suggestion (
 user_id uuid NOT NULL REFERENCES auth.users(id),source_table text NOT NULL,source_ref text NOT NULL,
 category text,note text NOT NULL,source_url text,basis text NOT NULL,researched_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,source_table,source_ref)
);
ALTER TABLE public.lts_v229_review_suggestion ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_suggestions ON public.lts_v229_review_suggestion FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
REVOKE ALL ON public.lts_v229_review_suggestion FROM public,anon,authenticated;
GRANT SELECT ON public.lts_v229_review_suggestion TO authenticated;
GRANT ALL ON public.lts_v229_review_suggestion TO service_role;
DO $$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('public.lts_browser_expense_review_queue_v229(date,date,integer,integer,text)'::regprocedure);
 definition:=replace(definition,'''suggestion'',(SELECT CASE WHEN count(DISTINCT category)=1',
 '''suggestion'',coalesce((SELECT jsonb_build_object(''category'',s.category,''note'',s.note,''source_url'',s.source_url,''basis'',s.basis) FROM public.lts_v229_review_suggestion s WHERE s.user_id=v_uid AND s.source_table=page.source_table AND s.source_ref=page.source_ref),(SELECT CASE WHEN count(DISTINCT category)=1');
 definition:=replace(definition,'''sem categoria''))', '''sem categoria'')))');
 EXECUTE definition;
END $$;
