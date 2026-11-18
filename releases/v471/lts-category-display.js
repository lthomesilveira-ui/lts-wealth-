/* Presentation only. Never use these labels as stored keys, aggregation keys or RPC arguments. */
(function(root){
 'use strict';
 const personPattern=/^(Lucas|Larissa|Benjamin|Rafiki)\s*[-—–·]\s*(.+)$/i;
 const same=(a,b)=>String(a).trim().toLocaleLowerCase('pt-BR')===String(b).trim().toLocaleLowerCase('pt-BR');
 const displayLabels=new Map([
  ['assinatura','Assinaturas'],['assinaturas','Assinaturas'],
  ['estacionamento e pedágio','Estacionamento e Pedágio'],
  ['tarifas bancárias','Tarifas Bancárias'],['financiamento imóvel','Financiamento Imobiliário'],['cabelereiro','Cabeleireiro']
 ]);
 function category(value){
  const text=String(value??'').trim(),match=text.match(personPattern);
  const person=match?.[1];let nature=match?match[2].trim():text;
  // Collapse only the catalogued repeated Benjamin prefix. Preserve conflicting names.
  if(person&&same(person,'Benjamin')){let repeated;while((repeated=nature.match(personPattern))&&same(repeated[1],person))nature=repeated[2].trim();if(repeated)return text;}
  const display=/^Vestu[aá]rio$/i.test(nature)?'Vestuário':nature==='Organon Despesas'?'Despesas Organon':displayLabels.get(nature.toLocaleLowerCase('pt-BR'))||nature;
  return person&&!same(person,'Lucas')?person+' — '+display:display;
 }
 function flow(value,centerCost){
  const label=category(value),person=String(centerCost??'').trim(),embedded=label.match(personPattern);
  if(!person||same(person,'Lucas')||same(person,'Não atribuído'))return label;
  if(embedded&&same(embedded[1],person))return label;
  return person+(/^(Larissa|Benjamin|Rafiki)$/i.test(person)&&!embedded?' — ':' · ')+label;
 }
 root.LTSCategoryDisplay=Object.freeze({category,flow});
})(typeof window==='undefined'?globalThis:window);
