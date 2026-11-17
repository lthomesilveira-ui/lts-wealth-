/* Preserve source positions; show a dated estimate instead of an empty liability. */
(function(){'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V463_DEBT)return;
  const previous=render,model=parent.LTSV463Debt;
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x),date=x=>x?.split('-').reverse().join('/')||'—';
  function data(){const j=window.__LTS_V168_STATE?.wealth?.data,loan=j?.financing?.summary?.commitments?.find(x=>x.id==='volvo'),asOf=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());return{j,estimate:model.estimate(j?.wealth?.assets?.volvo_xc40,loan,asOf)};}
  function basis(x){const d=document.createElement('details');d.className='v463-debt-basis';const title=document.createElement('summary');title.textContent='Base da estimativa';d.append(title);for(const text of ['Valor financiado informado: '+money(x.initialPrincipal)+'.',x.paidCount+' de '+x.totalCount+' parcelas pagas e identificadas no banco, somando '+money(x.paidAmount)+'.','Estimativa após o pagamento de '+date(x.asOf)+', pelas parcelas fixas do contrato. O extrato atualizado confirma juros, encargos e o valor para quitação.']){const p=document.createElement('p');p.textContent=text;d.append(p);}return d;}
  function paint(){
   const {j,estimate:x}=data();if(!x)return;
   if(V==='Patrimônio'){
    const row=document.querySelector('[data-v386-debt="volvo"]');
    if(row){row.querySelector('b').textContent=money(x.balance);const note=row.querySelector('small');if(note)note.textContent='Estimado após a parcela de '+date(x.asOf);row.querySelector('.v463-debt-basis')?.remove();row.append(basis(x));}
    const assessment=window.__LTS_V407_WEALTH?.assess(j),totals=document.querySelector('.v365-wealth-totals');
    if(totals&&assessment?.available&&assessment.missing?.length===1&&assessment.missing[0]==='volvo'){
     const cards=totals.querySelectorAll(':scope>article'),debt=cards[1],net=cards[2];
     if(debt){debt.querySelector('span').textContent='Dívidas';debt.querySelector('strong').textContent=money(assessment.known+x.balance);debt.querySelector('small').textContent='Inclui a estimativa do financiamento da Volvo';}
     if(net){net.querySelector('span').textContent='Patrimônio líquido estimado';net.querySelector('strong').textContent=money(assessment.gross-assessment.known-x.balance);net.querySelector('small').textContent='Ativos menos dívidas, incluindo a estimativa da Volvo';net.querySelectorAll('details').forEach(e=>e.remove());net.append(basis(x));}
     const warning=document.querySelector('.v365-material');if(warning&&/Volvo/.test(warning.textContent)){const action=warning.querySelector('button');warning.replaceChildren(document.createTextNode('Saldo da Volvo estimado. Você pode atualizar o extrato em Ações. '));if(action)warning.append(action);}
    }
    const vehicle=[...document.querySelectorAll('.v168-asset')].find(a=>a.querySelector('h3')?.textContent==='Volvo XC40');
    if(vehicle){const market=Number(j.wealth.assets.volvo_xc40.market_central);if(Number.isFinite(market))vehicle.querySelector('strong').textContent=money(market-x.balance);const fact=[...vehicle.querySelectorAll('.v168-fact')].find(a=>/Financiamento na contratação|Saldo para quitação/.test(a.querySelector('span')?.textContent||''));if(fact){fact.querySelector('span').textContent='Saldo devedor estimado';fact.querySelector('b').textContent=money(x.balance);}vehicle.querySelectorAll('.v463-debt-basis').forEach(a=>a.remove());vehicle.append(basis(x));}
   }
   if(V==='Atualizações'){
    const task=document.getElementById('v365WealthTasks');if(task){const h=task.querySelector('h2'),p=task.querySelector('p'),button=task.querySelector('button');h.textContent='Atualizar extrato do financiamento da Volvo';p.textContent='Usamos a base anterior e '+x.paidCount+' parcelas pagas para estimar o saldo. Envie uma posição recente quando estiver disponível.';if(button){button.textContent='Enviar extrato atualizado';button.onclick=()=>document.querySelector('.v168-updates [data-v168-upload]')?.click();}}
   }
  }
  render=function(){const result=previous.apply(this,arguments);paint();return result;};window.__LTS_V463_DEBT={installed:true,paint};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V407_WEALTH||!window.LTSV463Debt)return false;if(!w.__LTS_V463_DEBT){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return !!w.__LTS_V463_DEBT;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v463-debt-ui.js',install);
})();
