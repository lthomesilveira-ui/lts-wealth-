(function(){
  'use strict';
  const CONTRACT='dashboard-executive-cash-answer-v1';
  const MODEL_SRC='lts-dashboard-read-model.js?v=20260915-cash-answer-v1';
  const SESSION_KEY='lts_supabase_session_v1';
  const outer=document.getElementById('shell');
  const gate=document.getElementById('gate');
  let generation=0;
  function dashboardRuntime(){
    'use strict';
    if(window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed)return;
    const modelApi=window.LTSDashboardReadModel;
    if(!modelApi)return;
    const status=window.__LTS_DASHBOARD_EXECUTIVE_STATUS={installed:true,contract:'dashboard-executive-cash-answer-v1',reader:'lts_browser_dashboard_cockpit_v1',read_only:true,financial_writer_changed:false,flow_runtime_preserved:true,expense_runtime_preserved:true,public_index_changed:false,initial_route:'Dashboard',mobile_nav_six_fixed:true,permanent_polling:false,loaded:false,loading:false,error:null,calls:0};
    const state={cockpit:D?.dashboard_cockpit||null,loading:false,loaded:false,error:null,sequence:0,rpcRequested:false,initialApplied:false};
    const money=value=>value===null||value===undefined?'Indisponível':brl(value);
    const date=value=>value?fmt(value):'Indisponível';
    const txt=value=>esc(value==null?'':value);
    const signed=value=>value===null||value===undefined?'':value<0?'neg':'pos';
    function go(route){
      if(route==='Dashboard'){V='Dashboard';renderNav();render();return}
      const top=document.querySelector('.nav [data-v="'+CSS.escape(route)+'"]');
      if(top&&typeof top.onclick==='function'){top.click();return}
      V=route;renderNav();render();
    }
    function chart(series){
      const points=(series||[]).filter(point=>point.base!==null||point.conditional!==null||point.restricted!==null);
      if(points.length<2)return '<div class="dx1-empty">A curva será exibida quando houver pelo menos dois horizontes projetados documentados.</div>';
      const values=points.flatMap(point=>[point.base,point.conditional,point.restricted]).filter(value=>value!==null);
      const lo=Math.min(...values,0),hi=Math.max(...values,0),span=Math.max(hi-lo,1),x=index=>34+(index*(552/Math.max(points.length-1,1))),y=value=>22+((hi-value)/span)*156;
      const path=key=>{const valid=points.map((point,index)=>({value:point[key],index})).filter(point=>point.value!==null);return valid.length<2?'':valid.map((point,i)=>(i?'L':'M')+x(point.index).toFixed(1)+' '+y(point.value).toFixed(1)).join(' ')};
      const labels=points.map((point,index)=>'<text x="'+x(index)+'" y="201" text-anchor="middle">'+txt(point.label||fmt(point.date))+'</text>').join('');
      const dots=points.map((point,index)=>point.base===null?'':'<circle cx="'+x(index)+'" cy="'+y(point.base)+'" r="4"></circle>').join('');
      return '<div class="dx1-chart"><svg viewBox="0 0 620 214" role="img" aria-label="Evolução projetada da liquidez"><line class="zero" x1="34" x2="586" y1="'+y(0)+'" y2="'+y(0)+'"></line><path class="base" d="'+path('base')+'"></path><path class="conditional" d="'+path('conditional')+'"></path><path class="restricted" d="'+path('restricted')+'"></path><g class="dots">'+dots+'</g><g class="labels">'+labels+'</g></svg></div>';
    }
    function kpi(label,value,note,kind){return '<article class="dx1-kpi '+(kind||'')+'"><span>'+txt(label)+'</span><strong>'+money(value)+'</strong><small>'+txt(note)+'</small></article>'}
    function metric(label,value,note){return '<div class="dx1-metric"><span>'+txt(label)+'</span><b class="'+signed(value)+'">'+money(value)+'</b><small>'+txt(note||'')+'</small></div>'}
    function dashboardView(){
      const vm=modelApi.build(state.cockpit||{}),decision=vm.decision,k=vm.kpis,pa=vm.planning,expense=vm.expenses,current=expense.current||{},previous=expense.previous||{},next=vm.cards.nextDue||{};
      const decisionClass=decision.state==='negative'?'risk':decision.state==='sufficient'?'safe':'unknown';
      const firstNegative=decision.firstNegative?date(decision.firstNegative):decision.state==='sufficient'?'Não no horizonte':'Indisponível';
      const covered=decision.coveredUntil?date(decision.coveredUntil):decision.state==='sufficient'?'Horizonte confirmado':'Indisponível';
      const worstNote=decision.worstDate?'Em '+date(decision.worstDate):'Data não informada pelo leitor';
      const accounts=vm.accounts.map(account=>'<div class="dx1-row"><span>'+txt(account.institution||account.account||'Conta')+'</span><b>'+money(modelApi.finite(account.balance))+'</b></div>').join('');
      const horizons=vm.horizons.map(item=>'<div class="dx1-horizon"><div><span>'+txt(item.label||item.id||'Horizonte')+'</span><small>'+date(item.date)+'</small></div><b class="'+signed(item.base)+'">'+money(item.base)+'</b><em>Cenário-base</em></div>').join('');
      const maxTop=Math.max(...expense.top.map(item=>Math.abs(modelApi.finite(item.amount??item.spend??item.total)||0)),1);
      const top=expense.top.slice(0,5).map(item=>{const value=modelApi.finite(item.amount??item.spend??item.total);return '<button class="dx1-rank" data-go="Despesas" type="button"><span>'+txt(item.category||item.name||item.label||'Categoria')+'</span><i><u style="width:'+Math.min(100,Math.abs(value||0)/maxTop*100)+'%"></u></i><b>'+money(value)+'</b></button>'}).join('');
      const actions=vm.work.actions.slice(0,4).map(action=>'<div class="dx1-action"><div><b>'+txt(action.title||'Ação pendente')+'</b><span>'+txt(action.description||'')+'</span></div></div>').join('');
      const loading=state.loading?'<div class="dx1-loading" role="status">Atualizando dados executivos…</div>':'';
      const error=state.error?'<div class="notice" role="alert">Não foi possível atualizar o resumo. Os últimos dados disponíveis permanecem identificados na tela.</div>':'';
      return '<main class="dx1" data-dashboard-contract="executive-cash-answer-evidence-v1">'+
        '<header class="dx1-head"><div><span class="dx1-kicker">Resumo executivo</span><h1>Sua posição financeira</h1><p>Caixa disponível, projeção e compromissos — sem misturar fato presente com cenário futuro.</p></div><div class="dx1-head-actions"><span>Posição '+date(vm.asOf)+'</span><button id="dx1Refresh" class="chip" type="button">Atualizar</button></div></header>'+loading+error+
        '<section class="dx1-decision '+decisionClass+'"><div class="dx1-answer"><span>A pergunta principal</span><h2>Tenho dinheiro suficiente?</h2><strong>'+txt(decision.answer)+'</strong><p>'+txt(decision.detail)+'</p><i>Cenário-base operacional</i></div><div class="dx1-answer-grid">'+
          metric('Primeiro saldo negativo',null,decision.firstNegative?'Cenário-base projetado':decision.state==='sufficient'?'Sem ruptura no horizonte':'Data não informada').replace('Indisponível</b>',''+txt(firstNegative)+'</b>')+
          metric('Caixa coberto até',null,decision.firstNegative?'Véspera da primeira ruptura':decision.state==='sufficient'?'Fim do horizonte disponível':'Cobertura não confirmada').replace('Indisponível</b>',''+txt(covered)+'</b>')+
          metric('Pior saldo projetado',decision.worst,worstNote)+
          metric('Ponto de gestão',null,pa.managementDate?'Data de reavaliação':'Não informado').replace('Indisponível</b>',txt(pa.managementDate?date(pa.managementDate):'Indisponível')+'</b>')+
        '</div></section>'+ 
        '<section class="dx1-kpis">'+
          kpi('Dinheiro em contas',k.bankCash,'Saldo bancário documentado','primary')+
          kpi('Contas + curto prazo',k.shortTerm.value,k.shortTerm.method==='bank_cash_plus_d0'?'Contas + liquidez D+0':'Derivado de D+3 sem RSUs')+
          kpi('RSUs vested',k.vested,'Disponibilidade evidenciada separadamente')+
          kpi('FGTS',k.fgts,'Restrito · não é caixa presente','restricted')+
          kpi('Despesas (mês)',k.expenses,'Mês corrente no leitor reconciliado')+
        '</section>'+ 
        '<section class="dx1-grid-main"><article class="dx1-card dx1-evolution"><div class="dx1-cardhead"><div><span>Liquidez</span><h3>Evolução projetada do caixa</h3></div><button class="chip" data-go="Fluxo Diário" type="button">Abrir Fluxo</button></div><div class="dx1-legend"><i class="base"></i>Base operacional <i class="conditional"></i>Com RSUs futuras <i class="restricted"></i>Com recursos restritos</div>'+chart(vm.horizons)+'<div class="dx1-horizons">'+(horizons||'<div class="dx1-empty">Horizontes indisponíveis.</div>')+'</div></article>'+ 
        '<aside class="dx1-card"><div class="dx1-cardhead"><div><span>Contas</span><h3>Posição bancária</h3></div></div>'+(accounts||'<div class="dx1-empty">Detalhamento por conta indisponível.</div>')+'<button class="dx1-link" data-go="Fluxo Diário" type="button">Ver movimentações</button></aside></section>'+ 
        '<section class="dx1-grid-three"><article class="dx1-card"><div class="dx1-cardhead"><div><span>Consumo</span><h3>Principais despesas</h3></div></div>'+metric('Mês atual',modelApi.finite(current.spend),'Leitor reconciliado')+metric('Mês anterior',modelApi.finite(previous.spend),'Referência histórica')+(top||'<div class="dx1-empty">Categorias ainda indisponíveis.</div>')+'<button class="dx1-link" data-go="Despesas" type="button">Abrir relatório de despesas</button></article>'+ 
        '<article class="dx1-card"><div class="dx1-cardhead"><div><span>Compromissos</span><h3>O que vem pela frente</h3></div></div>'+metric('Próxima fatura',modelApi.finite(next.amount),next.due_date?'Vence em '+date(next.due_date):'Data indisponível')+metric('Ciclos em aberto',vm.cards.open,'Ainda podem mudar')+metric('Fechado ou vencido',vm.cards.closed,'Não somar novamente ao consumo')+'<button class="dx1-link" data-go="Cartões" type="button">Ver cartões</button></article>'+ 
        '<article class="dx1-card validation"><div class="dx1-cardhead"><div><span>Patrimônio</span><h3>Posição patrimonial em validação</h3></div></div><div class="dx1-validation"><b>Total consolidado ainda não certificado</b><p>Ativos, dívidas, disponibilidade, avaliação e datas-base continuam no gate independente. Nenhum total patrimonial é apresentado como aprovado nesta tela.</p></div><button class="dx1-link" data-go="Patrimônio" type="button">Abrir posição patrimonial</button></article></section>'+ 
        '<section class="dx1-grid-bottom"><article class="dx1-card"><div class="dx1-cardhead"><div><span>Planejamento</span><h3>Proteções e decisões</h3></div><button class="chip" data-go="Planejamento" type="button">Detalhar</button></div>'+metric('Após contingência / FGTS',pa.worstAfter,pa.fgtsRequestBy?'Solicitar até '+date(pa.fgtsRequestBy):'Prazo de solicitação indisponível')+'<div class="dx1-note">FGTS permanece separado do caixa presente. '+(pa.fgtsEstimated?'Há estimativa de acréscimo futuro sinalizada pelo leitor.':'Não há estimativa de acréscimo futuro aplicada.')+'</div></article>'+ 
        '<article class="dx1-card"><div class="dx1-cardhead"><div><span>Atualizações</span><h3>O que precisa da sua atenção</h3></div><b class="dx1-count">'+(vm.work.count===null?'—':txt(vm.work.count))+'</b></div>'+(actions||'<div class="dx1-empty">Nenhuma ação detalhada disponível no resumo.</div>')+'<button class="dx1-link" data-go="Atualizações" type="button">Abrir atualizações</button></article></section>'+ 
        '<p class="dx1-footnote">Fato documentado e projeção aparecem em camadas distintas. Valores indisponíveis não são inferidos.</p></main>';
    }
    dashboard=dashboardView;
    function bind(){
      document.querySelectorAll('[data-go]').forEach(button=>button.onclick=()=>go(button.dataset.go));
      const refresh=document.getElementById('dx1Refresh');if(refresh)refresh.onclick=()=>loadDashboard(true);
      const badge=window.parent.document.getElementById('scope');if(badge)badge.textContent=V==='Dashboard'?'Resumo executivo · homologação':V==='Despesas'?'Despesas · homologação':'Fluxo Diário · homologação';
      document.querySelectorAll('.brand small').forEach(node=>{node.textContent=V==='Dashboard'?'Resumo executivo':V==='Despesas'?'Relatório reconciliado':'Recuperação do Fluxo Diário'});
      bindMobileNav();
    }
    function bindMobileNav(){
      let nav=document.getElementById('dx1MobileNav');if(!nav){nav=document.createElement('nav');nav.id='dx1MobileNav';nav.className='dx1-mobile-nav';nav.setAttribute('aria-label','Navegação principal');document.body.appendChild(nav)}
      const routes=[['Dashboard','Resumo'],['Fluxo Diário','Fluxo'],['Despesas','Despesas'],['Cartões','Cartões'],['Patrimônio','Patrimônio'],['Atualizações','Atualizar']];
      nav.innerHTML=routes.map(route=>'<button type="button" data-mobile-route="'+route[0]+'" class="'+(V===route[0]?'active':'')+'"><i aria-hidden="true"></i><span>'+route[1]+'</span></button>').join('');
      nav.querySelectorAll('[data-mobile-route]').forEach(button=>button.onclick=()=>go(button.dataset.mobileRoute));
    }
    const baseRender=render;
    render=function(){baseRender();bind();if(V==='Dashboard'&&!state.rpcRequested&&!state.loading)queueMicrotask(()=>loadDashboard(false))};
    const baseRenderNav=renderNav;
    renderNav=function(){
      baseRenderNav();
      let button=N.querySelector('[data-v="Dashboard"]');
      if(!button){button=document.createElement('button');button.type='button';button.dataset.v='Dashboard';button.textContent='Dashboard';N.prepend(button)}
      button.classList.toggle('active',V==='Dashboard');button.onclick=()=>go('Dashboard');button.style.display='';
      const order=['Dashboard','Fluxo Diário','Despesas','Cartões','Patrimônio','Atualizações','Planejamento'];order.forEach(route=>{const item=N.querySelector('[data-v="'+route+'"]');if(item)N.appendChild(item)});
    };
    async function loadDashboard(force){
      if(state.loading)return;state.rpcRequested=true;state.loading=true;state.error=null;status.loading=true;status.calls+=1;const sequence=++state.sequence;if(V==='Dashboard')render();
      try{const {data,error}=await S.rpc('lts_browser_dashboard_cockpit_v1');if(sequence!==state.sequence)return;if(error||!data)throw new Error(error?.message||'Resumo executivo indisponível');state.cockpit=data;state.loaded=true;D.dashboard_cockpit=data;status.loaded=true;status.error=null;status.as_of=data.as_of||null}
      catch(error){if(sequence!==state.sequence)return;state.error=String(error?.message||error||'Falha de leitura');status.error=state.error}
      finally{if(sequence===state.sequence){state.loading=false;status.loading=false;if(V==='Dashboard')render()}}
    }
    function applyInitial(){const flow=window.__LTS_V162_FLOW_RECOVERY_STATUS;if(state.initialApplied||!D||flow?.installed!==true)return false;state.initialApplied=true;status.initial_applied_at=new Date().toISOString();status.flow_ready_before_initial=true;status.flow_runtime_ready_before_initial=true;status.flow_read_completion_not_required=true;V='Dashboard';renderNav();render();return true}
    window.__LTS_V163_ROUTE_DASHBOARD=function(){return applyInitial()?{state:'dashboard',done:true}:state.initialApplied?{state:'dashboard',done:true}:{state:document.querySelector('.login')?'login':'waiting',done:false}};
    const style=document.createElement('style');style.id='lts-dashboard-executive-style';style.textContent=`
      .nav [data-v="Dashboard"]{display:block!important}.dx1{max-width:1320px;margin:0 auto}.dx1-head{display:flex;align-items:flex-end;justify-content:space-between;gap:24px;margin:2px 0 14px}.dx1-head h1{font-size:30px;letter-spacing:-.04em;margin:3px 0}.dx1-head p{margin:0;color:var(--mut);font-size:11px}.dx1-kicker,.dx1-cardhead span{font-size:9px;font-weight:900;letter-spacing:.12em;text-transform:uppercase;color:#8d6f42}.dx1-head-actions{display:flex;align-items:center;gap:8px;color:var(--mut);font-size:10px}.dx1-decision{display:grid;grid-template-columns:minmax(280px,.82fr) minmax(0,1.45fr);border-radius:22px;overflow:hidden;box-shadow:0 16px 44px rgba(16,43,80,.14);margin-bottom:11px}.dx1-answer{padding:24px;color:#fff;background:linear-gradient(135deg,#102b50,#1b3b6f)}.dx1-decision.safe .dx1-answer{background:linear-gradient(135deg,#123f38,#1f705d)}.dx1-decision.risk .dx1-answer{background:linear-gradient(135deg,#6f2c2c,#a04742)}.dx1-answer>span{font-size:9px;opacity:.7;text-transform:uppercase;letter-spacing:.12em}.dx1-answer h2{font-size:16px;margin:15px 0 8px}.dx1-answer strong{display:block;font-size:25px;line-height:1.08;letter-spacing:-.025em}.dx1-answer p{font-size:10px;line-height:1.5;opacity:.78;margin:10px 0 14px}.dx1-answer i{font-style:normal;font-size:8px;border:1px solid #ffffff3a;border-radius:999px;padding:5px 8px}.dx1-answer-grid{display:grid;grid-template-columns:1fr 1fr;background:#fff}.dx1-metric{padding:15px;border-left:1px solid #edf0f4;border-bottom:1px solid #edf0f4}.dx1-metric span,.dx1-metric small{display:block;color:var(--mut);font-size:8px}.dx1-metric b{display:block;font-size:16px;margin:5px 0}.dx1-kpis{display:grid;grid-template-columns:repeat(5,1fr);gap:9px;margin-bottom:11px}.dx1-kpi{background:#fff;border:1px solid var(--bd);border-radius:15px;padding:14px;box-shadow:var(--shadow);min-width:0}.dx1-kpi.primary{border-color:#c3d3e5}.dx1-kpi.restricted{background:#fffcf5;border-color:#e5d6b7}.dx1-kpi span,.dx1-kpi small{display:block;color:var(--mut);font-size:8px}.dx1-kpi strong{display:block;font-size:19px;letter-spacing:-.025em;margin:7px 0;overflow-wrap:anywhere}.dx1-card{background:#fff;border:1px solid var(--bd);border-radius:17px;padding:15px;box-shadow:var(--shadow);min-width:0}.dx1-cardhead{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:9px}.dx1-cardhead h3{font-size:15px;margin:3px 0 0}.dx1-grid-main{display:grid;grid-template-columns:minmax(0,1.55fr) minmax(250px,.55fr);gap:10px;margin-bottom:10px}.dx1-grid-three{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:10px}.dx1-grid-bottom{display:grid;grid-template-columns:1fr 1fr;gap:10px}.dx1-legend{display:flex;gap:12px;flex-wrap:wrap;color:var(--mut);font-size:8px}.dx1-legend i{width:14px;height:3px;border-radius:9px;background:#1b3b6f;align-self:center}.dx1-legend i.conditional{background:#b8935a}.dx1-legend i.restricted{background:#a7b0bc}.dx1-chart{width:100%;overflow:hidden}.dx1-chart svg{width:100%;height:190px;display:block}.dx1-chart path{fill:none;stroke-width:4;stroke-linecap:round;stroke-linejoin:round}.dx1-chart .base{stroke:#1b3b6f}.dx1-chart .conditional{stroke:#b8935a;stroke-dasharray:8 7}.dx1-chart .restricted{stroke:#a7b0bc;stroke-dasharray:3 7}.dx1-chart .zero{stroke:#c5ccd5;stroke-dasharray:4 5}.dx1-chart .dots{fill:#1b3b6f}.dx1-chart text{font-size:9px;fill:#748197}.dx1-horizons{display:grid;grid-template-columns:repeat(3,1fr);gap:7px}.dx1-horizon{border:1px solid #edf0f4;border-radius:11px;padding:9px}.dx1-horizon>div{display:flex;justify-content:space-between;gap:5px}.dx1-horizon span,.dx1-horizon small,.dx1-horizon em{font-size:8px;color:var(--mut);font-style:normal}.dx1-horizon b{display:block;font-size:12px;margin:7px 0 2px}.dx1-row{display:flex;justify-content:space-between;gap:12px;padding:11px 0;border-bottom:1px solid #edf0f4;font-size:10px}.dx1-row:last-of-type{border-bottom:0}.dx1-link{display:block;width:100%;border:0;border-top:1px solid #edf0f4;background:none;color:var(--nv);text-align:left;padding:11px 0 0;margin-top:8px;font:800 9px/1.2 inherit;cursor:pointer}.dx1-rank{display:grid;grid-template-columns:minmax(80px,1fr) 1.2fr auto;gap:8px;align-items:center;width:100%;border:0;border-top:1px solid #edf0f4;background:none;padding:9px 0;text-align:left;color:inherit;font-family:inherit}.dx1-rank span,.dx1-rank b{font-size:9px}.dx1-rank i{height:5px;background:#eef1f4;border-radius:99px;overflow:hidden}.dx1-rank u{display:block;height:100%;background:var(--nv);border-radius:99px;text-decoration:none}.dx1-validation{padding:15px;border-radius:13px;background:#f7f9fb}.dx1-validation b{font-size:13px}.dx1-validation p,.dx1-note{font-size:9px;color:var(--mut);line-height:1.5}.dx1-action{padding:9px 0;border-top:1px solid #edf0f4}.dx1-action:first-of-type{border-top:0}.dx1-action b,.dx1-action span{display:block;font-size:9px}.dx1-action span{font-size:8px;color:var(--mut);margin-top:2px}.dx1-count{display:grid;place-items:center;min-width:30px;height:30px;border-radius:50%;background:#eef2f6;color:var(--nv);font-size:11px}.dx1-empty{padding:18px;text-align:center;color:var(--mut);font-size:9px}.dx1-loading{padding:8px 11px;margin-bottom:9px;border-radius:10px;background:#edf4fa;color:var(--nv);font-size:9px}.dx1-footnote{text-align:center;color:var(--mut);font-size:8px;margin:12px 0 72px}.dx1-mobile-nav{display:none}
      @media(max-width:1000px){.dx1-kpis{grid-template-columns:repeat(3,1fr)}.dx1-grid-main{grid-template-columns:1fr}.dx1-grid-three{grid-template-columns:1fr 1fr}.dx1-grid-three .validation{grid-column:1/-1}}
      @media(max-width:820px){body{padding-bottom:76px}.nav{display:none}.dx1-head{align-items:flex-start;flex-direction:column;gap:9px}.dx1-head h1{font-size:25px}.dx1-head-actions{width:100%;justify-content:space-between}.dx1-decision{grid-template-columns:1fr;border-radius:18px}.dx1-answer{padding:20px}.dx1-answer strong{font-size:23px}.dx1-answer-grid{grid-template-columns:1fr 1fr}.dx1-kpis{grid-template-columns:1fr 1fr}.dx1-kpi:first-child{grid-column:1/-1}.dx1-grid-three,.dx1-grid-bottom{grid-template-columns:1fr}.dx1-grid-three .validation{grid-column:auto}.dx1-chart svg{height:auto}.dx1-horizons{grid-template-columns:1fr}.dx1-card{border-radius:15px}.dx1-mobile-nav{position:fixed;display:grid;grid-template-columns:repeat(6,minmax(0,1fr));left:0;right:0;bottom:0;z-index:50;min-height:64px;padding:6px max(5px,env(safe-area-inset-right)) calc(6px + env(safe-area-inset-bottom)) max(5px,env(safe-area-inset-left));background:#fff;border-top:1px solid var(--bd);box-shadow:0 -8px 24px rgba(16,43,80,.09)}.dx1-mobile-nav button{min-width:0;min-height:48px;border:0;background:none;color:var(--mut);font-family:inherit;padding:3px 1px}.dx1-mobile-nav button i{display:block;width:7px;height:7px;border:2px solid currentColor;border-radius:50%;margin:0 auto 5px}.dx1-mobile-nav button span{display:block;font-size:7px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.dx1-mobile-nav button.active{color:var(--nv);font-weight:900}.dx1-mobile-nav button.active i{background:var(--ouro);border-color:var(--ouro)}}
      @media(max-width:420px){.dx1-kpis{grid-template-columns:1fr}.dx1-kpi:first-child{grid-column:auto}.dx1-metric{padding:12px}.dx1-mobile-nav button span{font-size:6.5px}}
    `;document.head.appendChild(style);
    renderNav();bindMobileNav();applyInitial();
  }
  function frame(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w||!d||!d.documentElement||!String(w.location.pathname||'').endsWith('/index.html'))return null;return {w,d}}catch(error){return null}}
  function install(){
    const f=frame();if(!f)return false;
    if(!f.w.LTSDashboardReadModel){
      if(!f.d.getElementById('lts-dashboard-read-model')){const script=f.d.createElement('script');script.id='lts-dashboard-read-model';script.src=MODEL_SRC;script.onload=burst;(f.d.head||f.d.documentElement).appendChild(script)}return false;
    }
    if(!f.w.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed&&!f.d.getElementById('lts-dashboard-executive-runtime')){const script=f.d.createElement('script');script.id='lts-dashboard-executive-runtime';script.textContent='('+dashboardRuntime.toString()+')();';(f.d.head||f.d.documentElement).appendChild(script)}
    const result=f.w.__LTS_V163_ROUTE_DASHBOARD?.();if((result?.state==='dashboard'||result?.state==='login')&&gate)gate.hidden=true;return result?.state==='dashboard';
  }
  function burst(){const current=++generation;let attempt=0;function step(){if(current!==generation)return;const done=install();attempt+=1;if(!done&&attempt<180)setTimeout(step,100)}step();[250,600,1200,2400,4800,8000,12000,18000].forEach(delay=>setTimeout(()=>{if(current===generation)install()},delay))}
  function sessionChanged(event){if(event.storageArea===localStorage&&event.key===SESSION_KEY&&event.newValue)burst()}
  window.addEventListener('storage',sessionChanged);
  outer?.addEventListener('load',burst);document.readyState==='loading'?document.addEventListener('DOMContentLoaded',burst,{once:true}):burst();
  window.__LTS_TOP_CANDIDATE_VERSION='v163-dashboard-executive';
  window.__LTS_V163_STATUS={contract:CONTRACT,source_candidate:'index.html',flow_baseline:'wip35-v162-flow-recovery',expense_baseline:'ex135-reconciled',dashboard_reader:'lts_browser_dashboard_cockpit_v1',read_only:true,financial_writer_changed:false,public_index_changed:false,bounded_boot:true,post_login_session_rearm:true,permanent_polling:false};
})();
