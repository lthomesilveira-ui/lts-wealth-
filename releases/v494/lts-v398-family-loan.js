/* Family debt: balance, correction and planning are separate visible concepts. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,state=window.__LTS_V168_STATE;
  const amount=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
  const money=v=>amount(v)===null?'A confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||''))?v.split('-').reverse().join('/'):'a confirmar';
  function line(label,value){const row=document.createElement('div'),name=document.createElement('span'),number=document.createElement('b');row.className='v365-pair';name.textContent=label;number.textContent=money(value);row.append(name,number);return row;}
  function paragraph(text){const p=document.createElement('p');p.textContent=text;return p;}
  function after(){
   if(V==='Atualizações'){
    const task=document.querySelector('#v365WealthTasks>p');if(task)task.textContent='Consulte os saldos e documentos pendentes em Patrimônio.';
   }
   if(V!=='Patrimônio'||state.wealth?.tab!=='overview')return;
   const j=state.wealth?.data,c=j?.financing?.summary?.commitments?.find(x=>x.id==='pai_mae'),p=c?.indexation;
   const root=document.querySelector('.v168-wealth');if(!root||!p||root.querySelector('[data-v398-family]'))return;
   const debt=root.querySelector('[data-v386-debt="pai_mae"] .v365-pair');
   if(debt){let small=debt.querySelector('small');if(!small){small=document.createElement('small');debt.querySelector('span')?.append(small);}small.textContent=p.complete?'Corrigido pela poupança · sem vencimento definido':'Correção a atualizar · sem vencimento definido';}
   const card=document.createElement('article');card.className='v168-card v398-family';card.dataset.v398Family='';
   const title=document.createElement('h2');title.textContent='Empréstimo Pai e Mãe';card.append(title);
   card.append(paragraph('Sem vencimento definido · correção pela poupança'));
   card.append(line('Valor original',p.original_principal_brl),line('Correção acumulada',p.accrued_savings_brl));
   if(amount(p.confirmed_repayments_brl)>0)card.append(line('Pagamentos confirmados',p.confirmed_repayments_brl));
   card.append(line('Saldo devedor',p.balance_brl));
   card.append(paragraph(p.complete?'Correção até '+date(p.corrected_through)+'. O saldo diminui quando um pagamento é confirmado.':'Falta atualizar o índice da poupança para apresentar o saldo corrigido.'));
   const plan=document.createElement('details'),summary=document.createElement('summary');summary.textContent='Planejamento de pagamentos';plan.append(summary);
   plan.append(paragraph(String(c.remaining_events??0)+' parcelas estimadas no fluxo. As datas são uma previsão de planejamento.'));
   if(c.planned_next_payment_date)plan.append(line('Próxima previsão · '+date(c.planned_next_payment_date),c.planned_next_payment_amount));
   plan.append(line('Total previsto no fluxo',c.remaining_scheduled_outflow));
   plan.append(paragraph('As previsões não reduzem o saldo devedor e não são somadas novamente à dívida.'));card.append(plan);
   const origin=document.createElement('details'),originTitle=document.createElement('summary');originTitle.textContent='Origem e atualização';origin.append(originTitle);
   origin.append(paragraph('Valor original e início em '+date(p.starts_on)+' registrados na planilha original e confirmados com você. Correção pelos índices da poupança publicados pelo Banco Central, a cada aniversário mensal completo.'));
   card.append(origin);root.querySelector('.v365-columns')?.after(card);
  }
  const style=document.createElement('style');style.textContent='.v398-family{margin-top:16px}.v398-family p{color:#64748b;font-size:13px;line-height:1.5}.v398-family details{margin-top:12px}.v398-family summary{cursor:pointer;font-size:13px;font-weight:600}.v398-family .v365-pair>span{min-width:0}.v398-family .v365-pair>b{white-space:nowrap}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};
  window.__LTS_V398_FAMILY={installed:true,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V398_FAMILY?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V398_FAMILY?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v398-family-loan.js',install);
})();
