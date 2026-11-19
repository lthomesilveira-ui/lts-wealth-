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
   const body=document.querySelector('.v382-tool-body');if(!body)return;old?.remove();
   let premises=document.getElementById('v441FlowPremises');if(!premises){premises=document.createElement('div');premises.id='v441FlowPremises';premises.dataset.v425Section='liquidity';body.append(premises);}
   premises.innerHTML='<strong>Premissas dos cenários de caixa</strong><p>Os cenários usam as entradas e saídas já previstas no Fluxo, inclusive salários futuros. Não representam dinheiro garantido. O horizonte de curto prazo é de até 90 dias, limitado ao período consultado.</p><p>O cenário com ações depende de venda, câmbio, impostos e transferência. Lotes futuros dependem da liberação. FGTS tem restrições e prazo para saque; a recomposição futura não é caixa disponível hoje.</p><p>Novos gastos: R$ 15 mil por mês somente no Aeternum, desde o terceiro mês à frente. A janela avança a cada mês; antes dela entram apenas faturas e parcelas conhecidas. Essa provisão pertence ao Fluxo e não é somada ao orçamento por categoria.</p>';
  }
  const style=document.createElement('style');style.textContent='#v441FlowSummary{border:1px solid #dce5f0;border-radius:12px;padding:14px;margin:12px 0;background:#fff;color:#173a61}#v441FlowSummary h2{font-size:17px;margin:0 0 12px}#v441FlowSummary h3{font-size:12px;margin:16px 0 6px}.v441-flow-cash{display:grid;grid-template-columns:1fr 1fr;gap:10px}.v441-flow-cash>div{background:#f3f7fc;padding:10px;border-radius:8px}.v441-flow-cash span{display:block;font-size:12px}.v441-flow-cash strong{display:block;margin-top:6px;font-size:21px;overflow-wrap:anywhere}.v441-flow-note{font-size:12px;line-height:1.5;color:#617083;margin:10px 0 0}#v441FlowSummary ul{list-style:none;padding:0;margin:0}#v441FlowSummary li{display:flex;justify-content:space-between;gap:14px;padding:8px 0;border-bottom:1px solid #e6edf4;font-size:13px}#v441FlowSummary li strong{text-align:right;overflow-wrap:anywhere}#v441FlowPremises{font-size:12px;line-height:1.5}@media(max-width:430px){.v441-flow-cash strong{font-size:17px}#v441FlowSummary li{font-size:12px}#v441FlowSummary li>span{max-width:45%}}';document.head.append(style);
  const mobileStyle=document.createElement('style');mobileStyle.textContent='#v441FlowSummary{scroll-margin-top:78px}@media(max-width:359px){.v441-flow-cash{grid-template-columns:1fr}}';document.head.append(mobileStyle);
  render=function(){const r=previous.apply(this,arguments);paint();return r;};window.__LTS_V441_FLOW={installed:true,paint};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V425_FLOW_OPTIONS||!window.LTSV441Budget)return false;if(!w.__LTS_V441_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return !!w.__LTS_V441_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v441-flow-summary.js',install);
})();
