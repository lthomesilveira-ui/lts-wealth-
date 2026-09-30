-- Every expense cell is derived from the same classified rows as the report.
-- Revenue and extraordinary income retain their approved source and presentation.
CREATE OR REPLACE FUNCTION public.lts_browser_monthly_v229(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' SET statement_timeout='18s' AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); b jsonb; groups jsonb; computed numeric; month_amounts jsonb; coverage jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid monthly range';END IF;
 b:=public.lts_browser_monthly_balance_v6(p_from,p_to);
 WITH r AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows(u,p_from,p_to)),
 months AS(SELECT (m#>>'{}')::date month_key FROM jsonb_array_elements(b->'months') m),
 a AS(SELECT management_group label,competence_month month_key,sum(amount) amount,count(*) source_rows FROM r WHERE coverage_mode<>'card_invoice_aggregate_fallback' GROUP BY 1,2),
 labels AS(SELECT label,sum(amount) total,sum(source_rows) source_rows FROM a GROUP BY label),
 monthly AS(SELECT competence_month month_key,sum(amount) amount FROM r GROUP BY 1),
 unknown AS(SELECT competence_month month_key,sum(amount) amount FROM r WHERE coverage_mode='card_invoice_aggregate_fallback' GROUP BY 1)
 SELECT coalesce(jsonb_agg(jsonb_build_object('label',l.label,'total',round(l.total,2),'source_rows',l.source_rows,
 'monthly',(SELECT jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) ORDER BY m.month_key)
 FROM months m LEFT JOIN a ON a.month_key=m.month_key AND a.label=l.label)) ORDER BY l.total DESC,l.label),'[]'),
 (SELECT round(coalesce(sum(amount),0),2) FROM r),
 (SELECT coalesce(jsonb_agg(to_jsonb(monthly)),'[]') FROM monthly),
 jsonb_build_object('total',(SELECT coalesce(sum(amount),0) FROM unknown),
 'monthly',(SELECT coalesce(jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(x.amount,0)) ORDER BY m.month_key),'[]')
 FROM months m LEFT JOIN unknown x ON x.month_key=m.month_key))
 INTO groups,computed,month_amounts,coverage FROM labels l;
 b:=b||jsonb_build_object('monthly_totals',coalesce((SELECT jsonb_agg(m||jsonb_build_object(
 'expenses',coalesce((a->>'amount')::numeric,0),
 'operating_balance',(m->>'revenue')::numeric-coalesce((a->>'amount')::numeric,0),
 'cash_after_extraordinary',(m->>'revenue')::numeric+coalesce((m->>'extraordinary')::numeric,0)-coalesce((a->>'amount')::numeric,0)) ORDER BY m->>'month')
 FROM jsonb_array_elements(b->'monthly_totals') m LEFT JOIN jsonb_array_elements(month_amounts) a ON a->>'month_key'=m->>'month'),'[]'),
 'totals',(b->'totals')||jsonb_build_object('expenses',computed,
 'operating_balance',(b#>>'{totals,revenue}')::numeric-computed,
 'cash_after_extraordinary',(b#>>'{totals,revenue}')::numeric+coalesce((b#>>'{totals,extraordinary}')::numeric,0)-computed),
 'expense_unclassified_card_coverage',coverage);
 IF abs(computed-coalesce((SELECT sum((m->>'expenses')::numeric) FROM jsonb_array_elements(b->'monthly_totals') m),0))>.005
 OR abs(computed-coalesce((SELECT sum((g->>'total')::numeric) FROM jsonb_array_elements(groups)g),0)-(coverage->>'total')::numeric)>.005
 THEN RAISE EXCEPTION 'monthly classified rows, months and total do not reconcile';END IF;
 RETURN b||jsonb_build_object('version','monthly-v178-person-integrity','expense_groups',groups,'expense_total_verified',computed);
END $function$;
NOTIFY pgrst,'reload schema';
