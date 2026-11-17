BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='10s';
DO $patch$
DECLARE target regprocedure;d text;attrs jsonb;u uuid;
BEGIN
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN RAISE EXCEPTION 'V464_WORKER_ACTIVE';END IF;
 FOR u IN SELECT user_id FROM lts_product_refresh_private_v415.queue LOOP IF NOT pg_try_advisory_xact_lock(hashtextextended(u::text,415)) THEN RAISE EXCEPTION 'V464_WORKER_LOCK_BUSY';END IF;END LOOP;
 target:='public.lts_expense_scope_v353(jsonb,jsonb,text,jsonb)'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='c35227076488ff258cc19a9c5f34dea2' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_expense_scope_v353(r jsonb, t jsonb, c text, s jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
 SELECT coalesce(
 (nullif(s->>'macrogroup','')IS NULL OR t->>'macrogroup'=s->>'macrogroup')AND
 (nullif(s->>'group','')IS NULL OR t->>'group'=s->>'group')AND
 (nullif(s->>'category','')IS NULL OR t->>'category'=s->>'category')AND
 (nullif(s->>'property','')IS NULL OR coalesce(r->>'property_code','__missing__')=s->>'property')AND
 (nullif(s->>'person','')IS NULL OR coalesce(r->>'beneficiary','__missing__')=s->>'person')AND
 (nullif(s->>'center_cost','')IS NULL OR coalesce(c,'__missing__')=s->>'center_cost')AND
 (coalesce(s->>'sign','net')='net'OR s->>'sign'='gross'AND(r->>'amount')::numeric>0 OR s->>'sign'='compensations'AND(r->>'amount')::numeric<0)AND
 (coalesce(s->>'view','type')<>'tax'OR t->>'is_tax'='true'),false)
$function$$definition$;
 ELSIF md5(d)<>'fa7b6cb4a3173bbe927ceece060002ad' THEN RAISE EXCEPTION 'V464_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'fa7b6cb4a3173bbe927ceece060002ad' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V464_FUNCTION_CONTRACT_CHANGED';END IF;
 target:='public.lts_expense_presentation_v353(uuid,date,date,jsonb)'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='9edede9a68a7a50f1d3cef18dd1ee2b0' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_expense_presentation_v353(p_user_id uuid, p_from date, p_to date, p_scope jsonb DEFAULT '{}'::jsonb)
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
 (taxonomy->>'is_tax')::boolean is_tax,sum(greatest(amount,0))gross,-sum(least(amount,0))compensations,sum(amount)net,count(*)rows
 FROM filtered GROUP BY 1,2,3,4,5,6,7)x),'[]'),
 'dimensions',jsonb_build_object(
 'property',coalesce((SELECT jsonb_agg(jsonb_build_object('key',k,'label',CASE k WHEN'__missing__'THEN'Sem bem informado'WHEN'cipo396'THEN'CIPÓ 396'WHEN'other_property'THEN'Outro imóvel'ELSE'Bem informado na origem'END)ORDER BY k)FROM(SELECT DISTINCT property_key k FROM all_rows)x),'[]'),
 'person',coalesce((SELECT jsonb_agg(jsonb_build_object('key',k,'label',CASE WHEN k='__missing__'THEN'Pessoa não informada'ELSE k END)ORDER BY k)FROM(SELECT DISTINCT coalesce(row_payload->>'beneficiary','__missing__')k FROM all_rows)x),'[]'),
 'center_cost',coalesce((SELECT jsonb_agg(jsonb_build_object('key',k,'label',CASE WHEN k='__missing__'THEN'Centro de custo não informado'ELSE k END)ORDER BY k)FROM(SELECT DISTINCT coalesce(center_cost,'__missing__')k FROM all_rows)x),'[]')))
 FROM filtered
$function$$definition$;
 ELSIF md5(d)<>'ac2b6ab32167cce65809b20e0550cbf0' THEN RAISE EXCEPTION 'V464_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'ac2b6ab32167cce65809b20e0550cbf0' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V464_FUNCTION_CONTRACT_CHANGED';END IF;
 target:='public.lts_browser_expense_detail_v353(date,date,jsonb,integer,integer,text)'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='d7a5222e9b6da4c58e83b362900d013c' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_browser_expense_detail_v353(p_from date, p_to date, p_scope jsonb DEFAULT '{}'::jsonb, p_offset integer DEFAULT 0, p_limit integer DEFAULT 500, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;base jsonb;result_rows jsonb;rev text;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to>current_date OR p_from<date '2013-10-10' OR p_offset<0 OR p_limit NOT BETWEEN 1 AND 10000 OR jsonb_typeof(p_scope)IS DISTINCT FROM 'object'OR(p_scope-ARRAY['macrogroup','group','category','property','person','center_cost','sign','view'])<>'{}'OR coalesce(p_scope->>'view','type')NOT IN('type','property','tax')OR coalesce(p_scope->>'sign','net')NOT IN('net','gross','compensations')THEN RAISE EXCEPTION 'invalid detail range or filters';END IF;
 rev:=public.lts_card_read_start_v269(u);
 WITH context AS MATERIALIZED(
 SELECT source_table,source_ref,min(nullif(trim(center_cost),''))center_cost FROM public.lts_expense_effective_rows_v176(u,p_from,p_to)GROUP BY source_table,source_ref HAVING count(*)=1),
 r AS MATERIALIZED(
 SELECT x.*,t.taxonomy,CASE WHEN c.center_cost IN('Não atribuído','Não identificado')THEN NULL ELSE c.center_cost END center_cost
 FROM public.lts_v229_expense_rows(u,p_from,p_to)x
 LEFT JOIN context c ON c.source_table=x.source_table AND c.source_ref=x.source_ref
 CROSS JOIN LATERAL(SELECT public.lts_expense_taxonomy_v353(x.category,x.property_component,x.management_group)taxonomy)t
 WHERE public.lts_expense_scope_v353(to_jsonb(x),t.taxonomy,CASE WHEN c.center_cost IN('Não atribuído','Não identificado')THEN NULL ELSE c.center_cost END,p_scope)
 ), filtered AS MATERIALIZED(
  SELECT * FROM r WHERE nullif(trim(p_query),'') IS NULL OR strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,beneficiary,raw_reference,category)),public.lts_v178_norm(trim(p_query)))>0
 ), page AS MATERIALIZED(SELECT * FROM filtered ORDER BY event_date DESC,amount DESC,row_key OFFSET p_offset LIMIT p_limit)
 SELECT jsonb_build_object('version','expense-detail-v178','from',p_from,'to',p_to,'scope',p_scope,
  'total',(SELECT round(coalesce(sum(amount),0),2) FROM r),'row_count',(SELECT count(*) FROM r),
  'matched_count',(SELECT count(*) FROM filtered),'matched_total',(SELECT round(coalesce(sum(amount),0),2) FROM filtered),'offset',p_offset,
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM filtered) THEN p_offset+p_limit END,
  'revision',(SELECT md5(coalesce(jsonb_agg(to_jsonb(x)ORDER BY x.row_key),'[]'::jsonb)::text)FROM r x),
  'rows',coalesce((SELECT jsonb_agg(jsonb_build_object(
   'key',p.row_key,'date',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.purchase_date ELSE p.event_date END,
   'event_date',p.event_date,'transaction_date',p.transaction_date,'period',p.competence_month,
   'date_kind',CASE WHEN (p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%') AND p.purchase_date IS NULL THEN 'month' ELSE 'day' END,
   'description',p.description,'account_source',p.account_source,'beneficiary',p.beneficiary,'reference',p.raw_reference,
   'amount',p.amount,'category',p.management_group,'current_category',p.category,'original_category',p.category,'taxonomy',p.taxonomy,'center_cost',p.center_cost,'component',p.property_component,
   'subgroup',p.management_subgroup,'status',p.identity_status,'property_code',p.property_code,'source_table',p.source_table,'source_ref',p.source_ref,
   'coverage_mode',p.coverage_mode,'can_classify',p.coverage_mode NOT IN ('card_invoice_aggregate_fallback','card_workbook_signed_adjustment_v235'),
   'invoice_family',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN coalesce(public.lts_card_family_v226(p.account_source,p.account_source),(SELECT public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) FROM public.lts_open_finance_staging s WHERE s.user_id=u AND p.source_table='lts_open_finance_staging' AND s.id::text=p.source_ref LIMIT 1)) END,
   'invoice_month',CASE WHEN p.source_table LIKE '%card%' OR p.coverage_mode LIKE 'card_%' THEN p.competence_month END,
   'document_status',CASE WHEN p.coverage_mode='card_invoice_aggregate_fallback' THEN 'composition_missing' END,
   'source_audit',CASE WHEN a.source_ref IS NOT NULL THEN jsonb_build_object(
    'file',a.source_file,'sheet',a.source_sheet,'rows',a.source_rows,'source_amount',a.source_signed_amount,
    'status',CASE WHEN a.source_signed_amount<0 THEN 'signed_adjustment' ELSE a.composition_status END,
    'detail_rows',a.detail_rows,'detail_total',a.detail_total,'difference',a.detail_difference,
    'note',CASE WHEN a.source_signed_amount<0 THEN 'Ajuste negativo registrado na planilha; não é nova compra nem comprovação de crédito bancário.'
     WHEN a.composition_status='unreconciled_detail' THEN 'A composição já foi recebida na planilha, mas ainda difere do total desta fatura.'
     ELSE 'A planilha registra o total ou parte da fatura. As compras individuais não foram localizadas nas fontes conferidas.' END) END,
   'source_identity',CASE WHEN e.source_ref IS NOT NULL THEN jsonb_build_object('category',e.original_category,'description',e.original_description,'sheet',e.source_sheet,'rows',e.source_rows,'note','Categoria conferida com a planilha original.') END,
   'review_question',CASE WHEN p.identity_status='pending' THEN 'Confirme a classificação deste lançamento.' END
  ) ORDER BY p.event_date DESC,p.amount DESC,p.row_key) FROM page p LEFT JOIN public.lts_card_history_source_audit_v235 a ON a.user_id=u
 AND a.source_table=p.source_table AND a.source_ref=p.source_ref AND a.event_date=p.event_date
 AND a.source_signed_amount=round(p.amount,2)
 LEFT JOIN public.lts_workbook_identity_evidence_v232 e ON e.user_id=u AND e.source_table=p.source_table AND e.source_ref=p.source_ref),'[]'::jsonb),
  'components','[]'::jsonb
 ) INTO result;
 base:=result;
 WITH items AS MATERIALIZED(SELECT e.r,e.ord FROM jsonb_array_elements(base->'rows') WITH ORDINALITY e(r,ord)),
 summary AS MATERIALIZED(
 SELECT c.parent_key,count(*) n,count(*) FILTER(WHERE c.amount<>0) nonzero,sum(c.amount) amount
 FROM public.lts_card_history_item_v346 c JOIN items i ON i.r->>'key'=c.parent_key
 WHERE c.user_id=u GROUP BY c.parent_key
 )
 SELECT coalesce(jsonb_agg(i.r || CASE WHEN i.r->>'coverage_mode' IN
 ('card_category_allocated_history','card_category_allocated_workbook_v176','card_invoice_aggregate_fallback')
 THEN jsonb_build_object('composition',jsonb_build_object(
 'status',public.lts_card_history_status_v346(p.signature=public.lts_card_history_signature_v346(i.r),p.parent_key IS NOT NULL,(i.r->>'amount')::numeric,s.amount,s.n),
 'count',coalesce(s.n,0),'nonzero_count',coalesce(s.nonzero,0))) ELSE '{}'::jsonb END ORDER BY i.ord),'[]'::jsonb)
 INTO result_rows FROM items i LEFT JOIN public.lts_card_history_parent_v346 p ON p.user_id=u AND p.parent_key=i.r->>'key'
 LEFT JOIN summary s ON s.parent_key=i.r->>'key';
 RETURN public.lts_card_read_finish_v269(u,rev,(base-'rows')||jsonb_build_object('rows',result_rows,'version','expense-detail-v353'));
END $function$$definition$;
 ELSIF md5(d)<>'50c40fde481733d256566166dff4d7cb' THEN RAISE EXCEPTION 'V464_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'50c40fde481733d256566166dff4d7cb' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V464_FUNCTION_CONTRACT_CHANGED';END IF;
 target:='public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='0c56f411fe56800f28348a544f9ff6d7' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_expense_taxonomy_v353(p_category text, p_component text, p_management text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE c text:=translate(lower(coalesce(p_category,'')),'áàâãéêíóôõúç','aaaaeeiooouc');
 k text:=translate(lower(coalesce(p_component,'')),'áàâãéêíóôõúç','aaaaeeiooouc');
 m text:=translate(lower(coalesce(p_management,'')),'áàâãéêíóôõúç','aaaaeeiooouc');
 original_c text:=c;
 macro text;g text;cat text:=nullif(trim(regexp_replace(coalesce(p_category,''),'[[:space:]]*[-—–][[:space:]]*O Parque$','','i')),'');
 tax boolean:=c~'tribut|imposto|iptu|ipva|itbi|licenci'OR k~'imposto';
BEGIN
 -- Preserve the original category and person dimension; normalize only the routing key.
 c:=btrim(regexp_replace(c,'^(lucas|larissa|benjamin|rafiki|marino)[[:space:]]*[-—–][[:space:]]*','','i'));
 CASE
 WHEN c='cartao — detalhe historico nao recuperado'THEN macro:='Sem composição individual';g:='Cartões históricos';
 WHEN c~'^(credito|ajustes de fatura)'THEN macro:='Compensações';g:='Créditos e ajustes da origem';
 WHEN k~'aquisicao'OR c~'financiamento[[:space:]]+(de[[:space:]]+)?(imobiliario|imovel)|consorcio'THEN macro:='Patrimônio e financiamentos';g:='Aquisição imobiliária';
 WHEN c~'financiamento[[:space:]]+(de[[:space:]]+)?veiculo'OR m~'financiamento.*veiculo'THEN macro:='Patrimônio e financiamentos';g:='Aquisição e financiamento de veículo';
 WHEN c~'^emprestimos?$'OR m~'^emprestimos?$'THEN macro:='Patrimônio e financiamentos';g:='Empréstimos';
 WHEN c~'^emprestimos$|compromissos financeiros'THEN macro:='Compromissos financeiros';g:='Empréstimos e compromissos';
 WHEN c~'ipva|licenci|veiculos - tributos'THEN macro:='Mobilidade';g:='Tributos';
 WHEN tax AND(k~'imposto'OR c~'imovel|iptu|itbi')THEN macro:='Moradia';g:='Tributos';
 WHEN tax THEN macro:='Tributos e encargos';g:='Tributos sem bem detalhado';
 WHEN k~'obra|reforma'OR c~'obra|reforma|ar-condicionado|camas e estofados|cortinas|deck|envidracamento|espelhos e box|jardim|loucas e metais|marcenaria|mesa e banho|moveis|porta quarto|projeto|revestimento|serralheria|eletrodomesticos'THEN macro:='Moradia';g:='Obra, reforma e equipamentos';
 WHEN k~'moradia'OR c~'condominio|energia|enel|seguro residencial|^moradia$|casa - utensilios'THEN macro:='Moradia';g:='Uso e manutenção';
 WHEN c~'restaurante|ifood|rappi|^alimentacao|^bebidas$|mercado|supermercado'AND c !~ 'mercado[[:space:]]+livre'THEN macro:='Alimentação';g:=CASE WHEN c~'restaurante|ifood|rappi'THEN'Refeições'ELSE'Compras e bebidas'END;
 WHEN c~'saude|farmacia|congelamento de ovulos'THEN macro:='Saúde';g:='Atendimento e medicamentos';
 WHEN c~'educacao|aulas|english class|desenvolvimento|lide futuro'THEN macro:='Educação';g:='Ensino e desenvolvimento';
 WHEN c~'combustivel|estacionamento|pedagio|taxi|uber|veiculos -|seguro carro|seguro jeep|aluguel carro|^carro$'THEN macro:='Mobilidade';g:='Uso de veículos';
 WHEN c~'company car|despesas organon'THEN macro:='Trabalho';g:='Despesas profissionais';
 WHEN c~'^vestuario$|cabelereiro|lavanderia'THEN macro:='Cuidados pessoais';g:='Vestuário e cuidados';
 WHEN c~'viage(m|ns)|passagem aerea|^hotel$|duty free|^mala$'THEN macro:='Viagens';g:='Viagens e estadias';
 WHEN c~'lazer|passeio|rock in rio|socio rei|gympass|natacao'THEN macro:='Lazer e bem-estar';g:='Atividades e lazer';
 WHEN c~'casamento|batizado|^eventos$'THEN macro:='Eventos';g:='Eventos pessoais';
 WHEN c~'assinaturas|spotify|google|apple|armazenamento|telefone|iphone'THEN macro:='Comunicações e serviços digitais';g:='Serviços e equipamentos';
 WHEN c~'tarifas|juros|^iof$|^anuidade$'THEN macro:='Serviços financeiros';g:='Taxas e encargos';
 WHEN c~'^seguro|^seguros'THEN macro:='Seguros';g:='Proteção pessoal';
 WHEN c~'^presentes$|^doacoes$|^religiao$'THEN macro:='Vida pessoal e familiar';g:='Presentes e contribuições';
 WHEN c~'^mercado[[:space:]]+livre$'THEN macro:='Outras despesas';g:='Categorias da origem';
 WHEN original_c~'^(lucas|larissa|benjamin|rafiki|marino)([[:space:]]|$)|^familia$'THEN macro:='Vida pessoal e familiar';g:='Tipo de gasto não detalhado';cat:='Despesas pessoais sem tipo informado';
 ELSE macro:='Outras despesas';g:='Categorias da origem';
 END CASE;
 IF c='cipo 396'AND k~'aquisicao'THEN cat:='Pagamentos de aquisição sem composição';END IF;
 RETURN jsonb_build_object('macrogroup',macro,'group',g,'category',coalesce(cat,'Categoria não informada'),'is_tax',tax);
END $function$$definition$;
 ELSIF md5(d)<>'5679e50ce6dc0fe2486977754effccd7' THEN RAISE EXCEPTION 'V464_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'5679e50ce6dc0fe2486977754effccd7' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V464_FUNCTION_CONTRACT_CHANGED';END IF;
 target:='public.lts_browser_expenses_v229(date,date)'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='f36b21764272fabd0fb8a08073d1aa3e' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_browser_expenses_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); result jsonb; source_epoch bigint;fingerprint text;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid expense range';END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='expenses-v353:'||source_epoch||':'||current_date::text;
 SELECT c.payload INTO result FROM public.lts_v229_read_cache c WHERE c.user_id=u AND c.kind='expenses_v251'
 AND c.as_of=current_date AND c.from_date=p_from AND c.to_date=p_to AND c.source_fingerprint=fingerprint
 AND c.refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);END IF;
 result:=public.lts_browser_expenses_v229_engine_v251(p_from,p_to);
 result:=result||jsonb_build_object('presentation',public.lts_expense_presentation_v353(u,p_from,p_to,'{}'));
 IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  BEGIN
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
   VALUES(u,'expenses_v251',current_date,p_from,p_to,result,clock_timestamp(),fingerprint)
   ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
  EXCEPTION WHEN read_only_sql_transaction THEN NULL;
  END;
 END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);
END $function$$definition$;
 ELSIF md5(d)<>'20cdbb632667f9393ba7a782fcf93dcc' THEN RAISE EXCEPTION 'V464_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'20cdbb632667f9393ba7a782fcf93dcc' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V464_FUNCTION_CONTRACT_CHANGED';END IF;
 target:='lts_product_refresh_private_v415.review_profile_v450()'::regprocedure;
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO d,attrs FROM pg_proc p WHERE p.oid=target;
 IF md5(d)='21e3ec09d2322aeb876d1136f9bbe2e2' THEN EXECUTE $definition$CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_profile_v450()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ SELECT $manifest${
  "producers": [
    {
      "md5": "3900ca2edf2711a189defff21baff121",
      "signature": "public.lts_current_evidence_position_v1(uuid)"
    },
    {
      "md5": "206c6ae57f42d3872a5526b6074bb9f2",
      "signature": "public.lts_corrected_cashflow_fix86_v1(uuid,date,date)"
    },
    {
      "md5": "b2a59acca5d7b3bda6c4d7623ae5576c",
      "signature": "public.lts_corrected_cashflow_fix86_v2(uuid,date,date)"
    },
    {
      "md5": "5107d8d47f89f04c44d77941b05900e2",
      "signature": "public.lts_canonical_description_fix86_v1(text)"
    },
    {
      "md5": "20d7ec098884b5a8ac06116781d8f3ac",
      "signature": "public.lts_corrected_cashflow_fix86_v3(uuid,date,date)"
    },
    {
      "md5": "bf16d2f5f23eac410cf1516674048d59",
      "signature": "public.lts_internal_transfer_legs_fix86_v1(uuid,date,date)"
    },
    {
      "md5": "c994cbe994eb1a22d43a79793b0f14c9",
      "signature": "public.lts_corrected_cashflow_fix86_v4(uuid,date,date)"
    },
    {
      "md5": "e9e5f710fe7144af4117a4a11688890d",
      "signature": "public.lts_historical_effective_cash_v2(uuid,date,date)"
    },
    {
      "md5": "6676a65ce3e8e41b678e62f0b489251a",
      "signature": "public.lts_historical_effective_cash_v3(uuid,date,date)"
    },
    {
      "md5": "1219e04b97f74a5190639e3d3f7d9618",
      "signature": "public.lts_flow_current_effective_v1(uuid,date,date)"
    },
    {
      "md5": "1c6fd4b90d14f41339b91d2db104319b",
      "signature": "public.lts_confirmation_key_for_flow_ref_v1(uuid,text)"
    },
    {
      "md5": "b5d0f51f32e389f903e2b6e2785cf63f",
      "signature": "public.lts_historical_effective_cash_v4(uuid,date,date)"
    },
    {
      "md5": "5ba5df8823c2986f3d94cee05433abe9",
      "signature": "public.lts_corrected_cashflow_operational_v1(uuid,date,date)"
    },
    {
      "md5": "2fe93166917418b9155a52c3ca39db74",
      "signature": "public.lts_canonical_category_v1(uuid,text)"
    },
    {
      "md5": "a6f95cef0dc87e44756cd08a476339bc",
      "signature": "public.lts_payroll_withholding_effective_v1(uuid,date,date)"
    },
    {
      "md5": "9330a40ad6071900cda300452a1c213b",
      "signature": "public.lts_historical_effective_cash_v5(uuid,date,date)"
    },
    {
      "md5": "0b181ac93fc98827cdf834043f214df9",
      "signature": "public.lts_flow_past_operational_v2(uuid,date,date)"
    },
    {
      "md5": "7280cf73ab6e4dd3003ab7ec66f5c013",
      "signature": "public.lts_corrected_cashflow_fix86_v5(uuid,date,date)"
    },
    {
      "md5": "2d94c51243c430e1ddfdcc8b98783c72",
      "signature": "public.lts_expense_management_group_v3(text,text,text,text,text)"
    },
    {
      "md5": "1be62bc2e068051f98f14c5fa2c828c3",
      "signature": "public.lts_expense_management_subgroup_v2(text,text,text,text,text)"
    },
    {
      "md5": "21af2733b8d46a42325233fa8e37257b",
      "signature": "public.lts_expense_effective_rows_v176(uuid,date,date)"
    },
    {
      "md5": "8bd38f36cd64245bdf8a84464a298839",
      "signature": "public.lts_v178_norm(text)"
    },
    {
      "md5": "affd7eefd5f929701be548b3da275f64",
      "signature": "public.lts_card_family_key_v181(text,text)"
    },
    {
      "md5": "c35a0e6a6941157964a79eb5f5b31fcf",
      "signature": "public.lts_card_invoice_account_v181(text)"
    },
    {
      "md5": "6c2360ed89bd0ee12de2e662de1ffce2",
      "signature": "public.lts_open_finance_current_bank_position_v1(uuid)"
    },
    {
      "md5": "b9d8f8f0db01f7a9a2310398ec5776bc",
      "signature": "public.lts_current_evidence_position_v2(uuid)"
    },
    {
      "md5": "848c0d41a080916b4c0a6b74dcc17a82",
      "signature": "public.lts_card_family_v226(text,text)"
    },
    {
      "md5": "ef996716f66fc61e5e466ce1636d6713",
      "signature": "public.lts_card_merchant_key_v226(text)"
    },
    {
      "md5": "d98e3a726149666eddf069cef8ad7a4e",
      "signature": "public.lts_card_source_rows_v226(uuid)"
    },
    {
      "md5": "71d0beacbd4803f0e14bbc2885e7247e",
      "signature": "public.lts_card_cycles_v226(uuid)"
    },
    {
      "md5": "9baacf4fb28872f1c17c00b862cad01f",
      "signature": "public.lts_card_exact_recovery_v226(uuid,date,date)"
    },
    {
      "md5": "1183985090fd8773db59036cee9e7ec6",
      "signature": "public.lts_expense_effective_rows_v225_baseline(uuid,date,date)"
    },
    {
      "md5": "3026f1d05acf5bc8ec573c9bfbf25531",
      "signature": "public.lts_flow_operational_read_v229(uuid,date,date)"
    },
    {
      "md5": "aae8c78fc55fe52fa0ddab347480f37c",
      "signature": "public.lts_v229_new_bank_rows(uuid,date,date)"
    },
    {
      "md5": "6bf5e8d7c0dda985892c8209b7222337",
      "signature": "public.lts_expense_rows_v230_baseline(uuid,date,date)"
    },
    {
      "md5": "ac823d4947b9a4f9739c24533ead5bc2",
      "signature": "public.lts_v229_review_rows(uuid,date,date)"
    },
    {
      "md5": "a95cf3f7802c4d3bafd7bfb49551e042",
      "signature": "public.lts_bank_description_key_v229(text)"
    },
    {
      "md5": "5edc57b30e5d6b8a52d632efa08ec498",
      "signature": "public.lts_card_invoice_amounts_v230(uuid)"
    },
    {
      "md5": "512e6b2b7f396b1e67e99818869ec12a",
      "signature": "public.lts_bank_merchant_key_v231(text)"
    },
    {
      "md5": "1dbb589d3877c60420fdff81c384fb8c",
      "signature": "public.lts_bank_posted_rows_v231(uuid)"
    },
    {
      "md5": "c89adcb69252efa960cbb34df2a89768",
      "signature": "public.lts_bank_known_classification_v231(uuid,uuid)"
    },
    {
      "md5": "24140ece2345c630f3db5051a6e422e9",
      "signature": "public.lts_payroll_bank_matches_v231(uuid)"
    },
    {
      "md5": "3df237f6269a6a13bc3403b05276fcac",
      "signature": "public.lts_card_installment_key_v231(public.lts_open_finance_staging)"
    },
    {
      "md5": "bd41db5479a15491422cf6268db89b47",
      "signature": "public.lts_v229_expense_rows_pre_v238(uuid,date,date)"
    },
    {
      "md5": "3f1a2c6e73150f6874cbda3db88317f9",
      "signature": "public.lts_card_document_matches_v234(uuid)"
    },
    {
      "md5": "68a27f360b474f8ac0df91a7650fe924",
      "signature": "public.lts_card_document_rows_v234(uuid)"
    },
    {
      "md5": "4df73b4ad0cafadc367377e48c5ca251",
      "signature": "public.lts_operational_source_key_v238(uuid)"
    },
    {
      "md5": "c0a390f6b415cde4fc47225bed44ffdf",
      "signature": "public.lts_realized_bank_sources_v238(uuid)"
    },
    {
      "md5": "a2ab1bb252ba1c27cb0ad7fa62cbe5cd",
      "signature": "public.lts_v229_expense_rows(uuid,date,date)"
    },
    {
      "md5": "164c5a3d3705549fcdbf2a6e93d6b9ed",
      "signature": "public.lts_card_workbook_bank_rows_v1(uuid)"
    },
    {
      "md5": "891b9f6b72365cc6d142aa098f941ff1",
      "signature": "public.lts_card_bank_monthly_deltas_v1(uuid)"
    },
    {
      "md5": "0c9a66e16022bb799bb268295515d50c",
      "signature": "public.lts_open_finance_checking_positions_v1(uuid)"
    },
    {
      "md5": "4bc0f47babbba8bf30fced74161cf19a",
      "signature": "public.lts_flow_classification_decision_v1(uuid,jsonb)"
    },
    {
      "md5": "60015122f8b310f2b3f79538e851f2cf",
      "signature": "public.lts_forecast_series_key_v1(text)"
    },
    {
      "md5": "1f72d7ac2b27a5e111de3f1c7d41fb42",
      "signature": "public.lts_historical_effective_cash_pre_v246(uuid,date,date)"
    },
    {
      "md5": "e2950ce945db74cbf6acc68587dcb7d6",
      "signature": "public.lts_card_observed_expense_eligible_v1(jsonb,date,date)"
    },
    {
      "md5": "240849f813a9ac43b853d42440ef02b0",
      "signature": "public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date)"
    },
    {
      "md5": "e3e63ef8481594d301f5b0560d6ae25b",
      "signature": "public.lts_c6_paid_identity_v237(uuid)"
    },
    {
      "md5": "38238af5e695c1d54d45e63f1579dd26",
      "signature": "public.lts_operational_source_key_pre_v242(uuid)"
    },
    {
      "md5": "0498aef77c7c7970de52c6712c0d6c30",
      "signature": "public.lts_historical_cash_engine_v243(uuid,date,date)"
    },
    {
      "md5": "5db62be42ab458431614f11172fb70bc",
      "signature": "public.lts_card_invoice_amounts_v230_engine_v243(uuid)"
    },
    {
      "md5": "65fbb2bf3db4cefcce6f70e7a89f9561",
      "signature": "public.lts_payroll_bank_matches_v231_engine_v243(uuid)"
    },
    {
      "md5": "6b8b11bef56c749826f713904fdea55c",
      "signature": "public.lts_corrected_cashflow_fix86_v1_engine_v247(uuid,date,date)"
    },
    {
      "md5": "3d06e4c309d8b0bc0466558f8f92e1a7",
      "signature": "public.lts_bank_fgts_combined_receipt_v261(uuid,uuid)"
    },
    {
      "md5": "d5e085fe7dbc8f6a2ad562feb290c1fb",
      "signature": "public.lts_card_source_rows_pre_v262(uuid)"
    },
    {
      "md5": "363c2c63d3ee64df40173f8c3d7aab21",
      "signature": "public.lts_owner_confirmed_transfer_pairs_v263(uuid)"
    },
    {
      "md5": "0738e3c16dfe4fdea7b6a59d42d5535c",
      "signature": "public.lts_current_received_card_bills_v263(uuid)"
    },
    {
      "md5": "c8c716093de7f247be51f6ed6f34bd8f",
      "signature": "public.lts_expense_effective_rows_pre_v268(uuid,date,date)"
    },
    {
      "md5": "3869ff49b557837aecbc11b8528fca6a",
      "signature": "public.lts_c6_cycle_identity_v269(uuid)"
    },
    {
      "md5": "dd6e02daa77ff6fb09df0324e3e45692",
      "signature": "public.lts_card_document_candidates_v269(uuid)"
    },
    {
      "md5": "1c875f3a1e0165ac1f87740119f88894",
      "signature": "public.lts_c6_completeness_state_v269(uuid)"
    },
    {
      "md5": "cbfae2833915df136d8046fd9e18f81c",
      "signature": "public.lts_card_settlement_contract_v273(uuid,uuid)"
    },
    {
      "md5": "c7fe16708fd3a9a1a768c0cfa8ee9a8c",
      "signature": "public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)"
    },
    {
      "md5": "56a8a53a1290893ae4f94634ffb01867",
      "signature": "public.lts_card_settlement_expense_excluded_v273(uuid,uuid,jsonb)"
    },
    {
      "md5": "45974b44368efcd4fa7080851a2125e1",
      "signature": "public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "29778e4a296e728ad9723a6e08e1c55b",
      "signature": "public.lts_bill_source_fields_v286(jsonb,jsonb,date)"
    },
    {
      "md5": "9f5b3bc99757b695e3c32022c90388fb",
      "signature": "public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)"
    },
    {
      "md5": "a8a083f160fb6e2937dc96e165b2fbd8",
      "signature": "public.lts_card_due_overlay_v290(uuid,jsonb)"
    },
    {
      "md5": "8cc4cb82649edc926c2842afb7522d06",
      "signature": "public.lts_card_projection_rows_v290(uuid)"
    },
    {
      "md5": "f5ff0aefd33935bb5eabf3fdc925fe74",
      "signature": "public.lts_card_settlement_overlay_v290(uuid,jsonb)"
    },
    {
      "md5": "0d845b5e55b0505af153d66adfcd6ea4",
      "signature": "public.lts_expense_rows_pre_categories_v290(uuid,date,date)"
    },
    {
      "md5": "6e7bf2157a330190a5003cd29247161d",
      "signature": "lts_income_private.category_v296(uuid,text,text)"
    },
    {
      "md5": "3c681814ed788e864f2e75511fa4ffd1",
      "signature": "public.lts_card_cycle_settlement_v301(jsonb,jsonb)"
    },
    {
      "md5": "ad76fd524058f3b4e75bc481a032c338",
      "signature": "public.lts_partial_obligation_settlement_valid_v302(jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "5f78416d190a1a7a375e3e0e11fe8445",
      "signature": "public.lts_posted_own_transfer_valid_v304(uuid,jsonb,jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "33c9ee21e5e049a5be0266c67c719620",
      "signature": "public.lts_posted_own_transfer_out_v304(uuid)"
    },
    {
      "md5": "291dc64044041416759df58589a50b44",
      "signature": "public.lts_prepared_card_cycles_v307(uuid)"
    },
    {
      "md5": "655b63c0813b334710615843b9b9ddb4",
      "signature": "public.lts_aeternum_forecast_cycles_v311(uuid)"
    },
    {
      "md5": "dc900351b38a8f5a3bbf31955dc4c61a",
      "signature": "public.lts_card_forecast_overlay_v311(uuid,jsonb)"
    },
    {
      "md5": "866bfd2faad09d44a60f946b7b8c6c43",
      "signature": "public.lts_workbook_transfer_identity_v336(uuid)"
    },
    {
      "md5": "34b7114165a4e91be404399836782d83",
      "signature": "public.lts_workbook_transfer_identity_v338(uuid)"
    },
    {
      "md5": "092e901ed772fb34d2bda78bfdafcb10",
      "signature": "public.lts_c6_contract_clock_rows_v349(jsonb)"
    },
    {
      "md5": "b7ab98acb2b884c21b7355302a79cff5",
      "signature": "public.lts_card_item_is_invoice_payment_v351(jsonb)"
    },
    {
      "md5": "e38bfe13754a3a8b5696db120b1004d5",
      "signature": "public.lts_card_cycle_settlement_v351(jsonb,jsonb)"
    },
    {
      "md5": "0bcd78087d78d80dd2b00724318d6903",
      "signature": "public.lts_transfer_refresh_valid_v363(uuid,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb)"
    },
    {
      "md5": "ad87d534451381da68a290d7ab67f38b",
      "signature": "public.lts_previously_proved_transfer_pairs_v363(uuid)"
    },
    {
      "md5": "031156449872239330aba72b614af71b",
      "signature": "public.lts_card_projection_date_v370(uuid,text,date,date,date)"
    },
    {
      "md5": "c79ae9493992a7826017fa3062f97060",
      "signature": "public.lts_card_transition_cash_date_v370(uuid,text,date)"
    },
    {
      "md5": "6a73e664c65611c7a1f51b9b54380b3d",
      "signature": "public.lts_card_transition_overlay_v370(uuid,jsonb)"
    },
    {
      "md5": "e7ed129c02e3212302a4759a4a950724",
      "signature": "public.lts_cofrinho_bank_redemptions_v381(uuid,date,date)"
    },
    {
      "md5": "d1ba27f82c8ec6fcecbe0637969bb238",
      "signature": "public.lts_fgts_position_evidence_v386(uuid,date)"
    },
    {
      "md5": "58eebeb755504d01304bd801d569e036",
      "signature": "public.lts_card_due_estimate_overlay_v391(uuid,jsonb)"
    },
    {
      "md5": "556b9cdfff74827eea5819422c278546",
      "signature": "public.lts_cofrinho_composition_v399(uuid,date)"
    },
    {
      "md5": "eeeba973bfb0d4b067e004fd7ab5199a",
      "signature": "public.lts_cofrinho_documentary_composition_v402(uuid,date)"
    },
    {
      "md5": "b9849fe1221396d0a6c891463f43f7bb",
      "signature": "public.lts_cofrinho_provider_position_v402(uuid,date)"
    },
    {
      "md5": "cd55278c925c273fab0f32691b3a6d77",
      "signature": "lts_projection_private_v412.fixed_amount(jsonb,date)"
    },
    {
      "md5": "f42d27119ebc9c79d65df908a2e006fd",
      "signature": "lts_projection_private_v412.owner_policy(uuid)"
    },
    {
      "md5": "61d623e8d18f329f6bebccd4afeaf719",
      "signature": "lts_projection_private_v412.horizon_end(date)"
    },
    {
      "md5": "7bc0289413a6d546c5070414827023ad",
      "signature": "lts_projection_private_v412.review_window(jsonb,date)"
    },
    {
      "md5": "17c3b90c1df758e489d13378936391df",
      "signature": "lts_projection_private_v412.base_flow(uuid,date,date)"
    },
    {
      "md5": "d378c15fc35b8c8c6e10c5b928cfe96f",
      "signature": "lts_projection_private_v412.source_label(text)"
    },
    {
      "md5": "86f60fe0c33409204db6de7dc0d1bc7b",
      "signature": "lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb)"
    },
    {
      "md5": "a0c466ed037263cc6e3419b06a26bcfe",
      "signature": "lts_projection_private_v412.calendar_templates_v412(uuid,jsonb)"
    },
    {
      "md5": "8241371be1fd9688da69459c0c5b3c3e",
      "signature": "lts_projection_private_v412.known_card_periods_v412(uuid)"
    },
    {
      "md5": "36e88d8f2482bd86bd24e3c129efb668",
      "signature": "lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "20cd10920678a7233965813167ec0706",
      "signature": "lts_projection_private_v412.reference_state(uuid)"
    },
    {
      "md5": "b5c214f5a8e1f54c7a82038bedbc03a1",
      "signature": "lts_projection_private_v412.build(uuid,date)"
    },
    {
      "md5": "314505cd40f7d4cbaea7c625a2f4f446",
      "signature": "lts_product_refresh_private_v415.card_source_key(uuid)"
    },
    {
      "md5": "e23ee4f8f05cfedac0ca3c68b04bbec8",
      "signature": "lts_projection_private_v412.scope_match_v416(jsonb,jsonb,boolean)"
    },
    {
      "md5": "eb5ec59c4a5ba9090c8bf1645d6ab258",
      "signature": "lts_projection_private_v412.scope_history_v416(jsonb,jsonb,jsonb,date)"
    },
    {
      "md5": "c14a4064624418b03cd0fc6dc9e7ce99",
      "signature": "lts_projection_private_v412.scope_history_read_v416(uuid,jsonb,jsonb,date)"
    },
    {
      "md5": "7d6a29396f98680308840f19e25f7a0a",
      "signature": "lts_projection_private_v412.scope_slots_v416(jsonb,jsonb,jsonb)"
    },
    {
      "md5": "82627286a1c3a73ee4d18f1dba54a866",
      "signature": "public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)"
    },
    {
      "md5": "9c0d1ac15cb98696ef8fc98aca9ef6b6",
      "signature": "lts_read_private_v430.try_cache_put(uuid,text,date,date,date,jsonb,text)"
    },
    {
      "md5": "fcdc0852c1f0e8316ea961168b04b33d",
      "signature": "public.lts_confirmed_schedule_pairs_v431(uuid)"
    },
    {
      "md5": "ff09da81dbc2a7e7358cac2315fe9147",
      "signature": "lts_projection_private_v412.read_build_cache_v438(uuid,date,jsonb)"
    },
    {
      "md5": "4755895d26b059d2cbf969b200d9ecb9",
      "signature": "lts_projection_private_v412.card_new_spend_provision(jsonb,date)"
    },
    {
      "md5": "75a1eb59a97d445da40c51a6d642aeae",
      "signature": "lts_projection_private_v412.verify_card_legacy_obligations(uuid,jsonb)"
    },
    {
      "md5": "d5f23851a4049a9c380b3d13991d0814",
      "signature": "lts_projection_private_v412.card_legacy_obligations_match(jsonb,jsonb)"
    },
    {
      "md5": "30a6a78744316806e0ca52a632c73e6b",
      "signature": "public.lts_invoice_payment_order_equal_v442(jsonb,jsonb)"
    },
    {
      "md5": "01810b2f491005875361b564088edb53",
      "signature": "lts_projection_private_v412.received_income_slot_v443(uuid,jsonb,date,date)"
    },
    {
      "md5": "8829d7dff268811b63f7a3b19eaff092",
      "signature": "public.lts_expense_matched_bank_rows_v445(uuid,date,date)"
    },
    {
      "md5": "99f49c4f11e130d6cab4196173f41ec0",
      "signature": "public.lts_v246_invalidate_finance_cache()"
    },
    {
      "signature": "lts_product_refresh_private_v415.documented_own_out_v450(uuid)",
      "md5": "9b8208a7d073c1d68272875841215911"
    },
    {
      "signature": "lts_product_refresh_private_v415.reviewed_c6_mode_v450(jsonb,jsonb,jsonb)",
      "md5": "5fd0dd7b5989e3d59c33d06820568bab"
    },
    {
      "signature": "public.lts_recurring_receipt_identities_v303(uuid,date)",
      "md5": "e9e929e7dfe951dc6f19dd032a2f91f0"
    },
    {
      "signature": "lts_receipt_private_v460.utility_receipts(uuid,date)",
      "md5": "854d3166b48e309d9216ca83423fe2ee"
    }
  ],
  "tables": [
    {
      "kind": "r",
      "name": "audit_log",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_product_read_cache",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_category_catalog",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_external_reference_fact",
      "epoch": false,
      "owner": null,
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_open_finance_sync_run",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_expense_effective_read_cache",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_open_finance_resource_map",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_v229_documentary_match",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_workbook_identity_evidence_v232",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_formula_resolution_v237",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_documentary_payment_link_v272",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_settlement_expense_contract_v273",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_category_binding_v290",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_rule_v290",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_recurring_plan_v366",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_transition_v370",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "lts_card_due_estimate_v391",
      "epoch": false,
      "owner": "user_id",
      "schema": "public"
    },
    {
      "kind": "r",
      "name": "queue",
      "epoch": false,
      "owner": "user_id",
      "schema": "lts_product_refresh_private_v415"
    },
    {
      "kind": "r",
      "name": "received_income_evidence_v443",
      "epoch": false,
      "owner": "user_id",
      "schema": "lts_projection_private_v412"
    }
  ],
  "epoch_tables": [
    {
      "signature": "public.accounts",
      "md5": "0cd95ba1233a645b7b6b89b899c91ee9"
    },
    {
      "signature": "public.financial_events",
      "md5": "cdd46c379c75ec1b13c0576d213d116c"
    },
    {
      "signature": "public.asset_positions",
      "md5": "784bbef4179e4c6201a0a57469fc2b9f"
    },
    {
      "signature": "public.card_invoices",
      "md5": "79141e85d01638ee3b3b5bcc85288ab0"
    },
    {
      "signature": "public.source_documents",
      "md5": "d2502a75b65d841b0078bdd23dc3f544"
    },
    {
      "signature": "public.app_settings",
      "md5": "8a272a34fee05cd774115f8b74bc891d"
    },
    {
      "signature": "public.legacy_namespace",
      "md5": "f1e3991f741b971ca5584408140f60b8"
    },
    {
      "signature": "public.evento_base",
      "md5": "67e711865d230fa0ebfeba0041da1d90"
    },
    {
      "signature": "public.historico_analitico",
      "md5": "a0743bb7ec6a95ea3fc069f531fa81f9"
    },
    {
      "signature": "public.evento_usuario",
      "md5": "d59d0ad57334f4dc2d4d28cb1858ff01"
    },
    {
      "signature": "public.reconciliacao",
      "md5": "931e76d391d7a2b142e983a1ef6c27a7"
    },
    {
      "signature": "public.deslocamento",
      "md5": "434b2d0111de5fb71ac0b34fd0fdb331"
    },
    {
      "signature": "public.projecao_op",
      "md5": "2898399189c102b2a555b92ee9fca339"
    },
    {
      "signature": "public.lts_projection_replacement_rule",
      "md5": "55abffad3dd07c3cf55f4ed7fc5b801e"
    },
    {
      "signature": "public.lts_semantic_rule",
      "md5": "81260f5c0c534b1aa65371f93040223b"
    },
    {
      "signature": "public.lts_manual_card_purchase",
      "md5": "4745ae14abd398447abd1d75094368fb"
    },
    {
      "signature": "public.lts_reconciliation_evidence",
      "md5": "29454b21cd3d71fae9c0e16967f7d876"
    },
    {
      "signature": "public.lts_document_card_purchase",
      "md5": "51f552d78c82e0a0ee24790ae1d293c4"
    },
    {
      "signature": "public.lts_fact_confirmation",
      "md5": "c252c1d875d3dfed8e6b5a299a539a09"
    },
    {
      "signature": "public.lts_flow_event_operation",
      "md5": "ced7e25c93af7437e65d0f450dae2c2f"
    },
    {
      "signature": "public.lts_commitment_documentary_schedule",
      "md5": "693ccd59d4f2c6ec1f9488a87541bef0"
    },
    {
      "signature": "public.lts_category_alias",
      "md5": "390fd09ae6c62e74adc764aff90404e6"
    },
    {
      "signature": "public.lts_semantic_amount_signature",
      "md5": "9158c8a6ddc3c3f60475ee2508e5d75c"
    },
    {
      "signature": "public.lts_card_history_recovered_purchase",
      "md5": "58596956f3c48ab508c925d2aab72466"
    },
    {
      "signature": "public.lts_open_finance_connection",
      "md5": "26b5c52a8f4be62ee376a6fe73888006"
    },
    {
      "signature": "public.lts_open_finance_staging",
      "md5": "3a4e2f69a3c7ae6d2564028a67121893"
    },
    {
      "signature": "public.lts_expense_documentary_amount_override",
      "md5": "5aea157c6ec11bee333ecb60340b98e1"
    },
    {
      "signature": "public.lts_card_historical_category_allocation",
      "md5": "17099f1184e352b7e39c9095d15ff88a"
    },
    {
      "signature": "public.lts_card_historical_validation_registry",
      "md5": "4c9b886570b29d69d91ae380336d5a28"
    },
    {
      "signature": "public.lts_liquidity_movement",
      "md5": "532e6df37a44350e864ff915bb958109"
    },
    {
      "signature": "public.lts_v175_workbook_monthly_category_source",
      "md5": "26bcfbde7b3616877262f5e5d4a09c98"
    },
    {
      "signature": "public.lts_v178_review_decision",
      "md5": "63cda13f1dcd530f551ab33fde4679f9"
    },
    {
      "signature": "public.lts_open_finance_observation",
      "md5": "10ab88c362d788e3023e10e025ed033a"
    },
    {
      "signature": "public.lts_validated_lock_registry",
      "md5": "522e3739fa5e349273c96eecfb990969"
    },
    {
      "signature": "public.lts_card_workbook_evidence_v226",
      "md5": "09977fb370184dcd69f03053c6825f01"
    },
    {
      "signature": "public.lts_card_document_supplement_v234",
      "md5": "5f25b9b2ab48bec94eeb07a7010d5fd0"
    },
    {
      "signature": "public.lts_card_history_source_audit_v235",
      "md5": "6e43df483c77c1b26d4777e6cbfb09ae"
    },
    {
      "signature": "public.lts_realized_bank_event_v238",
      "md5": "b9fdfeb875a350e9165fc66f4ff7a806"
    },
    {
      "signature": "public.lts_workbook_transfer_evidence_v336",
      "md5": "c9a73adb0694016e461716891c3a6279"
    },
    {
      "signature": "public.lts_workbook_transfer_reversal_v338",
      "md5": "3afb12f53e2d84a603838c6b293bbbcf"
    }
  ],
  "views": [
    {
      "md5": "30b883b57eac28644fafa04f96aec7ed",
      "signature": "public.lts_expense_realized"
    },
    {
      "md5": "5fb751309feb03a8b3ef84bf3816729c",
      "signature": "public.lts_card_purchase_detail"
    },
    {
      "md5": "950ad5a413e3cc3bf880714055858c89",
      "signature": "public.lts_workbook_nonspend_source_v343"
    }
  ]
}$manifest$::jsonb $function$$definition$;
 ELSIF md5(d)<>'25952f79bf0f8216a651aff7ce239923' THEN RAISE EXCEPTION 'V464_PREDECESSOR_CHANGED';END IF;
 IF md5(pg_get_functiondef(target))<>'25952f79bf0f8216a651aff7ce239923' OR attrs IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V464_FUNCTION_CONTRACT_CHANGED';END IF;
END $patch$;
COMMIT;
