/* Presentation only. All balances come from the existing canonical Flow response. */
(function(){'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V441_FLOW||!window.parent.LTSV441Budget)return;
  const api=window.parent.LTSV441Budget,previous=render;
  const money=n=>n===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n/100);
  const date=x=>x?.split('-').reverse().join('/')||'—';
  function paint(){
   const old=document.getElementById('v441FlowSummary');
   if(V!=='Fluxo Diário'||!D||N.classList.contains('hidden')||ACC!=='Consolidado'){old?.remove();return;}
   const controls=document.querySelector('.flow-sticky-controls'),body=document.querySelector('.v382-tool-body');if(!controls||!body)return;
   let host=old;if(!host){host=document.createElement('section');host.id='v441FlowSummary';controls.after(host);}
   const asOf=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
   const model=typeof FLOWQ==='undefined'?null:api.flow(FLOWQ,asOf);
   if(typeof FLOWLOADING!=='undefined'&&FLOWLOADING){host.innerHTML='<p role="status">Atualizando a visão de caixa…</p>';return;}
   if(!model){host.innerHTML='<p>A visão de caixa não está disponível neste período.</p>';return;}
   const card=(title,amount)=>'<div><span>'+title+'</span><strong>'+money(amount)+'</strong></div>';
   const next=(title,x)=>'<li><span>'+title+'</span><strong>'+(x.known?(x.date?date(x.date)+' · '+money(x.amount):'Sem saldo negativo no período consultado'):'Dados insuficientes no período')+'</strong></li>';
   host.innerHTML='<h2>Caixa hoje e risco de curto prazo</h2><div class="v441-flow-cash">'+card('Saldo em contas hoje',model.today?.bank??null)+card('Contas + resgates D0/D1',model.today?.liquid??null)+'</div>'+
    '<p class="v441-flow-note">D0/D1 exige resgate. Ações exigem venda e transferência. Entradas futuras são projeções e podem mudar.</p>'+
    '<h3>Primeiro saldo negativo projetado · até '+date(model.through)+'</h3><ul>'+next('Somente contas',model.bank)+next('Com D0/D1',model.liquid)+next('Com venda das ações do cenário',model.shares)+'</ul>'+
    (!model.today?'<p class="v441-flow-note">O período selecionado não inclui o saldo de hoje. Os cenários continuam limitados às datas consultadas.</p>':'');
   let premises=document.getElementById('v441FlowPremises');if(!premises){premises=document.createElement('div');premises.id='v441FlowPremises';premises.dataset.v425Section='liquidity';body.append(premises);}
   premises.innerHTML='<strong>Premissas dos cenários de caixa</strong><p>As datas acima usam as entradas e saídas já previstas no Fluxo, inclusive salários futuros. Não representam dinheiro garantido. O horizonte de curto prazo é de até 90 dias, limitado ao período consultado.</p><p>O cenário com ações depende de venda, câmbio, impostos e transferência. Lotes futuros dependem da liberação. FGTS tem restrições e prazo para saque; a recomposição futura não é caixa disponível hoje.</p><p>Novos gastos: R$ 15 mil por mês somente no Aeternum a partir de fevereiro de 2027, além das parcelas existentes. Essa provisão pertence ao Fluxo e não é somada ao orçamento por categoria.</p>';
  }
  const style=document.createElement('style');style.textContent='#v441FlowSummary{border:1px solid #dce5f0;border-radius:12px;padding:14px;margin:12px 0;background:#fff;color:#173a61}#v441FlowSummary h2{font-size:17px;margin:0 0 12px}#v441FlowSummary h3{font-size:12px;margin:16px 0 6px}.v441-flow-cash{display:grid;grid-template-columns:1fr 1fr;gap:10px}.v441-flow-cash>div{background:#f3f7fc;padding:10px;border-radius:8px}.v441-flow-cash span{display:block;font-size:12px}.v441-flow-cash strong{display:block;margin-top:6px;font-size:21px;overflow-wrap:anywhere}.v441-flow-note{font-size:12px;line-height:1.5;color:#617083;margin:10px 0 0}#v441FlowSummary ul{list-style:none;padding:0;margin:0}#v441FlowSummary li{display:flex;justify-content:space-between;gap:14px;padding:8px 0;border-bottom:1px solid #e6edf4;font-size:13px}#v441FlowSummary li strong{text-align:right;overflow-wrap:anywhere}#v441FlowPremises{font-size:12px;line-height:1.5}@media(max-width:430px){.v441-flow-cash strong{font-size:17px}#v441FlowSummary li{font-size:12px}#v441FlowSummary li>span{max-width:45%}}';document.head.append(style);
  render=function(){const r=previous.apply(this,arguments);paint();return r;};window.__LTS_V441_FLOW={installed:true,paint};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V425_FLOW_OPTIONS||!window.LTSV441Budget)return false;if(!w.__LTS_V441_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return !!w.__LTS_V441_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v441-flow-summary.js',install);
})();
