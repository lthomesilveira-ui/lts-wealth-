/* V183 candidate: make vested shares distinct from available brokerage cash. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V178_REVIEW?.installed)return false;
   if(d.getElementById('v183-rsu-component-runtime'))return true;
   const runtime=function(){
    const fmt=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n);
    let pending=false;
    function decorate(){
     pending=false;
     const head=document.querySelector('.fx87-cons.fx87-head');
     if(!head||head.children.length<9)return;
     if(head.children[7].getAttribute('aria-label')!=='RSU vested · ações')head.children[7].setAttribute('aria-label','RSU vested · ações');
     if(head.children[8].getAttribute('aria-label')!=='Saldo com RSU vested + corretora')head.children[8].setAttribute('aria-label','Saldo com RSU vested + corretora');
     const a=window.__LTS_V178_STATE?.awards?.data;
     const date=a?.as_of,shares=Number(a?.vested_shares),cash=Number(a?.brokerage_cash),other=Number(a?.other_available),available=Number(a?.brokerage_available);
     if(!/^\d{4}-\d\d-\d\d$/.test(date||'')||![shares,cash,other,available].every(Number.isFinite)||Math.abs(shares+cash+other-available)>.02)return;
     const row=document.getElementById('d-'+date);if(!row||row.children.length<11)return;
     let note=row.children[7].querySelector('.v183-rsu-components');
     const label='Corretora disponível: '+fmt(available)+' = ações vested '+fmt(shares)+' + saldo em corretora '+fmt(cash)+(Math.abs(other)>.005?' + não alocado '+fmt(other):'')+'. Não é entrada bancária.';
     if(!note){note=document.createElement('small');note.className='v183-rsu-components';note.style.cssText='display:block;white-space:normal;font-size:10px;line-height:1.25;color:#44546b';row.children[7].appendChild(note)}
     if(note.textContent!==label)note.textContent=label;
     row.children[8].title='Inclui caixa bancário, D0 e total disponível na corretora; componentes da corretora identificados na coluna RSU vested.';
    }
    new MutationObserver(()=>{if(!pending){pending=true;requestAnimationFrame(decorate)}}).observe(document.body,{childList:true,subtree:true,characterData:true});
    window.__LTS_V183_RSU_LABELS={installed:true,source:'awards-v180',finance_rows_changed:false};
    decorate();
   };
   if(!d.getElementById('v183-rsu-component-style')){const css=d.createElement('style');css.id='v183-rsu-component-style';css.textContent='.fx87-cons.fx87-head > :nth-child(8),.fx87-cons.fx87-head > :nth-child(9){font-size:0!important}.fx87-cons.fx87-head > :nth-child(8)::after{content:"RSU vested · ações";font-size:12px}.fx87-cons.fx87-head > :nth-child(9)::after{content:"Saldo com RSU vested + corretora";font-size:12px}';d.head.appendChild(css)}
   const s=d.createElement('script');s.id='v183-rsu-component-runtime';s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);return true;
  }catch{return false}
 }
 let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},150);
 shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,300)});
})();
