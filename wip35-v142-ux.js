(function(){
  const outer=document.getElementById('shell');
  const outerBadge=document.getElementById('badge');
  let wired=null;

  function chain(){
    try{
      const d141=outer&&outer.contentDocument,f140=d141&&d141.getElementById('shell');
      const d140=f140&&f140.contentDocument,f139=d140&&d140.getElementById('shell');
      const d139=f139&&f139.contentDocument,f138=d139&&d139.getElementById('shell');
      const d138=f138&&f138.contentDocument,f137=d138&&d138.getElementById('shell');
      const d137=f137&&f137.contentDocument,app=d137&&d137.getElementById('app');
      if(!app)return null;
      return {w:app.contentWindow,d:app.contentDocument,docs:[d141,d140,d139,d138,d137]};
    }catch(e){return null}
  }

  function hideBadges(docs){
    (docs||[]).forEach(d=>{try{['badge','candidateBadge'].forEach(id=>{const x=d&&d.getElementById(id);if(x)x.style.display='none'})}catch(e){}})
  }

  function claimOwnership(w,d){
    w.LTS_CANDIDATE_UX='v142-quick-planning-wealth-density-recovery-v2';
    if(!w.__lts_v142_version_guard){
      try{
        Object.defineProperty(w,'__LTS_TOP_CANDIDATE_VERSION',{
          configurable:true,
          enumerable:true,
          get(){return 'v142'},
          set(v){return v}
        });
        w.__lts_v142_version_guard=true;
      }catch(e){w.__LTS_TOP_CANDIDATE_VERSION='v142'}
    }
    try{if(w.__LTS_TOP_CANDIDATE_VERSION!=='v142')w.__LTS_TOP_CANDIDATE_VERSION='v142'}catch(e){}
    const applyLabel=()=>{
      try{
        const label=d.querySelector('.brand small');
        const txt='WIP35-v142 · validação interna';
        if(label&&label.textContent!==txt)label.textContent=txt;
      }catch(e){}
    };
    applyLabel();
    if(!w.__lts_v142_brand_observer){
      try{
        const label=d.querySelector('.brand small');
        if(label){
          const mo=new MutationObserver(applyLabel);mo.observe(label,{childList:true,characterData:true,subtree:true});
          w.__lts_v142_brand_observer=mo;
        }
      }catch(e){}
    }
    if(outerBadge)outerBadge.textContent='CANDIDATA v142 · validação interna';
  }

  function ensureCss(d){
    if(d.getElementById('wip35-v142-ux-css'))return;
    const s=d.createElement('style');s.id='wip35-v142-ux-css';s.textContent=`
      .u142-quick{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:9px;align-items:center;background:linear-gradient(135deg,#17304d,#214d77);color:#fff;border-radius:16px;padding:13px 14px;margin:0 0 12px;box-shadow:0 7px 22px rgba(20,42,70,.10)}
      .u142-quickcopy span,.u142-eye{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.08em;font-weight:900;color:#b79259}.u142-quickcopy b{display:block;font-size:15px;margin:3px 0}.u142-quickcopy small{display:block;font-size:9px;line-height:1.35;color:rgba(255,255,255,.7)}
      .u142-quickform{display:grid;grid-template-columns:minmax(300px,520px) auto;gap:7px;align-items:center}.u142-quickform input{width:100%;min-width:0;border:1px solid rgba(255,255,255,.18);background:#fff;color:#17304d;border-radius:10px;padding:10px 11px;font-size:12px;box-sizing:border-box}.u142-quickform button{border:0;border-radius:10px;background:#b8935a;color:#fff;padding:10px 12px;font-weight:850;white-space:nowrap}.u142-quickmsg{grid-column:1/-1;font-size:8px;color:rgba(255,255,255,.76);min-height:10px}
      .u132-classintro{display:none!important}.u131-batch{position:static!important;margin:6px 0!important;padding:7px!important}.fx89-review{padding:10px!important}.u141-mainthead{margin-top:10px!important}.u141-docout{margin:7px 0!important}.u141-docrows{display:none!important}
      .u132-classrow{display:grid!important;grid-template-columns:minmax(0,1fr) 270px!important;gap:10px!important;padding:10px!important;margin-top:7px!important;min-height:0!important}.u132-facts{grid-template-columns:1fr 1fr!important;gap:5px!important}.u132-facts>div{padding:6px 7px!important}.u132-facts>div:nth-child(2),.u132-facts>div:nth-child(3){display:none!important}.u132-facts p{font-size:9px!important;line-height:1.3!important}.u132-actions{display:grid!important;grid-template-columns:1fr!important;gap:5px!important}.u132-actions select.cardcat{height:36px!important;font-size:11px!important}.u132-actions .chip{min-height:34px!important;padding:6px 8px!important}.u133-save-msg{font-size:8px!important}
      .ex134-page{gap:10px!important}.ex134-head h1{font-size:25px!important}.ex134-kpis{gap:7px!important}.ex134-kpi{padding:10px!important}.ex134-kpi b{font-size:17px!important}.ex134-panel{padding:12px!important}.ex134-three{gap:8px!important}
      .u142-page{display:flex;flex-direction:column;gap:10px}.u142-head{display:flex;align-items:flex-end;justify-content:space-between;gap:14px}.u142-head h1{font-size:25px;line-height:1.05;margin:4px 0 5px;letter-spacing:-.035em}.u142-head p{margin:0;max-width:760px;font-size:10px;color:var(--mut);line-height:1.42}.u142-asof{font-size:9px;color:var(--mut);text-align:right;white-space:nowrap}
      .u142-hero{display:grid;grid-template-columns:1.35fr repeat(3,.72fr);gap:8px}.u142-main,.u142-kpi{border:1px solid var(--bd);border-radius:15px;padding:13px;background:#fff}.u142-main{background:linear-gradient(135deg,#17304d,#214d77);color:#fff}.u142-main span,.u142-kpi span{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.05em;font-weight:850;opacity:.72}.u142-main strong{display:block;font-size:28px;margin:5px 0}.u142-main small{display:block;font-size:8px;line-height:1.35;opacity:.74}.u142-kpi b{display:block;font-size:17px;margin:5px 0}.u142-kpi small{display:block;font-size:8px;line-height:1.35;color:var(--mut)}
      .u142-panel,.u142-asset{background:#fff;border:1px solid var(--bd);border-radius:16px;padding:13px}.u142-panelhead{display:flex;align-items:flex-end;justify-content:space-between;gap:10px;margin-bottom:8px}.u142-panelhead h3{font-size:14px;margin:3px 0 0}.u142-panelhead span,.u142-panelhead b{font-size:8px;color:var(--mut)}
      .u142-story{display:grid;grid-template-columns:repeat(5,1fr);gap:7px}.u142-step{position:relative;background:#fafbfd;border:1px solid #e5eaf0;border-radius:11px;padding:9px;min-height:82px}.u142-step em{font-style:normal;font-size:8px;font-weight:900;color:#8b6a39}.u142-step b{display:block;font-size:13px;margin:5px 0}.u142-step span{display:block;font-size:8px;color:var(--mut);line-height:1.3}.u142-step.warn{background:#fffaf0;border-color:#ead7b4}
      .u142-decision{display:grid;grid-template-columns:1.15fr .85fr;gap:8px}.u142-callout{border-left:3px solid #b8935a;background:#fffaf2;border-radius:10px;padding:10px 11px}.u142-callout b{display:block;font-size:11px;margin-bottom:3px}.u142-callout span{display:block;font-size:9px;color:#6c5a3c;line-height:1.4}
      .u142-minirow{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;padding:7px 0;border-top:1px solid #edf0f4}.u142-minirow:first-child{border-top:0}.u142-minirow b{font-size:9px}.u142-minirow span{display:block;font-size:8px;color:var(--mut);margin-top:2px}.u142-minirow strong{font-size:9px;white-space:nowrap}.u142-actions{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}.u142-actions button{border:1px solid var(--bd);background:#fff;border-radius:999px;padding:7px 10px;font-size:9px;font-weight:800;color:var(--ink)}
      .u142-assets{display:grid;grid-template-columns:1.3fr .7fr;gap:8px}.u142-assettop{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}.u142-assettop h3{font-size:15px;margin:3px 0}.u142-tag{font-size:8px;background:#eef2f6;color:#5a6878;border-radius:999px;padding:5px 7px;white-space:nowrap}.u142-facts{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:9px}.u142-facts div{background:#fafbfd;border:1px solid #e7ebef;border-radius:9px;padding:8px}.u142-facts span{display:block;font-size:7px;color:var(--mut);text-transform:uppercase;font-weight:850}.u142-facts b{display:block;font-size:13px;margin:4px 0}.u142-facts small{display:block;font-size:7px;color:var(--mut);line-height:1.3}.u142-footnote{font-size:8px;color:var(--mut);line-height:1.4;margin-top:8px}.u142-fold{background:#f8fafc;border:1px solid var(--bd);border-radius:12px;padding:0 10px}.u142-fold summary{padding:9px 0;cursor:pointer;font-size:9px;font-weight:850}.u142-audit{display:inline-flex;align-items:center;gap:5px;padding:5px 8px;border-radius:999px;background:#fff3dc;color:#7a5d2d;font-size:8px;font-weight:900}
      @media(max-width:1250px){.u142-quick{grid-template-columns:1fr}.u142-quickform{grid-template-columns:minmax(0,1fr) auto}.u132-classrow{grid-template-columns:1fr!important}.u132-actions{grid-template-columns:minmax(0,1fr) auto auto!important}.u142-hero{grid-template-columns:1fr 1fr}.u142-main{grid-column:1/-1}.u142-assets{grid-template-columns:1fr}.u142-story{grid-template-columns:repeat(3,1fr)}}
      @media(max-width:820px){.u142-quickform{grid-template-columns:1fr}.u142-quickform button{width:100%}.u132-actions{grid-template-columns:1fr!important}.u132-facts{grid-template-columns:1fr!important}.u142-head{align-items:flex-start;flex-direction:column}.u142-asof{text-align:left}.u142-hero,.u142-story,.u142-decision,.u142-facts{grid-template-columns:1fr}.u142-main{grid-column:auto}.u142-assets{grid-template-columns:1fr}.u142-assettop{flex-direction:column}.ex134-kpis{grid-template-columns:1fr 1fr!important}.ex134-grid,.ex134-three{grid-template-columns:1fr!important}}
      @media(max-width:480px){.ex134-kpis{grid-template-columns:1fr!important}}
    `;d.head.appendChild(s)
  }

  function quickHtml(){
    return `<div class="u142-quick"><div class="u142-quickcopy"><span>Lançamento rápido</span><b>Escreva como você fala.</b><small>Despesa ou receita vai para revisão antes de gravar. Resgate/aplicação é movimentação de liquidez e nunca será tratado como renda ou gasto.</small></div><div class="u142-quickform"><input id="u142Phrase" placeholder="Ex.: paguei 850 de pediatra hoje no Itaú"><button type="button" onclick="u142QuickInterpret()">Interpretar</button><div id="u142QuickMsg" class="u142-quickmsg"></div></div></div>`
  }

  function ensureQuick(w){
    if(!w.__lts_v142_updates_base)w.__lts_v142_updates_base=w.atualizacoes;
    if(!w.__lts_v142_updates_fn){
      w.__lts_v142_updates_fn=function u142UpdatesRenderer(){
        const base=w.__lts_v142_updates_base;
        return quickHtml()+(typeof base==='function'?base():'');
      };
    }
    if(w.atualizacoes!==w.__lts_v142_updates_fn)w.atualizacoes=w.__lts_v142_updates_fn;
    if(typeof w.u142QuickInterpret!=='function'){
      w.u142QuickInterpret=function(){
        const d=w.document,inp=d.getElementById('u142Phrase'),msg=d.getElementById('u142QuickMsg'),text=String(inp?.value||'').trim();if(!text)return;
        const n=text.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
        if(/\bresgat|\baplic/.test(n)){
          if(msg)msg.textContent='Movimentação de liquidez reconhecida. Ela não foi gravada como receita/despesa; o writer banco ↔ ativo segue protegido até fechar a validação de paridade.';
          return;
        }
        w.V='Entradas';w.renderNav();w.render();
        setTimeout(()=>{const p=d.getElementById('phrase'),b=d.getElementById('pbtn');if(p){p.value=text;b?.click()}},40)
      }
    }
  }

  function planningRenderer(w){
    return function u142PlanningAuditRenderer(){
      const l=w.D?.planning_ladder||{},layers=l.layers||[],eps=l.gap_episodes||[],fg=l.fgts_access||{},point=l.first_real_gap_date,first=eps[0]||{},fmt=w.fmt,brl=w.brl,esc=w.esc,num=w.num;
      const cash=layers.find(x=>x.id==='cash')||{},d01=layers.find(x=>x.id==='d01')||{},vest=layers.find(x=>x.id==='rsu_vested')||{},future=layers.find(x=>x.id==='future_vestings')||{};
      const now=num(cash.starting_amount)+num(d01.starting_amount)+num(vest.starting_amount);
      const story=[
        ['1 · Conta corrente',brl(cash.starting_amount),cash.first_need_next_layer?`primeiro uso de outra camada em ${fmt(cash.first_need_next_layer)}`:'sem necessidade adicional'],
        ['2 · + Cofrinho',brl(d01.starting_amount),d01.first_need_next_layer?`próxima camada em ${fmt(d01.first_need_next_layer)}`:'não exigido'],
        ['3 · + RSU vested',brl(vest.starting_amount),vest.first_need_next_layer?`próxima camada em ${fmt(vest.first_need_next_layer)}`:'não exigido'],
        ['4 · Novos vestings','Condicional',future.first_need_next_layer?`motor cruza zero em ${fmt(future.first_need_next_layer)}`:'cobre o horizonte'],
        ['5 · FGTS',brl(fg.amount_brl),fg.request_by_date?`referência do motor: ${fmt(fg.request_by_date)}`:'contingência ~D+30']
      ];
      return `<div class="u142-page"><div class="u142-head"><div><span class="u142-eye">Planejamento de liquidez</span><h1>${point?`O motor cruza zero em ${fmt(point)} — ponto em auditoria.`:'O motor não cruza zero no horizonte atual.'}</h1><p>Primeiro separamos caixa disponível, recursos já realizáveis, vestings futuros e FGTS. A ponte com o Excel antigo ainda está sendo fechada antes de chamar qualquer negativo de falta real de dinheiro.</p></div><div><span class="u142-audit">ponte Excel → motor em auditoria</span><div class="u142-asof" style="margin-top:5px">${fmt(l.from)} → ${fmt(l.to)}</div></div></div>
      <div class="u142-hero"><div class="u142-main"><span>Liquidez realizável hoje</span><strong>${brl(now)}</strong><small>Conta corrente + Cofrinho + RSU já vested. Não inclui novos vestings nem FGTS.</small></div><div class="u142-kpi"><span>Ponto do motor</span><b>${point?fmt(point):'Nenhum'}</b><small>não tratado como falta real até a ponte fechar</small></div><div class="u142-kpi"><span>Pior saldo do motor</span><b class="${num(first.worst_balance)<0?'neg':''}">${first.worst_balance!=null?brl(first.worst_balance):'—'}</b><small>${first.recovery_date?`recupera em ${fmt(first.recovery_date)}`:'sem episódio negativo'}</small></div><div class="u142-kpi"><span>FGTS</span><b>${brl(fg.amount_brl)}</b><small>contingência ~D+30; não é caixa automático</small></div></div>
      <div class="u142-panel"><div class="u142-panelhead"><div><span>De onde vem o dinheiro</span><h3>Camadas na ordem em que entram na gestão de liquidez</h3></div></div><div class="u142-story">${story.map((x,i)=>`<div class="u142-step ${i===4?'warn':''}"><em>${esc(x[0])}</em><b>${esc(x[1])}</b><span>${esc(x[2])}</span></div>`).join('')}</div></div>
      <div class="u142-decision"><div class="u142-callout"><b>O que já sabemos</b><span>${point?`No motor atual, depois dos vestings programados, o saldo cruza zero em ${fmt(point)} e o primeiro pior ponto calculado é ${brl(first.worst_balance)}. Isso é um resultado do modelo, não uma conclusão patrimonial validada.`:'O motor atual não mostra cruzamento negativo neste horizonte.'}</span></div><div class="u142-callout"><b>O que ainda está sendo conciliado</b><span>O Excel já ficava negativo sem RSUs. A diferença agora está concentrada na ponte de posição inicial, RSU já vested, FGTS e mudanças factuais posteriores; cartões e Benjamin explicam parte material da piora de setembro.</span></div></div>
      ${eps.length?`<details class="u142-fold"><summary>Ver episódios negativos calculados pelo motor</summary>${eps.map(e=>`<div class="u142-minirow"><div><b>${fmt(e.start_date)} → ${fmt(e.end_date)}</b><span>${e.days} dia(s) · recuperação em ${fmt(e.recovery_date)}</span></div><strong class="neg">${brl(e.worst_balance)}</strong></div>`).join('')}<div class="u142-actions"><button class="dashact" data-dashdest="Fluxo Diário">Abrir trajetória diária</button></div></details>`:''}</div>`
    }
  }

  function ensurePlanning(w){
    if(!w.__lts_v142_planning_fn)w.__lts_v142_planning_fn=planningRenderer(w);
    if(w.planejamento!==w.__lts_v142_planning_fn)w.planejamento=w.__lts_v142_planning_fn;
  }

  async function loadWealthExecutive(w){
    if(!w.D||!w.S||typeof w.S.rpc!=='function')return;
    const st=w.__lts_v142_wealth_state||(w.__lts_v142_wealth_state={loading:false,loaded:false,data:null,error:null});
    if(st.loading||st.loaded)return;
    st.loading=true;
    try{
      const {data,error}=await w.S.rpc('lts_browser_wealth_executive_v2');
      if(error||!data)throw Error(error?.message||'wealth executive unavailable');
      st.data=data;st.loaded=true;st.error=null;
    }catch(e){st.error=String(e?.message||e)}finally{
      st.loading=false;
      try{if(w.V==='Patrimônio'&&w.D)w.render()}catch(e){}
    }
  }

  function wealthRenderer(w){
    return function u142WealthExecutiveRenderer(){
      const st=w.__lts_v142_wealth_state||{},R=st.data||{},s=R.summary||{},liq=R.liquidity||{},assets=R.assets||{},c=assets.cipo_396||{},v=assets.volvo_xc40||{},brl=w.brl,fmt=w.fmt,num=w.num;
      if(!st.loaded){
        const W=w.D?.wealth||{},vals=W.market_valuations||{},cv=vals.cipo_396||{},vv=vals.volvo_xc40||{},docs=w.D?.documentary_commitments?.items||[],ci=docs.find(x=>x.commitment_id==='cipo_396')||{},accs=W.accounts||[],sn=W.asset_layers?.documentary_snapshots||[],sum=w.sum;
        const bank=sum(accs.map(x=>x.balance)),d0=sum(sn.filter(x=>x.liquidity_class==='D+0').map(x=>x.value_brl)),d3=sum(sn.filter(x=>x.liquidity_class==='D+3').map(x=>x.value_brl)),fg=sum(sn.filter(x=>x.liquidity_class==='restricted').map(x=>x.value_brl));
        const cVal=num(cv.central_value_brl),cDebt=num(ci.debt_balance||W.cipo_396?.mortgage?.current_debt_balance),vVal=num(vv.central_value_brl),vDebt=num(vv.metadata?.documented_total_financed_brl),nw=(bank+d0+d3+fg+cVal+vVal)-(cDebt+vDebt);
        return `<div class="u142-page"><div class="u142-head"><div><span class="u142-eye">Patrimônio</span><h1>Quanto você tem, quanto deve e quanto é seu.</h1><p>Carregando a leitura executiva certificada. Enquanto isso, a tela usa apenas posições já presentes no payload atual — sem inventar saldos.</p></div><span class="u142-audit">posição executiva carregando</span></div><div class="u142-hero"><div class="u142-main"><span>Patrimônio líquido estimado</span><strong>${brl(nw)}</strong><small>visão provisória até o read model executivo autenticado carregar</small></div><div class="u142-kpi"><span>Liquidez até D+3</span><b>${brl(bank+d0+d3)}</b><small>caixa + Cofrinho + RSU vested</small></div><div class="u142-kpi"><span>Imóvel</span><b>${brl(cVal)}</b><small>dívida documental ${brl(cDebt)}</small></div><div class="u142-kpi"><span>Volvo</span><b>${brl(vVal)}</b><small>dívida conhecida ${brl(vDebt)}</small></div></div></div>`
      }
      const nw=num(s.net_worth_central),debt=num(s.known_debt_total),assetsCentral=num(s.assets_central),through=num(s.liquidity_through_d3),fg=num(s.restricted_contingency),future=num(s.future_awards_excluded);
      return `<div class="u142-page"><div class="u142-head"><div><span class="u142-eye">Patrimônio</span><h1>Quanto você tem, quanto deve e quanto é seu.</h1><p>A primeira leitura mostra patrimônio líquido, liquidez e equity. Estimativas de mercado não são preço garantido de venda; compromissos futuros sem saldo devedor certificado ficam fora da dívida atual.</p></div><div class="u142-asof">posição ${fmt(R.as_of)}</div></div>
      <div class="u142-hero"><div class="u142-main"><span>Patrimônio líquido estimado</span><strong>${brl(nw)}</strong><small>Ativos ${brl(assetsCentral)} − dívidas atuais conhecidas ${brl(debt)}. Faixa estimada: ${brl(s.net_worth_low)} → ${brl(s.net_worth_high)}.</small></div><div class="u142-kpi"><span>Liquidez até D+3</span><b>${brl(through)}</b><small>caixa ${brl(liq.bank_cash)} + Cofrinho ${brl(liq.d0)} + RSU vested ${brl(liq.d3)}</small></div><div class="u142-kpi"><span>FGTS</span><b>${brl(fg)}</b><small>contingência restrita; separado da liquidez imediata</small></div><div class="u142-kpi"><span>Awards futuros</span><b>${brl(future)}</b><small>fora do patrimônio adquirido até vesting/settlement</small></div></div>
      <div class="u142-assets"><div class="u142-asset"><div class="u142-assettop"><div><span class="u142-eye">CIPÓ 396</span><h3>Cobertura duplex · O Parque</h3></div><span class="u142-tag">175 m² · 4 vagas · jacuzzi</span></div><div class="u142-facts"><div><span>Valor estimado</span><b>${brl(c.market_central)}</b><small>${brl(c.market_low)} → ${brl(c.market_high)}</small></div><div><span>Dívida documental</span><b>${brl(c.documentary_debt)}</b><small>não inferida por soma de parcelas</small></div><div><span>Equity estimado</span><b>${brl(c.equity_central)}</b><small>${brl(c.equity_low)} → ${brl(c.equity_high)}</small></div></div><div class="u142-footnote">Compra + reforma histórica: ${brl(c.historical_purchase_plus_reform)}. Melhorias históricas: ${brl(c.historical_improvements)}. O preço pedido do próprio ativo não é usado como comparável independente.</div></div>
      <div class="u142-asset"><div class="u142-assettop"><div><span class="u142-eye">Veículo</span><h3>Volvo XC40 · 2019/2020</h3></div><span class="u142-tag">blindado Avalon</span></div><div class="u142-facts"><div><span>Valor estimado</span><b>${brl(v.market_central)}</b><small>${brl(v.market_low)} → ${brl(v.market_high)}</small></div><div><span>Dívida financiada</span><b>${brl(v.documented_financed_balance)}</b><small>posição documental disponível</small></div><div><span>Equity estimado</span><b>${brl(v.equity_central)}</b><small>${brl(v.equity_low)} → ${brl(v.equity_high)}</small></div></div><div class="u142-footnote">Faixa provisória: versão/trim ainda não documentada e quilometragem ausente. O cronograma futuro do financiamento não é contado como dívida atual adicional.</div></div></div>
      <details class="u142-fold"><summary>Ver regras de confiança e detalhes</summary><div class="u142-minirow"><div><b>Estimativas de mercado</b><span>não são preço garantido de venda</span></div><strong>guardrail</strong></div><div class="u142-minirow"><div><b>Awards futuros</b><span>só entram depois de vesting/settlement</span></div><strong>${brl(future)}</strong></div><div class="u142-minirow"><div><b>FGTS</b><span>permanece contingência separada</span></div><strong>${brl(fg)}</strong></div></details></div>`
    }
  }

  function ensureWealth(w){
    if(!w.__lts_v142_wealth_fn)w.__lts_v142_wealth_fn=wealthRenderer(w);
    if(w.patrimonio!==w.__lts_v142_wealth_fn)w.patrimonio=w.__lts_v142_wealth_fn;
    loadWealthExecutive(w);
  }

  function install(){
    const z=chain();if(!z||!z.w)return;
    hideBadges(z.docs);
    const w=z.w,d=z.d;
    if(w.__LTS_LEXICAL_BRIDGE!=='v140')return;
    claimOwnership(w,d);ensureCss(d);ensureQuick(w);ensurePlanning(w);ensureWealth(w);
    if(wired!==w){
      wired=w;
      setTimeout(()=>{try{if(w.D&&['Atualizações','Planejamento','Patrimônio','Despesas'].includes(w.V))w.render()}catch(e){}},800);
    }
  }

  if(outer)outer.addEventListener('load',()=>setTimeout(install,160));
  setInterval(install,60);
})();
