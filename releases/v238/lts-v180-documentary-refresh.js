/* V180 keeps the V179 cash recovery and aligns future awards with the latest reconciled brokerage statement. */
(function(){
 'use strict';
 const outer=document.getElementById('shell');let generation=0;
 function runtime(){
  'use strict';
  if(window.__LTS_V180_DOCUMENTARY_REFRESH?.installed||!window.__LTS_V178_REVIEW?.installed)return;
  const previousDashboard=dashboard;
  const finite=value=>value==null||value===''?null:(Number.isFinite(Number(value))?Number(value):null);
  const money=value=>finite(value)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(value));
  const normalize=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const dateLabel=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value))?String(value).split('-').reverse().join('/'):String(value||'—');
  function patchKpi(root,label,value,note){
   const item=[...root.querySelectorAll('.v168-kpi')].find(node=>normalize(node.querySelector('span')?.textContent).trim()===normalize(label));
   if(!item)return;
   item.querySelector('strong').textContent=money(value);
   if(item.querySelector('small'))item.querySelector('small').textContent=note;
  }
  dashboard=function(){
   const html=previousDashboard();
   const statement=window.__LTS_V178_STATE?.wealth?.data?.morgan_statement;
   const future=statement?.future_components||{};
   const regular=finite(future.regular_rsu_gross_brl);
   const cashGross=finite(future.cash_rsu_gross_brl);
   const cashNet=finite(future.cash_rsu_after_reserve_brl);
   const other=finite(future.unallocated_statement_brl);
   const totalNet=finite(future.future_after_reserve_brl);
   const unavailable=finite(statement?.unavailable_gross_brl);
   const asOf=statement?.as_of;
   if([regular,cashGross,cashNet,other,totalNet,unavailable].some(value=>value==null)||!asOf)return html;
   if(Math.abs(regular+cashGross+other-unavailable)>=0.02)return html;
   if(Math.abs(regular+cashNet+other-totalNet)>=0.02)return html;
   const template=document.createElement('template');template.innerHTML=html;
   const root=template.content.querySelector('.v168-dashboard');if(!root)return html;
   patchKpi(root,'RSUs futuras',regular,'Valor bruto do extrato · '+dateLabel(asOf));
   patchKpi(root,'Cash RSUs futuras',cashNet,'70% após reserva de 30% · extrato '+dateLabel(asOf));
   patchKpi(root,'Total de posições futuras',totalNet,other>0?'Inclui '+money(other)+' não alocados no extrato; sem natureza presumida':'RSU + Cash RSU; ainda fora do caixa atual');
   return template.innerHTML;
  };
  window.__LTS_V180_DOCUMENTARY_REFRESH={installed:true,version:'v180-documentary-refresh',baseline:'v179-cash-recovery'};
  if(D&&!N.classList.contains('hidden'))render();
 }
 function install(){try{
  const frameWindow=outer?.contentWindow,frameDocument=outer?.contentDocument;
  if(!frameWindow?.__LTS_V178_REVIEW?.installed)return false;
  if(!frameWindow.__LTS_V180_DOCUMENTARY_REFRESH?.installed&&!frameDocument.getElementById('v180-documentary-runtime')){
   const script=frameDocument.createElement('script');
   script.id='v180-documentary-runtime';
   script.textContent='('+runtime.toString()+')();';
   frameDocument.head.appendChild(script);
  }
  return !!frameWindow.__LTS_V180_DOCUMENTARY_REFRESH?.installed;
 }catch{return false}}
 function burst(){const current=++generation;let count=0;function step(){if(current!==generation)return;if(!install()&&++count<320)setTimeout(step,100)}step()}
 outer?.addEventListener('load',burst);burst();
})();
