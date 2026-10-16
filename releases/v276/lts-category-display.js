/* Presentation only. Never use these labels as stored keys or RPC arguments. */
(function(root){
 'use strict';
 const personPattern=/^(Lucas|Larissa|Benjamin|Rafiki)\s*[-—–·]\s*(.+)$/i;
 const same=(a,b)=>String(a).trim().toLocaleLowerCase('pt-BR')===String(b).trim().toLocaleLowerCase('pt-BR');
 function category(value){
  const text=String(value??'').trim(),match=text.match(personPattern);
  const person=match?.[1],nature=match?match[2].trim():text;
  const display=/^Vestu[aá]rio$/i.test(nature)?'Imagem e cuidados pessoais':nature==='Organon Despesas'?'Despesas Organon':nature;
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
