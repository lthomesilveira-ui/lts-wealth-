/* Group the same canonical cells; no source classification or financial writes. */
(function(root){
 'use strict';
 const dims=['property','person','center_cost'],number=v=>(typeof v==='number'||typeof v==='string'&&v.trim()!=='')&&Number.isFinite(Number(v));
 function validate(p){
  if(p?.version!=='expense-presentation-v353'||!Array.isArray(p.cells)||!p.summary)throw Error('Apresentação indisponível');
  let gross=0,compensations=0,net=0,rows=0;
  for(const c of p.cells){
   if(!['macrogroup','group_name','category',...dims].every(k=>typeof c[k]==='string')||!['gross','compensations','net'].every(k=>number(c[k]))||!Number.isSafeInteger(c.rows)||c.rows<1||Number(c.gross)<0||Number(c.compensations)<0||Math.abs(Number(c.gross)-Number(c.compensations)-Number(c.net))>.011)throw Error('Composição indisponível');
   gross+=Number(c.gross);compensations+=Number(c.compensations);net+=Number(c.net);rows+=c.rows;
  }
  if(!['gross','compensations','net'].every(k=>number(p.summary[k]))||rows!==p.summary.rows||Math.abs(gross-Number(p.summary.gross))>.011||Math.abs(compensations-Number(p.summary.compensations))>.011||Math.abs(net-Number(p.summary.net))>.011)throw Error('Totais precisam ser atualizados');
  return p;
 }
 function build(input,requested={}){
  const p=validate(input),scope={view:requested.view||'type'};
  if(!['type','property','tax'].includes(scope.view))throw Error('Perspectiva inválida');
  for(const k of dims)if(requested[k])scope[k]=String(requested[k]);
  const cells=p.cells.filter(c=>dims.every(k=>!scope[k]||c[k]===scope[k])&&(scope.view!=='tax'||c.is_tax===true));
  const summary={gross:0,compensations:0,net:0,rows:0},tree=new Map();
  const labels=new Map((p.dimensions?.property||[]).map(x=>[x.key,x.label]));
  const add=(s,c)=>{for(const k of ['gross','compensations','net'])s[k]+=Number(c[k]);s.rows+=c.rows;};
  for(const c of cells){
   add(summary,c);let map=tree,path={...scope};
   const steps=scope.view==='property'?[['property',c.property,labels.get(c.property)||'Bem informado na origem']]:[];
   steps.push(['macrogroup',c.macrogroup,c.macrogroup],['group',c.group_name,c.group_name],['category',c.category,c.category]);
   for(const[k,key,name]of steps){
    path={...path,[k]:key};let n=map.get(key);
    if(!n){n={name,scope:{...path},gross:0,compensations:0,net:0,rows:0,children:new Map()};map.set(key,n)}
    add(n,c);map=n.children;
   }
  }
  const array=map=>[...map.values()].sort((a,b)=>b.net-a.net||a.name.localeCompare(b.name,'pt-BR')).map(n=>({...n,children:array(n.children)}));
  return{version:p.version,period:p.period,scope,summary,nodes:array(tree),dimensions:p.dimensions};
 }
 const api={validate,build};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.LTSExpensePresentation=api;
})(typeof window==='undefined'?{}:window);
