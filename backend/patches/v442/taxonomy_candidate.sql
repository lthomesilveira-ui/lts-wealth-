CREATE OR REPLACE FUNCTION public.lts_expense_taxonomy_v353(p_category text, p_component text, p_management text)
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
END $function$
