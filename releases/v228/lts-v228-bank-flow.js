/* Display the opening returned by the observed ledger, including a sliced range. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V228_FLOW)return;
  const previous=flowVals,previousTitle=flowSemanticTitle,previousRender=render;
  flowVals=function(x,prev){
   const value=previous(x,prev);
   if(ACC==='Consolidado'&&x.Itaú?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=x.fix86_columns.saldo_anterior_operacional;
   }else if(x[ACC]?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=Number(x[ACC].balance)-Number(x[ACC].net);
   }
   return value;
  };
  flowSemanticTitle=function(e){return e.asset_movement&&/resgate cofrinhos/i.test(e.description||'')?'Resgate Cofrinho':previousTitle(e);};
  function after(){
   if(V==='Fluxo Diário'&&typeof mergedFlowDays==='function')for(const day of mergedFlowDays()){
    const row=document.getElementById('d-'+day.date);if(!row)continue;
    const bank=ACC==='Consolidado'?day.Itaú:day[ACC];
    if(bank?.balance_basis!=='observed_bank_position_and_recent_movements')continue;
    for(const index of [1,4])if(row.children[index])row.children[index].title=day.is_today?'Saldo informado pelo banco e movimentos recebidos.':'Saldo reconstituído com os movimentos recebidos do banco.';
   }
   if(V!=='Atualizações')return;
   const gaps=typeof FLOWQ!=='undefined'?FLOWQ?.observed_bank_movements?.documentary_gaps:null;
   const rows=Object.entries(gaps||{}).filter(([,v])=>Math.abs(Number(v))>.005);
   const host=document.querySelector('.v168-openfinance');if(!host||!rows.length)return;
   let box=document.querySelector('.v228-bank-review');
   if(!box){box=document.createElement('div');box.className='v228-bank-review v168-note';host.insertAdjacentElement('afterend',box);}
   box.textContent='Conferência de posições anteriores: '+rows.map(([bank,value])=>bank+' · '+new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value)).join('; ')+'. Os saldos atuais vêm dos bancos. Essas diferenças não foram transformadas em lançamentos.';
  }
  render=function(){const result=previousRender.apply(this,arguments);after();return result;};
  window.__LTS_V228_FLOW={installed:true};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V227_LAYOUT)return false;if(!w.__LTS_V228_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V228_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
