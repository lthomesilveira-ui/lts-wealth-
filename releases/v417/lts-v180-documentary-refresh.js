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
   const summary=window.__LTS_V168_STATE?.dashboard?.data?.wealth?.rsu_summary||window.__LTS_V168_STATE?.wealth?.data?.rsu_summary||window.__LTS_V178_STATE?.wealth?.data?.rsu_summary;
   const regular=finite(summary?.future_regular_brl),cashNet=finite(summary?.future_cash_net_brl),totalNet=finite(summary?.future_considered_total_brl);
   if([regular,cashNet,totalNet].some(value=>value==null)||Math.abs(regular+cashNet-totalNet)>=0.02)return html;
   const template=document.createElement('template');template.innerHTML=html;
   const root=template.content.querySelector('.v168-dashboard');if(!root)return html;
   patchKpi(root,'RSUs futuras',regular,'Projeção da agenda · valor bruto');
   patchKpi(root,'Cash RSUs futuras',cashNet,'Projeção da agenda · reserva de 30%');
   patchKpi(root,'Total de posições futuras',totalNet,'RSU + Cash RSU; referências atuais em Cotações');
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
 window.LTSV339Boot?.watch('lts-v180-documentary-refresh.js',install);
})();
