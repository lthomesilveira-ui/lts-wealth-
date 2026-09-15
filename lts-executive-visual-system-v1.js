(function(){
  'use strict';
  const CONTRACT='executive-visual-system-v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let generation=0;

  function visualRuntime(){
    'use strict';
    if(window.__LTS_EXECUTIVE_VISUAL_SYSTEM?.installed)return;
    const modelApi=window.LTSDashboardReadModel;
    if(!modelApi||typeof dashboard!=='function'||typeof render!=='function'||typeof renderNav!=='function')return;

    const status=window.__LTS_EXECUTIVE_VISUAL_SYSTEM={
      installed:true,
      contract:'executive-visual-system-v1',
      version:'v164',
      planning_consolidated_into_dashboard:true,
      planning_route_visible:false,
      planning_tab_removed:true,
      reports_aligned:['Despesas','Cartões','Patrimônio'],
      flow_renderer_preserved:true,
      expense_reader_preserved:true,
      financial_writers_changed:false,
      public_index_changed:false,
      dashboard_refreshes:0,
      dashboard_refresh_error:null
    };

    const originalDespesas=despesas;
    const originalPatrimonio=patrimonio;
    const originalCartoes=typeof cartoesBase121==='function'?cartoesBase121:cartoes;
    const number=value=>value===null||value===undefined||value===''?null:Number.isFinite(Number(value))?Number(value):null;
    const money=value=>number(value)===null?'—':brl(Number(value));
    const date=value=>value?fmt(value):'—';
    const text=value=>esc(value==null?'':String(value));
    const pct=value=>number(value)===null?'—':Number(value).toLocaleString('pt-BR',{maximumFractionDigits:0})+'%';
    const dayBefore=value=>modelApi.dayBefore(value);
    const signed=value=>number(value)!==null&&Number(value)<0?'negative':'';

    function routeIcon(route){
      const paths={
        'Dashboard':'<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="4" rx="2"/><rect x="14" y="11" width="7" height="10" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/>',
        'Fluxo Diário':'<path d="M4 7h12M13 4l3 3-3 3M20 17H8M11 14l-3 3 3 3"/>',
        'Despesas':'<path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/>',
        'Cartões':'<rect x="2.5" y="5" width="19" height="14" rx="3"/><path d="M3 10h18M7 15h4"/>',
        'Patrimônio':'<path d="M3 10.5 12 4l9 6.5M5 10v9h14v-9M9 19v-5h6v5"/>',
        'Atualizações':'<path d="M12 3a9 9 0 1 0 8.1 5.1M20 3v5h-5"/><path d="M12 7v5l3 2"/>'
      };
      return '<svg viewBox="0 0 24 24" aria-hidden="true">'+(paths[route]||paths.Dashboard)+'</svg>';
    }

    function go(route){
      V=route==='Planejamento'?'Dashboard':route;
      renderNav();
      render();
      window.scrollTo({top:0,behavior:'smooth'});
    }

    function chart(series){
      const points=(series||[]).filter(point=>point&&point.date);
      if(points.length<2)return '<div class="v164-empty">A projeção ainda não possui pontos suficientes para desenhar a curva.</div>';
      const values=points.flatMap(point=>[point.base,point.conditional,point.restricted]).filter(value=>number(value)!==null);
      const lo=Math.min(0,...values),hi=Math.max(0,...values),span=Math.max(1,hi-lo);
      const x=index=>46+index*(624/Math.max(1,points.length-1));
      const y=value=>24+(hi-Number(value))/span*178;
      const path=key=>points.map((point,index)=>number(point[key])===null?null:{index,value:Number(point[key])}).filter(Boolean).map((point,index)=>(index?'L':'M')+x(point.index).toFixed(1)+' '+y(point.value).toFixed(1)).join(' ');
      const labels=points.map((point,index)=>'<text x="'+x(index)+'" y="232" text-anchor="middle">'+text(point.label||date(point.date))+'</text>').join('');
      const dots=points.map((point,index)=>number(point.conditional)===null?'':'<circle cx="'+x(index)+'" cy="'+y(point.conditional)+'" r="4"/>').join('');
      return '<div class="v164-chart"><svg viewBox="0 0 716 246" role="img" aria-label="Projeção da liquidez"><defs><linearGradient id="v164Area" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#355f8f" stop-opacity=".16"/><stop offset="1" stop-color="#355f8f" stop-opacity="0"/></linearGradient></defs><line class="grid" x1="46" x2="670" y1="'+y(0)+'" y2="'+y(0)+'"/><path class="cash" d="'+path('base')+'"/><path class="scheduled" d="'+path('conditional')+'"/><path class="protected" d="'+path('restricted')+'"/><g class="dots">'+dots+'</g><g class="labels">'+labels+'</g></svg></div>';
    }

    function kpi(label,value,note,tone){
      return '<article class="v164-kpi '+(tone||'')+'"><span>'+text(label)+'</span><strong class="'+signed(value)+'">'+money(value)+'</strong><small>'+text(note||'')+'</small></article>';
    }

    function metric(label,value,note,tone){
      return '<div class="v164-metric '+(tone||'')+'"><span>'+text(label)+'</span><b>'+text(value)+'</b><small>'+text(note||'')+'</small></div>';
    }

    function rank(items,total,route){
      const rows=(items||[]).slice(0,6),max=Math.max(1,...rows.map(item=>Math.abs(number(item.amount??item.total??item.spend)||0)));
      return rows.map(item=>{
        const value=number(item.amount??item.total??item.spend)||0;
        const share=number(total)&&Number(total)!==0?Math.abs(value/Number(total)*100):null;
        return '<button class="v164-rank" type="button" data-v164-go="'+text(route)+'"><span><b>'+text(item.category||item.name||item.label||'Categoria')+'</b><small>'+(share===null?'':pct(share)+' do período')+'</small></span><i><u style="width:'+Math.max(2,Math.abs(value)/max*100)+'%"></u></i><strong>'+money(value)+'</strong></button>';
      }).join('')||'<div class="v164-empty">Sem composição disponível.</div>';
    }

    function dashboardV164(){
      const vm=modelApi.build(D?.dashboard_cockpit||{});
      const cockpit=D?.dashboard_cockpit||{};
      const planning=D?.planning_executive||{};
      const ps=planning.summary||{};
      const episodes=planning.gap_episodes||[];
      const layers=planning.layers||[];
      const fgts=planning.fgts_access||{};
      const wealth=D?.wealth_executive||{};
      const ws=wealth.summary||{};
      const current=vm.expenses.current||{};
      const previous=vm.expenses.previous||{};
      const next=vm.cards.nextDue||{};
      const firstGap=ps.first_real_gap_date||vm.decision?.firstNegative||null;
      const uncovered=ps.first_negative_even_with_fgts||cockpit.planning_audited?.first_uncovered_gap_date||null;
      const requestBy=ps.fgts_request_by||fgts.request_by_date||cockpit.planning_audited?.fgts_request_by||null;
      const worst=number(ps.worst_balance??cockpit.planning_audited?.worst_before_brl);
      const worstAfter=number(cockpit.planning_audited?.worst_after_brl);
      const coveredUntil=firstGap?dayBefore(firstGap):vm.decision?.coveredUntil;
      const firstEpisode=episodes[0]||{};
      const answer=firstGap?'Até '+date(coveredUntil)+', sim. Depois, é preciso agir.':'Sim, no horizonte analisado.';
      const answerDetail=firstGap
        ?'O primeiro saldo negativo aparece em '+date(firstGap)+(firstEpisode.days?' e dura '+firstEpisode.days+' dia'+(Number(firstEpisode.days)===1?'':'s'):'')+'. '+(uncovered?'Com o FGTS disponível, essa janela fica coberta; a primeira falta ainda descoberta passa para '+date(uncovered)+'.':'')
        :'A projeção atual não mostra saldo negativo no horizonte disponível.';
      const accounts=(vm.accounts||[]).map(account=>'<div class="v164-account"><span><i></i>'+text(account.institution||account.account||'Conta')+'</span><b>'+money(account.balance)+'</b></div>').join('');
      const horizonCards=(vm.horizons||[]).map(item=>'<div class="v164-horizon"><span>'+text(item.label||date(item.date))+'</span><b class="'+signed(item.conditional)+'">'+money(item.conditional)+'</b><small>com vestings previstos · '+date(item.date)+'</small></div>').join('');
      const layerRows=layers.map(layer=>'<div class="v164-layer"><i>'+text(layer.order)+'</i><div><b>'+text(layer.label)+'</b><small>'+text(layer.liquidity||'')+' · início '+money(layer.starting_amount)+'</small></div><strong>'+(layer.first_need_next_layer?'até '+date(dayBefore(layer.first_need_next_layer)):'não se esgota')+'</strong></div>').join('');
      const episodeRows=episodes.map((episode,index)=>'<div class="v164-episode"><div><i>'+(index+1)+'</i><span><b>'+date(episode.start_date)+' → '+date(episode.end_date)+'</b><small>'+text(episode.days)+' dia(s) · recupera em '+date(episode.recovery_date)+'</small></span></div><strong>'+money(episode.worst_balance)+'</strong></div>').join('');
      const actions=(vm.work.actions||[]).slice(0,5).map(action=>'<div class="v164-action"><i></i><div><b>'+text(action.title||'Ação pendente')+'</b><small>'+text(action.description||'')+'</small></div></div>').join('');

      return '<div class="v164-dashboard" data-dashboard-contract="cash-answer-and-evidence-v2">'+
        '<header class="v164-pagehead"><div><span class="v164-eyebrow">Visão executiva</span><h1>Dashboard</h1><p>Dinheiro disponível, próximos compromissos e patrimônio em uma única leitura.</p></div><div class="v164-pageactions"><span>Posição '+date(vm.asOf||cockpit.as_of)+'</span><button id="v164Refresh" class="v164-button secondary" type="button">Atualizar dados</button></div></header>'+
        '<section class="v164-answer '+(firstGap?'attention':'safe')+'"><div class="v164-answer-main"><span>A pergunta principal</span><h2>Tenho dinheiro suficiente?</h2><strong>'+text(answer)+'</strong><p>'+text(answerDetail)+'</p></div><div class="v164-answer-metrics">'+
          metric('Fico negativo?',firstGap?'Sim · '+date(firstGap):'Não','primeira ruptura com os recursos programados',firstGap?'warn':'ok')+
          metric('Pior falta prevista',money(worst),worst===null?'sem valor disponível':'antes do FGTS')+
          metric('Com o FGTS',uncovered?'Falta em '+date(uncovered):'Horizonte coberto',worstAfter===null?'contingência separada do caixa':'pior ponto ainda descoberto '+money(worstAfter))+
          metric('Data para agir',requestBy?date(requestBy):'—','prazo estimado para disponibilizar o FGTS')+
        '</div></section>'+
        '<section class="v164-kpis">'+
          kpi('Dinheiro em contas',vm.kpis.bankCash,'saldo bancário documentado','primary')+
          kpi('Contas + curto prazo',vm.kpis.shortTerm.value,'inclui liquidez D+0')+
          kpi('RSUs disponíveis',vm.kpis.vested,'posição já adquirida')+
          kpi('FGTS',vm.kpis.fgts,'contingência · não é caixa atual','restricted')+
          kpi('Despesas do mês',vm.kpis.expenses,'leitor reconciliado')+
        '</section>'+
        '<section class="v164-grid hero-grid"><article class="v164-card evolution"><div class="v164-cardhead"><div><span>Liquidez</span><h3>Como seu caixa evolui</h3></div><button class="v164-button tertiary" data-v164-go="Fluxo Diário" type="button">Abrir fluxo</button></div><div class="v164-legend"><span><i class="cash"></i>Sem novos vestings</span><span><i class="scheduled"></i>Com vestings programados</span><span><i class="protected"></i>Com FGTS</span></div>'+chart(vm.horizons)+'<div class="v164-horizons">'+horizonCards+'</div></article><aside class="v164-card bank-card"><div class="v164-cardhead"><div><span>Contas</span><h3>Posição bancária</h3></div></div>'+accounts+'<button class="v164-link" data-v164-go="Fluxo Diário" type="button">Ver movimentações</button></aside></section>'+
        '<section class="v164-grid insight-grid"><article class="v164-card"><div class="v164-cardhead"><div><span>Despesas</span><h3>Para onde foi o dinheiro</h3></div><strong>'+money(current.spend)+'</strong></div><div class="v164-inline-comparison"><span>Mês anterior</span><b>'+money(previous.spend)+'</b></div>'+rank(vm.expenses.top,current.spend,'Despesas')+'<button class="v164-link" data-v164-go="Despesas" type="button">Analisar despesas</button></article><article class="v164-card"><div class="v164-cardhead"><div><span>Cartões</span><h3>Próximas faturas</h3></div></div><div class="v164-bigmetric"><span>Próximo vencimento</span><b>'+money(next.amount)+'</b><small>'+(next.due_date?date(next.due_date):'data não informada')+' · '+text(next.card_name||'cartão')+'</small></div><div class="v164-split"><div><span>Em aberto</span><b>'+money(vm.cards.open)+'</b></div><div><span>Fechadas ou vencidas</span><b>'+money(vm.cards.closed)+'</b></div></div><button class="v164-link" data-v164-go="Cartões" type="button">Ver cartões</button></article><article class="v164-card"><div class="v164-cardhead"><div><span>Patrimônio</span><h3>Quanto você tem e deve</h3></div></div><div class="v164-bigmetric"><span>Patrimônio líquido estimado</span><b>'+money(ws.net_worth_central)+'</b><small>faixa '+money(ws.net_worth_low)+' → '+money(ws.net_worth_high)+'</small></div><div class="v164-split"><div><span>Ativos</span><b>'+money(ws.assets_central)+'</b></div><div><span>Dívidas conhecidas</span><b>'+money(ws.known_debt_total)+'</b></div></div><button class="v164-link" data-v164-go="Patrimônio" type="button">Abrir patrimônio</button></article></section>'+
        '<section class="v164-grid planning-grid"><article class="v164-card"><div class="v164-cardhead"><div><span>Planejamento incorporado</span><h3>Até quando cada recurso sustenta o caixa</h3></div><small>ordem de uso da liquidez</small></div><div class="v164-layers">'+layerRows+'</div></article><article class="v164-card"><div class="v164-cardhead"><div><span>Janelas de atenção</span><h3>Quando falta dinheiro e quando recupera</h3></div><b>'+text(episodes.length)+'</b></div><div class="v164-episodes">'+(episodeRows||'<div class="v164-empty">Nenhuma janela negativa no horizonte.</div>')+'</div><div class="v164-fgts"><span>FGTS de contingência</span><b>'+money(fgts.amount_brl||ps.fgts_amount)+'</b><small>'+(requestBy?'acionar até '+date(requestBy):'prazo não informado')+' · disponibilidade aproximada D+30</small></div></article></section>'+
        '<section class="v164-grid bottom-grid"><article class="v164-card"><div class="v164-cardhead"><div><span>Atualizações</span><h3>O que precisa da sua atenção</h3></div><b class="v164-count">'+(vm.work.count===null?'—':text(vm.work.count))+'</b></div>'+(actions||'<div class="v164-empty">Nenhuma ação detalhada disponível.</div>')+'<button class="v164-link" data-v164-go="Atualizações" type="button">Abrir atualizações</button></article><article class="v164-card methodology"><div><span>Como ler</span><h3>Fato, projeção e contingência separados</h3><p>Saldos bancários mostram a última posição documental. Dias posteriores são projeções. Vestings entram apenas nas datas previstas; FGTS aparece como proteção planejável e nunca como dinheiro já disponível.</p></div></article></section>'+
      '</div>';
    }

    dashboard=dashboardV164;
    despesas=function(){return '<div class="v164-report v164-expenses">'+originalDespesas()+'</div>'};
    cartoes=function(){return '<div class="v164-report v164-cards">'+originalCartoes()+'</div>'};
    patrimonio=function(){return '<div class="v164-report v164-wealth">'+originalPatrimonio()+'</div>'};

    async function refreshDashboard(){
      const button=document.getElementById('v164Refresh');
      if(button){button.disabled=true;button.textContent='Atualizando…'}
      status.dashboard_refreshes+=1;
      status.dashboard_refresh_error=null;
      try{
        const {data,error}=await S.rpc('lts_browser_dashboard_cockpit_v1');
        if(error||!data)throw new Error(error?.message||'Resumo indisponível');
        D.dashboard_cockpit=data;
      }catch(error){status.dashboard_refresh_error=String(error?.message||error||'Falha de leitura')}
      finally{if(V==='Dashboard')render()}
    }

    function decorateNav(){
      const planning=N.querySelector('[data-v="Planejamento"]');
      if(planning)planning.remove();
      const order=['Dashboard','Fluxo Diário','Despesas','Cartões','Patrimônio','Atualizações'];
      const labels={'Dashboard':'Dashboard','Fluxo Diário':'Fluxo de caixa','Despesas':'Despesas','Cartões':'Cartões','Patrimônio':'Patrimônio','Atualizações':'Atualizações'};
      order.forEach(route=>{
        const button=N.querySelector('[data-v="'+route+'"]');
        if(!button)return;
        button.innerHTML=routeIcon(route)+'<span>'+labels[route]+'</span>';
        button.setAttribute('aria-label',labels[route]);
        N.appendChild(button);
      });
      N.querySelectorAll('[data-v]').forEach(button=>{if(!order.includes(button.dataset.v))button.remove()});
    }

    function decorateMobile(){
      const nav=document.getElementById('dx1MobileNav');
      if(!nav)return;
      const routes=[['Dashboard','Início'],['Fluxo Diário','Fluxo'],['Despesas','Despesas'],['Cartões','Cartões'],['Patrimônio','Bens'],['Atualizações','Ações']];
      nav.innerHTML=routes.map(([route,label])=>'<button type="button" data-mobile-route="'+route+'" class="'+(V===route?'active':'')+'">'+routeIcon(route)+'<span>'+label+'</span></button>').join('');
      nav.querySelectorAll('[data-mobile-route]').forEach(button=>button.onclick=()=>go(button.dataset.mobileRoute));
    }

    function bind(){
      const authenticated=Boolean(D)&&!N.classList.contains('hidden');
      document.body.classList.toggle('v164-authenticated',authenticated);
      document.body.classList.add('v164-ready');
      decorateMobile();
      document.querySelectorAll('[data-v164-go]').forEach(button=>button.onclick=()=>go(button.dataset.v164Go));
      const refresh=document.getElementById('v164Refresh');if(refresh)refresh.onclick=refreshDashboard;
      document.querySelectorAll('.brand small').forEach(node=>{node.textContent=V==='Dashboard'?'Visão financeira executiva':V==='Fluxo Diário'?'Caixa e disponibilidade':V==='Despesas'?'Consumo reconciliado':V==='Cartões'?'Faturas e compromissos':V==='Patrimônio'?'Ativos, dívidas e liquidez':'Pendências e documentos'});
      const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent=(V==='Dashboard'?'Dashboard':V)+' · homologação V164';
    }

    const baseRenderNav=renderNav;
    renderNav=function(){
      if(V==='Planejamento')V='Dashboard';
      baseRenderNav();
      decorateNav();
    };
    const baseRender=render;
    render=function(){
      if(V==='Planejamento')V='Dashboard';
      const value=baseRender();
      bind();
      return value;
    };

    const style=document.createElement('style');
    style.id='lts-executive-visual-system-v1-style';
    style.textContent=`
      :root{--v164-navy:#10243e;--v164-navy-2:#183a61;--v164-blue:#315f8d;--v164-gold:#caa66a;--v164-canvas:#f2f5f8;--v164-card:#fff;--v164-ink:#172b44;--v164-muted:#6f7e90;--v164-border:#dfe5eb;--v164-shadow:0 10px 34px rgba(24,48,79,.055);--v164-radius:18px}
      body.v164-ready{background:var(--v164-canvas);color:var(--v164-ink);font-size:14px}
      body.v164-ready .notice{background:#f7f9fb;border-color:#dfe5eb;color:#59697b;font-size:12px;line-height:1.55}
      body.v164-ready .lts-reconciliation-warning{background:#fff8e8;border-color:#ead4a6;color:#755822}
      body.v164-ready #ltsBankEvidence{margin:8px 0 14px;padding:9px 12px;border:1px solid var(--v164-border);border-radius:11px;background:#fff;font-size:11px;line-height:1.45}
      body.v164-authenticated .footer{display:none!important}
      .v164-nav-icon,body.v164-authenticated .nav svg{width:19px;height:19px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;flex:0 0 19px}
      body.v164-authenticated .nav button{display:flex;align-items:center;gap:11px;text-align:left}
      .v164-pagehead{display:flex;align-items:flex-start;justify-content:space-between;gap:24px;margin-bottom:22px}
      .v164-pagehead h1{font-size:34px;line-height:1;margin:6px 0 8px;letter-spacing:-.045em}
      .v164-pagehead p{margin:0;color:var(--v164-muted);font-size:14px;line-height:1.55}
      .v164-eyebrow,.v164-cardhead span,.v164-answer-main>span,.v164-kpi>span,.v164-metric>span,.v164-bigmetric>span,.v164-fgts>span,.methodology span{display:block;color:#8491a0;font-size:10px;font-weight:850;letter-spacing:.095em;text-transform:uppercase}
      .v164-pageactions{display:flex;align-items:center;gap:10px;color:var(--v164-muted);font-size:12px;white-space:nowrap}
      .v164-button{border:0;border-radius:10px;padding:9px 12px;background:var(--v164-navy);color:#fff;font:750 12px/1.2 inherit;cursor:pointer}
      .v164-button.secondary,.v164-button.tertiary{background:#fff;color:var(--v164-navy);border:1px solid var(--v164-border)}
      .v164-button:disabled{opacity:.55;cursor:wait}
      .v164-answer{display:grid;grid-template-columns:minmax(310px,.95fr) minmax(0,1.55fr);overflow:hidden;background:#fff;border:1px solid var(--v164-border);border-radius:22px;box-shadow:var(--v164-shadow);margin-bottom:14px}
      .v164-answer-main{padding:25px 27px;background:linear-gradient(135deg,#173959,#244d72);color:#fff;position:relative}
      .v164-answer.attention .v164-answer-main:before{content:'';position:absolute;left:0;top:0;bottom:0;width:5px;background:var(--v164-gold)}
      .v164-answer.safe .v164-answer-main:before{content:'';position:absolute;left:0;top:0;bottom:0;width:5px;background:#55a27e}
      .v164-answer-main>span{color:#d7e0e9}
      .v164-answer-main h2{font-size:15px;margin:8px 0;color:#e9eef4}
      .v164-answer-main strong{display:block;font-size:27px;line-height:1.12;letter-spacing:-.035em;max-width:520px}
      .v164-answer-main p{font-size:12px;line-height:1.55;color:#d9e3ec;margin:12px 0 0;max-width:590px}
      .v164-answer-metrics{display:grid;grid-template-columns:1fr 1fr}
      .v164-metric{padding:20px;border-left:1px solid #ebeff3;border-bottom:1px solid #ebeff3;min-width:0}
      .v164-metric:nth-last-child(-n+2){border-bottom:0}
      .v164-metric b{display:block;font-size:17px;line-height:1.25;margin:7px 0;color:var(--v164-ink);overflow-wrap:anywhere}
      .v164-metric.warn b{color:#9b6424}.v164-metric.ok b{color:#2f7b5c}
      .v164-metric small{display:block;color:var(--v164-muted);font-size:10px;line-height:1.4}
      .v164-kpis{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px;margin-bottom:12px}
      .v164-kpi{background:#fff;border:1px solid var(--v164-border);border-radius:16px;padding:17px;box-shadow:var(--v164-shadow);min-width:0}
      .v164-kpi.primary{border-top:3px solid var(--v164-blue)}.v164-kpi.restricted{background:#fffdf8;border-color:#eadfca}
      .v164-kpi strong{display:block;font-size:21px;letter-spacing:-.025em;margin:8px 0 6px;overflow-wrap:anywhere}
      .v164-kpi strong.negative{color:#ad4b4b}.v164-kpi small{display:block;color:var(--v164-muted);font-size:10px;line-height:1.4}
      .v164-grid{display:grid;gap:12px;margin-bottom:12px}.hero-grid{grid-template-columns:minmax(0,1.75fr) minmax(270px,.65fr)}.insight-grid{grid-template-columns:repeat(3,minmax(0,1fr))}.planning-grid{grid-template-columns:1fr 1fr}.bottom-grid{grid-template-columns:1fr .72fr}
      .v164-card{background:#fff;border:1px solid var(--v164-border);border-radius:var(--v164-radius);padding:19px;box-shadow:var(--v164-shadow);min-width:0}
      .v164-cardhead{display:flex;align-items:flex-start;justify-content:space-between;gap:14px;margin-bottom:14px}
      .v164-cardhead h3{font-size:17px;margin:4px 0 0;line-height:1.25}.v164-cardhead>strong{font-size:17px}.v164-cardhead>small{color:var(--v164-muted);font-size:10px;text-align:right}
      .v164-legend{display:flex;flex-wrap:wrap;gap:14px;color:var(--v164-muted);font-size:10px}.v164-legend span{display:flex;align-items:center;gap:6px}.v164-legend i{width:18px;height:3px;border-radius:4px;background:#aab4bf}.v164-legend i.cash{background:#aab4bf}.v164-legend i.scheduled{background:#315f8d}.v164-legend i.protected{background:#caa66a}
      .v164-chart{width:100%;overflow:hidden}.v164-chart svg{display:block;width:100%;height:230px}.v164-chart path{fill:none;stroke-width:3;stroke-linecap:round;stroke-linejoin:round}.v164-chart .cash{stroke:#aab4bf;stroke-dasharray:5 7}.v164-chart .scheduled{stroke:#315f8d}.v164-chart .protected{stroke:#caa66a;stroke-dasharray:10 6}.v164-chart .grid{stroke:#d7dde4;stroke-dasharray:4 5}.v164-chart .dots{fill:#315f8d}.v164-chart text{font-size:10px;fill:#718094}
      .v164-horizons{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.v164-horizon{padding:11px;border:1px solid #e7ebef;border-radius:12px;background:#fbfcfd}.v164-horizon span,.v164-horizon small{display:block;color:var(--v164-muted);font-size:9px}.v164-horizon b{display:block;font-size:13px;margin:5px 0}.v164-horizon b.negative{color:#ad4b4b}
      .v164-account{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:13px 0;border-bottom:1px solid #edf0f3}.v164-account span{display:flex;align-items:center;gap:8px;color:#536477;font-size:12px}.v164-account span i{width:8px;height:8px;border-radius:50%;background:#7f9ab7}.v164-account b{font-size:13px}
      .v164-link{display:block;width:100%;border:0;border-top:1px solid #edf0f3;background:none;color:#234f7b;text-align:left;padding:13px 0 0;margin-top:12px;font:800 11px/1.2 inherit;cursor:pointer}.v164-link:after{content:' →'}
      .v164-inline-comparison{display:flex;justify-content:space-between;gap:10px;padding:10px 0 12px;color:var(--v164-muted);font-size:11px}.v164-inline-comparison b{color:var(--v164-ink)}
      .v164-rank{display:grid;grid-template-columns:minmax(100px,1fr) minmax(70px,.8fr) auto;align-items:center;gap:10px;width:100%;border:0;border-top:1px solid #edf0f3;background:none;color:inherit;text-align:left;padding:10px 0;font-family:inherit;cursor:pointer}.v164-rank span b,.v164-rank span small{display:block;font-size:10px}.v164-rank span small{color:var(--v164-muted);font-size:8px;margin-top:2px}.v164-rank>i{height:6px;background:#edf1f4;border-radius:9px;overflow:hidden}.v164-rank>i u{display:block;height:100%;background:#436d96;border-radius:9px;text-decoration:none}.v164-rank>strong{font-size:10px;white-space:nowrap}
      .v164-bigmetric{padding:5px 0 15px}.v164-bigmetric b{display:block;font-size:25px;letter-spacing:-.035em;margin:8px 0 4px}.v164-bigmetric small{color:var(--v164-muted);font-size:10px;line-height:1.45}.v164-split{display:grid;grid-template-columns:1fr 1fr;gap:8px}.v164-split>div{padding:12px;background:#f7f9fb;border-radius:11px}.v164-split span{display:block;color:var(--v164-muted);font-size:9px}.v164-split b{display:block;font-size:13px;margin-top:4px}
      .v164-layers,.v164-episodes{display:flex;flex-direction:column;gap:7px}.v164-layer{display:grid;grid-template-columns:30px minmax(0,1fr) auto;align-items:center;gap:10px;padding:11px;border:1px solid #e5e9ed;border-radius:12px}.v164-layer>i{width:27px;height:27px;border-radius:9px;display:grid;place-items:center;background:#e9f0f6;color:#244c73;font-style:normal;font-size:10px;font-weight:900}.v164-layer b,.v164-layer small{display:block}.v164-layer b{font-size:11px}.v164-layer small{font-size:9px;color:var(--v164-muted);margin-top:2px}.v164-layer strong{font-size:10px;color:#875f2a;text-align:right}
      .v164-episode{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:10px 0;border-bottom:1px solid #edf0f3}.v164-episode>div{display:flex;align-items:center;gap:9px}.v164-episode i{width:24px;height:24px;border-radius:50%;display:grid;place-items:center;background:#f8e8e8;color:#9c4848;font-size:9px;font-style:normal;font-weight:900}.v164-episode b,.v164-episode small{display:block}.v164-episode b{font-size:10px}.v164-episode small{font-size:9px;color:var(--v164-muted);margin-top:2px}.v164-episode>strong{font-size:11px;color:#a74a4a;white-space:nowrap}.v164-fgts{margin-top:13px;padding:13px 14px;background:#fffaf1;border:1px solid #eadbc0;border-radius:13px}.v164-fgts b,.v164-fgts small{display:block}.v164-fgts b{font-size:18px;margin:5px 0}.v164-fgts small{color:#76684e;font-size:9px}
      .v164-action{display:flex;gap:10px;padding:11px 0;border-bottom:1px solid #edf0f3}.v164-action>i{width:8px;height:8px;border-radius:50%;background:var(--v164-gold);margin-top:4px;flex:0 0 8px}.v164-action b,.v164-action small{display:block}.v164-action b{font-size:11px}.v164-action small{font-size:9px;color:var(--v164-muted);margin-top:3px;line-height:1.4}.v164-count{display:grid;place-items:center;min-width:31px;height:31px;border-radius:50%;background:#eaf0f5;color:#244c73;font-size:11px}.methodology{display:flex;align-items:center;background:linear-gradient(145deg,#f8fafc,#eef3f7)}.methodology h3{font-size:18px;margin:6px 0 9px}.methodology p{font-size:11px;line-height:1.6;color:var(--v164-muted);margin:0}.v164-empty{padding:22px;text-align:center;color:var(--v164-muted);font-size:11px}
      .v164-report{display:flex;flex-direction:column;gap:14px}.v164-report .lts-exp-source-notice,.v164-report .lts-exp-precision-notice{margin:0 0 10px;background:#f8fafc;color:#627183;border-color:#e0e6ec}
      .v164-report .ex135-head h1,.v164-report .v136 h1,.v164-report .c111-head h1{font-size:32px;line-height:1.08;margin-top:6px}.v164-report .ex135-head p,.v164-report .v136-sub,.v164-report .c111-head p{font-size:13px;line-height:1.55;max-width:800px}.v164-report .ex135-eye,.v164-report .v136-eye,.v164-report .c111-kicker{font-size:10px}
      .v164-report .ex135-main,.v164-report .ex135-kpi,.v164-report .v136-main,.v164-report .v136-card,.v164-report .ex135-panel,.v164-report .v136-panel,.v164-report .c111-panel,.v164-report .c111-card,.v164-report .c111-summary>div{border-radius:17px;box-shadow:var(--v164-shadow)}
      .v164-report .ex135-main,.v164-report .v136-main{background:linear-gradient(135deg,#153654,#285478)}
      .v164-report .ex135-main strong,.v164-report .v136-main strong{font-size:31px}.v164-report .ex135-kpi b,.v164-report .v136-card b,.v164-report .c111-summary b{font-size:20px}.v164-report .ex135-main span,.v164-report .ex135-kpi span,.v164-report .v136-card span,.v164-report .v136-main span,.v164-report .c111-summary span{font-size:9px}.v164-report .ex135-main small,.v164-report .ex135-kpi small,.v164-report .v136-card small,.v164-report .v136-main small,.v164-report .c111-summary small{font-size:10px;line-height:1.45}
      .v164-report .ex135-panel,.v164-report .v136-panel,.v164-report .c111-panel{padding:18px}.v164-report .ex135-panelhead h3,.v164-report .v136-title h3,.v164-report .c111-panelhead h3{font-size:16px}.v164-report .ex135-panelhead span,.v164-report .v136-title span,.v164-report .c111-panelhead span{font-size:9px}.v164-report .ex135-panelhead>small,.v164-report .v136-title small,.v164-report .c111-panelhead>small{font-size:10px}.v164-report .ex135-window b{font-size:19px}.v164-report .ex135-window span,.v164-report .ex135-window small{font-size:10px}.v164-report .ex135-window{padding:15px}
      .v164-report .c111-cardname{font-size:15px}.v164-report .c111-bank,.v164-report .c111-state,.v164-report .c111-main span,.v164-report .c111-main small,.v164-report .c111-nextcycle span,.v164-report .c111-nextcycle small,.v164-report .c111-floor span,.v164-report .c111-floor small{font-size:9px}.v164-report .c111-main b{font-size:27px}.v164-report .c111-guard,.v164-report .w112-note{font-size:10px;line-height:1.55}
      .v164-report .v136-row b,.v164-report .v136-row strong,.v164-report .v136-step b,.v164-report .v136-episodehead b{font-size:11px}.v164-report .v136-row small,.v164-report .v136-step small,.v164-report .v136-source,.v164-report .v136-note,.v164-report .v136-tag,.v164-report .v136-chip{font-size:9px}
      body.v164-authenticated .flowbar{margin-bottom:10px}body.v164-authenticated .mesa{border-radius:16px;box-shadow:var(--v164-shadow)}body.v164-authenticated .mrow>div{font-size:11px}
      @media(min-width:901px){
        body.v164-authenticated .hdr{position:fixed;left:0;top:0;bottom:0;width:236px;height:100vh;background:linear-gradient(180deg,#102b49,#0d2138);border:0;box-shadow:none;overflow:hidden}
        body.v164-authenticated .hdrin{height:100%;padding:26px 18px 20px;display:flex;flex-direction:column;max-width:none}
        body.v164-authenticated .top{display:flex;align-items:flex-start;flex-direction:column;height:100%;justify-content:flex-start}
        body.v164-authenticated .brand{gap:12px;padding:0 6px 24px}.v164-authenticated .logo{width:38px;height:38px;border-radius:11px}.v164-authenticated .brand b{font-size:18px}.v164-authenticated .brand small{font-size:10px;line-height:1.35;margin-top:3px}
        body.v164-authenticated .logout{position:absolute;left:24px;bottom:23px;border:0;color:#b8c4d0;padding:8px 4px;font-size:11px}
        body.v164-authenticated .nav{display:flex!important;flex-direction:column;gap:5px;margin:0;overflow:visible;width:100%}
        body.v164-authenticated .nav button{width:100%;padding:11px 12px;border:0;border-radius:10px;color:#aebdcb;background:transparent;font-size:12px;font-weight:650}
        body.v164-authenticated .nav button:hover{background:#ffffff0c;color:#fff}.v164-authenticated .nav button.active{background:#fff;color:#173858;box-shadow:0 7px 20px #08162852}.v164-authenticated .nav button.active svg{color:#b58c4d}
        body.v164-authenticated .wrap{max-width:1600px;margin:0 0 0 236px;padding:30px 34px 84px;min-height:100vh}
        body.v164-authenticated #dx1MobileNav{display:none!important}
      }
      @media(max-width:1180px){.v164-kpis{grid-template-columns:repeat(3,1fr)}.hero-grid{grid-template-columns:1fr}.insight-grid{grid-template-columns:1fr 1fr}.insight-grid>article:last-child{grid-column:1/-1}.planning-grid{grid-template-columns:1fr}.bottom-grid{grid-template-columns:1fr 1fr}}
      @media(max-width:900px){
        body.v164-authenticated{padding-bottom:78px}.v164-authenticated .hdr{position:sticky;top:0;width:auto;height:auto;background:#102b49}.v164-authenticated .hdrin{padding:10px 14px}.v164-authenticated .top{flex-direction:row;height:auto;align-items:center}.v164-authenticated .brand{padding:0}.v164-authenticated .logo{width:32px;height:32px}.v164-authenticated .brand b{font-size:16px}.v164-authenticated .logout{position:static;margin-left:auto}.v164-authenticated .nav{display:none!important}.v164-authenticated .wrap{margin:0;padding:18px 14px 88px;min-height:0}.v164-authenticated #dx1MobileNav{display:grid!important;grid-template-columns:repeat(6,minmax(0,1fr));position:fixed;left:0;right:0;bottom:0;z-index:80;min-height:70px;padding:7px max(5px,env(safe-area-inset-right)) calc(7px + env(safe-area-inset-bottom)) max(5px,env(safe-area-inset-left));background:#fff;border-top:1px solid var(--v164-border);box-shadow:0 -8px 28px rgba(16,36,62,.1)}.v164-authenticated #dx1MobileNav button{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;min-width:0;min-height:52px;padding:3px 1px;border:0;background:none;color:#768496;font-family:inherit}.v164-authenticated #dx1MobileNav svg{width:19px;height:19px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.v164-authenticated #dx1MobileNav span{font-size:8px;line-height:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}.v164-authenticated #dx1MobileNav button.active{color:#173a5c;font-weight:850}.v164-authenticated #dx1MobileNav button.active svg{color:#b4894c}
        .v164-pagehead{margin-bottom:16px}.v164-pagehead h1{font-size:29px}.v164-answer{grid-template-columns:1fr}.v164-answer-main{padding:22px}.v164-answer-main strong{font-size:24px}.v164-answer-metrics{grid-template-columns:1fr 1fr}.v164-kpis{grid-template-columns:1fr 1fr}.v164-kpi:first-child{grid-column:1/-1}.insight-grid,.bottom-grid{grid-template-columns:1fr}.insight-grid>article:last-child{grid-column:auto}.v164-report .ex135-head h1,.v164-report .v136 h1,.v164-report .c111-head h1{font-size:27px}
      }
      @media(max-width:620px){.v164-pagehead{flex-direction:column;gap:12px}.v164-pageactions{width:100%;justify-content:space-between}.v164-answer-metrics{grid-template-columns:1fr}.v164-metric{border-left:0;border-bottom:1px solid #ebeff3!important}.v164-metric:last-child{border-bottom:0!important}.v164-kpis{grid-template-columns:1fr}.v164-kpi:first-child{grid-column:auto}.v164-horizons{grid-template-columns:1fr}.v164-chart svg{height:auto}.v164-rank{grid-template-columns:minmax(110px,1fr) auto}.v164-rank>i{display:none}.v164-layer{grid-template-columns:30px 1fr}.v164-layer>strong{grid-column:2;text-align:left}.v164-card{padding:15px}.v164-report .ex135-panel,.v164-report .v136-panel,.v164-report .c111-panel{padding:14px}}
    `;
    document.head.appendChild(style);
    renderNav();
    render();
  }

  function frame(){
    try{
      const w=outer?.contentWindow,d=outer?.contentDocument;
      if(!w||!d||!d.documentElement||!String(w.location.pathname||'').endsWith('/index.html'))return null;
      return {w,d};
    }catch(error){return null}
  }

  function install(){
    const current=frame();
    if(!current)return false;
    if(!current.w.__LTS_V162_FLOW_RECOVERY_STATUS?.installed||!current.w.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed||!current.w.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed)return false;
    if(!current.w.__LTS_EXECUTIVE_VISUAL_SYSTEM?.installed&&!current.d.getElementById('lts-executive-visual-system-v1-runtime')){
      const script=current.d.createElement('script');
      script.id='lts-executive-visual-system-v1-runtime';
      script.textContent='('+visualRuntime.toString()+')();';
      (current.d.head||current.d.documentElement).appendChild(script);
    }
    const ready=current.w.__LTS_EXECUTIVE_VISUAL_SYSTEM?.installed===true;
    if(ready&&gate)gate.hidden=true;
    return ready;
  }

  function burst(){
    const current=++generation;
    let attempt=0;
    function step(){if(current!==generation)return;const ready=install();attempt+=1;if(!ready&&attempt<220)setTimeout(step,100)}
    step();
    [300,700,1400,2800,5200,9000,15000,22000].forEach(delay=>setTimeout(()=>{if(current===generation)install()},delay));
  }

  outer?.addEventListener('load',burst);
  document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v164-complete-visual-cockpits';
  window.__LTS_V164_STATUS={contract:CONTRACT,source_candidate:'index.html',public_index_changed:false,financial_writers_changed:false,planning_tab_removed:true,reports:['Dashboard','Fluxo Diário','Despesas','Cartões','Patrimônio','Atualizações']};
})();
