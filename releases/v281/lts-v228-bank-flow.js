/* Display the opening returned by the observed ledger, including a sliced range. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V228_FLOW)return;
  const previous=flowVals,previousTitle=flowSemanticTitle,previousMeta=flowSemanticMeta,previousRender=render;
  flowVals=function(x,prev){
   const value=previous(x,prev);
   // Historical source positions own both their opening and gross cash columns.
   // Earlier presentation layers may have retained only a subset of the events.
   if(x?.historical){
    const p=x[ACC],consolidated=ACC==='Consolidado',c=x.fix86_columns||{};
    const documented=(p?.workbook_cash_reconciled===true||p?.documentary_reconstruction===true)
     &&(consolidated?x.v170_cash_arithmetic?.balanced===true:!!(p.workbook_evidence_ref||p.documentary_anchor_ref));
    if(documented){
     value.prev=consolidated?(c.saldo_anterior_operacional??c.saldo_anterior??null):(p.opening_balance??null);
     value.en=consolidated?(c.entradas??null):(p.cash_entries??null);
     value.ex=consolidated?(c.saidas??null):(p.cash_exits??null);
     value.fin=consolidated?(c.saldo_final_operacional??p.bank_balance??null):(p.balance??null);
     value.basis=p.balance_basis;
    }else if(p?.balance_basis==='relative_tracked_bank_ledger'||x.relative_balance_display===true){
     value.prev=null;value.fin=null;
    }
   }
   if(ACC==='Consolidado'&&x.Itaú?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=x.fix86_columns.saldo_anterior_operacional;
   }else if(x[ACC]?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=x[ACC].opening_balance??(Number(x[ACC].balance)-Number(x[ACC].net));
   }
   const incomplete=ACC==='Consolidado'?x.movements_complete===false:x[ACC]?.movements_complete===false;
   if(incomplete){value.prev=ACC==='Consolidado'?x.fix86_columns.saldo_anterior:x[ACC].opening_balance;value.en=null;value.ex=null}
   if(x?.projection_complete===false&&(ACC==='C6'||ACC==='Consolidado')){
    if(x[ACC]?.projection_complete===false){value.prev=null;value.fin=null;value.ex=null;value.basis='incomplete_card_cycle';}
    if(ACC==='Consolidado')for(const key of ['liq_d30','d30'])if(key in value)value[key]=null;
   }
   return value;
  };
  flowSemanticTitle=function(e){if(e.asset_movement&&/resgate cofrinh/i.test(e.description||''))return 'Resgate Cofrinho';if(e.internal_transfer&&/^Transferência entre contas/.test(e.description||''))return e.description;return previousTitle(e)};
  flowSemanticMeta=function(e){return e.internal_transfer?'':previousMeta(e)};
  function after(){
   const localToday=typeof today==="function"?today():null;
   if(V==='Fluxo Diário'&&typeof FLOWQ!=='undefined'&&FLOWQ?.observed_bank_movements){const label=document.getElementById('ltsBankEvidence');if(label)label.textContent='O fluxo combina movimentos recebidos e previsões, inclusive no dia de hoje. O saldo de encerramento pode diferir da última posição recebida do banco.';}
   if(V==='Fluxo Diário'&&typeof mergedFlowDays==='function')for(const day of mergedFlowDays()){
    const row=document.getElementById('d-'+day.date);if(!row)continue;
    const incomplete=ACC==='Consolidado'?day.movements_complete===false:day[ACC]?.movements_complete===false;
    if(incomplete)for(const index of [2,3])if(row.children[index]){row.children[index].textContent='—';row.children[index].title='Movimentos deste dia aguardam conferência em Atualizações.'}
    const bank=ACC==='Consolidado'?day.Itaú:day[ACC];
    if(localToday&&day.date===localToday){
     const ending=row.children[4];
     if(ending){
      ending.style.flexDirection='column';ending.style.alignItems='flex-end';ending.style.justifyContent='center';
      ending.title='Saldo de encerramento do fluxo; pode incluir previsões ainda não realizadas.';
      let badge=ending.querySelector('.v274-ending-label');
      if(!badge){badge=document.createElement('small');badge.className='v274-ending-label';badge.style.cssText='display:block;font-size:11px;line-height:1.35;font-weight:400;white-space:normal;text-align:right;max-width:100%';ending.appendChild(badge);}
      badge.textContent='Encerramento do fluxo';
     }
     if(row.children[1])row.children[1].title='Saldo anterior usado no fluxo; não é a posição bancária recebida agora.';
    }else if(bank?.balance_basis==='observed_bank_position_and_recent_movements'){
     for(const index of [1,4])if(row.children[index])row.children[index].title='Saldo reconstituído com os movimentos recebidos do banco.';
    }
   }
   const evidence=document.getElementById('ltsBankEvidence')||document.querySelector('.flowbar');
   let position=document.getElementById('v274ReceivedPosition');
   if(V==='Fluxo Diário'&&evidence){
    if(!position){position=document.createElement('div');position.id='v274ReceivedPosition';position.className='v168-note';evidence.insertAdjacentElement('afterend',position);}
    const cash=window.__LTS_V178_STATE?.cash;
    const valid=!!cash&&window.__LTS_V178_REVIEW?.cashComplete?.(cash)===true;
    const value=valid?(ACC==='Consolidado'?cash.data.cash:cash.data.day?.[ACC]?.balance):null;
    const numeric=typeof value==='number'||(typeof value==='string'&&/^-?\d+(?:\.\d+)?$/.test(value.trim()));
    const amount=numeric&&Number.isFinite(Number(value))?Number(value):null;
    const account=ACC==='Consolidado'?'todas as contas':ACC;
    const pending=cash?.status==='idle'||cash?.status==='loading';
    position.textContent=amount===null?(pending?'Atualizando a posição recebida ('+account+')… O encerramento do fluxo pode incluir previsões.':'Última posição recebida ('+account+'): indisponível nesta visualização. O encerramento do fluxo pode incluir previsões.'):
     'Última posição recebida ('+account+'): '+new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(amount)+'. Não é uma consulta em tempo real. O encerramento do fluxo pode incluir previsões ainda não realizadas.';
   }else position?.remove();
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
  window.__LTS_V228_FLOW={installed:true,completeness_contract:269};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V227_LAYOUT)return false;if(!w.__LTS_V228_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V228_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();

