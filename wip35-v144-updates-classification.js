(function(){
  const outer=document.getElementById('shell');
  const MARK='updates-classification-confidence-layout-v1';
  let installedWindow=null;
  const n=x=>Number(x||0)||0;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  function deep(){
    try{
      let d=document,w=window,f=outer;
      for(let i=0;i<12;i++){
        if(!f)return null;
        d=f.contentDocument;w=f.contentWindow;
        if(!d||!w)return null;
        const app=d.getElementById('app');
        if(app&&app.contentWindow&&app.contentDocument)return {w:app.contentWindow,d:app.contentDocument};
        f=d.getElementById('shell');
      }
    }catch(e){}
    return null;
  }

  function addCss(d){
    if(d.getElementById('wip35-v144-updates-css'))return;
    const s=d.createElement('style');
    s.id='wip35-v144-updates-css';
    s.textContent=`
      #v143FeedbackUpdates.v144-legacy-suppressed{display:none!important}
      .v144u{display:flex;flex-direction:column;gap:12px;max-width:1180px;margin:0 auto}
      .v144u-head{display:flex;justify-content:space-between;align-items:flex-end;gap:18px;padding:2px 0 2px}
      .v144u-head .eye{display:block;font-size:9px;text-transform:uppercase;letter-spacing:.08em;font-weight:900;color:#98713a}
      .v144u-head h1{font-size:28px;line-height:1.08;letter-spacing:-.035em;margin:4px 0 5px}
      .v144u-head p{margin:0;color:var(--mut);font-size:11px;line-height:1.45;max-width:720px}
      .v144u-asof{flex:0 0 auto;background:#fff;border:1px solid var(--bd);border-radius:13px;padding:9px 12px;text-align:right;box-shadow:0 5px 18px rgba(20,42,70,.04)}
      .v144u-asof span{display:block;font-size:8px;text-transform:uppercase;font-weight:900;color:var(--mut)}
      .v144u-asof b{display:block;font-size:13px;margin-top:3px}
      .v144u-summary{display:grid;grid-template-columns:1.15fr .85fr .85fr;gap:8px}
      .v144u-sum{border:1px solid var(--bd);background:#fff;border-radius:14px;padding:12px;text-align:left;color:inherit;cursor:pointer;display:grid;grid-template-columns:1fr auto;gap:8px;align-items:center}
      .v144u-sum.primary{border-color:#d7c39e;background:#fffaf1}
      .v144u-sum span{display:block;font-size:8px;text-transform:uppercase;font-weight:900;color:var(--mut)}
      .v144u-sum b{display:block;font-size:13px;margin-top:3px}.v144u-sum strong{font-size:22px}.v144u-sum small{display:block;color:var(--mut);font-size:8px;margin-top:3px;line-height:1.35}
      .v144u-section{background:#fff;border:1px solid var(--bd);border-radius:17px;padding:14px;box-shadow:0 7px 24px rgba(20,42,70,.045)}
      .v144u-section.primary{border-color:#d8c7a6}
      .v144u-sec-head{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;margin-bottom:10px}
      .v144u-sec-head .eye{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.07em;font-weight:900;color:#98713a}
      .v144u-sec-head h2{font-size:19px;margin:3px 0 3px}.v144u-sec-head p{margin:0;font-size:9px;color:var(--mut);line-height:1.45;max-width:760px}
      .v144u-count{background:#eef2f6;border-radius:999px;padding:7px 10px;font-size:10px;font-weight:900;white-space:nowrap}
      .v144u-method{display:flex;gap:5px;flex-wrap:wrap;margin:2px 0 11px}.v144u-method span{font-size:8px;font-weight:850;padding:5px 7px;border-radius:999px;background:#f2f5f8;color:#667384}.v144u-method i{font-style:normal;color:#a2acb7;align-self:center}
      .v144u-batch{display:flex;align-items:center;justify-content:space-between;gap:10px;border:1px solid #e2e7ec;border-radius:11px;padding:8px 10px;background:#fafbfd;margin-bottom:8px}.v144u-batch .mut{font-size:8px;line-height:1.4}.v144u-batch .btn{font-size:9px;padding:7px 10px;white-space:nowrap}
      .v144u-classlist{display:flex;flex-direction:column;gap:7px}
      .v144u-class.cardclass-row{display:grid;grid-template-columns:minmax(0,1fr) 210px;gap:13px;border:1px solid #e3e8ed;border-radius:13px;padding:12px;background:#fff;align-items:stretch}
      .v144u-class.safe121-suggested{border-color:#cfe1d7;background:#fbfefc}
      .v144u-class-main{min-width:0}.v144u-class-top{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.v144u-class-top b{font-size:12px}.v144u-class-top small{display:block;font-size:8px;color:var(--mut);margin-top:2px;line-height:1.4}.v144u-amount{font-size:12px;font-weight:900;white-space:nowrap}
      .v144u-reco{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:9px;align-items:center;background:#f5f8fa;border:1px solid #e4e9ee;border-radius:10px;padding:9px 10px;margin-top:8px}.v144u-reco.has{background:#f5faf7;border-color:#d7e6dd}.v144u-reco span{display:block;font-size:7px;text-transform:uppercase;font-weight:900;color:var(--mut)}.v144u-reco b{display:block;font-size:12px;margin-top:2px}.v144u-conf{display:flex;gap:5px;flex-wrap:wrap;justify-content:flex-end}.v144u-conf i{font-style:normal;font-size:8px;font-weight:900;border-radius:999px;padding:5px 7px;background:#eef2f6;color:#526273;white-space:nowrap}.v144u-conf i.high{background:#eaf6f0;color:#2f6a50}.v144u-conf i.medium{background:#fff5df;color:#896221}
      .v144u-facts{display:grid;grid-template-columns:1.25fr .9fr .9fr;gap:6px;margin-top:7px}.v144u-fact{background:#fafbfd;border-radius:9px;padding:8px}.v144u-fact span{display:block;font-size:7px;text-transform:uppercase;font-weight:900;color:var(--mut)}.v144u-fact p{font-size:8px;line-height:1.42;margin:3px 0 0;color:#405269}
      .v144u-tags{display:flex;gap:5px;flex-wrap:wrap;margin-top:7px}.v144u-tags i{font-style:normal;font-size:7px;border:1px solid #dfe5eb;border-radius:999px;padding:4px 6px;color:#667384;background:#fff}.v144u-tags i.warn{border-color:#e0cda7;background:#fff9ed;color:#7b5a27}
      .v144u-actions{border-left:1px solid #edf0f4;padding-left:12px;display:flex;flex-direction:column;gap:7px;justify-content:center}.v144u-actions label{font-size:8px;text-transform:uppercase;font-weight:900;color:var(--mut)}.v144u-actions select{width:100%;min-width:0}.v144u-actions .chip{width:100%;font-size:9px;min-height:32px}.v144u-actions .cardclass-save{background:#17304d;border-color:#17304d;color:#fff}.v144u-actions .safe121-check{font-size:8px;text-transform:none;font-weight:750;color:#3d654f;display:flex;align-items:flex-start;gap:5px;line-height:1.35}
      .v144u-empty{padding:16px;text-align:center;color:var(--mut);font-size:9px;background:#fafbfd;border-radius:10px}
      .v144u-secondary{padding:0;background:#fff;border:1px solid var(--bd);border-radius:15px;overflow:hidden}.v144u-secondary>summary{cursor:pointer;list-style:none;padding:12px 14px;font-size:11px;font-weight:850;display:flex;justify-content:space-between;gap:12px;align-items:center}.v144u-secondary>summary::-webkit-details-marker{display:none}.v144u-secondary>summary span{font-size:9px;color:var(--mut);font-weight:800}.v144u-secondary-body{padding:0 13px 13px}.v144u-secondary .u130-list,.v144u-secondary .u132-maint{box-shadow:none;margin:0;border-radius:11px}.v144u-secondary .u130-classhead{margin-top:6px}.v144u-secondary .u132-tools{margin-top:0}
      .v144u-guard{font-size:8px;color:var(--mut);line-height:1.45;text-align:center;padding:4px 10px 0}
      @media(max-width:900px){.v144u{max-width:none}.v144u-summary{grid-template-columns:1fr}.v144u-class.cardclass-row{grid-template-columns:1fr}.v144u-actions{border-left:0;border-top:1px solid #edf0f4;padding:9px 0 0}.v144u-facts{grid-template-columns:1fr}.v144u-head{align-items:flex-start;flex-direction:column}.v144u-asof{text-align:left}.v144u-batch{align-items:flex-start;flex-direction:column}.v144u-conf{justify-content:flex-start}}
      @media(max-width:520px){.v144u-head h1{font-size:24px}.v144u-class-top{flex-direction:column}.v144u-reco{grid-template-columns:1fr}.v144u-summary{gap:6px}}
    `;
    d.head.appendChild(s);
  }

  function basis(w,x){
    try{if(typeof w.u132BasisTag==='function')return w.u132BasisTag(x)}catch(e){}
    const b=String(x?.suggestion_basis||'').toLowerCase();
    if(b.includes('histor'))return 'Histórico do LTS';
    if(x?.enrichment_attempted)return 'Pesquisa pública';
    return 'Revisão manual';
  }
  function research(w,x){
    try{if(typeof w.u132Research==='function')return w.u132Research(x)}catch(e){}
    return x?.enrichment_evidence||'Sem evidência adicional preservada.';
  }
  function recurrence(w,x){
    try{if(typeof w.u132Recurrence==='function')return w.u132Recurrence(x)}catch(e){}
    return n(x?.occurrences)>1?`${n(x.occurrences)} ocorrências neste grupo.`:'Sem repetição suficiente.';
  }
  function need(w,q,x){
    try{if(typeof w.u132Need==='function')return w.u132Need(q,x)}catch(e){}
    return x?.suggested_category?`Confirmar ${x.suggested_category} ou escolher outra categoria.`:'Escolher a categoria correta.';
  }
  function confidencePills(x){
    const sc=n(x?.suggestion_confidence),ec=n(x?.enrichment_confidence),out=[];
    const cls=v=>v>=.9?'high':v>=.65?'medium':'';
    if(sc>0)out.push(`<i class="${cls(sc)}">${Math.round(sc*100)}% sugestão</i>`);
    if(ec>0&&(Math.abs(ec-sc)>.001||sc<=0))out.push(`<i class="${cls(ec)}">${Math.round(ec*100)}% identificação</i>`);
    if(!out.length)out.push('<i>sem % conclusivo</i>');
    return out.join('');
  }
  function cardItem(w,q,x,opts){
    const sug=String(x?.suggested_category||''),name=x?.merchant_name||x?.example_description||x?.description_key||'Lançamento';
    const safe=!!x?.suggestion_safe,source=basis(w,x),meta=[x?.example_description&&x?.merchant_name?`Original: ${x.example_description}`:'',x?.card_name||'',x?.due_date&&w.fmt?w.fmt(x.due_date):x?.due_date||'',`${n(x?.occurrences)} ocorrência(s)`].filter(Boolean).join(' · ');
    const tags=[`Fonte: ${source}`];
    if(x?.taxonomy_ambiguous)tags.push('taxonomia protegida');
    if(x?.amount_pattern_months)tags.push(`${n(x.amount_pattern_months)} mês(es) no padrão`);
    if(x?.enrichment_status==='marketplace_needs_item_context')tags.push('marketplace');
    if(x?.enrichment_status==='payment_intermediary_needs_context')tags.push('intermediador');
    return `<article class="v144u-class cardclass-row ${safe?'safe121-suggested':''}">
      <div class="v144u-class-main">
        <div class="v144u-class-top"><div><b>${esc(name)}</b><small>${esc(meta)}</small></div><div class="v144u-amount">${w.brl?w.brl(x?.total_value):esc(x?.total_value)}</div></div>
        <div class="v144u-reco ${sug?'has':''}"><div><span>${sug?'Sugestão do LTS':'Sugestão ainda não fechada'}</span><b>${sug?esc(sug):'Precisa de contexto para classificar'}</b></div><div class="v144u-conf">${confidencePills(x)}</div></div>
        <div class="v144u-facts"><div class="v144u-fact"><span>Pesquisa / evidência</span><p>${esc(research(w,x))}</p></div><div class="v144u-fact"><span>Histórico / repetição</span><p>${esc(recurrence(w,x))}</p></div><div class="v144u-fact"><span>O que falta de você</span><p>${esc(need(w,q,x))}</p></div></div>
        <div class="v144u-tags">${tags.map((t,i)=>`<i class="${i&&String(t).includes('protegida')?'warn':''}">${esc(t)}</i>`).join('')}</div>
      </div>
      <div class="v144u-actions"><label>Classificação final</label><select class="chip cardcat"><option value="">Escolher categoria…</option>${opts.map(c=>`<option value="${esc(c)}" ${sug===c?'selected':''}>${esc(c)}</option>`).join('')}</select><button type="button" class="chip newcatbtn">+ Nova categoria</button><button class="chip cardclass-save" data-key="${esc(x?.description_key||'')}">${sug?'Confirmar / salvar':'Salvar classificação'}</button>${safe&&sug?`<label class="safe121-check"><input type="checkbox" class="safe121-pick" data-key="${esc(x.description_key)}" data-category="${esc(sug)}" checked> incluir no lote seguro</label>`:''}</div>
    </article>`;
  }

  function classificationSection(w,q,sq){
    const items=(q?.items||[]).slice().sort((a,b)=>(b.suggestion_safe?1:0)-(a.suggestion_safe?1:0)||(b.suggested_category?1:0)-(a.suggested_category?1:0)||n(b.total_value)-n(a.total_value));
    const opts=(q?.category_options||[]).slice().sort((a,b)=>String(a).localeCompare(String(b),'pt-BR',{sensitivity:'base'}));
    const total=n(q?.pending_groups)+n(sq?.pending_groups),safe=n(q?.safe_suggestion_groups);
    const batch=safe?`<div class="v144u-batch"><div><b>${safe} sugestão(ões) marcada(s) como seguras</b><div class="mut">A confirmação em lote continua passando pela revalidação do backend.</div></div><button class="btn ghost safe121-submit">Confirmar selecionadas (${safe})</button></div>`:`<div class="v144u-batch"><div><b>Sem confirmação automática em lote</b><div class="mut">O LTS mostra a melhor evidência disponível, mas mantém sua decisão quando a taxonomia/contexto não fecha.</div></div></div>`;
    const cardRows=items.map(x=>cardItem(w,q,x,opts)).join('');
    let semantic='';
    try{semantic=typeof w.expenseClassificationUpdates==='function'?w.expenseClassificationUpdates():''}catch(e){}
    return `<section id="v144Classification" class="v144u-section primary"><div class="v144u-sec-head"><div><span class="eye">Classificar agora</span><h2>Sugestão + pesquisa + % de confiança, item por item</h2><p>O histórico do LTS vem primeiro. Quando ele não resolve, a pesquisa pública identifica o estabelecimento e mostra a confiança. A finalidade real da compra nunca é inventada.</p></div><span class="v144u-count">${total} pendente(s)</span></div><div class="v144u-method"><span>1 · Histórico do LTS</span><i>›</i><span>2 · Pesquisa pública</span><i>›</i><span>3 · % de confiança</span><i>›</i><span>4 · Sua confirmação quando necessário</span></div>${batch}<div id="cardClassReview" class="v144u-classlist">${cardRows||'<div class="v144u-empty">Nenhuma classificação de cartão pendente.</div>'}</div>${semantic?`<details class="v144u-secondary" style="margin-top:9px"><summary>Outras classificações de despesas <span>abrir</span></summary><div class="v144u-secondary-body">${semantic}</div></details>`:''}</section>`;
  }

  function v144Updates(w){
    return function(){
      const u=w.D?.updates||{},q=w.D?.card_classification_review||{},sq=w.D?.semantic_review||{};
      const raw=typeof w.groupUpdateItems==='function'?w.groupUpdateItems((u.items||[]).slice()):(u.items||[]).slice();
      raw.sort((a,b)=>n(a.priority)-n(b.priority)||Math.abs(n(b.impact_amount))-Math.abs(n(a.impact_amount)));
      const actions=typeof w.updateIsAction==='function'?raw.filter(w.updateIsAction):raw;
      const oper=actions.filter(x=>String(x.type||'')!=='maintenance_request'),info=typeof w.updateIsAction==='function'?raw.filter(x=>!w.updateIsAction(x)):[];
      const checks=u.maintenance_checks||[],maintOpen=checks.filter(x=>x.actionable).length,classes=n(q.pending_groups)+n(sq.pending_groups),uf=u.freshness||{},fresh=uf.position_as_of&&w.fmt?w.fmt(uf.position_as_of):'—';
      let operHtml='',maintHtml='',toolsHtml='',infoHtml='';
      try{operHtml=oper.length&&typeof w.u132Task==='function'?oper.map(w.u132Task).join(''):''}catch(e){}
      try{maintHtml=typeof w.u132Maintenance==='function'?w.u132Maintenance():''}catch(e){}
      try{toolsHtml=(typeof w.u132LedgerPanel==='function'&&typeof w.u132InvoicePanel==='function')?`<div class="u132-tools">${w.u132LedgerPanel()}${w.u132InvoicePanel()}</div>`:''}catch(e){}
      try{infoHtml=info.length&&typeof w.renderUpdateInfo==='function'?info.map(w.renderUpdateInfo).join(''):''}catch(e){}
      const classHtml=classes?classificationSection(w,q,sq):`<section id="v144Classification" class="v144u-section primary"><div class="v144u-sec-head"><div><span class="eye">Classificar agora</span><h2>Nenhuma classificação pendente</h2><p>Quando surgir um item, sugestão, pesquisa e confiança aparecerão aqui antes das tarefas secundárias.</p></div><span class="v144u-count">0</span></div></section>`;
      return `<div id="v144UpdatesRoot" class="v144u"><div id="v143FeedbackUpdates" class="v144-legacy-suppressed" aria-hidden="true"></div><div class="v144u-head"><div><span class="eye">Atualizações</span><h1>Resolva o que precisa de você.</h1><p>Classificação vem primeiro. Depois ficam documentos, atualizações de base, recorrências e ferramentas de manutenção — sem blocos soltos nem espaços vazios no caminho principal.</p></div><div class="v144u-asof"><span>Base documental</span><b>${esc(fresh)}</b></div></div><div class="v144u-summary"><button class="v144u-sum primary" data-v144-jump="v144Classification"><div><span>Classificar agora</span><b>Sugestão + evidência + %</b><small>decisões que realmente precisam de você</small></div><strong>${classes}</strong></button><button class="v144u-sum" data-v144-jump="v144OtherActions"><div><span>Outras ações</span><b>Documentos e confirmações</b><small>somente itens operacionais abertos</small></div><strong>${oper.length}</strong></button><button class="v144u-sum" data-v144-jump="v144Integrity"><div><span>Integridade</span><b>Dados e cobertura futura</b><small>checks de atualização e recorrência</small></div><strong>${maintOpen}</strong></button></div>${classHtml}<details id="v144OtherActions" class="v144u-secondary" ${oper.length?'open':''}><summary>Outras ações que precisam de você <span>${oper.length} aberta(s)</span></summary><div class="v144u-secondary-body">${operHtml?`<div class="u130-list">${operHtml}</div>`:'<div class="v144u-empty">Nenhuma outra ação operacional.</div>'}</div></details><details id="v144Integrity" class="v144u-secondary"><summary>Integridade do LTS · dados, faturas e cobertura futura <span>${maintOpen} para revisar</span></summary><div class="v144u-secondary-body">${maintHtml||'<div class="v144u-empty">Sem checks de manutenção disponíveis.</div>'}</div></details>${toolsHtml?`<details class="v144u-secondary"><summary>Ferramentas de manutenção <span>ledger, fatura e documentos</span></summary><div class="v144u-secondary-body">${toolsHtml}</div></details>`:''}${infoHtml?`<details class="v144u-secondary"><summary>Informações e proteções do sistema <span>${info.length}</span></summary><div class="v144u-secondary-body">${infoHtml}</div></details>`:''}<div class="v144u-guard">${esc(u.maintenance_contract||u.guardrail||'Itens resolvidos não reaparecem; documentos existentes não são pedidos novamente.')}</div></div>`;
    };
  }

  function bind(w,d){
    if(d.__V144_UPDATES_BOUND)return;d.__V144_UPDATES_BOUND=true;
    d.addEventListener('click',e=>{
      const b=e.target?.closest?.('[data-v144-jump]');if(!b)return;
      const target=d.getElementById(String(b.dataset.v144Jump||''));
      if(target){e.preventDefault();if(target.tagName==='DETAILS')target.open=true;target.scrollIntoView({behavior:'smooth',block:'start'});}
    },true);
  }

  function install(){
    const z=deep();if(!z||!z.w||!z.d)return;
    const w=z.w,d=z.d;if(!w.D||typeof w.render!=='function'||typeof w.atualizacoes!=='function')return;
    addCss(d);bind(w,d);
    if(w.LTS_V144_UPDATES_CLASSIFICATION===MARK&&w.__LTS_V144_UPDATES_RENDERER===w.atualizacoes)return;
    const renderer=v144Updates(w);
    w.atualizacoes=renderer;
    w.__LTS_V144_UPDATES_RENDERER=renderer;
    w.LTS_V144_UPDATES_CLASSIFICATION=MARK;
    installedWindow=w;
    if(w.V==='Atualizações'){try{w.render()}catch(e){}}
  }

  setInterval(()=>{const z=deep();if(z?.w!==installedWindow||z?.w?.__LTS_V144_UPDATES_RENDERER!==z?.w?.atualizacoes)install();else{addCss(z.d);bind(z.w,z.d)}},300);
  setTimeout(install,60);
})();
