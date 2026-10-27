-- Presentation over the canonical signed reader. No classification or event writes.
CREATE FUNCTION public.lts_expense_taxonomy_v353(p_category text,p_component text,p_management text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE c text:=lower(translate(coalesce(p_category,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 k text:=lower(translate(coalesce(p_component,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 m text:=lower(translate(coalesce(p_management,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 macro text;g text;cat text:=nullif(trim(regexp_replace(coalesce(p_category,''),'[[:space:]]*[-—–][[:space:]]*O Parque$','','i')),'');
 tax boolean:=c~'tribut|imposto|iptu|ipva|itbi|licenci'OR k~'imposto';
BEGIN
 CASE
 WHEN c='cartao — detalhe historico nao recuperado'THEN macro:='Sem composição individual';g:='Cartões históricos';
 WHEN c~'^(credito|ajustes de fatura)'THEN macro:='Compensações';g:='Créditos e ajustes da origem';
 WHEN k~'aquisicao'OR c~'financiamento imobiliario|consorcio'THEN macro:='Patrimônio e financiamentos';g:='Aquisição imobiliária';
 WHEN c~'financiamento veiculo'OR m~'financiamento.*veiculo'THEN macro:='Patrimônio e financiamentos';g:='Aquisição e financiamento de veículo';
 WHEN c~'^emprestimos$|compromissos financeiros'THEN macro:='Compromissos financeiros';g:='Empréstimos e compromissos';
 WHEN c~'ipva|licenci|veiculos - tributos'THEN macro:='Mobilidade';g:='Tributos';
 WHEN tax AND(k~'imposto'OR c~'imovel|iptu|itbi')THEN macro:='Moradia';g:='Tributos';
 WHEN tax THEN macro:='Tributos e encargos';g:='Tributos sem bem detalhado';
 WHEN k~'obra|reforma'OR c~'obra|reforma|ar-condicionado|camas e estofados|cortinas|deck|envidracamento|espelhos e box|jardim|loucas e metais|marcenaria|mesa e banho|moveis|porta quarto|projeto|revestimento|serralheria|eletrodomesticos'THEN macro:='Moradia';g:='Obra, reforma e equipamentos';
 WHEN k~'moradia'OR c~'condominio|energia|enel|seguro residencial|^moradia$|casa - utensilios'THEN macro:='Moradia';g:='Uso e manutenção';
 WHEN c~'restaurante|ifood|rappi|^alimentacao|^bebidas$|mercado|supermercado'AND c NOT IN('mercado livre')THEN macro:='Alimentação';g:=CASE WHEN c~'restaurante|ifood|rappi'THEN'Refeições'ELSE'Compras e bebidas'END;
 WHEN c~'saude|farmacia|congelamento de ovulos'THEN macro:='Saúde';g:='Atendimento e medicamentos';
 WHEN c~'educacao|aulas|english class|desenvolvimento|lide futuro'THEN macro:='Educação';g:='Ensino e desenvolvimento';
 WHEN c~'combustivel|estacionamento|pedagio|taxi|uber|veiculos -|seguro carro|seguro jeep|aluguel carro|^carro$'THEN macro:='Mobilidade';g:='Uso de veículos';
 WHEN c~'company car|despesas organon'THEN macro:='Trabalho';g:='Despesas profissionais';
 WHEN c~'^vestuario$|cabelereiro|lavanderia'THEN macro:='Cuidados pessoais';g:='Vestuário e cuidados';
 WHEN c~'viagem|passagem aerea|^hotel$|duty free|^mala$'THEN macro:='Viagens';g:='Viagens e estadias';
 WHEN c~'lazer|passeio|rock in rio|socio rei|gympass|natacao'THEN macro:='Lazer e bem-estar';g:='Atividades e lazer';
 WHEN c~'casamento|batizado|^eventos$'THEN macro:='Eventos';g:='Eventos pessoais';
 WHEN c~'assinaturas|spotify|google|apple|armazenamento|telefone|iphone'THEN macro:='Comunicações e serviços digitais';g:='Serviços e equipamentos';
 WHEN c~'tarifas|juros|^iof$|^anuidade$'THEN macro:='Serviços financeiros';g:='Taxas e encargos';
 WHEN c~'^seguro|^seguros'THEN macro:='Seguros';g:='Proteção pessoal';
 WHEN c~'^presentes$|^doacoes$|^religiao$'THEN macro:='Vida pessoal e familiar';g:='Presentes e contribuições';
 WHEN c~'^(lucas|larissa|benjamin|rafiki|marino)([[:space:]]|$)|^familia$'THEN macro:='Vida pessoal e familiar';g:='Tipo de gasto não detalhado';cat:='Despesas pessoais sem tipo informado';
 ELSE macro:='Outras despesas';g:='Categorias da origem';
 END CASE;
 IF c='cipo 396'AND k~'aquisicao'THEN cat:='Pagamentos de aquisição sem composição';END IF;
 RETURN jsonb_build_object('macrogroup',macro,'group',g,'category',coalesce(cat,'Categoria não informada'),'is_tax',tax);
END $fn$;

CREATE FUNCTION public.lts_expense_view_rows_v353(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(row_payload jsonb,taxonomy jsonb,center_cost text)
LANGUAGE sql STABLE SET search_path='' AS $fn$
 WITH context AS MATERIALIZED(
 SELECT source_table,source_ref,min(nullif(trim(center_cost),''))center_cost
 FROM public.lts_expense_effective_rows_v176(p_user_id,p_from,p_to)
 GROUP BY source_table,source_ref HAVING count(*)=1)
 SELECT to_jsonb(r),public.lts_expense_taxonomy_v353(r.category,r.property_component,r.management_group),
 CASE WHEN c.center_cost IN('Não atribuído','Não identificado')THEN NULL ELSE c.center_cost END
 FROM public.lts_v229_expense_rows(p_user_id,p_from,p_to)r
 LEFT JOIN context c ON c.source_table=r.source_table AND c.source_ref=r.source_ref
$fn$;

CREATE FUNCTION public.lts_expense_scope_v353(r jsonb,t jsonb,c text,s jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT coalesce(
 (nullif(s->>'macrogroup','')IS NULL OR t->>'macrogroup'=s->>'macrogroup')AND
 (nullif(s->>'group','')IS NULL OR t->>'group'=s->>'group')AND
 (nullif(s->>'category','')IS NULL OR t->>'category'=s->>'category')AND
 (nullif(s->>'property','')IS NULL OR coalesce(r->>'property_code','__missing__')=s->>'property')AND
 (nullif(s->>'person','')IS NULL OR coalesce(r->>'beneficiary','__missing__')=s->>'person')AND
 (nullif(s->>'center_cost','')IS NULL OR coalesce(c,'__missing__')=s->>'center_cost')AND
 (coalesce(s->>'sign','net')='net'OR s->>'sign'='gross'AND(r->>'amount')::numeric>0 OR s->>'sign'='compensations'AND(r->>'amount')::numeric<0)AND
 (coalesce(s->>'view','type')<>'tax'OR t->>'is_tax'='true'),false)
$fn$;

CREATE FUNCTION public.lts_expense_node_v353(n text,s jsonb,g numeric,c numeric,v numeric,r bigint,ch jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $fn$
 SELECT jsonb_build_object('name',n,'scope',s,'gross',round(coalesce(g,0),2),'compensations',round(coalesce(c,0),2),'net',round(coalesce(v,0),2),'rows',r,'children',coalesce(ch,'[]'))
$fn$;

CREATE FUNCTION public.lts_expense_presentation_v353(p_user_id uuid,p_from date,p_to date,p_scope jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $fn$
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
$fn$;

CREATE FUNCTION public.lts_browser_expense_hierarchy_v353(p_from date,p_to date,p_scope jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo'AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1();rev text;result jsonb;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date'2013-10-10'OR p_to>current_date
 OR jsonb_typeof(p_scope)IS DISTINCT FROM'object'OR(p_scope-ARRAY['macrogroup','group','category','property','person','center_cost','sign','view'])<>'{}'
 OR coalesce(p_scope->>'view','type')NOT IN('type','property','tax')OR coalesce(p_scope->>'sign','net')NOT IN('net','gross','compensations')THEN RAISE EXCEPTION 'invalid expense presentation range or filters';END IF;
 rev:=public.lts_card_read_start_v269(u);result:=public.lts_expense_presentation_v353(u,p_from,p_to,p_scope);
 RETURN public.lts_card_read_finish_v269(u,rev,result);
END $fn$;

REVOKE ALL ON FUNCTION public.lts_expense_taxonomy_v353(text,text,text),public.lts_expense_view_rows_v353(uuid,date,date),public.lts_expense_scope_v353(jsonb,jsonb,text,jsonb),public.lts_expense_node_v353(text,jsonb,numeric,numeric,numeric,bigint,jsonb),public.lts_expense_presentation_v353(uuid,date,date,jsonb),public.lts_browser_expense_hierarchy_v353(date,date,jsonb)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_expense_taxonomy_v353(text,text,text),public.lts_expense_view_rows_v353(uuid,date,date),public.lts_expense_scope_v353(jsonb,jsonb,text,jsonb),public.lts_expense_node_v353(text,jsonb,numeric,numeric,numeric,bigint,jsonb),public.lts_expense_presentation_v353(uuid,date,date,jsonb)TO service_role;
GRANT EXECUTE ON FUNCTION public.lts_browser_expense_hierarchy_v353(date,date,jsonb)TO authenticated,service_role;
