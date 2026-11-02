  function dashboardFgtsPosition(j){
   const f=j?.fgts_position||{},valid=f.version==='fgts-position-evidence-v386';
   const dated=valid&&f.status==='dated_documentary_position'&&/^\d{4}-\d\d-\d\d$/.test(String(f.balance_as_of||''))&&finite(f.balance_brl)!==null;
   const fallback=finite(j?.wealth?.liquidity?.fgts_contingency);
   const balance=dated?finite(f.balance_brl):!valid&&fallback>0?fallback:null;
   return {balance,note:dated?'Posição em '+dateLabel(f.balance_as_of)+' · restrito':balance!==null?'Restrito · data da posição a confirmar':'Saldo atual a confirmar no extrato'};
  }
  function dashboard178(){
   const ds=v168.dashboard;ds.started=true;ds.loading=false;ds.error=null;ds.detailErrors=[];
   ds.data=ds.data||{};
   ds.data.planningUI=state.planningUI.status==='ready'&&state.planningUI.date===day()?state.planningUI.data:null;
   if(state.wealth.data)ds.data.wealth=state.wealth.data;
   if(state.dashboardReport.data)ds.data.expense=state.dashboardReport.data;
   const f=state.forecast.date===day()?state.forecast.data:null;
   ds.data.flow=f?structuredClone(f):{flow:{current_future:{days:[],events:[]}}};
   if(cashComplete(state.cash)){
    const days=ds.data.flow.flow.current_future.days.filter(d=>d.date!==day());days.unshift(observedTodayForForecast(state.cash.data.day,f));ds.data.flow.flow.current_future.days=days;
   }
   const saved=v175.expense.data;
   v175.expense.data=state.dashboardReport.data||null;
   let html;try{html=previousDashboard()}finally{v175.expense.data=saved}
   const t=template(html),root=t.content.querySelector('.v168-dashboard');if(!root)return html;
   root.querySelectorAll('.v168-loadstatus').forEach(x=>x.remove());
   const complete=cashComplete(state.cash),c=complete?state.cash.data:null;
   const pendingCash=state.cash.status==='idle'||state.cash.status==='loading';
   const note=pendingCash?'Carregando…':complete?'Calculado para '+dateLabel(c.as_of):'Indisponível';
   kpi(root,'Contas correntes hoje',c?.cash,note);
   kpi(root,'Aplicações D0',c?.d0,complete?'Disponibilidade de curto prazo':'Aguardando posição completa');
   kpi(root,'RSUs já disponíveis',c?.brokerage_available,complete?'Ações disponíveis + saldo em corretora':'Aguardando posição completa');
   const fgtsPosition=dashboardFgtsPosition(state.wealth.status==='ready'?state.wealth.data:null);
   kpi(root,'FGTS',fgtsPosition.balance,fgtsPosition.note);
   kpi(root,'Total disponível hoje',c?.available_total,complete?'Contas, aplicações e ações disponíveis':'Indisponível');
   const warnings=[];
   if(!complete)warnings.push(pendingCash?'Atualizando a posição de caixa…':'Não foi possível obter a posição completa de caixa.');
   if(state.wealth.status==='error')warnings.push('Posições patrimoniais não atualizadas.');
   if(state.planningUI.status==='error')warnings.push('Planejamento não atualizado.');
   if(state.dashboardReport.status==='error')warnings.push('Relatório de despesas não atualizado.');
   if(warnings.length)(root.querySelector('.v168-pagehead')||root.firstElementChild)?.insertAdjacentHTML('afterend','<div class="v178-notice" role="status">'+escape(warnings.join(' '))+' <button class="v178-refresh">Tentar novamente</button></div>');
   const cards=[...root.querySelectorAll('.v168-card')];
   const forecastReady=!!f&&f.complete!==false&&arr(f.flow?.current_future?.days).length>1&&state.forecast.date===day();
   if(!forecastReady){for(const card of cards.filter(x=>/Evolução projetada|O que exige decisão/.test(x.querySelector('h2')?.textContent||''))){const head=card.querySelector('.v168-cardhead')?.outerHTML||'';card.innerHTML=head+'<div class="v178-empty" role="status">'+(state.forecast.status==='loading'?'<span class="v242-spinner" style="display:inline-block;vertical-align:middle;margin-right:8px" aria-hidden="true"></span>Carregando projeção…':(state.forecast.status==='idle'?'Aguardando carregamento da projeção…':(f?.coverage?.complete===false?'Projeção incompleta. Atualize para conferir todo o período.':f?.complete===false?'Projeção consolidada incompleta: C6 em conferência. Os demais bancos continuam disponíveis no fluxo.':'Projeção indisponível.')))+'</div><button class="v178-refresh">Atualizar projeção</button>'}}
   else if(state.forecast.status!=='ready'){
    const last=arr(f.flow.current_future.days).at(-1)?.date;const title=cards.find(x=>/Evolução projetada/.test(x.querySelector('h2')?.textContent||''))?.querySelector('h2');if(title)title.textContent='Evolução projetada até '+dateLabel(last);
    cards.find(x=>/Evolução projetada/.test(x.querySelector('h2')?.textContent||''))?.insertAdjacentHTML('beforeend','<div class="v178-notice">Projeção disponível até '+escape(dateLabel(last))+'. O restante ainda não foi atualizado.</div>');
   }
   const exp=cards.find(x=>/Principais grupos/.test(x.querySelector('h2')?.textContent||''));
   if(exp){const head=exp.querySelector('.v168-cardhead')?.outerHTML||'';exp.innerHTML=head+(state.dashboardReport.data?reportRank(state.dashboardReport.data,12):'<div class="v178-empty">'+(state.dashboardReport.status==='error'?'Despesas indisponíveis.':'Carregando despesas…')+'</div>');exp.dataset.v178Scope='dashboard'}
   kpi(root,'Total de despesas do período',state.dashboardReport.data?.summary?.selected_total,dateLabel(yearRange().from)+' a '+dateLabel(yearRange().to));
   publishCashDiagnostic();return t.innerHTML;
  }
  function kpi(root,label,value,note,newLabel){
   const el=[...root.querySelectorAll('.v168-kpi')].find(x=>normalize(x.querySelector('span')?.textContent).trim()===normalize(label));
   if(!el)return;
   if(newLabel)el.querySelector('span').textContent=newLabel;
   el.querySelector('strong').textContent=money(value);
   if(el.querySelector('small'))el.querySelector('small').textContent=note||'';
  }

