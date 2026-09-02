(function(){
  const outer=document.getElementById('shell');
  let lastFocus='';
  const n=x=>Number(x||0)||0;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function deep(){
    try{
      let d=document,w=window,f=outer;
      for(let i=0;i<11;i++){
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
  function css(d){
    if(d.getElementById('wip35-v143-feedback-polish-css'))return;
    const s=d.createElement('style');s.id='wip35-v143-feedback-polish-css';s.textContent=`
      .v143fb-wrap{display:grid;grid-template-columns:1.05fr .95fr;gap:8px;margin:10px 0 12px}.v143fb{background:#fff;border:1px solid var(--bd);border-radius:15px;padding:12px}.v143fb-head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px}.v143fb-head span{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.07em;font-weight:900;color:#9a743d}.v143fb-head h3{font-size:14px;margin:3px 0 0}.v143fb-head p{font-size:8px;color:var(--mut);line-height:1.45;margin:4px 0 0;max-width:640px}.v143fb-count{min-width:30px;height:30px;padding:0 8px;border-radius:999px;background:#eef3f7;display:grid;place-items:center;font-size:10px;font-weight:900}.v143fb-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:9px;padding:8px 0;border-top:1px solid #edf0f4;align-items:start}.v143fb-row:first-of-type{margin-top:7px}.v143fb-row b{display:block;font-size:10px}.v143fb-row small{display:block;font-size:8px;color:var(--mut);line-height:1.38;margin-top:2px}.v143fb-suggest{display:block;font-size:9px;font-weight:850;color:#365f52;margin-top:4px}.v143fb-source{font-size:7px;font-weight:850;border:1px solid #dfe6ec;border-radius:999px;padding:3px 6px;white-space:nowrap;background:#f8fafc}.v143fb-source.web{color:#315a78}.v143fb-source.history{color:#4f684d}.v143fb-note{font-size:8px;color:var(--mut);line-height:1.45;margin-top:8px}.v143fb-covered{display:flex;gap:5px;flex-wrap:wrap;margin-top:8px}.v143fb-covered span{font-size:7px;border-radius:999px;background:#eef7f2;color:#3f6e57;padding:4px 6px}.v143fb-btn{border:1px solid #d7dde5;background:#fff;color:#17304d;border-radius:999px;padding:6px 9px;font-size:8px;font-weight:850;cursor:pointer;margin-top:8px}.v143-focus-target{scroll-margin-top:92px}.v143-p0-context{border:1px solid #dce6df;background:#f5faf7;border-radius:11px;padding:9px 11px;font-size:8px;color:#456454;line-height:1.45}.v143-p0-context b{font-size:9px;color:#315745}
      @media(max-width:900px){.v143fb-wrap{grid-template-columns:1fr}.v143fb-row{grid-template-columns:1fr}.v143fb-source{justify-self:start}}
    `;d.head.appendChild(s);
  }
  function sourceMeta(x){
    const b=String(x?.suggestion_basis||'').toLowerCase();
    if(b.includes('historico'))return ['Histórico do LTS','history'];
    if(x?.enrichment_attempted)return ['Pesquisa pública','web'];
    return ['Revisão do LTS',''];
  }
  function evidencePanel(w){
    const q=w.D?.card_classification_review||{},all=(q.items||[]).filter(x=>x.suggested_category||x.enrichment_attempted);
    all.sort((a,b)=>String(b.due_date||'').localeCompare(String(a.due_date||''))||Number(!!b.suggested_category)-Number(!!a.suggested_category)||n(b.total_value)-n(a.total_value));
    const xs=all.slice(0,8);
    const rows=xs.map(x=>{const [src,cls]=sourceMeta(x),name=x.merchant_name||x.example_description||x.description_key||'Item';let ev=String(x.enrichment_evidence||'').trim();if(!ev&&x.suggested_category)ev='Sugestão baseada em evidência já preservada no LTS.';return `<div class="v143fb-row"><div><b>${esc(name)}</b><small>${esc(x.card_name||'')} · venc. ${x.due_date&&w.fmt?w.fmt(x.due_date):esc(x.due_date||'')} · ${w.brl?w.brl(x.total_value):esc(x.total_value)}</small>${x.suggested_category?`<span class="v143fb-suggest">Sugestão: ${esc(x.suggested_category)}</span>`:'<span class="v143fb-suggest" style="color:var(--mut)">Estabelecimento pesquisado; categoria ainda depende do contexto.</span>'}<small>${esc(ev)}</small></div><span class="v143fb-source ${cls}">${src}</span></div>`}).join('');
    return `<section class="v143fb" id="v143EvidenceSuggestions"><div class="v143fb-head"><div><span>Classificação assistida</span><h3>Sugestões com evidência</h3><p>O LTS tenta primeiro seu histórico. Quando ele não basta, pesquisa o estabelecimento. A sugestão continua para sua confirmação quando a taxonomia ou o contexto forem ambíguos.</p></div><div class="v143fb-count">${all.length}</div></div>${rows||'<div class="v143fb-note">Nenhuma sugestão baseada em evidência disponível agora.</div>'}<button class="v143fb-btn" type="button" data-v143-feedback-classify>Ir para classificação</button><div class="v143fb-note">Pesquisa pública identifica o estabelecimento; ela não autoriza o LTS a inventar finalidade da compra. Marketplaces, intermediadores e nomes ambíguos continuam para revisão.</div></section>`;
  }
  function recurringPanel(w){
    const a=w.D?.updates?.recurring_future_audit||{},xs=a.planning_review_candidates||[];
    const covered=(a.covered||[]).filter(x=>x&&String(x.description||'').trim()).slice(0,4);
    const rows=xs.map(x=>`<div class="v143fb-row"><div><b>${esc(x.description||'Recorrência')}</b><small>${n(x.historical_event_count)} ocorrência(s) · ${n(x.historical_active_months)} mês(es) com histórico · último em ${x.historical_last_date&&w.fmt?w.fmt(x.historical_last_date):esc(x.historical_last_date||'')}</small><span class="v143fb-suggest" style="color:#8b6428">Revisar cobertura futura</span><small>Mediana histórica ${w.brl?w.brl(x.observed_median_amount_brl):esc(x.observed_median_amount_brl)} — mediana é evidência, não valor projetado.</small></div><span class="v143fb-source">auditoria</span></div>`).join('');
    return `<section class="v143fb" id="v143RecurringAudit"><div class="v143fb-head"><div><span>Assistente de futuro</span><h3>Futuro conferido contra o seu histórico</h3><p>O sistema procura genericamente séries que aparecem com frequência no passado e verifica se existe cobertura nos próximos 12 meses. Nada é criado automaticamente.</p></div><div class="v143fb-count">${xs.length}</div></div>${rows||'<div class="v143fb-note">Nenhuma recorrência relevante sem cobertura futura encontrada.</div>'}${covered.length?`<div class="v143fb-note"><b>Exemplos já cobertos no futuro</b><div class="v143fb-covered">${covered.map(x=>`<span>${esc(x.description)}</span>`).join('')}</div></div>`:''}<div class="v143fb-note">A ausência futura abre uma investigação: pode significar término, mudança de nome ou projeção faltante. O LTS não copia automaticamente a mediana histórica para o futuro.</div></section>`;
  }
  function injectUpdates(w,d){
    if(w.V!=='Atualizações'||!w.D)return;
    if(d.getElementById('v143FeedbackUpdates'))return;
    const wrap=d.createElement('div');wrap.id='v143FeedbackUpdates';wrap.className='v143fb-wrap';wrap.innerHTML=evidencePanel(w)+recurringPanel(w);
    const quick=d.querySelector('.u142-quick');
    const host=d.getElementById('app')||d.querySelector('.wrap')||d.body;
    if(quick&&quick.parentNode)quick.insertAdjacentElement('afterend',wrap);else host.insertBefore(wrap,host.firstChild||null);
  }
  function polishDashboard(w,d){
    if(w.V!=='Dashboard'||!w.D?.dashboard_cockpit)return;
    const c=w.D.dashboard_cockpit,cards=c.cards||{},pa=c.planning_audited||{};
    const head=d.querySelector('.v143-head');
    if(head){const h=head.querySelector('h1'),p=head.querySelector('p');if(h)h.textContent='Sua vida financeira, em uma tela.';if(p)p.textContent='Tenho dinheiro hoje? O que exige ação? Para onde estou indo?';}
    const action=d.querySelector('.v143-action');
    if(action&&pa.management_point_date){const b=action.querySelector('b');if(b)b.textContent=`Sem uma ação de liquidez, o caixa cruza zero em ${w.fmt(pa.management_point_date)}.`;}
    const kpis=Array.from(d.querySelectorAll('.v143-kpis > .v143-kpi'));
    if(kpis.length>=4){const k=kpis[3],label=k.querySelector('span'),value=k.querySelector('b'),note=k.querySelector('small'),amount=n(cards.closed_or_due_total);if(label)label.textContent='Fatura vencida / a confirmar';if(value)value.textContent=w.brl(amount);if(note)note.textContent=amount>0?'há valor aguardando confirmação':'nenhuma pendente';}
  }
  function polishPlanning(w,d){
    if(w.V!=='Planejamento'||!w.__LTS_V142_PLAN_BRIDGE?.data)return;
    const q=w.__LTS_V142_PLAN_BRIDGE.data.summary||{},after=q.worst_balance_after_planned_fgts_brl;
    const action=d.querySelector('.v143-action');
    if(!action||d.querySelector('.v143-p0-context')||!q.first_management_point_date||after==null||n(after)<0)return;
    const note=d.createElement('div');note.className='v143-p0-context';note.innerHTML=`<b>Ponto de gestão de liquidez, não falta patrimonial comprovada.</b> Com a contingência modelada acionada no prazo, o pior saldo do horizonte auditado permanece em ${w.brl(after)}. Vestings futuros continuam condicionais e separados da liquidez já disponível.`;
    action.insertAdjacentElement('afterend',note);
  }
  function bind(w,d){
    if(d.__V143_FEEDBACK_BOUND)return;d.__V143_FEEDBACK_BOUND=true;
    d.addEventListener('click',e=>{
      const b=e.target?.closest?.('[data-v143-feedback-classify]');if(!b)return;
      e.preventDefault();
      const target=d.getElementById('cardClassReview')||d.querySelector('.u132-classrow')||d.querySelector('[class*=class]');
      if(target){target.classList.add('v143-focus-target');target.scrollIntoView({behavior:'smooth',block:'start'});}
    },true);
  }
  function focusDetail(w,d){
    let el=null,key='';
    if(w.__V143_EXP_DRILL&&!w.__V143_EXP_DRILL.loading){el=d.querySelector('.v143-drill');key='expense:'+String(w.__V143_EXP_DRILL.data?.key||w.__V143_EXP_DRILL.error||'done');}
    else if(w.__V143_CARD_DETAIL&&!w.__V143_CARD_DETAIL.loading){el=d.querySelector('[data-v143-card-close]')?.closest('.v143-panel');key='card:'+String(w.__V143_CARD_DETAIL.card?.invoice_id||w.__V143_CARD_DETAIL.card?.card_name||'done');}
    else if(w.__V143_CIPO_OPEN){el=d.querySelector('[data-v143-cipo-close]')?.closest('.v143-panel');key='cipo:open';}
    else if(w.__V143_VEST_SCEN){el=d.querySelector('.v143-scenario');key='scenario:'+String(w.__V143_VEST_SCEN.id||'open');}
    if(!el||!key||key===lastFocus)return;
    lastFocus=key;el.classList.add('v143-focus-target');setTimeout(()=>{try{el.scrollIntoView({behavior:'smooth',block:'start'});el.focus?.({preventScroll:true})}catch(e){}},40);
  }
  function tick(){
    const z=deep();if(!z||!z.w||!z.d)return;
    const w=z.w,d=z.d;
    w.LTS_V143_FEEDBACK_POLISH='classification-evidence-recurrence-generic-decision-cockpit-v2';
    css(d);bind(w,d);injectUpdates(w,d);polishDashboard(w,d);polishPlanning(w,d);focusDetail(w,d);
  }
  setInterval(tick,220);setTimeout(tick,40);
})();
