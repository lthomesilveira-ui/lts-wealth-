(function(){
  const outer=document.getElementById('shell');
  let wired=null;

  function chain(){
    try{
      const d141=outer&&outer.contentDocument,f140=d141&&d141.getElementById('shell');
      const d140=f140&&f140.contentDocument,f139=d140&&d140.getElementById('shell');
      const d139=f139&&f139.contentDocument,f138=d139&&d139.getElementById('shell');
      const d138=f138&&f138.contentDocument,f137=d138&&d138.getElementById('shell');
      const d137=f137&&f137.contentDocument,app=d137&&d137.getElementById('app');
      if(!app)return null;
      return {w:app.contentWindow,d:app.contentDocument};
    }catch(e){return null}
  }

  function ensureCss(d){
    if(d.getElementById('wip35-v142-dashboard-cockpit-css'))return;
    const s=d.createElement('style');s.id='wip35-v142-dashboard-cockpit-css';s.textContent=`
      .d142-audit{margin-top:10px;border:1px solid #ead7b4;background:#fffaf0;border-radius:12px;padding:11px;display:grid;grid-template-columns:1fr auto 1fr;gap:10px;align-items:center}.d142-audit>div span,.d142-audit>div small{display:block;font-size:8px;color:var(--mut)}.d142-audit>div b{display:block;font-size:14px;margin:3px 0}.d142-audit .arrow{font-size:15px;color:#a7b0bc}.d142-audit .good b{color:var(--ok)}
      .d142-links button strong{display:block;font-size:13px;margin-top:6px}.d142-warning{font-size:8px;color:var(--mut);line-height:1.4;margin-top:7px}.d142-loading{padding:26px;border:1px solid var(--bd);border-radius:18px;background:#fff}.d142-loading b{display:block;font-size:18px}.d142-loading span{display:block;color:var(--mut);font-size:10px;margin-top:5px}
      @media(max-width:650px){.d142-audit{grid-template-columns:1fr}.d142-audit .arrow{display:none}}
    `;d.head.appendChild(s)
  }

  function navRenderer(w){
    return function v142DashboardNav(){
      const N=w.document.querySelector('.nav');if(!N)return;
      const main=['Dashboard','Atualizações','Fluxo Diário','Despesas','Cartões','Patrimônio','Planejamento'];
      N.innerHTML=main.map(x=>`<button data-v="${x}" class="${w.V===x?'active':''}">${x}</button>`).join('');
      N.querySelectorAll('[data-v]').forEach(b=>b.onclick=()=>{w.V=b.dataset.v;w.renderNav();w.render()});
    }
  }

  function dashboardRenderer(w){
    return function v142ClaudeCockpitDashboard(){
      const c=w.D?.dashboard_cockpit||{},brl=w.brl,fmt=w.fmt,esc=w.esc,num=w.num;
      if(!c.version)return `<div class="d114-head"><div><span class="d114-kicker">Tesouraria pessoal · ${fmt(w.today())}</span><h1>Sua vida financeira, em uma tela.</h1><p>Liquidez, próximos riscos e ações que realmente pedem sua atenção.</p></div></div><div class="d142-loading"><b>Atualizando o cockpit…</b><span>A tela executiva está sincronizando a leitura auditada de caixa, Planejamento, cartões, despesas e patrimônio.</span></div>`;
      const l=c.liquidity||{},cards=c.cards||{},work=c.work||{},pa=c.planning_audited||{},we=c.wealth||{},ex=c.expenses||{},future=c.future_liquidity||[],hz=c.horizons||[],h30=hz.find(x=>x.id==='30d')||{},h90=hz.find(x=>x.id==='90d')||{},hye=hz.find(x=>x.id==='year_end')||{},next=cards.next_due||{},acts=work.top_actions||[],available=num(l.through_d3),bank=num(l.bank_cash),d0=num(l.d0),vested=num(l.d3_vested),fgts=num(l.fgts_d30);
      const heroTone=c.status==='critical'?'no':c.status==='attention'?'at':'ok';
      const heroStatus=c.status==='critical'?'Ação necessária':c.status==='attention'?'Coberto com gestão antecipada':'Liquidez coberta';
      const horizon=(x,label)=>{const a=x.current_liquidity_balance,b=x.conditional_rsu_balance,n=num(a),cls=n<0?'neg':n<20000?'at':'pos';return `<div class="d114-horizon"><span>${esc(label||x.label||'')}</span><b class="${cls}">${a==null?'—':brl(a)}</b><small>${x.date?fmt(x.date):''} · sem novos vestings</small>${b!=null&&Math.abs(num(b)-n)>.01?`<div><i>com vestings</i><strong class="${num(b)<0?'neg':'pos'}">${brl(b)}</strong></div>`:''}</div>`};
      const expNow=ex.current_month||{},expPrev=ex.previous_month||{};
      return `<div class="d114-head"><div><span class="d114-kicker">Tesouraria pessoal · ${fmt(c.as_of)}</span><h1>Sua vida financeira, em uma tela.</h1><p>Liquidez, próximos riscos e ações que realmente pedem sua atenção.</p></div><div class="d114-headright"><span class="status ${heroTone}">${heroStatus}</span><small>Base operacional ${fmt(c.as_of)} · Planejamento auditado</small></div></div>
      <div class="d114-hero"><div class="d114-liquidity"><span>Disponível realizável até D+3</span><strong>${brl(available)}</strong><small>caixa + D0 + RSU já vested · FGTS fora</small><div class="d114-parts"><div><span>Caixa bancário</span><b>${brl(bank)}</b></div><div><span>D0 · Cofrinho</span><b>${brl(d0)}</b></div><div><span>RSU vested</span><b>${brl(vested)}</b></div><div class="restricted"><span>FGTS · D+30</span><b>${brl(fgts)}</b></div></div></div><div class="d114-snapshot"><div class="d114-snap ${num(cards.closed_or_due_total)>0?'warn':''}"><span>Fatura vencida / a confirmar</span><b>${brl(cards.closed_or_due_total)}</b><small>${num(cards.closed_or_due_total)>0?'há valor aguardando confirmação':'nenhuma pendente'}</small></div><div class="d114-snap"><span>Faturas abertas</span><b>${brl(cards.open_cycles_total)}</b><small>ainda podem crescer</small></div><div class="d114-snap"><span>Pendências operacionais</span><b>${num(work.actionable_count)}</b><small>${num(work.classification_groups)} grupo(s) de classificação</small></div><div class="d114-snap"><span>Próxima ação de cartão</span><b>${next.due_date?fmt(next.due_date):'—'}</b><small>${next.amount?brl(next.amount)+' · '+esc(next.card_name||''):''}</small></div></div></div>
      <div class="section d114-grid"><div class="d114-panel"><div class="d114-panelhead"><div><span>Trajetória</span><h3>Quanto sobra nos próximos horizontes</h3></div><button class="chip dashact" data-dashdest="Planejamento">Abrir planejamento</button></div><div class="d114-horizons">${horizon(h30,'30 dias')}${horizon(h90,'90 dias')}${horizon(hye,'Fim de 2026')}</div><div class="d142-audit"><div><span>Ponto de gestão auditado</span><b>${pa.management_point_date?fmt(pa.management_point_date):'Nenhum'}</b><small>${pa.worst_before_brl!=null?'pior saldo antes da contingência '+brl(pa.worst_before_brl):'sem ruptura'}</small></div><div class="arrow">→</div><div class="good"><span>Plano de cobertura · FGTS D+30</span><b>${pa.fgts_request_by?'solicitar até '+fmt(pa.fgts_request_by):'não necessário'}</b><small>${pa.worst_after_brl!=null?'pior saldo depois da cobertura '+brl(pa.worst_after_brl):''}</small></div></div></div>
      <div class="d114-panel"><div class="d114-panelhead"><div><span>Ação</span><h3>O que merece você agora</h3></div><button class="chip dashact" data-dashdest="Atualizações">Central de trabalho</button></div>${acts.map(x=>`<button class="d114-action dashact" data-dashdest="Atualizações"><div><b>${esc(x.title||'Pendência')}</b><span>${esc(x.detail||'')}</span></div>${num(x.impact_amount)?`<strong>${brl(Math.abs(num(x.impact_amount)))}</strong>`:''}</button>`).join('')||'<div class="empty">Nenhuma ação prioritária.</div>'}</div></div>
      <div class="section d114-grid"><div class="d114-panel"><div class="d114-panelhead"><div><span>Agenda</span><h3>Liquidez futura conhecida</h3></div></div>${future.slice(0,5).map(x=>`<div class="d114-event"><div><b>${fmt(x.available_date)}</b><span>${esc(x.label||x.asset_type||'RSU')} · condicionado</span></div><strong>${brl(x.gross_value_brl)}</strong></div>`).join('')||'<div class="empty">Sem liquidez futura condicionada.</div>'}<div class="d114-note">Vestings futuros só entram depois de vesting + liquidação. FGTS permanece contingência D+30.</div></div>
      <div class="d114-panel"><div class="d114-panelhead"><div><span>Atalhos de decisão</span><h3>Aprofunde sem procurar</h3></div></div><div class="d114-links d142-links"><button class="dashact" data-dashdest="Fluxo Diário"><b>Fluxo Diário</b><strong>${brl(bank)}</strong><span>caixa bancário hoje</span></button><button class="dashGoExpenses"><b>Despesas</b><strong>${expNow.spend!=null?brl(expNow.spend):'—'}</strong><span>${expNow.month?fmt(expNow.month).slice(3):'mês atual'}${expPrev.spend!=null?' · anterior '+brl(expPrev.spend):''}</span></button><button class="dashact" data-dashdest="Cartões"><b>Cartões</b><strong>${brl(cards.open_cycles_total)}</strong><span>faturas abertas</span></button><button class="dashact" data-dashdest="Patrimônio"><b>Patrimônio</b><strong>${we.net_worth_central!=null?brl(we.net_worth_central):'—'}</strong><span>estimativa central · dívida conhecida ${we.known_debt_total!=null?brl(we.known_debt_total):'—'}</span></button></div>${ex.coverage_warning?`<div class="d142-warning">Despesas: ${esc(ex.coverage_warning)} A comparação mensal é descritiva enquanto a cobertura histórica de cartões não for homogênea.</div>`:''}</div></div>`;
    }
  }

  async function loadCockpit(w){
    if(w.__LTS_V142_DASHBOARD_LOADING||!w.D||!w.S||typeof w.S.rpc!=='function')return;
    w.__LTS_V142_DASHBOARD_LOADING=true;
    try{
      const {data,error}=await w.S.rpc('lts_browser_dashboard_cockpit_v1');
      if(error||!data)throw Error(error?.message||'Dashboard indisponível');
      w.D.dashboard_cockpit=data;
      w.LTS_DASHBOARD_COCKPIT='v142-claude-cockpit-audited';
      if(!w.__LTS_V142_DASHBOARD_BOOTED){w.__LTS_V142_DASHBOARD_BOOTED=true;w.V='Dashboard';w.renderNav();w.render()}
      else if(w.V==='Dashboard')w.render();
    }catch(e){w.__LTS_V142_DASHBOARD_ERROR=String(e?.message||e)}
    finally{w.__LTS_V142_DASHBOARD_LOADING=false}
  }

  function install(){
    const z=chain();if(!z)return;const w=z.w,d=z.d;ensureCss(d);
    if(!w.__lts_v142_dashboard_fn)w.__lts_v142_dashboard_fn=dashboardRenderer(w);
    if(w.dashboard!==w.__lts_v142_dashboard_fn)w.dashboard=w.__lts_v142_dashboard_fn;
    if(!w.__lts_v142_dashboard_nav)w.__lts_v142_dashboard_nav=navRenderer(w);
    if(w.renderNav!==w.__lts_v142_dashboard_nav)w.renderNav=w.__lts_v142_dashboard_nav;
    if(w.D&&w.D.dashboard_cockpit)w.LTS_DASHBOARD_COCKPIT='v142-claude-cockpit-audited';
    loadCockpit(w);
    if(wired!==w){wired=w;try{w.renderNav()}catch(e){}}
  }

  outer?.addEventListener('load',()=>setTimeout(install,120));
  setInterval(install,180);
})();
