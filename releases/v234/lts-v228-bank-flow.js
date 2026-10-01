/* Display the opening returned by the observed ledger, including a sliced range. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V228_FLOW)return;
  const previous=flowVals,previousTitle=flowSemanticTitle,previousMeta=flowSemanticMeta,previousRender=render;
  flowVals=function(x,prev){
   const value=previous(x,prev);
   if(ACC==='Consolidado'&&x.Itaú?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=x.fix86_columns.saldo_anterior_operacional;
   }else if(x[ACC]?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=x[ACC].opening_balance??(Number(x[ACC].balance)-Number(x[ACC].net));
   }
   const incomplete=ACC==='Consolidado'?x.movements_complete===false:x[ACC]?.movements_complete===false;
   if(incomplete){value.prev=ACC==='Consolidado'?x.fix86_columns.saldo_anterior:x[ACC].opening_balance;value.en=null;value.ex=null}
   return value;
  };
  flowSemanticTitle=function(e){if(e.asset_movement&&/resgate cofrinh/i.test(e.description||''))return 'Resgate Cofrinho';if(e.internal_transfer&&/^Transferência entre contas/.test(e.description||''))return e.description;return previousTitle(e)};
  flowSemanticMeta=function(e){return e.internal_transfer?'':previousMeta(e)};
  function after(){
   if(V==='Fluxo Diário'&&typeof FLOWQ!=='undefined'&&FLOWQ?.observed_bank_movements){const label=document.getElementById('ltsBankEvidence');if(label)label.textContent='Movimentos recebidos dos bancos até hoje. As datas futuras mostram previsões.';}
   if(V==='Fluxo Diário'&&typeof mergedFlowDays==='function')for(const day of mergedFlowDays()){
    const row=document.getElementById('d-'+day.date);if(!row)continue;
    const incomplete=ACC==='Consolidado'?day.movements_complete===false:day[ACC]?.movements_complete===false;
    if(incomplete)for(const index of [2,3])if(row.children[index]){row.children[index].textContent='—';row.children[index].title='Movimentos deste dia aguardam conferência em Atualizações.'}
    const bank=ACC==='Consolidado'?day.Itaú:day[ACC];
    if(bank?.balance_basis!=='observed_bank_position_and_recent_movements')continue;
    for(const index of [1,4])if(row.children[index])row.children[index].title=day.is_today?'Saldo informado pelo banco e movimentos recebidos.':'Saldo reconstituído com os movimentos recebidos do banco.';
   }
   if(V==='Fluxo Diário')for(const row of document.querySelectorAll('.fx87-row[id^="d-"]')){
    const detail=row.nextElementSibling;if(!detail?.classList.contains('fx89-details'))continue;
    const events=dayEvents(row.id.slice(2));detail.querySelectorAll('.fx89-detail-row').forEach((entry,i)=>{const e=events[i];if(e?.internal_transfer){const label=entry.querySelector('.fx89-detail-desc>span');if(label)label.textContent=(e.account||'Conta')+' · '+(e.asset_movement?'Resgate':'Transferência')}});
   }
   if(V!=='Atualizações')return;
   const gaps=typeof FLOWQ!=='undefined'?FLOWQ?.observed_bank_movements?.documentary_gaps:null;
   const rows=Object.entries(gaps||{}).filter(([,v])=>Math.abs(Number(v))>.005);
   const host=document.querySelector('.v168-openfinance');if(!rows.length){document.querySelector('.v228-bank-review')?.remove();return;}if(!host)return;
   let box=document.querySelector('.v228-bank-review');
   if(!box){box=document.createElement('div');box.className='v228-bank-review v168-note';host.insertAdjacentElement('afterend',box);}
   box.textContent='Conferência de posições anteriores: '+rows.map(([bank,value])=>bank+' · '+new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value)).join('; ')+'. Os saldos atuais vêm dos bancos. Falta o movimento que explique a mudança de posição; o ajuste sem comprovante foi retirado.';
  }
  render=function(){const result=previousRender.apply(this,arguments);after();return result;};
  window.__LTS_V228_FLOW={installed:true};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V227_LAYOUT)return false;if(!w.__LTS_V228_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V228_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
