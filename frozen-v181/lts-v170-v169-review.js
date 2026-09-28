(function(){
  'use strict';
  const outer=document.getElementById('shell'),gate=document.getElementById('gate'),scope=document.getElementById('scope');
  let generation=0;

  function runtime(){
    'use strict';
    if(window.__LTS_V170_V169_REVIEW?.installed||!window.__LTS_V169_V168_FEEDBACK?.installed)return;
    const baseRender=render,baseNav=renderNav,baseDashboard=dashboard,baseExpenses=despesas,baseWealth=patrimonio,baseLoadFlowRange=loadFlowRange,baseFlowVals=flowVals,baseFlowSemanticMeta=flowSemanticMeta;
    const v168=window.__LTS_V168_STATE;
    const state=window.__LTS_V170_STATE||(window.__LTS_V170_STATE={globalAward:{saving:false,message:'',error:''},lastRoute:V,defaultOpening:false});
    const priorRpc=S.rpc.bind(S),rpcCalls=[];
    S.rpc=async function(name,args){
      const requested=String(name||''),mapped=requested==='lts_browser_flow_v3'||requested==='lts_browser_flow_v4'||requested==='lts_browser_flow_v11'?'lts_browser_flow_v12':requested==='lts_browser_wealth_detail_v3'?'lts_browser_wealth_detail_v4':requested==='lts_browser_expense_executive_v4'?'lts_browser_expense_executive_v5':requested;
      rpcCalls.push({requested,mapped,at:new Date().toISOString()});if(rpcCalls.length>50)rpcCalls.shift();
      return priorRpc(mapped,args);
    };
    window.__LTS_V170_V169_REVIEW={
      installed:true,version:'v170',base_version:'v169',public_index_changed:false,
      data_rpcs:{flow:'lts_browser_flow_v12',wealth:'lts_browser_wealth_detail_v4',expense:'lts_browser_expense_executive_v5'},
      default_flow_range:'previous-5-through-next-year-end',historical_balance_basis:'relative_movement_ledger',
      morgan_statement_reconciled:true,global_award_assumption:true,management_groups:true,rpcCalls
    };

    const arr=v=>Array.isArray(v)?v:[],finite=v=>v===null||v===undefined||v===''?null:(Number.isFinite(Number(v))?Number(v):null);
    const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
    const norm=s=>String(s??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const money=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const number=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{maximumFractionDigits:3}).format(Number(v));
    const usd=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'USD',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(v));
    const fx=v=>finite(v)==null?'—':new Intl.NumberFormat('pt-BR',{minimumFractionDigits:4,maximumFractionDigits:6}).format(Number(v));
    const date=v=>{const p=String(v||'').slice(0,10).split('-');return p.length===3?p.reverse().join('/'):'—'};
    const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    const shift=(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
    const template=html=>{const t=document.createElement('template');t.innerHTML=html;return t};
    const total=xs=>arr(xs).reduce((a,x)=>a+(finite(x)||0),0);

    function managementGroups(source){return arr(source?.management_groups).filter(x=>finite(x.total)!=null)}
    function managementRows(source,limit=15){
      const rows=[];
      for(const group of managementGroups(source)){
        const children=arr(group.subgroups).filter(x=>finite(x.total)!=null);
        if(norm(group.name)==='educacao'&&children.length){rows.push({name:'Educação',total:group.total,detail:'por pessoa',children,source_categories:group.source_categories,forceChildren:true});continue}
        rows.push({name:group.name,total:group.total,detail:children.slice(0,4).map(x=>x.name.replace(/^Educação · /i,'')).join(' · '),children,source_categories:group.source_categories});
      }
      return rows.sort((a,b)=>(finite(b.total)||0)-(finite(a.total)||0)).slice(0,limit);
    }
    function managementRank(rows,expanded){
      const xs=arr(rows),top=Math.max(1,...xs.map(x=>Math.abs(finite(x.total)||0)));
      return '<div class="v170-rank">'+(xs.map((x,i)=>'<div class="v170-rankrow"><span class="v170-rankn">'+(i+1)+'</span><div><b>'+esc(x.name||'Outros')+'</b>'+(x.detail?'<small>'+esc(x.detail)+'</small>':'')+'<i><u style="width:'+Math.max(2,Math.abs(finite(x.total)||0)/top*100)+'%"></u></i>'+((expanded||x.forceChildren)&&arr(x.children).length?'<div class="v170-subgroups">'+x.children.map(y=>'<span><em>'+esc(y.name)+'</em><strong>'+money(y.total)+'</strong></span>').join('')+'</div>':'')+(expanded&&arr(x.source_categories).length?'<details><summary>Ver categorias de origem</summary>'+x.source_categories.map(y=>'<span><em>'+esc(y.name)+'</em><strong>'+money(y.total)+'</strong></span>').join('')+'</details>':'')+'</div><strong>'+money(x.total)+'</strong></div>').join('')||'<div class="v168-empty">Sem grupos gerenciais neste período.</div>')+'</div>';
    }
    function coverage(source){const c=source?.coverage_disclosure||{};return finite(c.total)>0?'<div class="v169-coverage"><b>'+esc(c.label||'Faturas históricas sem compras individualizadas')+' · '+money(c.total)+'</b><span>'+esc(c.guardrail||'O total foi preservado, sem inventar estabelecimentos ou categorias.')+'</span></div>':''}
    function auditNote(source){const a=source?.management_group_audit||{};return '<div class="v170-audit"><div><span>Financiamentos auditados</span><b>'+money(a.financing_brl)+'</b><small>'+esc(a.financing_definition||'Parcelas imobiliárias e de veículo.')+'</small></div><div><span>Empréstimos</span><b>'+money(a.loans_brl)+'</b><small>Itaú e consignado Coopharma separados em subgrupos.</small></div><div><span>Obra e reforma · O Parque / CIPÓ 396</span><b>'+money(a.works_brl)+'</b><small>'+esc(a.works_definition||'O Parque / CIPÓ 396, sem financiamento.')+'</small></div></div>'}

    function dashboardV170(){
      const t=template(baseDashboard()),root=t.content.querySelector('.v168-dashboard');if(!root)return t.innerHTML;
      const sections=[...root.querySelectorAll('.v168-kpi-section')],restricted=sections[2]?.querySelector('.v168-kpis');
      if(restricted){const pension=[...restricted.querySelectorAll('.v168-kpi')].find(x=>norm(x.querySelector('span')?.textContent).includes('total em previdencias'));const expense=[...restricted.querySelectorAll('.v168-kpi')].find(x=>norm(x.querySelector('span')?.textContent).includes('total de despesas'));if(pension&&expense)restricted.insertBefore(pension,expense)}
      const data=v168.dashboard.data?.expense||{},card=[...root.querySelectorAll('.v168-card')].find(x=>/principais grupos/i.test(x.querySelector('h2')?.textContent||''));
      if(card&&managementGroups(data).length){card.querySelector('.v168-rank,.v169-coverage,.v170-rank')?.remove();const cardHead=card.querySelector('.v168-cardhead'),head=cardHead?.querySelector('small');if(head)head.textContent='Top 15 · grupos gerenciais';else cardHead?.insertAdjacentHTML('beforeend','<small>Top 15 · grupos gerenciais</small>');card.insertAdjacentHTML('beforeend',managementRank(managementRows(data,15),false)+coverage(data))}
      return t.innerHTML;
    }

    function expensesV170(){
      const t=template(baseExpenses()),root=t.content.querySelector('.v168-expenses'),data=v168.expense.data||{},groups=managementGroups(data);if(!root||!groups.length)return t.innerHTML;
      if(v168.expense.tab==='overview'){
        const card=[...root.querySelectorAll('.v168-card')].find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
        if(card){card.querySelector('.v168-rank,.v170-rank')?.remove();const h=card.querySelector('h2');if(h)h.textContent='Maiores grupos gerenciais';card.insertAdjacentHTML('beforeend',managementRank(managementRows(data,15),true)+auditNote(data)+coverage(data))}
      }
      if(v168.expense.tab==='categories'){
        const tabs=root.querySelector('.v168-tabs');tabs?.insertAdjacentHTML('afterend','<article class="v168-card v170-management-card"><div class="v168-cardhead"><div><span>Composição consolidada e rastreável</span><h2>Grupos gerenciais com subgrupos</h2></div><small>categorias originais preservadas abaixo</small></div>'+managementRank(managementRows(data,99),true)+auditNote(data)+coverage(data)+'</article>');
      }
      return t.innerHTML;
    }

    function awardType(x){return /cash/i.test(String(x.asset_type||''))?'Cash RSU':'RSU'}
    function rsuPanel(j){
      const r=j.rsu_summary||{},m=j.morgan_statement||{},available=m.available_components||{},future=m.future_components||{},q=m.quantities||{},recon=m.planning_schedule_reconciliation||{},rows=arr(j.rsu?.future_schedule),ret=j.employment_awards?.retention||{},first=rows[0]||{},currentPairs=[...new Set(rows.map(x=>String(x.unit_price_usd)+'|'+String(x.fx_rate)))],mixed=currentPairs.length>1;
      const gross=m.gross_total_brl??((finite(r.available_total_brl)||0)+(finite(r.future_regular_brl)||0)+(finite(r.future_cash_net_brl)||0)),considered=m.considered_total_after_reserve_brl??((finite(r.available_total_brl)||0)+(finite(r.future_considered_total_brl)||0));
      return '<div class="v170-morgan-summary"><div class="v168-kpis"><article class="v168-kpi primary"><span>Total bruto do extrato</span><strong>'+money(gross)+'</strong><small>disponível + indisponível · '+date(m.as_of||r.as_of)+'</small></article><article class="v168-kpi"><span>Total considerado após reserva</span><strong>'+money(considered)+'</strong><small>cenário de planejamento; não é outro saldo do banco</small></article><article class="v168-kpi"><span>Disponível agora</span><strong>'+money(m.available_total_brl??r.available_total_brl)+'</strong><small>ações vested + saldo em corretora</small></article><article class="v168-kpi"><span>Indisponível bruto</span><strong>'+money(m.unavailable_gross_brl)+'</strong><small>RSU + Cash RSU futuros</small></article><article class="v168-kpi"><span>Reserva fiscal projetada</span><strong>'+money(future.cash_rsu_reserve_brl)+'</strong><small>30% somente sobre Cash RSU</small></article></div><div class="v170-morgan-components"><article><span>Disponível</span><h3>'+money(m.available_total_brl??r.available_total_brl)+'</h3><dl><dt>Ações vested</dt><dd>'+money(available.vested_shares_brl??r.vested_shares_brl)+'</dd><dt>Saldo em corretora</dt><dd>'+money(available.brokerage_cash_brl??r.brokerage_cash_brl)+'</dd></dl></article><article><span>RSUs futuras · bruto</span><h3>'+money(future.regular_rsu_gross_brl)+'</h3><small>'+number(q.future_regular_rsu)+' unidades</small></article><article><span>Cash RSUs futuras · bruto</span><h3>'+money(future.cash_rsu_gross_brl)+'</h3><dl><dt>Após reserva</dt><dd>'+money(future.cash_rsu_after_reserve_brl)+'</dd><dt>Quantidade</dt><dd>'+number(q.future_cash_rsu)+'</dd></dl></article></div><div class="v168-note"><b>Leitura correta:</b> o total bruto confere com a tela da Morgan Stanley. O total considerado aplica uma reserva de 30% às Cash RSUs para planejamento; não presume imposto definitivo.</div></div>'+
      '<article class="v168-card v170-global-award"><div class="v168-cardhead"><div><span>Premissa única</span><h2>Atualizar a cotação de todos os vestings</h2></div><small>'+rows.length+' vesting(s) ativo(s)</small></div><div class="v170-global-form"><label>Preço da ação (USD)<input id="v170AllAwardPrice" type="number" min="0.01" max="10000" step="0.01" value="'+esc(first.unit_price_usd??'')+'"></label><label>Câmbio USD/BRL<input id="v170AllAwardFx" type="number" min="0.0001" max="100" step="0.000001" value="'+esc(first.fx_rate??'')+'"></label><button class="v168-btn primary" id="v170AllAwardApply" '+(state.globalAward.saving?'disabled':'')+'>'+(state.globalAward.saving?'Atualizando todos…':'Aplicar a todos os vestings')+'</button></div><div class="v170-global-help">'+(mixed?'As premissas atuais variam entre vestings. Os campos acima usam a primeira linha; ao aplicar, todos receberão exatamente os mesmos valores.':'A mesma ação e o mesmo câmbio serão aplicados a RSUs e Cash RSUs. A reserva de 30% continua somente nas Cash RSUs.')+'</div>'+(state.globalAward.message?'<div class="v168-note good">'+esc(state.globalAward.message)+'</div>':'')+(state.globalAward.error?'<div class="v168-note warn">'+esc(state.globalAward.error)+'</div>':'')+'</article>'+
      '<article class="v168-card"><div class="v168-cardhead"><div><span>Agenda calculada</span><h2>Vestings e disponibilidade</h2></div><strong>'+money(r.future_considered_total_brl)+'</strong></div><div class="v170-reconciliation"><span>Extrato e agenda permanecem separados para conferência.</span><small>RSU: diferença '+money(recon.regular_delta_brl)+' · Cash RSU bruto: diferença '+money(recon.cash_delta_brl)+'. Atualizar a cotação recalcula a agenda; não reescreve o extrato de '+date(m.as_of)+'.</small></div><div class="v168-awards">'+rows.map((x,i)=>{const type=awardType(x),value=type==='Cash RSU'?x.net_value_brl:x.gross_value_brl;return '<div class="v168-award"><div><span>Vesting</span><b>'+date(x.eligibility_date)+'</b><small>'+esc(type)+'</small></div><div><span>Quantidade</span><b>'+number(x.quantity)+'</b></div><div><span>Cotação usada</span><b>'+usd(x.unit_price_usd)+'</b><small>câmbio '+fx(x.fx_rate)+'</small></div><div><span>Valor considerado</span><b>'+money(value)+'</b><small>'+date(x.available_date)+' disponível</small></div><label><span>Antecipação opcional</span><input type="date" data-v168-award-date="'+i+'" max="'+esc(x.eligibility_date)+'" value="'+esc(x.anticipated_date||'')+'"></label><div><button class="v168-btn" data-v168-award-edit="'+i+'">Cotação individual</button> <button class="v168-btn blue" data-v168-award-save="'+i+'">Salvar data</button></div></div>'}).join('')+'</div></article><article class="v168-card"><div class="v168-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div><strong>'+money(ret.gross_total_brl)+'</strong></div><div class="v168-note">Permanece fora dos totais Morgan Stanley e da agenda de RSU/Cash RSU.</div></article>';
    }
    function wealthV170(){
      const t=template(baseWealth()),root=t.content.querySelector('.v168-wealth'),j=v168.wealth.data||{};if(!root)return t.innerHTML;
      const tabs=root.querySelector('.v168-tabs');
      if(v168.wealth.tab==='rsu'&&tabs){let n=tabs.nextSibling;while(n){const next=n.nextSibling;n.remove();n=next}tabs.insertAdjacentHTML('afterend',rsuPanel(j))}
      if(v168.wealth.tab==='overview'&&tabs){tabs.insertAdjacentHTML('afterend','<div class="v170-wealth-guide"><span><b>Hoje</b> ativos já adquiridos</span><span><b>Futuro</b> vestings ainda condicionais</span><span><b>Restrito</b> previdências fora do caixa</span><span><b>Passivos</b> saldo atual separado de parcelas futuras</span></div>');const cards=[...root.querySelectorAll('.v168-card')],passive=cards.find(x=>/dívidas e obrigações/i.test(x.querySelector('h2')?.textContent||''));passive?.classList.add('v170-passive-card');const net=[...root.querySelectorAll('.v168-kpi')].find(x=>norm(x.querySelector('span')?.textContent).includes('patrimonio liquido'));if(net){net.querySelector('span').textContent='Patrimônio líquido · saldos atuais';net.querySelector('small').textContent='obrigações sem saldo de quitação ficam visíveis, sem dupla contagem'}}
      return t.innerHTML;
    }

    async function applyAllAwards(){
      if(state.globalAward.saving)return;const price=Number(document.getElementById('v170AllAwardPrice')?.value),fxRate=Number(document.getElementById('v170AllAwardFx')?.value),count=arr(v168.wealth.data?.rsu?.future_schedule).length;
      if(!Number.isFinite(price)||price<=0||!Number.isFinite(fxRate)||fxRate<=0){state.globalAward.error='Informe preço e câmbio válidos.';state.globalAward.message='';render();return}
      if(!confirm('Aplicar US$ '+price.toLocaleString('pt-BR')+' e câmbio '+fxRate.toLocaleString('pt-BR')+' a todos os '+count+' vestings ativos?'))return;
      state.globalAward={saving:true,message:'',error:''};render();
      try{const {data,error}=await S.rpc('lts_browser_save_all_award_assumptions_v1',{p_unit_price_usd:price,p_fx_rate:fxRate});if(error||!data?.ok)throw Error(error?.message||'Não foi possível atualizar as premissas.');state.globalAward={saving:false,message:data.award_count+' vesting(s) recalculado(s) com a mesma cotação e câmbio.',error:''};v168.wealth.data=null;v168.dashboard.data=null;render()}
      catch(e){state.globalAward={saving:false,message:'',error:'Falha ao atualizar todos: '+String(e?.message||e)};render()}
    }

    function defaultRange(){const t=today();return{from:shift(t,-5),to:String(Number(t.slice(0,4))+1)+'-12-31'}}
    function oldDefaultRange(){const t=today();return{from:shift(t,-5),to:shift(t,30)}}
    function isOldDefault(from,to){const r=oldDefaultRange();return from===r.from&&to===r.to}
    loadFlowRange=async function(from,to){if(isOldDefault(from,to)){const r=defaultRange();from=r.from;to=r.to}const s=window.__LTS_V162_FLOW_RECOVERY_STATUS;if(s){s.default_range_applied=true;s.default_range_contract='previous-5-through-next-year-end-v170';s.default_range=defaultRange()}return baseLoadFlowRange(from,to)};
    function trackedBankEvent(e){return ['itau','bradesco','c6'].includes(norm(e?.account))&&String(e?.source||'')!=='economic_withholding'}
    function historicalCashParts(day){
      const record=mergedFlowDays().find(x=>x.date===day),proof=record?.v170_cash_arithmetic;if(proof?.version==='tracked-bank-cash-arithmetic-v1')return{rows:dayEvents(day).filter(trackedBankEvent),internalNet:finite(proof.internal_transfer_net_brl)||0,entries:(finite(proof.operating_entries_brl)||0)+Math.max(finite(proof.internal_transfer_net_brl)||0,0),exits:(finite(proof.operating_exits_brl)||0)+Math.max(-(finite(proof.internal_transfer_net_brl)||0),0),proof};
      const rows=dayEvents(day).filter(trackedBankEvent),operating=rows.filter(e=>!e.internal_transfer),internalNet=total(rows.filter(e=>e.internal_transfer).map(e=>e.signed_amount));
      return{rows,internalNet,entries:total(operating.filter(e=>(finite(e.signed_amount)||0)>0).map(e=>e.signed_amount))+Math.max(internalNet,0),exits:Math.abs(total(operating.filter(e=>(finite(e.signed_amount)||0)<0).map(e=>e.signed_amount)))+Math.max(-internalNet,0)};
    }
    function flowValsV170(x,prev){
      if(!x?.historical||ACC!=='Consolidado')return baseFlowVals(x,prev);
      const cash=historicalCashParts(x.date),z=x.Consolidado||{},c=x.fix86_columns||{},fin=c.saldo_final_operacional??z.bank_balance;
      if(fin==null)return{prev:null,en:cash.entries,ex:cash.exits,fin:null,basis:'movement_only',internalNet:cash.internalNet};
      const pc=prev?.fix86_columns||{},opening=pc.saldo_final_operacional??(prev?.historical?prev?.Consolidado?.bank_balance:null)??c.saldo_anterior_operacional??c.saldo_anterior??(Number(fin)-cash.entries+cash.exits);
      return{prev:opening,en:cash.entries,ex:cash.exits,fin,basis:'tracked_bank_cash',internalNet:cash.internalNet};
    }
    flowVals=flowValsV170;
    flowSemanticMeta=function(e){return e?.internal_transfer?'Movimentação interna · não é receita nem despesa':baseFlowSemanticMeta(e)};
    function openDefault(){const r=defaultRange();FLOWPRESET='5 anteriores + fim do próximo ano';SHOWZERO=true;FLOWFORCEZERO=false;return loadFlowRange(r.from,r.to)}
    function bindFlowDefault(){
      const nav=document.querySelector('.nav [data-v="Fluxo Diário"]');if(nav)nav.onclick=()=>{V='Fluxo Diário';state.lastRoute=V;renderNav();openDefault()};
      if(V!=='Fluxo Diário')return;const b=document.getElementById('flowDefaultRange');if(b){const r=defaultRange();b.textContent='5 anteriores + fim de '+r.to.slice(0,4);b.title='Cinco dias anteriores até 31 de dezembro do ano subsequente';b.classList.toggle('active',FLOWFROM===r.from&&FLOWTO===r.to);b.onclick=openDefault}const go=document.getElementById('goToday');if(go)go.onclick=openDefault;
    }
    function decorateFlow(){
      if(V!=='Fluxo Diário')return;document.querySelectorAll('.fx87-cons.fx87-head').forEach(h=>{const cells=h.children;if(cells[7])cells[7].textContent='Morgan disponível';if(cells[8])cells[8].textContent='Saldo c/ Morgan'});let note=document.querySelector('.v168-history-note');if(!note){const controls=document.querySelector('.flow-sticky-controls');controls?.insertAdjacentHTML('beforeend','<div class="v168-history-note"></div>');note=document.querySelector('.v168-history-note')}if(note)note.innerHTML='<b>Histórico auditável:</b> antes da primeira abertura documental completa, “saldo anterior” e “saldo final” usam o acumulado dos movimentos recuperados, com base zero em 09/10/2013. O consolidado considera somente Itaú, Bradesco e C6; transferências pareadas se anulam e uma movimentação interna líquida só aparece quando altera o caixa acompanhado.';
      document.querySelectorAll('.fx87-row.fx87-cons[id^="d-"]').forEach(row=>{const day=row.id.slice(2),x=mergedFlowDays().find(d=>d.date===day);if(!x?.historical)return;const cash=historicalCashParts(day);row.querySelector('.v170-internal-net')?.remove();if(Math.abs(cash.internalNet)>.005)row.querySelector('.fx87-date')?.insertAdjacentHTML('beforeend','<small class="v170-internal-net" title="Movimentação entre o caixa acompanhado e um recurso fora dele">Mov. interna líquida '+money(cash.internalNet)+'</small>')});
      document.querySelectorAll('.fx89-detail-row').forEach(row=>{const meta=[...row.querySelectorAll('small')].find(x=>/não é receita nem despesa/i.test(x.textContent||''));if(!meta)return;const label=row.querySelector('.fx89-detail-desc>span');if(label)label.textContent=(label.textContent||'').replace(/ · (Receita|Despesa)$/,' · Mov. interna')});
    }
    function bind(){document.getElementById('v170AllAwardApply')?.addEventListener('click',applyAllAwards);bindFlowDefault();decorateFlow()}
    function stamp(){const badge=window.parent.document.getElementById('scope');if(badge)badge.dataset.v170Route=V==='Fluxo Diário'?'Fluxo de caixa':V}
    function after(){stamp();bind()}

    dashboard=dashboardV170;despesas=expensesV170;patrimonio=wealthV170;
    render=function(){const entered=V==='Fluxo Diário'&&state.lastRoute!=='Fluxo Diário';state.lastRoute=V;const out=baseRender();after();if(entered)queueMicrotask(()=>{if(V==='Fluxo Diário')openDefault()});return out};
    renderNav=function(){const out=baseNav();stamp();bindFlowDefault();return out};
    const observer=new MutationObserver(()=>requestAnimationFrame(()=>{stamp();decorateFlow()}));observer.observe(document.body,{childList:true,subtree:true});

    if(v168.dashboard.data&&!v168.dashboard.data.expense?.management_groups){v168.dashboard.token=(v168.dashboard.token||0)+1;v168.dashboard.data=null;v168.dashboard.started=false;v168.dashboard.loading=false;v168.dashboard.pending=0}
    if(v168.expense.data&&!v168.expense.data.management_groups){v168.expense.token=(v168.expense.token||0)+1;v168.expense.data=null;v168.expense.loading=false}
    if(v168.wealth.data&&!v168.wealth.data.morgan_statement){v168.wealth.data=null;v168.wealth.loading=false}
    if(D&&!N.classList.contains('hidden'))render();
  }

  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!String(w.location.pathname||'').endsWith('/index.html'))return null;return{w,d}}catch{return null}}
  function install(){const f=frame();if(!f)return false;if(!f.w.__LTS_V169_V168_FEEDBACK?.installed)return false;if(!f.d.getElementById('lts-v170-style')){const l=f.d.createElement('link');l.id='lts-v170-style';l.rel='stylesheet';l.href='lts-v170-v169-review.css?v=20260917-v170a';f.d.head.appendChild(l)}if(!f.w.__LTS_V170_V169_REVIEW?.installed&&!f.d.getElementById('lts-v170-runtime')){const s=f.d.createElement('script');s.id='lts-v170-runtime';s.textContent='('+runtime.toString()+')();';f.d.head.appendChild(s)}const ready=f.w.__LTS_V170_V169_REVIEW?.installed===true;if(ready&&gate)gate.hidden=true;return ready}
  function burst(){const current=++generation;let n=0;function step(){if(current!==generation)return;const ok=install();n++;if(!ok&&n<320)setTimeout(step,100)}step();[400,900,1800,3600,7000,12000,20000,30000].forEach(ms=>setTimeout(()=>{if(current===generation)install()},ms))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();window.__LTS_TOP_CANDIDATE_VERSION='v170-v169-review';
})();
