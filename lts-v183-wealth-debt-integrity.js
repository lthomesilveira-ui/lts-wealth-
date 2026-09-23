/* Candidate-only Patrimônio: distinguish payoff evidence, initial financing and future installments. */
(function(){
  'use strict';
  function componentRemainder(total,values){
    const cents=value=>value===null||value===undefined||value===''||!Number.isFinite(Number(value))?null:Math.round(Number(value)*100);
    const target=cents(total),parts=values.map(cents);
    if(target===null||parts.some(x=>x===null))return null;
    return (target-parts.reduce((a,b)=>a+b,0))/100;
  }
  const shell=document.getElementById('shell');
  function install(){
    try{
      const w=shell?.contentWindow,d=shell?.contentDocument;
      if(!w?.__LTS_V183_RETENTION?.installed||!w?.__LTS_V168_STATE)return false;
      if(w.__LTS_V183_WEALTH_INTEGRITY?.installed)return true;
      const runtime=function(){
        const componentRemainder=window.parent.__LTS_V183_COMPONENT_REMAINDER;
        const state=window.__LTS_V168_STATE,previous=patrimonio;
        const amount=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
        const money=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v);
        const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||'').slice(0,10))?String(v).slice(0,10).split('-').reverse().join('/'):'data não informada';
        const audit=window.__LTS_V183_WEALTH_INTEGRITY={installed:true,status:'waiting'};
        function row(name,value,note){
          const div=document.createElement('div'),label=document.createElement('span'),bold=document.createElement('b');
          label.textContent=name;
          if(note){const small=document.createElement('small');small.textContent=note;label.appendChild(small)}
          bold.textContent=value===null?'Aguardando extrato':money(value);
          div.append(label,bold);return div;
        }
        function note(text){const p=document.createElement('p');p.className='v168-note';p.textContent=text;return p}
        function decorate(html){
          const j=state.wealth?.data;
          if(!j?.wealth||!html)return html;
          const t=document.createElement('template');t.innerHTML=html;
          const root=t.content.querySelector('.v168-wealth');if(!root)return html;
          if(state.wealth.tab==='rsu'){
            const m=j.morgan_statement||{},a=m.available_components||{},f=m.future_components||{},r=j.rsu_summary||{};
            const available=componentRemainder(m.available_total_brl??r.available_total_brl,[a.vested_shares_brl??r.vested_shares_brl,a.brokerage_cash_brl??r.brokerage_cash_brl]);
            const future=componentRemainder(f.future_after_reserve_brl??r.future_considered_total_brl,[f.regular_rsu_gross_brl,f.cash_rsu_after_reserve_brl]);
            const components=root.querySelector('.v172-morgan-components');
            if(components){
              const card=document.createElement('article');card.className='v168-card v183-statement-remainders';
              const title=document.createElement('h3');title.textContent='Conferência da composição';card.appendChild(title);
              const list=document.createElement('div');list.className='v172-value-list';card.appendChild(list);
              const label=value=>value===null?'Composição indisponível':value<0?'Componentes acima do total':'Parcela não detalhada';
              for(const [name,value] of [['Disponível agora',available],['Posições futuras',future]]){
                const line=row(name,value,label(value));if(value===null)line.querySelector('b').textContent='—';list.appendChild(line);
              }
              card.appendChild(note('Diferenças entre o total e os componentes exibidos, na posição de '+date(m.as_of||r.as_of)+'. Já estão incluídas nos totais; não são novas entradas, imposto presumido ou valores a somar novamente.'));
              components.after(card);
              const kpi=[...root.querySelectorAll('.v168-kpi')].find(x=>x.querySelector('span')?.textContent==='Disponível agora');
              if(kpi&&available!==null&&Math.abs(available)>=0.005)kpi.querySelector('small').textContent=available<0?'Composição divergente; veja a conferência abaixo':'ações vested + saldo em corretora + parcela não detalhada';
            }
          }
          const commitments=Array.isArray(j.financing?.summary?.commitments)?j.financing.summary.commitments:[];
          const docs=Array.isArray(j.financing?.documentary?.items)?j.financing.documentary.items:[];
          const names={cipo_396:'Financiamento imobiliário · CIPÓ 396',volvo:'Financiamento do Volvo XC40',coopharma:'Empréstimo consignado · Coopharma',pai_mae:'Empréstimo familiar · Pai e Mãe'};
          const debt=Object.entries(names).map(([id,name])=>{
            const c=commitments.find(x=>x.id===id)||{},doc=docs.find(x=>x.commitment_id===id)||{};
            const balance=amount(c.current_documentary_debt_balance??doc.debt_balance);
            const asOf=c.current_debt_as_of||doc.as_of_date;
            return {id,name,balance:balance!==null&&asOf?balance:null,asOf,remaining:amount(c.remaining_scheduled_outflow_current_terms??c.remaining_scheduled_outflow??c.remaining_economic_outflow)};
          });
          const known=debt.filter(x=>x.balance!==null),missing=debt.filter(x=>x.balance===null),knownTotal=known.reduce((sum,x)=>sum+x.balance,0);
          if(state.wealth.tab==='overview'){
            const kpis=root.querySelectorAll('.v168-kpis .v168-kpi');
            if(kpis.length>=3){
              const primary=kpis[0],label=primary.querySelector('span'),value=primary.querySelector('strong'),small=primary.querySelector('small');
              if(missing.length){label.textContent='Patrimônio líquido em apuração';value.textContent='—';small.textContent='Faltam saldos de quitação atuais de '+missing.map(x=>x.id==='pai_mae'?'Pai e Mãe':x.id==='cipo_396'?'CIPÓ 396':x.id==='volvo'?'Volvo':'Coopharma').join(', ')+'.'}
              const debtKpi=kpis[2];debtKpi.querySelector('span').textContent='Dívidas com saldo atual documentado';debtKpi.querySelector('strong').textContent=known.length?money(knownTotal):'—';debtKpi.querySelector('small').textContent=missing.length?'Demais saldos ainda não informados':'Soma de saldos para quitação';
            }
            const card=root.querySelector('.v172-debts');
            if(card){
              const lists=card.querySelectorAll('.v172-value-list');
              if(lists[0])lists[0].replaceChildren(...debt.map(x=>row(x.name,x.balance,x.balance!==null?'Posição em '+date(x.asOf):'Saldo atual não comprovado')));
              if(lists[1])lists[1].replaceChildren(...debt.filter(x=>x.remaining!==null).map(x=>row(x.name,x.remaining,'Parcelas futuras nos termos atuais; não é saldo de quitação')));
              const headings=card.querySelectorAll('h3');if(headings[1])headings[1].textContent='Compromissos de parcelas futuras';
              if(missing.length)card.appendChild(note('O financiamento inicial e a soma das parcelas futuras não substituem um extrato com saldo atual. O patrimônio líquido fica em apuração até que todos os passivos sejam identificados.'));
            }
          }
          if(state.wealth.tab==='assets'){
            const vehicle=[...root.querySelectorAll('.v168-asset')].find(x=>x.querySelector('h3')?.textContent==='Volvo XC40');
            if(vehicle){
              const balance=debt.find(x=>x.id==='volvo')?.balance;
              vehicle.querySelector('strong').textContent=balance===null?'Patrimônio líquido em apuração':money((amount(j.wealth?.assets?.volvo_xc40?.market_central)||0)-balance);
              const fact=[...vehicle.querySelectorAll('.v168-fact')].find(x=>x.querySelector('span')?.textContent==='Saldo financiado');
              if(fact){fact.querySelector('span').textContent=balance===null?'Financiamento na contratação':'Saldo para quitação';fact.querySelector('b').textContent=balance===null?money(amount(j.wealth?.assets?.volvo_xc40?.documented_financed_balance)||0):money(balance)}
              vehicle.appendChild(note(balance===null?'O valor financiado na contratação não é o saldo devedor de hoje. Aguardando extrato para calcular a participação líquida no veículo.':'Participação líquida estimada pela posição de mercado e pelo saldo documental de quitação.'));
            }
            const rsu=[...root.querySelectorAll('.v168-asset')].find(x=>x.querySelector('h3')?.textContent==='RSUs e corretora');
            if(rsu){const available=amount(j.morgan_statement?.available_total_brl??j.rsu_summary?.available_total_brl);if(available!==null){rsu.querySelector('strong').textContent=money(available);rsu.appendChild(note('O valor em destaque é o disponível agora. Vestings futuros permanecem separados e não são patrimônio disponível hoje.'))}}
          }
          audit.status=missing.length?'partial_debt_evidence':'documented_debts';audit.missing=missing.map(x=>x.id);audit.documented_count=known.length;
          return t.innerHTML;
        }
        patrimonio=function(){return decorate(previous())};
        if(typeof D!=='undefined'&&D&&typeof N!=='undefined'&&!N.classList.contains('hidden')&&V==='Patrimônio')render();
      };
      const script=d.createElement('script');script.id='v183-wealth-debt-integrity-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
      return !!w.__LTS_V183_WEALTH_INTEGRITY?.installed;
    }catch{return false}
  }
  window.__LTS_V183_COMPONENT_REMAINDER=componentRemainder;
  let tries=0;const timer=setInterval(()=>{if(install()||++tries>120)clearInterval(timer)},150);
  shell?.addEventListener('load',()=>{tries=0;if(!install())setTimeout(install,300)});
})();
