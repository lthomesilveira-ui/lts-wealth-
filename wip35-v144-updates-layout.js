(function(){
  const outer=document.getElementById('shell');
  const MARK='classification-action-center-v2';
  const n=x=>Number(x||0)||0;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  function deep(){
    try{
      let d=document,w=window;
      for(let i=0;i<12;i++){
        const frames=Array.from(d.querySelectorAll('iframe'));
        if(!frames.length)break;
        const next=frames.find(x=>x.id==='shell'||x.id==='app')||frames[0];
        if(!next||!next.contentDocument||!next.contentWindow)break;
        d=next.contentDocument;w=next.contentWindow;
      }
      if(d&&w&&typeof w.render==='function'&&typeof w.atualizacoes==='function')return {w,d};
    }catch(e){}
    return null;
  }

  function css(d){
    if(d.getElementById('wip35-v144-updates-layout-css'))return;
    const s=d.createElement('style');
    s.id='wip35-v144-updates-layout-css';
    s.textContent=`
      #v144UpdatesRoot{display:flex;flex-direction:column;gap:10px;max-width:1180px;margin:0 auto 12px}
      .v144-head{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;padding:2px 0 1px}.v144-head .eye{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.08em;font-weight:900;color:#98713a}.v144-head h1{margin:4px 0 5px;font-size:27px;line-height:1.06;letter-spacing:-.035em}.v144-head p{margin:0;max-width:760px;font-size:10px;line-height:1.45;color:var(--mut)}.v144-asof{flex:0 0 auto;border:1px solid var(--bd);background:#fff;border-radius:12px;padding:8px 10px;text-align:right}.v144-asof span{display:block;font-size:7px;color:var(--mut);text-transform:uppercase;font-weight:900}.v144-asof b{display:block;font-size:11px;margin-top:3px}
      .v144-summary{display:grid;grid-template-columns:1.15fr .85fr .85fr;gap:7px}.v144-summary>div{border:1px solid var(--bd);background:#fff;border-radius:13px;padding:10px 11px}.v144-summary>div.primary{border-color:#d9c7a6;background:#fffaf1}.v144-summary span{display:block;font-size:7px;color:var(--mut);text-transform:uppercase;font-weight:900}.v144-summary b{display:block;font-size:12px;margin-top:3px}.v144-summary strong{display:block;font-size:20px;margin-top:4px}.v144-summary small{display:block;font-size:7px;color:var(--mut);margin-top:3px;line-height:1.35}
      #v144ClassificationZone{background:#fff;border:1px solid #d9c7a6;border-radius:16px;padding:12px;box-shadow:0 6px 20px rgba(20,42,70,.04)}.v144-zonehead{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:9px}.v144-zonehead span{display:block;font-size:8px;text-transform:uppercase;letter-spacing:.07em;font-weight:900;color:#98713a}.v144-zonehead h2{margin:3px 0;font-size:18px}.v144-zonehead p{margin:0;font-size:9px;color:var(--mut);line-height:1.4;max-width:760px}.v144-count{background:#eef2f6;border-radius:999px;padding:6px 9px;font-size:9px;font-weight:900;white-space:nowrap}.v144-method{display:flex;gap:5px;align-items:center;flex-wrap:wrap;margin-bottom:9px}.v144-method span{font-size:7px;font-weight:850;border-radius:999px;background:#f2f5f8;color:#607082;padding:4px 6px}.v144-method i{font-style:normal;color:#a4aeba;font-size:8px}
      #v144ClassificationZone #cardClassReview,#v144ClassificationZone #expenseClassReview{margin:0!important;padding:0!important;background:transparent!important;border:0!important;box-shadow:none!important}.v144-class-gap{height:8px}.v144-proofline{display:flex;gap:5px;flex-wrap:wrap;align-items:center;margin-top:7px}.v144-proofline span{font-size:7px;font-weight:900;border-radius:999px;padding:4px 6px;background:#eef2f6;color:#536477}.v144-proofline span.high{background:#eaf6f0;color:#32694f}.v144-proofline span.medium{background:#fff5df;color:#86601f}.v144-proofline span.source{background:#f3f6f9;color:#5d6c7b}.v144-prooftext{margin-top:6px;border:1px solid #e4e9ee;background:#f8fafc;border-radius:9px;padding:7px 8px;font-size:8px;line-height:1.4;color:#405269}.v144-prooftext b{font-size:7px;text-transform:uppercase;letter-spacing:.04em;color:#718095;margin-right:4px}.v144-row-enhanced .u138-proof{display:none!important}
      #v143EvidenceSuggestions.v144-duplicate-hidden{display:none!important}.v143fb-wrap.v144-feedback-reduced{display:block!important;margin:0!important}.v143fb-wrap.v144-feedback-reduced>#v143RecurringAudit{margin:0!important}
      .v144-fold{border:1px solid var(--bd);border-radius:14px;background:#fff;overflow:hidden}.v144-fold>summary{cursor:pointer;list-style:none;padding:11px 13px;font-size:10px;font-weight:850;display:flex;justify-content:space-between;gap:10px;align-items:center}.v144-fold>summary::-webkit-details-marker{display:none}.v144-fold>summary span{font-size:8px;color:var(--mut);font-weight:800}.v144-fold-body{padding:0 12px 12px}.v144-fold-body>.u142-quick{margin:0 0 8px!important}.v144-empty{padding:13px;text-align:center;background:#fafbfd;border-radius:10px;color:var(--mut);font-size:8px}.v144-guard{font-size:8px;line-height:1.4;color:var(--mut);text-align:center;padding:1px 8px 0}
      @media(max-width:900px){.v144-head{align-items:flex-start;flex-direction:column}.v144-asof{text-align:left}.v144-summary{grid-template-columns:1fr}.v144-zonehead{flex-direction:column}.v144-proofline{justify-content:flex-start}}
      @media(max-width:520px){.v144-head h1{font-size:23px}.v144-summary>div{padding:9px 10px}#v144ClassificationZone{padding:10px}}
    `;
    d.head.appendChild(s);
  }

  function confidenceClass(v){return v>=.9?'high':v>=.65?'medium':''}
  function sourceLabel(x){
    const b=String(x?.suggestion_basis||'').toLowerCase();
    if(b.includes('histor'))return 'Histórico do LTS';
    if(x?.enrichment_attempted)return 'Pesquisa pública';
    return 'Revisão manual';
  }
  function evidenceText(x){return String(x?.enrichment_evidence||x?.amount_pattern_evidence||'').trim()}
  function materialize(w,d,id,fn){
    let node=d.getElementById(id);if(node)return node;
    try{
      const html=typeof w[fn]==='function'?w[fn]():'';if(!html)return null;
      const box=d.createElement('div');box.innerHTML=html;node=box.querySelector('#'+id);return node||null;
    }catch(e){return null}
  }

  function enhanceCardRows(w,d){
    const items=w.D?.card_classification_review?.items||[],byKey=new Map(items.map(x=>[String(x?.description_key||''),x]));
    d.querySelectorAll('#cardClassReview .cardclass-row').forEach(row=>{
      const btn=row.querySelector('.cardclass-save[data-key]'),x=byKey.get(String(btn?.dataset?.key||''));if(!x)return;
      row.classList.add('v144-row-enhanced');
      row.querySelector('.v144-proofline')?.remove();row.querySelector('.v144-prooftext')?.remove();
      const strip=d.createElement('div');strip.className='v144-proofline';
      const sc=n(x.suggestion_confidence),ec=n(x.enrichment_confidence),parts=[];
      if(sc>0)parts.push(`<span class="${confidenceClass(sc)}">${Math.round(sc*100)}% sugestão</span>`);
      if(ec>0)parts.push(`<span class="${confidenceClass(ec)}">${Math.round(ec*100)}% identificação</span>`);
      if(!parts.length)parts.push('<span>sem % conclusivo</span>');
      parts.push(`<span class="source">${esc(sourceLabel(x))}</span>`);strip.innerHTML=parts.join('');
      const main=row.firstElementChild||row,signals=main.querySelector('.u138-signals');if(signals)signals.insertAdjacentElement('afterend',strip);else main.appendChild(strip);
      const ev=evidenceText(x);if(ev){const proof=d.createElement('div');proof.className='v144-prooftext';proof.innerHTML=`<b>Pesquisa / evidência</b>${esc(ev)}`;strip.insertAdjacentElement('afterend',proof)}
    });
  }
  function enhanceExpenseRows(w,d){
    const items=w.D?.semantic_review?.items||[],byKey=new Map(items.map(x=>[String(x?.description_key||''),x]));
    d.querySelectorAll('#expenseClassReview .cardclass-row').forEach(row=>{
      const btn=row.querySelector('.cardclass-save[data-key]'),x=byKey.get(String(btn?.dataset?.key||''));if(!x)return;
      row.classList.add('v144-row-enhanced');if(row.querySelector('.v144-proofline'))return;
      const strip=d.createElement('div');strip.className='v144-proofline';const sc=n(x.suggestion_confidence);
      strip.innerHTML=(sc>0?`<span class="${confidenceClass(sc)}">${Math.round(sc*100)}% sugestão</span>`:'<span>sem % conclusivo</span>')+`<span class="source">${esc(sourceLabel(x))}</span>`;
      const main=row.firstElementChild||row,signals=main.querySelector('.u138-signals');if(signals)signals.insertAdjacentElement('afterend',strip);else main.appendChild(strip);
    });
  }
  function actionCount(w){const xs=(w.D?.updates?.items||[]).slice();try{return typeof w.updateIsAction==='function'?xs.filter(w.updateIsAction).length:xs.length}catch(e){return xs.length}}
  function maintenanceCount(w){return (w.D?.updates?.maintenance_checks||[]).filter(x=>x?.actionable).length}

  function attachLate(w,d,root,zone){
    const card=materialize(w,d,'cardClassReview','cardClassificationUpdates'),expense=materialize(w,d,'expenseClassReview','expenseClassificationUpdates');
    if(card&&!zone.contains(card))zone.appendChild(card);
    if(expense&&!zone.contains(expense)){if(card&&!zone.querySelector('.v144-class-gap')){const gap=d.createElement('div');gap.className='v144-class-gap';zone.appendChild(gap)}zone.appendChild(expense)}
    const evidence=d.getElementById('v143EvidenceSuggestions');if(evidence)evidence.classList.add('v144-duplicate-hidden');
    const feedback=d.getElementById('v143FeedbackUpdates');if(feedback)feedback.classList.add('v144-feedback-reduced');
    const recurring=d.getElementById('v143RecurringAudit');if(recurring&&!root.contains(recurring)){
      let fold=d.getElementById('v144FutureChecks');if(!fold){fold=d.createElement('details');fold.className='v144-fold';fold.id='v144FutureChecks';fold.innerHTML='<summary>Recorrências e cobertura futura <span>abrir auditoria</span></summary><div class="v144-fold-body"></div>';root.insertBefore(fold,d.getElementById('v144OtherActions')||root.lastElementChild)}
      fold.querySelector('.v144-fold-body').appendChild(recurring);
    }
    enhanceCardRows(w,d);enhanceExpenseRows(w,d);
    return {card,expense};
  }

  function build(w,d){
    if(w.V!=='Atualizações'||!w.D)return;
    css(d);
    const host=d.getElementById('app')||d.querySelector('.wrap');if(!host)return;
    let root=d.getElementById('v144UpdatesRoot');
    if(root){const zone=d.getElementById('v144ClassificationZone');if(zone)attachLate(w,d,root,zone);w.LTS_V144_UPDATES_LAYOUT=MARK;return}
    const q=w.D?.card_classification_review||{},sq=w.D?.semantic_review||{},classes=n(q.pending_groups)+n(sq.pending_groups),actions=actionCount(w),maint=maintenanceCount(w),fresh=w.D?.updates?.freshness?.position_as_of;
    const card=materialize(w,d,'cardClassReview','cardClassificationUpdates'),expense=materialize(w,d,'expenseClassReview','expenseClassificationUpdates');
    const feedback=d.getElementById('v143FeedbackUpdates'),evidence=d.getElementById('v143EvidenceSuggestions'),recurring=d.getElementById('v143RecurringAudit');
    if(evidence)evidence.classList.add('v144-duplicate-hidden');if(feedback)feedback.classList.add('v144-feedback-reduced');

    root=d.createElement('div');root.id='v144UpdatesRoot';
    const head=d.createElement('div');head.className='v144-head';head.innerHTML=`<div><span class="eye">Atualizações</span><h1>Resolva o que precisa de você.</h1><p>Classificação primeiro. Sugestão, pesquisa e confiança ficam na mesma leitura; documentos, recorrências e manutenção ficam organizados abaixo.</p></div><div class="v144-asof"><span>Base documental</span><b>${fresh&&w.fmt?w.fmt(fresh):esc(fresh||'—')}</b></div>`;root.appendChild(head);
    const summary=d.createElement('div');summary.className='v144-summary';summary.innerHTML=`<div class="primary"><span>Classificar agora</span><b>Sugestão + evidência + %</b><strong>${classes}</strong><small>itens pendentes de decisão</small></div><div><span>Outras ações</span><b>Documentos e confirmações</b><strong>${actions}</strong><small>fila operacional aberta</small></div><div><span>Integridade</span><b>Dados e cobertura futura</b><strong>${maint}</strong><small>checks acionáveis</small></div>`;root.appendChild(summary);
    const zone=d.createElement('section');zone.id='v144ClassificationZone';zone.innerHTML=`<div class="v144-zonehead"><div><span>Classificar agora</span><h2>Sugestão + pesquisa + % de confiança, item por item</h2><p>O LTS usa primeiro histórico consistente; quando não basta, pesquisa o estabelecimento. A finalidade real da compra continua dependendo de evidência ou da sua confirmação.</p></div><div class="v144-count">${classes} pendente(s)</div></div><div class="v144-method"><span>1 · Histórico do LTS</span><i>›</i><span>2 · Pesquisa pública</span><i>›</i><span>3 · % de confiança</span><i>›</i><span>4 · Sua confirmação quando necessária</span></div>`;
    if(card)zone.appendChild(card);if(card&&expense){const gap=d.createElement('div');gap.className='v144-class-gap';zone.appendChild(gap)}if(expense)zone.appendChild(expense);
    if(!card&&!expense){const empty=d.createElement('div');empty.className='v144-empty';empty.textContent='Nenhuma classificação pendente neste momento.';zone.appendChild(empty)}root.appendChild(zone);
    if(recurring){const fold=d.createElement('details');fold.className='v144-fold';fold.id='v144FutureChecks';fold.innerHTML='<summary>Recorrências e cobertura futura <span>abrir auditoria</span></summary><div class="v144-fold-body"></div>';fold.querySelector('.v144-fold-body').appendChild(recurring);root.appendChild(fold)}
    const other=d.createElement('details');other.className='v144-fold';other.id='v144OtherActions';if(classes===0&&actions>0)other.open=true;other.innerHTML=`<summary>Outras ações, documentos e manutenção <span>${actions+maint} item(ns)</span></summary><div class="v144-fold-body"></div>`;
    const body=other.querySelector('.v144-fold-body');Array.from(host.children).forEach(x=>{if(x!==root&&x!==card&&x!==expense&&x!==recurring)body.appendChild(x)});if(!body.children.length){const empty=d.createElement('div');empty.className='v144-empty';empty.textContent='Nenhum bloco secundário aberto.';body.appendChild(empty)}root.appendChild(other);
    const guard=d.createElement('div');guard.className='v144-guard';guard.textContent='Pesquisa pública identifica o estabelecimento, não a finalidade da compra. Marketplaces, intermediadores e taxonomia ambígua continuam para revisão.';root.appendChild(guard);
    host.insertBefore(root,host.firstChild||null);attachLate(w,d,root,zone);w.LTS_V144_UPDATES_LAYOUT=MARK;
  }
  function tick(){const z=deep();if(!z||!z.w||!z.d)return;build(z.w,z.d)}
  setInterval(tick,160);setTimeout(tick,80);
})();
