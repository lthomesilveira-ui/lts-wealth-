CREATE OR REPLACE FUNCTION public.lts_expense_presentation_v353(p_user_id uuid, p_from date, p_to date, p_scope jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH all_rows AS MATERIALIZED(
 SELECT v.*,v.taxonomy->>'macrogroup'macro,v.taxonomy->>'group'grp,v.taxonomy->>'category'cat,
 coalesce(v.row_payload->>'property_code','__missing__')property_key,
 (v.row_payload->>'amount')::numeric amount FROM public.lts_expense_view_rows_v353(p_user_id,p_from,p_to)v),
 filtered AS MATERIALIZED(SELECT*FROM all_rows WHERE public.lts_expense_scope_v353(row_payload,taxonomy,center_cost,p_scope)),
 leaves AS MATERIALIZED(
 SELECT CASE WHEN p_scope->>'view'='property'THEN property_key ELSE ''END root,macro,grp,cat,
 sum(greatest(amount,0))gross,-sum(least(amount,0))comp,sum(amount)net,count(*)n FROM filtered GROUP BY 1,2,3,4),
 groups AS MATERIALIZED(SELECT root,macro,grp,sum(gross)gross,sum(comp)comp,sum(net)net,sum(n)::bigint n FROM leaves GROUP BY 1,2,3),
 macros AS MATERIALIZED(SELECT root,macro,sum(gross)gross,sum(comp)comp,sum(net)net,sum(n)::bigint n FROM groups GROUP BY 1,2),
 roots AS MATERIALIZED(SELECT root,sum(gross)gross,sum(comp)comp,sum(net)net,sum(n)::bigint n FROM macros GROUP BY 1),
 group_nodes AS MATERIALIZED(
 SELECT g.root,g.macro,g.grp,public.lts_expense_node_v353(g.grp,p_scope||CASE WHEN g.root<>''THEN jsonb_build_object('property',g.root)ELSE'{}'END||jsonb_build_object('macrogroup',g.macro,'group',g.grp),g.gross,g.comp,g.net,g.n,
 (SELECT jsonb_agg(public.lts_expense_node_v353(l.cat,p_scope||CASE WHEN l.root<>''THEN jsonb_build_object('property',l.root)ELSE'{}'END||jsonb_build_object('macrogroup',l.macro,'group',l.grp,'category',l.cat),l.gross,l.comp,l.net,l.n,'[]')ORDER BY l.net DESC,l.cat)FROM leaves l WHERE l.root=g.root AND l.macro=g.macro AND l.grp=g.grp))node FROM groups g),
 macro_nodes AS MATERIALIZED(
 SELECT m.root,m.macro,public.lts_expense_node_v353(m.macro,p_scope||CASE WHEN m.root<>''THEN jsonb_build_object('property',m.root)ELSE'{}'END||jsonb_build_object('macrogroup',m.macro),m.gross,m.comp,m.net,m.n,
 (SELECT jsonb_agg(g.node ORDER BY(g.node->>'net')::numeric DESC,g.grp)FROM group_nodes g WHERE g.root=m.root AND g.macro=m.macro))node FROM macros m),
 root_nodes AS MATERIALIZED(
 SELECT r.root,public.lts_expense_node_v353(CASE r.root WHEN '__missing__'THEN'Sem bem informado'WHEN'cipo396'THEN'CIPÓ 396'WHEN'other_property'THEN'Outro imóvel'ELSE'Bem informado na origem'END,p_scope||jsonb_build_object('property',r.root),r.gross,r.comp,r.net,r.n,
 (SELECT jsonb_agg(m.node ORDER BY(m.node->>'net')::numeric DESC,m.macro)FROM macro_nodes m WHERE m.root=r.root))node FROM roots r)
 SELECT jsonb_build_object('version','expense-presentation-v353','period',jsonb_build_object('from',p_from,'to',p_to),'scope',p_scope,
 'summary',jsonb_build_object('gross',round(coalesce(sum(greatest(amount,0)),0),2),'compensations',round(coalesce(-sum(least(amount,0)),0),2),'net',round(coalesce(sum(amount),0),2),'rows',count(*),'zero_rows',count(*)FILTER(WHERE amount=0)),
 'nodes',CASE WHEN p_scope->>'view'='property'THEN coalesce((SELECT jsonb_agg(node ORDER BY(node->>'net')::numeric DESC,root)FROM root_nodes),'[]')ELSE coalesce((SELECT jsonb_agg(node ORDER BY(node->>'net')::numeric DESC,macro)FROM macro_nodes),'[]')END,
 'cells',coalesce((SELECT jsonb_agg(to_jsonb(x)ORDER BY macrogroup,group_name,category,property,person,center_cost)FROM(
 SELECT macro macrogroup,grp group_name,cat category,property_key property,
 coalesce(row_payload->>'beneficiary','__missing__')person,coalesce(center_cost,'__missing__')center_cost,
 (taxonomy->>'is_tax')::boolean is_tax,CASE WHEN coalesce(row_payload->>'source_table','') LIKE '%card%' OR coalesce(row_payload->>'coverage_mode','') LIKE 'card_%' THEN 'card' ELSE 'account' END payment,sum(greatest(amount,0))gross,-sum(least(amount,0))compensations,sum(amount)net,count(*)rows
 FROM filtered GROUP BY 1,2,3,4,5,6,7,8)x),'[]'),
 'dimensions',jsonb_build_object(
 'property',coalesce((SELECT jsonb_agg(jsonb_build_object('key',k,'label',CASE k WHEN'__missing__'THEN'Sem bem informado'WHEN'cipo396'THEN'CIPÓ 396'WHEN'other_property'THEN'Outro imóvel'ELSE'Bem informado na origem'END)ORDER BY k)FROM(SELECT DISTINCT property_key k FROM all_rows)x),'[]'),
 'person',coalesce((SELECT jsonb_agg(jsonb_build_object('key',k,'label',CASE WHEN k='__missing__'THEN'Pessoa não informada'ELSE k END)ORDER BY k)FROM(SELECT DISTINCT coalesce(row_payload->>'beneficiary','__missing__')k FROM all_rows)x),'[]'),
 'center_cost',coalesce((SELECT jsonb_agg(jsonb_build_object('key',k,'label',CASE WHEN k='__missing__'THEN'Centro de custo não informado'ELSE k END)ORDER BY k)FROM(SELECT DISTINCT coalesce(center_cost,'__missing__')k FROM all_rows)x),'[]')))
 FROM filtered
$function$;
