(function(){
  'use strict';
  const CONTRACT='executive-visual-system-v2';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let generation=0;

  function visualRuntime(){
    'use strict';
    if(window.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed)return;
    const modelApi=window.LTSDashboardReadModel;
    if(!modelApi||typeof dashboard!=='function'||typeof render!=='function'||typeof renderNav!=='function')return;

    const original={
      dashboard,
      despesas,
      patrimonio,
      atualizacoes,
      cartoes:typeof cartoesBase121==='function'?cartoesBase121:cartoes,
      render,
      renderNav
    };
    const VERSION='V165';
    const state=window.__LTS_V165_STATE||(window.__LTS_V165_STATE={
      expenseTab:'overview',wealthTab:'overview',
      wealth:{loading:false,loaded:false,data:null,error:null},
      search:{query:'',loading:false,total:0,rows:[],error:null,seq:0,timer:null},
      anticipation:{results:{},loading:{},errors:{}}
    });

    const status=window.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2={
      installed:true,contract:'executive-visual-system-v2',version:'v165',
      reference_sha256:'0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b',
      navigation_routes:['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações'],
      planning_consolidated_into_dashboard:true,cards_consolidated_into_expenses:true,
      classification_and_document_coverage_separated:true,
      rsu_regular_gross_factor:1,cash_rsu_net_factor:.7,
      anticipated_vesting_is_scenario_only:true,retention_separate_from_rsu:true,
      transaction_search_without_date:true,flow_renderer_preserved:true,
      private_awards_only:true,anticipation_audited_and_user_scoped:true,
      financial_writers_changed:false,public_index_changed:false,style_ready:false
    };

    let link=document.getElementById('lts-executive-visual-system-v2-style');
    if(!link){link=document.createElement('link');link.id='lts-executive-visual-system-v2-style';link.rel='stylesheet';link.href='lts-executive-visual-system-v2.css?v=20260916-v165';document.head.appendChild(link)}
    link.addEventListener('load',()=>{status.style_ready=true;if(D&&!N.classList.contains('hidden'))render()},{once:true});
    if(link.sheet)status.style_ready=true;

    const finite=value=>value!==null&&value!==undefined&&value!==''&&Number.isFinite(Number(value))?Number(value):null;
    const amount=value=>finite(value)===null?'—':brl(Number(value));
    const date=value=>value?fmt(String(value).slice(0,10)):'—';
    const iso=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||'').slice(0,10))?String(value).slice(0,10):null;
    const text=value=>esc(value==null?'':String(value));
    const signed=value=>finite(value)!==null&&Number(value)<0?'is-negative':'';
    const total=values=>(values||[]).reduce((sum,value)=>sum+(finite(value)||0),0);
    const pct=value=>finite(value)===null?'—':Number(value).toLocaleString('pt-BR',{maximumFractionDigits:0})+'%';
    const number=value=>finite(value)===null?'—':Number(value).toLocaleString('pt-BR',{maximumFractionDigits:3});
    const usd=value=>finite(value)===null?'—':'US$ '+Number(value).toLocaleString('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:3});
    const fx=value=>finite(value)===null?'—':'R$ '+Number(value).toLocaleString('pt-BR',{minimumFractionDigits:4,maximumFractionDigits:5});
    const dayBefore=value=>modelApi.dayBefore(value);
    const monthLabel=value=>{const key=String(value||'').slice(0,7);if(!/^\d{4}-\d{2}$/.test(key))return key||'—';return new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(key+'-01T12:00:00')).replace('.','')};
    const normalize=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();

    function icon(route){
      const paths={
        'Dashboard':'<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="4" rx="2"/><rect x="14" y="11" width="7" height="10" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/>',
        'Fluxo Diário':'<path d="M4 7h12M13 4l3 3-3 3M20 17H8M11 14l-3 3 3 3"/>',
        'Despesas':'<path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/>',
        'Patrimônio':'<path d="M3 10.5 12 4l9 6.5M5 10v9h14v-9M9 19v-5h6v5"/>',
        'Atualizações':'<path d="M12 3a9 9 0 1 0 8.1 5.1M20 3v5h-5"/><path d="M12 7v5l3 2"/>'
      };
      return '<svg viewBox="0 0 24 24" aria-hidden="true">'+(paths[route]||paths.Dashboard)+'</svg>';
    }

    function go(route,tab){
      if(route==='Planejamento')route='Dashboard';
      if(route==='Cartões'){route='Despesas';tab='cards'}
      if(route==='Lançamentos'){route='Atualizações';tab='search'}
      if(route==='Despesas'&&tab)state.expenseTab=tab;
      if(route==='Patrimônio'&&tab)state.wealthTab=tab;
      V=route;renderNav();render();window.scrollTo({top:0,behavior:'smooth'});
      if(tab==='search')setTimeout(()=>document.getElementById('v165SearchInput')?.focus(),50);
    }

    function sourceAsOf(){
      const candidates=[D?.expense_universe_qa?.bank_documented_through,D?.updates?.freshness?.position_as_of,D?.dashboard_cockpit?.liquidity?.as_of,D?.dashboard_cockpit?.as_of].map(iso).filter(Boolean);
      return candidates[0]||null;
    }

    function pageHead(kicker,title,subtitle,aside){
      return '<header class="v165-pagehead"><div><span class="v165-eyebrow">'+text(kicker)+'</span><h1>'+text(title)+'</h1><p>'+text(subtitle)+'</p></div>'+(aside||'')+'</header>';
    }

    function kpi(label,value,note,kind){
      return '<article class="v165-kpi '+(kind||'')+'"><span>'+text(label)+'</span><strong class="'+signed(value)+'">'+amount(value)+'</strong><small>'+text(note||'')+'</small></article>';
    }

    function chart(vm){
      const initial=finite(vm.kpis.shortTerm?.value??vm.kpis.bankCash);
      const points=[];
      if(initial!==null)points.push({date:today(),label:'Hoje',base:initial,conditional:initial,restricted:initial+(finite(vm.kpis.fgts)||0)});
      (vm.horizons||[]).forEach(point=>points.push(point));
      if(points.length<2)return '<div class="v165-empty">Projeção ainda sem pontos suficientes.</div>';
      const values=points.flatMap(point=>[point.base,point.conditional,point.restricted]).filter(value=>finite(value)!==null);
      const lo=Math.min(0,...values),hi=Math.max(0,...values),span=Math.max(1,hi-lo),W=650,H=218,pad={l:34,r:18,t:18,b:34};
      const x=index=>pad.l+index*((W-pad.l-pad.r)/Math.max(1,points.length-1));
      const y=value=>pad.t+(hi-Number(value))/span*(H-pad.t-pad.b);
      const path=key=>points.map((point,index)=>finite(point[key])===null?null:{index,value:Number(point[key])}).filter(Boolean).map((point,index)=>(index?'L':'M')+x(point.index).toFixed(1)+' '+y(point.value).toFixed(1)).join(' ');
      const labels=points.map((point,index)=>'<text x="'+x(index)+'" y="'+(H-8)+'" text-anchor="middle">'+text(point.label||date(point.date))+'</text>').join('');
      return '<div class="v165-chart"><svg viewBox="0 0 '+W+' '+H+'" role="img" aria-label="Evolução da liquidez"><line class="zero" x1="'+pad.l+'" x2="'+(W-pad.r)+'" y1="'+y(0)+'" y2="'+y(0)+'"/><text class="zero-label" x="2" y="'+(y(0)+3)+'">R$ 0</text><path class="base" d="'+path('base')+'"/><path class="conditional" d="'+path('conditional')+'"/><path class="restricted" d="'+path('restricted')+'"/><g class="labels">'+labels+'</g></svg></div>';
    }

    function categoryParts(label){
      const raw=String(label||'Outros'),n=normalize(raw);
      if(n.includes('benjamin')&&n.includes('educa'))return {group:'Benjamin',detail:'Educação'};
      if(n==='educacao')return {group:'Benjamin',detail:'Educação'};
      if(n.includes('financ'))return {group:'Financiamento imobiliário',detail:''};
      return {group:raw,detail:''};
    }

    function rank(items,maxItems=5){
      const rows=(items||[]).slice(0,maxItems),max=Math.max(1,...rows.map(item=>Math.abs(finite(item.amount??item.total??item.spend)||0)));
      return '<div class="v165-rank">'+(rows.map(item=>{const value=finite(item.amount??item.total??item.spend)||0,parts=categoryParts(item.category||item.name||item.label);return '<div class="v165-rankrow"><div><b>'+text(parts.group)+'</b>'+(parts.detail?'<small>'+text(parts.detail)+'</small>':'')+'</div><i><u style="width:'+Math.max(3,Math.abs(value)/max*100)+'%"></u></i><strong>'+amount(value)+'</strong></div>'}).join('')||'<div class="v165-empty">Sem composição disponível.</div>')+'</div>';
    }

    function dashboardV165(){
      const cockpit=D?.dashboard_cockpit||{},vm=modelApi.build(cockpit),planning=D?.planning_executive||{},ps=planning.summary||{},wealth=D?.wealth_executive||{},ws=wealth.summary||{},source=sourceAsOf();
      const firstGap=iso(ps.first_real_gap_date)||vm.decision.firstNegative,covered=firstGap?dayBefore(firstGap):vm.decision.coveredUntil,requestBy=iso(ps.fgts_request_by)||vm.planning.fgtsRequestBy,uncovered=iso(ps.first_negative_even_with_fgts)||iso(cockpit.planning_audited?.first_uncovered_gap_date),worst=finite(ps.worst_balance??cockpit.planning_audited?.worst_before_brl),worstAfter=finite(cockpit.planning_audited?.worst_after_brl),fgts=finite(vm.kpis.fgts),episodes=planning.gap_episodes||[];
      const accounts=(vm.accounts||[]).map((account,index)=>'<div class="v165-bankrow"><i>'+text((account.institution||account.account||'C').slice(0,3).toUpperCase())+'</i><div><b>'+text(account.institution||account.account||'Conta')+'</b><small>posição '+date(source||vm.asOf)+'</small></div><strong>'+amount(account.balance)+'</strong></div>').join('');
      const next=vm.cards.nextDue||{},actions=(vm.work.actions||[]).slice(0,3),current=vm.expenses.current||{},previous=vm.expenses.previous||{};
      const liquidity=finite(ws.liquidity_through_d3??vm.kpis.shortTerm?.value)||0,assets=finite(ws.assets_central)||0,cipo=finite(wealth.assets?.cipo_396?.market_central)||0,vehicle=finite(wealth.assets?.volvo_xc40?.market_central)||0,ringTotal=Math.max(1,assets),liqShare=Math.max(2,Math.min(35,liquidity/ringTotal*100)),vehicleShare=Math.max(2,Math.min(15,vehicle/ringTotal*100));
      const actionTitle=requestBy?'Resgatar FGTS até '+date(requestBy):'Definir ação de cobertura';
      const answer=firstGap?'Coberto até '+date(covered):'Horizonte coberto';
      return '<div class="v165-dashboard" data-reference-sha="0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b">'+
        pageHead('LTS Wealth / resumo executivo','Dashboard','Caixa, horizonte e decisões em uma única leitura.','<div class="v165-headtools"><span class="v165-source"><i></i>Hoje '+date(today())+(source?' · dados até '+date(source):'')+'</span><button id="v165Refresh" class="v165-btn secondary" type="button">Atualizar</button></div>')+
        '<section class="v165-decision"><div class="v165-decision-main"><span>Disponibilidade projetada</span><strong>'+text(answer)+'</strong><small>'+(firstGap?'primeiro dia negativo em '+date(firstGap):'nenhum saldo negativo encontrado')+'</small></div><div class="v165-decision-step danger"><span>Quando fico negativo</span><b>'+date(firstGap)+'</b><small>'+(worst!==null?'pior ponto '+amount(worst):'valor ainda não disponível')+'</small></div><div class="v165-decision-step action"><span>Ação recomendada</span><b>'+text(actionTitle)+'</b><small>'+amount(fgts)+' · contingência aproximada D+30</small></div><div class="v165-decision-step"><span>Depois do FGTS</span><b>'+(uncovered?'nova falta em '+date(uncovered):'horizonte coberto')+'</b><small>'+(worstAfter!==null?'pior ponto '+amount(worstAfter):'sem valor residual informado')+'</small></div></section>'+
        '<section class="v165-kpis">'+
          kpi('Dinheiro em contas',vm.kpis.bankCash,'saldo bancário evidenciado','primary')+
          kpi('Contas + curto prazo',vm.kpis.shortTerm?.value,'contas + liquidez D+0')+
          kpi('RSUs vested',vm.kpis.vested,'adquiridas · liquidez D+3','positive')+
          kpi('FGTS',vm.kpis.fgts,'restrito · aproximadamente D+30','restricted')+
          kpi('Despesas do mês',vm.kpis.expenses,'mês parcial documentado','expense')+
        '</section>'+
        '<section class="v165-grid dashboard-main"><article class="v165-card liquidity-card"><div class="v165-cardhead"><div><span>Liquidez</span><h2>Evolução projetada</h2></div><button class="v165-btn quiet" data-v165-go="Fluxo Diário" type="button">Abrir fluxo</button></div><div class="v165-legend"><span><i class="base"></i>sem novos vestings</span><span><i class="conditional"></i>com vestings</span><span><i class="restricted"></i>com FGTS</span></div>'+chart(vm)+'</article><article class="v165-card distribution-card"><div class="v165-cardhead"><div><span>Patrimônio</span><h2>Distribuição</h2></div></div><div class="v165-ring" style="--liq:'+liqShare+'%;--vehicle:'+vehicleShare+'%"><div><b>'+amount(ws.net_worth_central)+'</b><small>líquido estimado</small></div></div><div class="v165-ringlegend"><span><i class="property"></i>CIPÓ <b>'+amount(cipo)+'</b></span><span><i class="liquid"></i>Liquidez <b>'+amount(liquidity)+'</b></span><span><i class="vehicle"></i>Volvo <b>'+amount(vehicle)+'</b></span></div></article><article class="v165-card bank-card"><div class="v165-cardhead"><div><span>Contas</span><h2>Posição por banco</h2></div></div>'+(accounts||'<div class="v165-empty">Contas não recebidas.</div>')+'<button class="v165-link" data-v165-go="Fluxo Diário" type="button">Ver movimentações</button></article></section>'+
        '<section class="v165-grid dashboard-lower"><article class="v165-card"><div class="v165-cardhead"><div><span>Despesas</span><h2>Principais grupos</h2></div><button class="v165-btn quiet" data-v165-go="Despesas" type="button">Ver análise</button></div>'+rank(vm.expenses.top,4)+'<div class="v165-comparison"><span>Mês anterior</span><b>'+amount(previous.spend)+'</b><span>Atual</span><b>'+amount(current.spend)+'</b></div></article><article class="v165-card"><div class="v165-cardhead"><div><span>Próximos compromissos</span><h2>O que vem pela frente</h2></div></div><div class="v165-commit"><i class="blue">'+date(next.due_date).slice(0,5)+'</i><div><b>Próxima fatura</b><small>'+text(next.card_name||'cartão')+'</small></div><strong>'+amount(next.amount)+'</strong></div><div class="v165-commit"><i class="gold">'+date(requestBy).slice(0,5)+'</i><div><b>Acionar FGTS</b><small>para chegar antes da primeira ruptura</small></div><strong>'+amount(fgts)+'</strong></div><div class="v165-commit"><i class="red">'+date(firstGap).slice(0,5)+'</i><div><b>Primeiro dia negativo</b><small>com vestings programados</small></div><strong>'+amount(worst)+'</strong></div></article><article class="v165-card"><div class="v165-cardhead"><div><span>Atualizações</span><h2>O que pede atenção</h2></div><b class="v165-count">'+text(vm.work.count??0)+'</b></div>'+(actions.map(action=>'<button class="v165-actionrow" data-v165-go="Atualizações" type="button"><i></i><span><b>'+text(action.title||'Atualização')+'</b><small>'+text(action.description||'')+'</small></span></button>').join('')||'<div class="v165-ok"><i>✓</i><span><b>Nenhuma ação prioritária</b><small>O caixa não depende de uma pendência aberta agora.</small></span></div>')+'<button class="v165-link" data-v165-go="Atualizações" type="button">Abrir central</button></article></section>'+
        '<section class="v165-cashplan"><div><span>Plano de caixa</span><h2>Agir antes do déficit</h2></div><div class="v165-planpoint"><span>Preparar</span><b>'+date(requestBy)+'</b></div><i></i><div class="v165-planpoint danger"><span>Primeiro negativo</span><b>'+date(firstGap)+'</b></div><div class="v165-planpoint"><span>Contingência</span><b>'+amount(fgts)+'</b></div></section>'+
      '</div>';
    }

    function expenseState(){
      try{return typeof ex135State==='function'?ex135State():(window.EX135||{})}catch(error){return {error:String(error?.message||error)}}
    }

    function expenseTabs(){
      const tabs=[['overview','Visão geral'],['categories','Categorias'],['cards','Cartões'],['transactions','Lançamentos']];
      return '<div class="v165-tabs" role="tablist">'+tabs.map(([key,label])=>'<button type="button" role="tab" aria-selected="'+(state.expenseTab===key)+'" class="'+(state.expenseTab===key?'active':'')+'" data-v165-expense-tab="'+key+'">'+label+'</button>').join('')+'</div>';
    }

    function periodPicker(s){
      const current=s?.rangeKey||'ytd';return '<div class="v165-periods">'+[['ytd','Ano atual'],['6m','6 meses'],['12m','12 meses'],['all','Desde 2013']].map(([key,label])=>'<button type="button" class="'+(current===key?'active':'')+'" data-v165-expense-range="'+key+'">'+label+'</button>').join('')+'</div>';
    }

    function monthBars(rows,key='total'){
      const items=(rows||[]).slice(-12),max=Math.max(1,...items.map(row=>Math.abs(finite(row[key])||0)));
      return '<div class="v165-bars">'+(items.map(row=>{const value=finite(row[key])||0;return '<button type="button" class="v165-bar" data-v165-month="'+text(row.month||row.reference_month)+'" title="'+text(monthLabel(row.month||row.reference_month))+' · '+text(amount(value))+'"><b>'+amount(value)+'</b><i><u style="height:'+Math.max(4,Math.abs(value)/max*100)+'%"></u></i><span>'+text(monthLabel(row.month||row.reference_month))+'</span></button>'}).join('')||'<div class="v165-empty">Sem histórico mensal disponível.</div>')+'</div>';
    }

    function cardGroups(){
      const operating=D?.card_operating||{},map=new Map(),key=name=>{const n=normalize(name);if(n.includes('aeternum'))return'aeternum';if(n.includes('personnalite'))return'personnalite';if(n.includes('c6'))return'c6';return n||'cartao'};
      const ensure=name=>{const id=key(name);if(!map.has(id))map.set(id,{id,name:String(name||'Cartão'),open:null,closed:null,future:[]});return map.get(id)};
      (operating.open_cycles||[]).forEach(item=>ensure(item.card_name).open=item);
      (operating.closed_or_due||[]).forEach(item=>ensure(item.card_name).closed=item);
      (operating.contracted_installment_floor_months||[]).forEach(month=>(month.detail||[]).forEach(item=>ensure(item.card_name).future.push({...item,reference_month:month.reference_month})));
      return [...map.values()].sort((a,b)=>(b.open?.amount||0)-(a.open?.amount||0));
    }

    function cardsPanel(){
      const o=D?.card_operating||{},groups=cardGroups(),history=D?.card_history?.monthly||[],next=o.next_due||{};
      return '<section class="v165-expense-cards"><div class="v165-kpis four">'+kpi('Faturas abertas',o.open_cycles_total,(o.open_cycles||[]).length+' ciclo(s)','primary')+'<article class="v165-kpi"><span>Próximo vencimento</span><strong>'+date(next.due_date)+'</strong><small>'+amount(next.amount)+' · '+text(next.card_name||'cartão')+'</small></article>'+kpi('Parcelas contratadas',o.contracted_installment_floor_total,'piso futuro conhecido','restricted')+'<article class="v165-kpi '+(finite(o.classification_review?.pending_lines)?'expense':'positive')+'"><span>A classificar</span><strong>'+text(String(o.classification_review?.pending_lines||0))+'</strong><small>lançamento(s) de cartão</small></article></div><div class="v165-grid split"><article class="v165-card"><div class="v165-cardhead"><div><span>Histórico</span><h2>Uso mensal dos cartões</h2></div></div>'+monthBars(history,'total')+'</article><article class="v165-card"><div class="v165-cardhead"><div><span>Carteira</span><h2>Faturas e parcelas</h2></div></div>'+(groups.map(group=>{const current=group.closed||group.open,future=total(group.future.map(item=>item.amount));return '<div class="v165-cardrow"><i>'+text(group.id==='aeternum'?'AE':group.id==='personnalite'?'IT':group.id==='c6'?'C6':'CC')+'</i><div><b>'+text(group.name)+'</b><small>'+(group.closed?'vencida · confirmar pagamento':group.open?'aberta · ainda pode crescer':'sem ciclo aberto')+(current?.due_date?' · vence '+date(current.due_date):'')+'</small></div><strong>'+amount(current?.amount)+'</strong><em>parcelas '+amount(future)+'</em></div>'}).join('')||'<div class="v165-empty">Nenhum cartão recebido.</div>')+'</article></div><div class="v165-callout"><b>Uma compra, uma despesa.</b><span>Pagamento de fatura liquida o caixa e não duplica o consumo. Cartões da mesma fatura permanecem agrupados pela base reconciliada.</span></div></section>';
    }

    function expenseOverview(report,s){
      const summary=report.summary||{},monthly=report.monthly_detail||[],windows=report.rolling_windows||{},windowData=windows[s.winKey||'6m']||windows['6m']||{},last=monthly.at(-1)||{},pending=(finite(D?.semantic_review?.pending_groups)||0)+(finite(D?.card_classification_review?.pending_groups)||0),documentCoverage=finite(windowData.transaction_detail_pct??report.data_quality?.selected_transaction_detail_pct),classified=pending===0?'100%':pending+' pendência(s)';
      return '<div class="v165-kpis four"><article class="v165-kpi primary"><span>Gasto no período</span><strong>'+amount(summary.selected_total)+'</strong><small>'+text(monthly.length)+' competência(s)</small></article>'+kpi('Média mensal',summary.monthly_average,'média do período')+kpi('Mês atual',last.total,(last.is_partial?'parcial · ':'')+monthLabel(last.month),'expense')+'<article class="v165-kpi positive"><span>Classificação revisada</span><strong>'+text(classified)+'</strong><small>escopo disponível; cobertura documental '+pct(documentCoverage)+'</small></article></div><div class="v165-grid expense-overview"><article class="v165-card wide"><div class="v165-cardhead"><div><span>Tendência</span><h2>Despesas mês a mês</h2></div><small>toque no mês para abrir os lançamentos</small></div>'+monthBars(monthly)+'</article><article class="v165-card"><div class="v165-cardhead"><div><span>Composição</span><h2>Principais grupos</h2></div></div>'+rank(windowData.top_categories,7)+'</article></div><div class="v165-grid split"><article class="v165-card"><div class="v165-cardhead"><div><span>Qualidade</span><h2>O que está classificado</h2></div></div><div class="v165-quality"><div class="complete"><i>✓</i><span><b>'+text(classified)+'</b><small>das decisões no escopo revisado</small></span></div><div><b>'+pct(documentCoverage)+'</b><small>dos lançamentos têm detalhe documental individual</small></div></div><p class="v165-footnote">Classificação e cobertura documental são medidas diferentes. Faturas antigas sem itens preservam o total sem inventar estabelecimentos.</p></article><article class="v165-card"><div class="v165-cardhead"><div><span>Cartões</span><h2>Obrigações atuais</h2></div><button class="v165-btn quiet" data-v165-expense-tab="cards">Ver cartões</button></div><div class="v165-bigrow"><span>Em aberto</span><b>'+amount(D?.card_operating?.open_cycles_total)+'</b></div><div class="v165-bigrow"><span>Piso de parcelas futuras</span><b>'+amount(D?.card_operating?.contracted_installment_floor_total)+'</b></div></article></div>';
    }

    function categoriesPanel(report,s){
      const w=report.rolling_windows?.[s.winKey||'6m']||report.rolling_windows?.['6m']||{},items=w.top_categories||[];
      return '<div class="v165-grid categories"><article class="v165-card"><div class="v165-cardhead"><div><span>Grupos</span><h2>Para onde foi o dinheiro</h2></div><b>'+amount(w.known_category_total)+'</b></div>'+rank(items,20)+'</article><article class="v165-card"><div class="v165-cardhead"><div><span>Família</span><h2>Benjamin</h2></div></div><div class="v165-family"><i>B</i><div><b>Benjamin</b><small>grupo de acompanhamento</small></div><strong>'+amount(total(items.filter(item=>normalize(item.name||item.category).includes('educa')||normalize(item.name||item.category).includes('benjamin')).map(item=>item.total??item.amount)))+'</strong></div><div class="v165-subcategory"><span>Educação</span><b>'+amount(total(items.filter(item=>normalize(item.name||item.category).includes('educa')||normalize(item.name||item.category).includes('benjamin')).map(item=>item.total??item.amount)))+'</b></div><p class="v165-footnote">A apresentação agrupa Educação em Benjamin; os lançamentos e a classificação de origem permanecem preservados.</p></article></div>';
    }

    function transactionsPanel(report){
      const rows=(D?.expense_drilldown?.rows||[]).slice().sort((a,b)=>String(b.transaction_date||b.event_date||'').localeCompare(String(a.transaction_date||a.event_date||''))).slice(0,80);
      return '<article class="v165-card"><div class="v165-cardhead"><div><span>Detalhes</span><h2>Lançamentos recentes</h2></div><button class="v165-btn quiet" data-v165-go="Atualizações" data-v165-tab="search">Pesquisar todo o histórico</button></div><div class="v165-tablewrap"><table class="v165-table"><thead><tr><th>Data</th><th>Descrição</th><th>Grupo</th><th>Origem</th><th class="num">Valor</th></tr></thead><tbody>'+(rows.map(row=>{const parts=categoryParts(row.category);return '<tr><td>'+date(row.transaction_date||row.event_date)+'</td><td><b>'+text(row.counterparty||row.description||row.description_raw||'Não informado')+'</b></td><td>'+text(parts.group)+(parts.detail?'<small>'+text(parts.detail)+'</small>':'')+'</td><td>'+text(row.card_name||row.account||row.origin_name||'—')+'</td><td class="num">'+amount(row.amount)+'</td></tr>'}).join('')||'<tr><td colspan="5" class="v165-empty">Abra um mês para carregar os lançamentos detalhados.</td></tr>')+'</tbody></table></div></article>';
    }

    function despesasV165(){
      const s=expenseState(),report=s.data||{},source=sourceAsOf(),aside='<div class="v165-headtools"><span class="v165-source"><i></i>Dados até '+date(report.period?.last_available||source)+'</span>'+periodPicker(s)+'</div>';
      let body='';
      if(s.loading&&!s.data)body='<div class="v165-skeleton">Carregando despesas reconciliadas…</div>';
      else if(s.error&&!s.data)body='<div class="v165-callout error"><b>Despesas indisponíveis</b><span>'+text(s.error)+'</span></div>';
      else if(state.expenseTab==='cards')body=cardsPanel();
      else if(state.expenseTab==='categories')body=categoriesPanel(report,s);
      else if(state.expenseTab==='transactions')body=transactionsPanel(report);
      else body=expenseOverview(report,s);
      return '<div class="v165-report v165-expenses">'+pageHead('Despesas / consumo e cartões','Despesas','Consumo, cartões e lançamentos sem dupla contagem.',aside)+expenseTabs()+body+'</div>';
    }

    function ensureWealth(){
      if(state.wealth.loading||state.wealth.loaded)return;
      state.wealth.loading=true;
      S.rpc('lts_browser_wealth_detail_v2').then(({data,error})=>{if(error||!data)throw Error(error?.message||'Patrimônio indisponível');state.wealth.data=data;state.wealth.loaded=true}).catch(error=>state.wealth.error=String(error?.message||error)).finally(()=>{state.wealth.loading=false;if(V==='Patrimônio')render()});
    }

    function awardType(item){return /cash/i.test(String(item?.asset_type||item?.type||item?.label||''))?'Cash RSU':'RSU'}
    function awardData(){
      const j=state.wealth.data||{},source=Array.isArray(j.rsu?.future_schedule)?j.rsu.future_schedule:[];
      return source.map(item=>{
        const type=awardType(item),vesting=iso(item.eligibility_date),anticipated=iso(item.anticipated_date),id=String(item.group_key||''),awardIds=Array.isArray(item.award_ids)?item.award_ids.map(String):[];
        return {...item,id,awardIds,type,vesting,units:finite(item.quantity),price:finite(item.unit_price_usd),fx:finite(item.fx_rate),gross:finite(item.gross_value_brl),net:type==='Cash RSU'?finite(item.net_value_brl):finite(item.gross_value_brl),available:iso(item.available_date),anticipated,effective:anticipated||vesting};
      }).filter(item=>item.id&&item.vesting&&item.awardIds.length).sort((a,b)=>String(a.effective).localeCompare(String(b.effective)));
    }

    function wealthTabs(){
      const tabs=[['overview','Visão geral'],['rsu','RSUs e awards'],['assets','Bens e dívidas']];return '<div class="v165-tabs" role="tablist">'+tabs.map(([key,label])=>'<button type="button" role="tab" aria-selected="'+(state.wealthTab===key)+'" class="'+(state.wealthTab===key?'active':'')+'" data-v165-wealth-tab="'+key+'">'+label+'</button>').join('')+'</div>';
    }

    function wealthOverview(j){
      const w=j.wealth||D?.wealth_executive||{},s=w.summary||{},l=w.liquidity||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},mid=finite(s.net_worth_central),lo=finite(s.net_worth_low),hi=finite(s.net_worth_high),span=Math.max(1,(hi||0)-(lo||0)),marker=Math.max(0,Math.min(100,((mid||0)-(lo||0))/span*100));
      return '<div class="v165-kpis four"><article class="v165-kpi primary"><span>Patrimônio líquido estimado</span><strong>'+amount(mid)+'</strong><small>faixa '+amount(lo)+' → '+amount(hi)+'</small></article>'+kpi('Ativos',s.assets_central,'valor central')+kpi('Dívidas conhecidas',s.known_debt_total,'saldos documentados','expense')+kpi('Liquidez até D+3',s.liquidity_through_d3,'FGTS separado','positive')+'</div><div class="v165-grid split"><article class="v165-card"><div class="v165-cardhead"><div><span>Faixa patrimonial</span><h2>Valor líquido estimado</h2></div></div><div class="v165-range-values"><span>Baixa<b>'+amount(lo)+'</b></span><span>Central<b>'+amount(mid)+'</b></span><span>Alta<b>'+amount(hi)+'</b></span></div><div class="v165-range"><i style="left:'+marker+'%"></i></div><p class="v165-footnote">A faixa varia com o preço de mercado do imóvel e do veículo; não é laudo nem preço garantido.</p></article><article class="v165-card"><div class="v165-cardhead"><div><span>Liquidez</span><h2>Quando pode virar caixa</h2></div><button class="v165-btn quiet" data-v165-wealth-tab="rsu">Abrir RSUs</button></div><div class="v165-liqrow"><span>Contas + Cofrinho</span><b>'+amount((finite(l.bank_cash)||0)+(finite(l.d0)||0))+'</b><em>D+0</em></div><div class="v165-liqrow"><span>RSUs vested</span><b>'+amount(l.d3)+'</b><em>D+3</em></div><div class="v165-liqrow"><span>FGTS</span><b>'+amount(l.fgts_contingency)+'</b><em>D+30</em></div><div class="v165-liqrow"><span>Awards futuros</span><b>'+amount(s.future_awards_excluded)+'</b><em>futuro</em></div></article></div><div class="v165-grid split"><article class="v165-card asset-summary"><div class="v165-cardhead"><div><span>Principal ativo</span><h2>CIPÓ 396</h2></div><button class="v165-btn quiet" data-v165-wealth-tab="assets">Ver detalhes</button></div><strong>'+amount(c.equity_central)+'</strong><small>equity central</small><div class="v165-splitvalues"><span>Mercado<b>'+amount(c.market_central)+'</b></span><span>Dívida<b>'+amount(c.documentary_debt)+'</b></span></div></article><article class="v165-card asset-summary"><div class="v165-cardhead"><div><span>Veículo</span><h2>Volvo XC40</h2></div></div><strong>'+amount(v.equity_central)+'</strong><small>equity central</small><div class="v165-splitvalues"><span>Mercado<b>'+amount(v.market_central)+'</b></span><span>Financiado<b>'+amount(v.documented_financed_balance)+'</b></span></div></article></div>';
    }

    function scenarioResult(award){
      const result=state.anticipation.results[award.id],error=state.anticipation.errors[award.id];if(state.anticipation.loading[award.id])return '<div class="v165-scenario-result">Calculando impacto no caixa…</div>';if(error)return '<div class="v165-scenario-result error">'+text(error)+'</div>';if(!result)return '';
      return '<div class="v165-scenario-result"><span>Modelo atual <b>'+(result.current_model?.first_negative_date?date(result.current_model.first_negative_date):'sem ruptura')+'</b></span><span>Com antecipação <b>'+(result.scenario?.first_negative_date?date(result.scenario.first_negative_date):'sem ruptura')+'</b></span><span>Valor deslocado <b>'+amount(result.selected_amount_brl)+'</b></span></div>';
    }

    function retentionPanel(j){
      const award=j.employment_awards?.retention||{},gross=finite(award.gross_total_brl),installments=Array.isArray(award.installments)?award.installments:[],projected=Array.isArray(j.employment_awards?.retention_projected_events)?j.employment_awards.retention_projected_events:[];
      if(gross===null&&!installments.length)return '<article class="v165-card retention"><div class="v165-cardhead"><div><span>Retention Award</span><h2>Acordo separado de RSU</h2></div></div><div class="v165-empty">Detalhes contratuais não disponíveis na leitura autenticada.</div></article>';
      const rows=installments.map((item,index)=>{const event=projected[index]||{},share=finite(item.share),portion=finite(item.gross_value_brl)??(share===null?null:gross*share);return '<div><i>'+text(item.sequence||index+1)+'</i><span><b>'+text(item.label||'Parcela')+'</b><small>'+text(item.detail||'')+(event.date?' · projeção '+date(event.date):'')+'</small></span><strong>'+amount(portion)+'</strong></div>'}).join('');
      return '<article class="v165-card retention"><div class="v165-cardhead"><div><span>'+text(award.label||'Retention Award')+'</span><h2>Acordo separado de RSU</h2></div><strong>'+amount(gross)+'</strong></div><div class="v165-retention">'+(rows||'<div class="v165-empty">Parcelas ainda não documentadas.</div>')+'</div><div class="v165-callout muted"><b>Tratamento separado.</b><span>'+text(award.note||'O Fluxo mantém somente as parcelas documentadas. O total bruto e a tributação não são confundidos com a regra de Cash RSU.')+'</span></div></article>';
    }

    function rsuPanel(j){
      const rsu=j.rsu||{},position=(rsu.vested_positions||[])[0]||{},awards=awardData(),regular=awards.filter(x=>x.type==='RSU'),cash=awards.filter(x=>x.type==='Cash RSU'),regularTotal=total(regular.map(x=>x.gross)),cashGross=total(cash.map(x=>x.gross)),cashNet=total(cash.map(x=>x.net));
      const rows=awards.map(award=>'<div class="v165-award '+(award.type==='Cash RSU'?'cash':'regular')+'"><div class="v165-award-date"><span>Vesting original</span><b>'+date(award.vesting)+'</b><small>'+text(award.type)+'</small></div><div class="v165-award-units"><span>Quantidade</span><b>'+number(award.units)+'</b><small>'+(award.type==='Cash RSU'?'liquidação em dinheiro':'ações após vesting')+'</small></div><div><span>Preço OGN usado</span><b>'+usd(award.price)+'</b><small>câmbio '+fx(award.fx)+'</small></div><div><span>'+(award.type==='Cash RSU'?'Líquido projetado':'Valor de referência')+'</span><b>'+amount(award.type==='Cash RSU'?award.net:award.gross)+'</b><small>'+(award.type==='Cash RSU'?'70% do bruto; 30% de imposto':'100% bruto; sem corte automático')+'</small></div><label><span>Data antecipada</span><input type="date" data-v165-award-date="'+text(award.id)+'" max="'+text(award.vesting)+'" value="'+text(award.anticipated||'')+'"><small>'+(award.anticipated?'cenário ativo · original preservada':'opcional · cenário Sun Pharma')+'</small></label><button type="button" class="v165-btn '+(award.anticipated?'secondary':'quiet')+'" data-v165-award-save="'+text(award.id)+'">'+(award.anticipated?'Atualizar cenário':'Salvar cenário')+'</button>'+scenarioResult(award)+'</div>').join('');
      return '<div class="v165-kpis four"><article class="v165-kpi primary"><span>RSU já vested</span><strong>'+amount(position.value_brl||j.wealth?.liquidity?.d3)+'</strong><small>'+(position.units!=null?number(position.units)+' ações · ':'')+'D+3</small></article>'+kpi('RSUs futuras',regularTotal,regular.length+' vestings · 100% bruto')+kpi('Cash RSUs · bruto',cashGross,cash.length+' parcelas','restricted')+kpi('Cash RSUs · líquido',cashNet,'70% após imposto de 30%','positive')+'</div><article class="v165-card"><div class="v165-cardhead"><div><span>Agenda de vesting</span><h2>Datas, quantidades e valor considerado</h2></div><div class="v165-quote"><span>Referência usada</span><b>'+usd(awards[0]?.price)+'</b><small>FX '+fx(awards[0]?.fx)+'</small></div></div><div class="v165-awards-head"><span>Vesting</span><span>Quantidade</span><span>Cotação</span><span>Valor</span><span>Antecipação</span><span>Ação</span></div><div class="v165-awards">'+(rows||'<div class="v165-empty">Nenhum vesting futuro disponível.</div>')+'</div><div class="v165-callout"><b>Antecipação é cenário.</b><span>A data original nunca é apagada. A data alternativa fica salva na sua conta; o Fluxo oficial e o vesting real continuam inalterados até existir evidência.</span></div></article>'+retentionPanel(j);
    }

    function assetsPanel(j){
      const w=j.wealth||D?.wealth_executive||{},c=w.assets?.cipo_396||{},v=w.assets?.volvo_xc40||{},vf=j.volvo_financing||{},commitments=j.documentary_commitments?.items||[];
      return '<div class="v165-grid split"><article class="v165-card asset-detail"><div class="v165-cardhead"><div><span>Imóvel</span><h2>CIPÓ 396</h2></div><em>valor · dívida · equity</em></div><div class="v165-fourfacts"><span>Mercado<b>'+amount(c.market_central)+'</b><small>'+amount(c.market_low)+' → '+amount(c.market_high)+'</small></span><span>Dívida documental<b>'+amount(c.documentary_debt)+'</b><small>Bradesco</small></span><span>Equity central<b>'+amount(c.equity_central)+'</b><small>mercado − dívida</small></span><span>Compra + reforma<b>'+amount(c.historical_purchase_plus_reform)+'</b><small>histórico</small></span></div><p class="v165-footnote">O preço pedido do próprio imóvel não é usado como comparável independente.</p></article><article class="v165-card asset-detail"><div class="v165-cardhead"><div><span>Veículo</span><h2>Volvo XC40</h2></div><em>mercado · financiamento</em></div><div class="v165-fourfacts"><span>Mercado<b>'+amount(v.market_central)+'</b><small>'+amount(v.market_low)+' → '+amount(v.market_high)+'</small></span><span>Saldo financiado<b>'+amount(v.documented_financed_balance)+'</b><small>posição documental</small></span><span>Equity central<b>'+amount(v.equity_central)+'</b><small>mercado − dívida</small></span><span>Próxima parcela<b>'+amount(vf.installment_amount)+'</b><small>'+date(vf.next_due)+'</small></span></div></article></div><article class="v165-card"><div class="v165-cardhead"><div><span>Compromissos</span><h2>Saídas futuras sem confundir com dívida atual</h2></div></div>'+(commitments.map(item=>'<div class="v165-liqrow"><span>'+text(item.label||item.commitment_id||'Compromisso')+'</span><b>'+amount(item.debt_balance??item.schedule_loaded?.future_loaded_total)+'</b><em>'+date(item.schedule_loaded?.next_date)+'</em></div>').join('')||'<div class="v165-empty">Nenhum compromisso adicional recebido.</div>')+'</article>';
    }

    function patrimonioV165(){
      ensureWealth();const j=state.wealth.data||{wealth:D?.wealth_executive||{},rsu:{future_schedule:D?.wealth?.asset_layers?.derived_future_schedule||[],vested_positions:[]}},w=j.wealth||{},body=state.wealth.loading&&!state.wealth.data?'<div class="v165-skeleton">Carregando patrimônio e RSUs…</div>':state.wealth.error&&!state.wealth.data?'<div class="v165-callout error"><b>Patrimônio detalhado indisponível</b><span>'+text(state.wealth.error)+'</span></div>':state.wealthTab==='rsu'?rsuPanel(j):state.wealthTab==='assets'?assetsPanel(j):wealthOverview(j);
      return '<div class="v165-report v165-wealth">'+pageHead('Patrimônio / visão executiva','Patrimônio','Ativos, dívidas, liquidez e awards em camadas claras.','<div class="v165-headtools"><span class="v165-source"><i></i>Posição '+date(w.as_of||j.as_of||sourceAsOf())+'</span></div>')+wealthTabs()+body+'</div>';
    }

    function searchRows(){
      const s=state.search;if(s.loading)return '<div class="v165-search-empty">Buscando em todo o histórico…</div>';if(s.error)return '<div class="v165-search-empty error">'+text(s.error)+'</div>';if(!s.query)return '<div class="v165-search-empty">Comece a digitar. Ex.: retention, Mastercard, condomínio, escola.</div>';if(!s.rows.length)return '<div class="v165-search-empty">Nenhum lançamento encontrado para “'+text(s.query)+'”.</div>';
      return s.rows.map(row=>'<div class="v165-searchrow"><div><b>'+text(row.description||row.counterparty||row.category||'Lançamento')+'</b><small>'+date(row.date||row.event_date)+' · '+text(row.account||'sem conta')+' · '+text(row.category||'sem categoria')+(row.center_cost?' · '+text(row.center_cost):'')+'</small></div><strong>'+amount(row.amount)+'</strong></div>').join('');
    }

    function paintSearch(){
      const meta=document.getElementById('v165SearchMeta'),out=document.getElementById('v165SearchResults');if(meta)meta.textContent=state.search.loading?'Buscando…':state.search.query?'Data e valor são opcionais · '+state.search.total.toLocaleString('pt-BR')+' lançamento(s) encontrado(s)':'Data e valor são opcionais';if(out)out.innerHTML=searchRows();
    }

    function scheduleSearch(value){
      state.search.query=String(value||'');clearTimeout(state.search.timer);if(!state.search.query.trim()){state.search.loading=false;state.search.total=0;state.search.rows=[];state.search.error=null;paintSearch();return}state.search.timer=setTimeout(()=>runSearch(state.search.query),260);paintSearch();
    }

    async function runSearch(value){
      const query=String(value||'').trim(),seq=++state.search.seq;state.search.query=query;state.search.loading=true;state.search.error=null;paintSearch();
      try{const {data,error}=await S.rpc('lts_browser_transactions_v2',{p_from:'2013-10-10',p_to:null,p_query:query,p_direction:null,p_account:null,p_limit:200,p_offset:0});if(seq!==state.search.seq)return;if(error||!data)throw Error(error?.message||'Consulta indisponível');state.search.total=finite(data.total)||0;state.search.rows=Array.isArray(data.rows)?data.rows:[]}
      catch(error){if(seq!==state.search.seq)return;state.search.total=0;state.search.rows=[];state.search.error='Não foi possível consultar agora: '+String(error?.message||error)}finally{if(seq===state.search.seq){state.search.loading=false;paintSearch()}}
    }

    function updateButton(item){
      const type=String(item?.type||''),id=text(item?.id||''),destination=String(item?.destination||'');
      if(type==='overdue_transfer_review')return '<button class="v165-btn secondary updconfirm" data-update="'+id+'">Confirmar realizado</button>';
      if(type==='overdue_event_review')return '<button class="v165-btn secondary updeventconfirm" data-update="'+id+'">Confirmar realizado</button>';
      if(type==='card_payment_review')return '<button class="v165-btn secondary cardpayconfirm" data-update="'+id+'">Confirmar pagamento</button>';
      if(type==='document_request'||type==='reconciliation')return '<button class="v165-btn secondary updinput" data-update="'+id+'">Enviar evidência</button>';
      if(destination)return '<button class="v165-btn quiet" data-v165-go="'+text(destination)+'">Abrir</button>';
      return '<span class="v165-pill">Revisar</span>';
    }

    function atualizacoesV165(){
      const updates=D?.updates||{},items=(updates.items||[]).filter(item=>typeof updateIsAction==='function'?updateIsAction(item):true).sort((a,b)=>(finite(a.priority)||9)-(finite(b.priority)||9)||Math.abs(finite(b.impact_amount)||0)-Math.abs(finite(a.impact_amount)||0)),pending=(finite(D?.semantic_review?.pending_groups)||0)+(finite(D?.card_classification_review?.pending_groups)||0),fresh=sourceAsOf();
      const search='<article class="v165-card v165-search"><div class="v165-cardhead"><div><span>Pesquisar lançamentos</span><h2>Encontre sem saber a data</h2></div><small>histórico desde 2013 + lançamentos futuros</small></div><div class="v165-searchbox"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg><input id="v165SearchInput" type="search" autocomplete="off" placeholder="Digite retention, Mastercard, condomínio…" value="'+text(state.search.query)+'"></div><div id="v165SearchMeta" class="v165-searchmeta">'+(state.search.query?'Data e valor são opcionais · '+state.search.total.toLocaleString('pt-BR')+' lançamento(s) encontrado(s)':'Data e valor são opcionais')+'</div><div id="v165SearchResults" class="v165-searchresults">'+searchRows()+'</div></article>';
      const taskRows=items.slice(0,12).map((item,index)=>'<div class="v165-task '+((finite(item.priority)||9)===1?'urgent':'')+'"><i>'+(index+1)+'</i><div><b>'+text(item.title||'Atualização')+'</b><small>'+text(item.detail||'')+(finite(item.impact_amount)?' · impacto '+amount(Math.abs(finite(item.impact_amount))):'')+'</small></div>'+updateButton(item)+'</div>').join('');
      const classifications=pending?'<details class="v165-card v165-details"><summary>Classificações pendentes <b>'+pending+'</b></summary><div class="v165-details-body">'+(typeof cardClassificationUpdates==='function'?cardClassificationUpdates():'')+(typeof expenseClassificationUpdates==='function'?expenseClassificationUpdates():'')+'</div></details>':'<div class="v165-ok wide"><i>✓</i><span><b>Classificação concluída no escopo revisado</b><small>0 grupos pendentes nas fontes disponíveis. Cobertura documental continua medida separadamente.</small></span></div>';
      return '<div class="v165-report v165-updates">'+pageHead('Atualizações / trabalho e controle','Atualizações','Pesquise o histórico e resolva somente o que exige sua decisão.','<div class="v165-headtools"><span class="v165-source"><i></i>Dados até '+date(fresh)+'</span><button type="button" class="v165-btn secondary" data-v165-go="Entradas">Adicionar documento</button></div>')+'<div class="v165-update-kpis"><div><span>Ações abertas</span><b>'+items.length+'</b></div><div><span>Classificações pendentes</span><b>'+pending+'</b></div><div><span>Escopo revisado</span><b>'+(pending?'em revisão':'100%')+'</b></div></div>'+search+'<article class="v165-card"><div class="v165-cardhead"><div><span>Prioridades</span><h2>O que precisa de você</h2></div><b class="v165-count">'+items.length+'</b></div><div class="v165-tasks">'+(taskRows||'<div class="v165-empty">Nenhuma ação operacional aberta.</div>')+'</div></article>'+classifications+'</div>';
    }

    async function refreshDashboard(){
      const button=document.getElementById('v165Refresh');if(button){button.disabled=true;button.textContent='Atualizando…'}
      try{const {data,error}=await S.rpc('lts_browser_dashboard_cockpit_v1');if(error||!data)throw Error(error?.message||'Resumo indisponível');D.dashboard_cockpit=data;render()}catch(error){toast('Não foi possível atualizar: '+String(error?.message||error));if(button){button.disabled=false;button.textContent='Atualizar'}}
    }

    async function saveAnticipation(id){
      const input=document.querySelector('[data-v165-award-date="'+CSS.escape(id)+'"]'),value=iso(input?.value),award=awardData().find(item=>item.id===id);if(!award)return;
      if(value&&value>award.vesting){toast('A antecipação precisa ser anterior ao vesting original.');return}
      delete state.anticipation.results[id];delete state.anticipation.errors[id];
      state.anticipation.loading[id]=true;render();
      try{const {data,error}=await S.rpc('lts_browser_save_vesting_anticipation_v1',{p_group_key:id,p_anticipated_date:value});if(error||!data)throw Error(error?.message||'Cenário indisponível');const row=state.wealth.data?.rsu?.future_schedule?.find(item=>item.group_key===id);if(row)row.anticipated_date=value||null;if(data.scenario)state.anticipation.results[id]=data.scenario;toast(value?'Cenário salvo na sua conta.':'Cenário removido.')}catch(error){state.anticipation.errors[id]='Não foi possível salvar: '+String(error?.message||error)}finally{state.anticipation.loading[id]=false;if(V==='Patrimônio')render()}
    }

    function decorateNav(){
      const order=['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações'],labels={'Dashboard':'Dashboard','Fluxo Diário':'Fluxo de caixa','Despesas':'Despesas','Patrimônio':'Patrimônio','Atualizações':'Atualizações'};
      order.forEach(route=>{let button=N.querySelector('[data-v="'+route+'"]');if(!button){button=document.createElement('button');button.dataset.v=route}button.classList.toggle('active',V===route);button.innerHTML=icon(route)+'<span>'+labels[route]+'</span>';button.setAttribute('aria-label',labels[route]);button.onclick=()=>go(route);N.appendChild(button)});
      N.querySelectorAll('[data-v]').forEach(button=>{if(!order.includes(button.dataset.v))button.remove()});
    }

    function decorateMobile(){
      const nav=document.getElementById('dx1MobileNav');if(!nav)return;const routes=[['Dashboard','Início'],['Fluxo Diário','Fluxo'],['Despesas','Despesas'],['Patrimônio','Bens'],['Atualizações','Ações']];nav.innerHTML=routes.map(([route,label])=>'<button type="button" data-mobile-route="'+route+'" class="'+(V===route?'active':'')+'">'+icon(route)+'<span>'+label+'</span></button>').join('');nav.querySelectorAll('[data-mobile-route]').forEach(button=>button.onclick=()=>go(button.dataset.mobileRoute));
    }

    function stampBrand(){
      document.querySelectorAll('.brand small').forEach(node=>{if(node.textContent.trim()!=='V165 · Homologação')node.innerHTML='<b>V165</b> · Homologação'});
    }

    function preserveBrand(){
      stampBrand();
      if(window.__LTS_V165_FLOW_ROUTE_WRAPPED||typeof window.__LTS_V162_ROUTE_FLOW!=='function')return;
      const routeFlow=window.__LTS_V162_ROUTE_FLOW;window.__LTS_V162_ROUTE_FLOW=function(){const result=routeFlow.apply(this,arguments);stampBrand();return result};window.__LTS_V165_FLOW_ROUTE_WRAPPED=true;
    }

    function bind(){
      const authenticated=Boolean(D)&&!N.classList.contains('hidden');document.body.classList.toggle('v165-authenticated',authenticated);document.body.classList.add('v165-ready');decorateMobile();
      document.querySelectorAll('[data-v165-go]').forEach(button=>button.onclick=()=>go(button.dataset.v165Go,button.dataset.v165Tab));
      document.querySelectorAll('[data-v165-expense-tab]').forEach(button=>button.onclick=()=>{state.expenseTab=button.dataset.v165ExpenseTab;render()});
      document.querySelectorAll('[data-v165-wealth-tab]').forEach(button=>button.onclick=()=>{state.wealthTab=button.dataset.v165WealthTab;render()});
      document.querySelectorAll('[data-v165-expense-range]').forEach(button=>button.onclick=()=>{if(typeof ex135SetRange==='function')ex135SetRange(button.dataset.v165ExpenseRange)});
      document.querySelectorAll('[data-v165-month]').forEach(button=>button.onclick=()=>{if(button.dataset.v165Month&&typeof ex135OpenMonth==='function'){state.expenseTab='transactions';ex135OpenMonth(button.dataset.v165Month)}});
      document.querySelectorAll('[data-v165-award-save]').forEach(button=>button.onclick=()=>saveAnticipation(button.dataset.v165AwardSave));
      const input=document.getElementById('v165SearchInput');if(input)input.oninput=event=>scheduleSearch(event.target.value);
      const refresh=document.getElementById('v165Refresh');if(refresh)refresh.onclick=refreshDashboard;
      preserveBrand();
      const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent=VERSION+' · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação';
    }

    dashboard=dashboardV165;despesas=despesasV165;patrimonio=patrimonioV165;atualizacoes=atualizacoesV165;
    renderNav=function(){if(D&&!status.authenticated_started){V='Dashboard';status.authenticated_started=true}if(V==='Planejamento')V='Dashboard';if(V==='Cartões'){V='Despesas';state.expenseTab='cards'}original.renderNav();decorateNav()};
    render=function(){if(V==='Planejamento')V='Dashboard';if(V==='Cartões'){V='Despesas';state.expenseTab='cards'}const value=original.render();bind();return value};

    if(D&&!N.classList.contains('hidden')){V='Dashboard';status.authenticated_started=true;renderNav();render()}else bind();
  }

  function frame(){
    try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!d.documentElement||!String(w.location.pathname||'').endsWith('/index.html'))return null;return {w,d}}catch(_){return null}
  }

  function install(){
    const current=frame();if(!current)return false;
    if(!current.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed||!current.w.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed||!current.w.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed)return false;
    if(!current.w.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed&&!current.d.getElementById('lts-executive-visual-system-v2-runtime')){const script=current.d.createElement('script');script.id='lts-executive-visual-system-v2-runtime';script.textContent='('+visualRuntime.toString()+')();';(current.d.head||current.d.documentElement).appendChild(script)}
    const ready=current.w.__LTS_EXECUTIVE_VISUAL_SYSTEM_V2?.installed===true;
    if(ready){
      current.d.querySelectorAll('.brand small').forEach(node=>{if(node.textContent.trim()!=='V165 · Homologação')node.innerHTML='<b>V165</b> · Homologação'});
      if(gate)gate.hidden=true;
    }
    return ready;
  }

  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const ready=install();attempt+=1;if(!ready&&attempt<240)setTimeout(step,100)}step();[300,700,1400,2800,5200,9000,15000,22000].forEach(delay=>setTimeout(()=>{if(current===generation)install()},delay))}
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v165-executive-ux-rsu';
  window.__LTS_V165_STATUS={contract:CONTRACT,source_candidate:'index.html',public_index_changed:false,financial_writers_changed:false,routes:['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações'],reference_sha256:'0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b'};
})();
