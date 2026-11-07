-- Synthetic predecessor: no owner names, financial records or real documents.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE OR REPLACE FUNCTION public.lts_expense_taxonomy_v353(p_category text,p_component text,p_management text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $function$
DECLARE c text:=lower(translate(coalesce(p_category,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 k text:=lower(translate(coalesce(p_component,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 m text:=lower(translate(coalesce(p_management,''),'áàâãéêíóôõúç','aaaaeeiooouc'));
 macro text;g text;cat text:=coalesce(p_category,'Categoria não informada');tax boolean:=false;
BEGIN
 CASE
 WHEN k~'aquisicao' THEN macro:='Patrimônio e financiamentos';g:='Aquisição imobiliária';
 WHEN c~'financiamento veiculo'OR m~'financiamento.*veiculo'THEN macro:='Patrimônio e financiamentos';g:='Aquisição e financiamento de veículo';
 WHEN c~'^emprestimos$|compromissos financeiros'THEN macro:='Compromissos financeiros';g:='Empréstimos e compromissos';
 WHEN c~'iptu|ipva' THEN macro:='Tributos';g:='Tributos';tax:=true;
 ELSE macro:='Outras despesas';g:='Categorias da origem';
 END CASE;
 RETURN jsonb_build_object('macrogroup',macro,'group',g,'category',cat,'is_tax',tax);
END $function$;
REVOKE ALL ON FUNCTION public.lts_expense_taxonomy_v353(text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_expense_taxonomy_v353(text,text,text) TO service_role;
CREATE SCHEMA qa;
CREATE TABLE qa.taxonomy_before AS SELECT category,component,management,
public.lts_expense_taxonomy_v353(category,component,management) AS before_value
FROM unnest(ARRAY['Compromissos Financeiros','Empréstimos','Financiamento Veículo','Alimentação','Moradia','IPTU','IPVA','Saúde','Assinaturas','Presentes','Outras despesas',NULL]::text[])category
CROSS JOIN unnest(ARRAY['Empréstimos','Financiamento Veículo','Outros','empréstimos sem confirmação',NULL]::text[])management
CROSS JOIN unnest(ARRAY['Aquisição','Obra','Uso','Tributos',NULL]::text[])component;
CREATE TABLE qa.attributes AS SELECT to_jsonb(p)-'prosrc' attributes FROM pg_proc p WHERE oid='public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure;
