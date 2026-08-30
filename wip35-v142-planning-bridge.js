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
  function installCss(d){
    if(d.getElementById('wip35-v142-planning-bridge-css'))return;
    const s=d.createElement('style');s.id='wip35-v142-planning-bridge-css';s.textContent=`
      .pb142-page{display:flex;flex-direction:column;gap:10px}.pb142-head{display:flex;justify-content:space-between;align-items:flex-end;gap:16px}.pb142-eye{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.09em;font-weight:900;color:#8b6a39}.pb142-head h1{font-size:26px;line-height:1.05;margin:4px 0 5px;letter-spacing:-.035em}.pb142-head p{margin:0;max-width:760px;font-size:10px;color:var(--mut);line-height:1.45}.pb142-status{font-size:9px;padding:6px 9px;border-radius:999px;background:#eaf6f0;color:#326b53;font-weight:850;white-space:nowrap}
      .pb142-hero{display:grid;grid-template-columns:1.3fr repeat(3,.72fr);gap:8px}.pb142-main,.pb142-kpi{border:1px solid var(--bd);border-radius:16px;padding:13px;background:#fff}.pb142-main{background:linear-gradient(135deg,#17304d,#214d77);color:#fff}.pb142-main span,.pb142-kpi span{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.05em;font-weight:850;opacity:.72}.pb142-main strong{display:block;font-size:27px;margin:6px 0}.pb142-main small{display:block;font-size:8px;line-height:1.4;opacity:.74}.pb142-kpi b{display:block;font-size:17px;margin:6px 0}.pb142-kpi small{display:block;font-size:8px;line-height:1.35;color:var(--mut)}
      .pb142-panel{background:#fff;border:1px solid var(--bd);border-radius:16px;padding:13px}.pb142-panelhead{display:flex;justify-content:space-between;align-items:flex-end;gap:10px;margin-bottom:8px}.pb142-panelhead h3{font-size:14px;margin:3px 0 0}.pb142-panelhead span,.pb142-panelhead small{font-size:8px;color:var(--mut)}
      .pb142-story{display:grid;grid-template-columns:repeat(5,1fr);gap:7px}.pb142-step{background:#fafbfd;border:1px solid #e5eaf0;border-radius:11px;padding:9px;min-height:86px}.pb142-step em{font-style:normal;font-size:8px;font-weight:900;color:#8b6a39}.pb142-step b{display:block;font-size:13px;margin:5px 0}.pb142-step span{display:block;font-size:8px;color:var(--mut);line-height:1.35}.pb142-step.last{background:#fffaf0;border-color:#ead7b4}.pb142-step.ok{background:#eef7f2;border-color:#cee5d8}
      .pb142-grid{display:grid;grid-template-columns:1.1fr .9fr;gap:8px}.pb142-callout{border-left:3px solid #b8935a;background:#fffaf2;border-radius:10px;padding:11px 12px}.pb142-callout.ok{border-left-color:#4f8a6b;background:#eef7f2}.pb142-callout b{display:block;font-size:11px;margin-bottom:4px}.pb142-callout span{display:block;font-size:9px;line-height:1.45;color:#6a5a3e}.pb142-callout.ok span{color:#3f6652}.pb142-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;padding:7px 0;border-top:1px solid #edf0f4}.pb142-row:first-child{border-top:0}.pb142-row b{font-size:9px}.pb142-row span{display:block;font-size:8px;color:var(--mut);margin-top:2px}.pb142-row strong{font-size:9px;white-space:nowrap}.pb142-fold{background:#f8fafc;border:1px solid var(--bd);border-radius:12px;padding:0 10px}.pb142-fold summary{padding:9px 0;cursor:pointer;font-size:9px;font-weight:850}.pb142-fold .pb142-body{font-size:8px;color:var(--mut);line-height:1.5;padding:0 0 10px}.pb142-loading{padding:20px;border:1px dashed var(--bd);border-radius:14px;background:#fafbfd;font-size:10px;color:var(--mut);text-align:center}
      @media(max-width:1100px){.pb142-hero{grid-template-columns:1fr 1fr}.pb142-main{grid-column:1/-1}.pb142-story{grid-template-columns:repeat(3,1fr)}}
      @media(max-width:760px){.pb142-head{align-items:flex-start;flex-direction:column}.pb142-hero,.pb142-story,.pb142-grid{grid-template-columns:1fr}.pb142-main{grid-column:auto}.pb142-status{white-space:normal}}
    `;d.head.appendChild(s)
  }
  function fmtLayer(w,x){
    const id=String(x?.id||'');
    const amount=id==='future_vestings'?'Condicional':id==='fgts'?w.brl(x.projected_at_request??x.starting_amount):w.brl(x.starting_amount);
    const note=id==='cash'?'saldo bancário':id==='d01'?'liquidez imediata':id==='rsu_vested'?'realizável em D+3':id==='future_vestings'?'somente após vesting + liquidação':'saldo projetado na data de solicitação';
    const cls=id==='fgts'?'pb142-step last ok':id==='future_vestings'?'pb142-step last':'pb142-step';
    return `<div class="${cls}"><em>${w.esc(x.label||id)}</em><b>${amount}</b><span>${note}${x.first_need_next_layer?` · próxima camada em ${w.fmt(x.first_need_next_layer)}`:''}</span></div>`
  }
  function render(w){
    const s=w.__LTS_V142_PLAN_BRIDGE||{};
    if(s.loading)return `<div class="pb142-page"><div class="pb142-head"><div><span class="pb142-eye">Planejamento</span><h1>Atualizando sua escada de liquidez.</h1><p>Estou conciliando caixa, Cofrinho, RSUs e FGTS na mesma linha do tempo.</p></div></div><div class="pb142-loading">Carregando a leitura reconciliada…</div></div>`;
    if(s.error)return `<div class="pb142-page"><div class="pb142-head"><div><span class="pb142-eye">Planejamento</span><h1>Não consegui atualizar a leitura agora.</h1><p>A versão anterior permanece preservada; nenhum valor foi substituído por hipótese.</p></div></div><div class="pb142-loading">${w.esc(s.error)}</div></div>`;
    const p=s.data;if(!p)return `<div class="pb142-loading">Preparando Planejamento…</div>`;
    const q=p.summary||{},fg=p.fgts_access||{},layers=p.layers||[],mg=q.first_management_point_date,uncovered=q.first_uncovered_gap_date,covered=!!q.fgts_covers_horizon;
    const headline=covered&&mg?`Sua liquidez cobre o horizonte. Janeiro é um ponto de gestão.`:uncovered?`Há um gap ainda não coberto em ${w.fmt(uncovered)}.`:'Sua liquidez cobre o horizonte atual.';
    const status=covered?'coberto com ação no prazo':'revisão necessária';
    const rows=(p.management_episodes||[]).map((e,i)=>`<div class="pb142-row"><div><b>${i+1}º intervalo de gestão · ${w.fmt(e.start_date)} → ${w.fmt(e.end_date)}</b><span>saldo mínimo antes da contingência ${w.brl(e.worst_balance)} · recuperação ${e.recovery_date?w.fmt(e.recovery_date):'fora do horizonte'}</span></div><strong>${w.brl(Math.abs(Number(e.worst_balance||0)))}</strong></div>`).join('');
    const rsu=p.position_bridge?.rsu||{},fh=p.position_bridge?.fgts||{};
    return `<div class="pb142-page"><div class="pb142-head"><div><span class="pb142-eye">Planejamento · liquidez</span><h1>${headline}</h1><p>Caixa, Cofrinho, RSUs e FGTS estão separados por prazo real de acesso. FGTS continua restrito e só entra como contingência D+30 quando a solicitação cabe antes do ponto de gestão.</p></div><span class="pb142-status">${status}</span></div>
      <div class="pb142-hero"><div class="pb142-main"><span>Primeiro ponto de gestão</span><strong>${mg?w.fmt(mg):'Nenhum'}</strong><small>${mg?'é quando as camadas livres + vestings programados cruzam zero; não é falta patrimonial automática':'sem cruzamento no horizonte atual'}</small></div><div class="pb142-kpi"><span>Solicitar FGTS até</span><b>${q.fgts_request_by?w.fmt(q.fgts_request_by):'—'}</b><small>D+30 antes do primeiro ponto de gestão</small></div><div class="pb142-kpi"><span>FGTS conservador no pedido</span><b>${w.brl(q.fgts_coverage_amount_brl)}</b><small>não conta contribuições posteriores à data do pedido</small></div><div class="pb142-kpi"><span>Pior saldo após ação</span><b>${w.brl(q.worst_balance_after_planned_fgts_brl)}</b><small>${uncovered?'ainda existe gap residual':'permanece positivo no horizonte'}</small></div></div>
      <div class="pb142-panel"><div class="pb142-panelhead"><div><span>Escada de recursos</span><h3>Qual camada entra, e quando</h3></div><small>ordem econômica preservada</small></div><div class="pb142-story">${layers.map(x=>fmtLayer(w,x)).join('')}</div></div>
      <div class="pb142-grid"><div class="pb142-callout ${covered?'ok':''}"><b>${covered?'Não há falta real de recursos no horizonte atual.':'Existe uma insuficiência ainda não coberta.'}</b><span>${covered?`O pior ponto antes do FGTS é ${w.brl(q.worst_balance_before_fgts_brl)}. Usando apenas ${w.brl(fg.projected_balance_at_request_brl)} projetados para já existir em ${w.fmt(fg.request_by_date)}, a posição mínima passa para ${w.brl(q.worst_balance_after_planned_fgts_brl)}.`:`O primeiro gap não coberto aparece em ${w.fmt(uncovered)} e exige uma decisão financeira real antes de alterar o modelo.`}</span></div><div class="pb142-panel"><div class="pb142-panelhead"><div><span>Agenda</span><h3>O que merece atenção</h3></div></div>${rows||'<div class="pb142-row"><div><b>Sem intervalo negativo antes da contingência</b><span>nenhuma ação extraordinária identificada</span></div><strong>OK</strong></div>'}</div></div>
      <details class="pb142-fold"><summary>Por que esta leitura mudou em relação à tela anterior</summary><div class="pb142-body">A tela anterior testava o FGTS usando somente a posição documentada de ${w.brl(fg.current_documented_amount_brl)}, apesar de o próprio motor já projetar os créditos mensais. A leitura reconciliada usa, de forma mais conservadora, apenas o saldo projetado que já existe na data-limite do pedido: ${w.brl(fg.projected_balance_at_request_brl)}. O saldo projetado no próprio ponto de gestão seria ${w.brl(fg.projected_balance_at_management_point_brl)}, mas esse valor maior não é necessário para provar cobertura.</div></details>
      <details class="pb142-fold"><summary>Ponte documental de RSU e FGTS</summary><div class="pb142-body">RSU: a posição atual é ${w.num(rsu.current_units)} ações / ${w.brl(rsu.current_value_brl)}; há realização documentada de ${w.brl(rsu.sale_cash_2026_08_05_brl)} em 05/08 e a trilha histórica registra baixa de 283 unidades. FGTS: houve saque histórico de ${w.brl(fh.withdrawal_2026_05_07_brl)} em 07/05, seguido no mesmo dia por ${w.brl(fh.same_day_investment_2026_05_07_brl)} em investimentos Itaú. Esse saque histórico e o saldo FGTS atual são posições de datas diferentes e não devem ser comparados como um saldo estático.</div></details>
    </div>`
  }
  function load(w){
    const s=w.__LTS_V142_PLAN_BRIDGE||(w.__LTS_V142_PLAN_BRIDGE={loading:false,data:null,error:null});
    if(s.loading||s.data)return;
    if(!w.S||typeof w.S.rpc!=='function')return;
    s.loading=true;s.error=null;
    if(w.V==='Planejamento')try{w.render()}catch(e){}
    w.S.rpc('lts_browser_planning_bridge_executive_v1').then(({data,error})=>{
      if(error||!data)throw Error(error?.message||'Não foi possível carregar Planejamento');
      s.data=data;
    }).catch(e=>{s.error=String(e?.message||e)}).finally(()=>{s.loading=false;if(w.V==='Planejamento')try{w.render()}catch(e){}})
  }
  function install(){
    const c=chain();if(!c)return;const {w,d}=c;if(!w||!d||typeof w.render!=='function')return;
    installCss(d);
    w.LTS_V142_PLANNING_BRIDGE='fgts-d30-projected-conservative-v1';
    if(!w.__LTS_V142_PLAN_BRIDGE)w.__LTS_V142_PLAN_BRIDGE={loading:false,data:null,error:null};
    w.planejamento=function u142PlanningBridgeRenderer(){load(w);return render(w)};
    wired=w;
    try{if(w.V==='Planejamento'){load(w);w.render()}}catch(e){}
  }
  function tick(){const c=chain();if(c&&c.w!==wired)install();else if(c&&c.w){try{if(c.w.V==='Planejamento'&&!c.w.__LTS_V142_PLAN_BRIDGE?.data&&!c.w.__LTS_V142_PLAN_BRIDGE?.loading)load(c.w)}catch(e){}}}
  if(outer)outer.addEventListener('load',()=>{setTimeout(install,450);setTimeout(install,1400)});
  setInterval(tick,1200);
  setTimeout(install,900);
})();
