(function(){
  const w=window,d=document;
  const MARK='document-interpretation-review-v1';
  if(w.LTS_V149_DOCUMENT_INTERPRETATION_REVIEW===MARK)return;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const scalar=v=>v===null||v===undefined?null:(['string','number','boolean'].includes(typeof v)?String(v):null);
  const skipKey=k=>/^(raw|raw_text|ocr_text|text|html|base64|content|binary|bytes|pages?|rows?|lines?)$/i.test(String(k||''));
  const label=k=>String(k||'campo').replace(/[_\-.]+/g,' ').replace(/\b\w/g,m=>m.toUpperCase());
  const typeLabel=t=>({bank_statement:'Extrato bancário',card_statement:'Fatura de cartão',financing_statement:'Financiamento / saldo devedor',other_financial_document:'Outro documento financeiro'})[t]||'Documento financeiro';
  function association(it){return it?.interpretation?.task_context?.document_association||null}
  function requiredMissing(a){
    if(!a)return ['associação explícita'];
    const miss=[];
    if(!a.document_type)miss.push('tipo do documento');
    if(a.document_type==='bank_statement'){if(!a.entity_label)miss.push('conta/instituição');if(!/^\d{4}-\d{2}$/.test(String(a.competence||'')))miss.push('competência')}
    if(a.document_type==='card_statement'){if(!a.entity_label)miss.push('cartão');if(!/^\d{4}-\d{2}$/.test(String(a.competence||'')))miss.push('competência')}
    if(a.document_type==='financing_statement'){if(!a.entity_label)miss.push('compromisso/financiamento');if(!/^\d{4}-\d{2}-\d{2}$/.test(String(a.as_of_date||'')))miss.push('data da posição')}
    return miss;
  }
  function addEvidence(out,path,value,meta){
    if(out.length>=14)return;
    const v=scalar(value);if(v===null||v===''||v.length>240)return;
    const key=path.join('.');
    if(!key||out.some(x=>x.key===key&&x.value===v))return;
    out.push({key,label:label(path[path.length-1]),value:v,confidence:meta?.confidence??null,source:meta?.source??null,page:meta?.page??null});
  }
  function walk(obj,path,out,depth){
    if(out.length>=14||depth>3||obj===null||obj===undefined)return;
    if(Array.isArray(obj)){
      obj.slice(0,6).forEach((v,i)=>walk(v,path.concat(String(i+1)),out,depth+1));return;
    }
    if(typeof obj!=='object'){addEvidence(out,path,obj);return}
    if(Object.prototype.hasOwnProperty.call(obj,'value')&&scalar(obj.value)!==null){
      addEvidence(out,path,obj.value,{confidence:obj.confidence,source:obj.source,page:obj.page});return;
    }
    Object.entries(obj).forEach(([k,v])=>{
      if(out.length>=14||skipKey(k)||k==='task_context')return;
      if(['confidence','source','page'].includes(k)&&path.length)return;
      walk(v,path.concat(k),out,depth+1);
    });
  }
  function evidence(it){
    const x=it?.interpretation||{},out=[];
    const roots=['extracted_fields','fields','facts','document','summary','metadata'];
    roots.forEach(k=>{if(x[k]!==undefined)walk(x[k],[k],out,0)});
    if(!out.length){
      Object.entries(x).forEach(([k,v])=>{if(!['task_context','raw','raw_text','text','content','pages','rows','lines'].includes(k))walk(v,[k],out,0)});
    }
    return out;
  }
  function relevantQueue(){return (w.D?.input?.queue||[]).filter(it=>it?.interpretation||association(it)).slice(0,6)}
  function stateKey(){
    return JSON.stringify(relevantQueue().map(it=>({id:it.id||it.original_name||'',status:it.status||'',a:association(it),e:evidence(it).map(x=>({k:x.key,v:x.value,c:x.confidence}))})));
  }
  function css(){
    if(d.getElementById('wip35-v149-doc-review-css'))return;
    const s=d.createElement('style');s.id='wip35-v149-doc-review-css';s.textContent=`
      .v149-review{background:#fff;border:1px solid #d9e1e8;border-radius:16px;padding:13px 14px;margin:0 0 10px;box-shadow:0 7px 24px rgba(20,42,70,.045)}.v149-head{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.v149-eye{font-size:8px;letter-spacing:.08em;text-transform:uppercase;font-weight:900;color:#54677a}.v149-head h2{font-size:17px;margin:3px 0 4px}.v149-head p{font-size:9px;color:var(--mut);line-height:1.45;margin:0;max-width:800px}.v149-safe{font-size:8px;font-weight:900;background:#eef6f2;color:#35664f;border-radius:999px;padding:6px 9px;white-space:nowrap}.v149-doc{border-top:1px solid #edf0f3;padding-top:10px;margin-top:10px}.v149-doc:first-of-type{border-top:0}.v149-dochead{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;align-items:start}.v149-dochead b{font-size:10px}.v149-dochead small{display:block;font-size:8px;color:var(--mut);margin-top:2px}.v149-status{font-size:8px;font-weight:900;color:#657486}.v149-cols{display:grid;grid-template-columns:.8fr 1.2fr;gap:9px;margin-top:8px}.v149-box{border:1px solid #e5e9ee;background:#fafbfd;border-radius:11px;padding:9px 10px}.v149-box>span{display:block;font-size:7px;text-transform:uppercase;font-weight:900;color:var(--mut);margin-bottom:5px}.v149-box b{font-size:9px}.v149-box small{display:block;font-size:8px;color:var(--mut);line-height:1.4;margin-top:3px}.v149-ev{display:grid;grid-template-columns:minmax(0,.7fr) minmax(0,1fr) auto;gap:7px;padding:6px 0;border-top:1px solid #edf0f3;align-items:center}.v149-ev:first-of-type{border-top:0}.v149-ev label{font-size:8px;font-weight:850;overflow:hidden;text-overflow:ellipsis}.v149-ev strong{font-size:8px;font-weight:750;overflow-wrap:anywhere}.v149-ev em{font-style:normal;font-size:7px;color:#7b8793;white-space:nowrap}.v149-warn{margin-top:7px;font-size:8px;line-height:1.4;color:#8a6427;background:#fff8e9;border:1px solid #ead8b5;border-radius:9px;padding:7px 8px}.v149-ok{margin-top:7px;font-size:8px;line-height:1.4;color:#35664f}.v149-empty{font-size:9px;color:var(--mut);padding:8px 0}.v149-foot{margin-top:10px;font-size:8px;color:var(--mut);line-height:1.45;border-top:1px solid #edf0f3;padding-top:8px}
      @media(max-width:820px){.v149-head{grid-template-columns:1fr;display:grid}.v149-safe{white-space:normal;justify-self:start}.v149-cols{grid-template-columns:1fr}.v149-ev{grid-template-columns:1fr}.v149-ev em{white-space:normal}}
    `;(d.head||d.documentElement).appendChild(s);
  }
  function associationHtml(a){
    if(!a)return '<b>Sem associação explícita</b><small>O nome do arquivo não será usado para inferir conta, cartão, competência ou posição.</small>';
    const target=a.entity_label||a.note||'revisão manual';
    const period=a.competence?`competência ${a.competence}`:a.as_of_date?`posição ${a.as_of_date}`:'sem período informado';
    return `<b>${esc(typeLabel(a.document_type))}</b><small>${esc(target)} · ${esc(period)} · informado explicitamente pelo usuário</small>`;
  }
  function evHtml(xs){
    if(!xs.length)return '<div class="v149-empty">Nenhum campo estruturado foi retornado para esta leitura. O documento continua em revisão manual.</div>';
    return xs.map(x=>{const meta=[x.confidence!==null&&x.confidence!==undefined?`conf. ${esc(x.confidence)}`:'',x.page?`pág. ${esc(x.page)}`:''].filter(Boolean).join(' · ')||'extraído';return `<div class="v149-ev"><label>${esc(x.label)}</label><strong>${esc(x.value)}</strong><em>${meta}</em></div>`}).join('');
  }
  function docHtml(it){
    const a=association(it),miss=requiredMissing(a),ev=evidence(it),name=it.original_name||it.name||it.id||'Documento';
    const warning=miss.length?`<div class="v149-warn">Antes de qualquer aplicação: confirme ${esc(miss.join(', '))}. A leitura abaixo é evidência, não decisão.</div>`:`<div class="v149-ok">Associação explícita completa. Os campos extraídos ainda exigem revisão antes de qualquer efeito financeiro.</div>`;
    return `<article class="v149-doc"><div class="v149-dochead"><div><b>${esc(name)}</b><small>${esc(typeLabel(a?.document_type))}</small></div><span class="v149-status">${esc(it.status||'needs_review')}</span></div><div class="v149-cols"><div class="v149-box"><span>Vínculo informado por você</span>${associationHtml(a)}${warning}</div><div class="v149-box"><span>Leitura do arquivo · revisar</span>${evHtml(ev)}</div></div></article>`;
  }
  function panelHtml(sig){
    const q=relevantQueue();
    return `<section id="v149DocumentReview" data-v149-state="${esc(sig)}" class="v149-review"><div class="v149-head"><div><span class="v149-eye">Interpretação documental</span><h2>Veja o que o LTS leu — sem transformar leitura em fato.</h2><p>Campos extraídos de PDF/imagem ficam separados do vínculo informado por você. Nada desta camada cria lançamento, concilia, classifica ou altera saldo.</p></div><span class="v149-safe">Somente evidência · revisão manual</span></div>${q.length?q.map(docHtml).join(''):'<div class="v149-empty">Nenhum documento interpretado na fila atual.</div>'}<div class="v149-foot">Regra de segurança: filename não define identidade; leitura automática não confirma valor; qualquer aplicação financeira continua dependendo do fluxo explícito de revisão/aprovação.</div></section>`;
  }
  function ensure(){
    if(String(w.V)!=='Entradas')return false;
    css();
    const anchor=d.getElementById('v147DocAssociation')||d.getElementById('file')?.closest('.grid2');if(!anchor)return false;
    const sig=stateKey();let box=d.getElementById('v149DocumentReview');if(box?.dataset?.v149State===sig)return true;
    const html=panelHtml(sig);
    if(box)box.outerHTML=html;else anchor.insertAdjacentHTML('afterend',html);
    w.__LTS_V149_DOCUMENT_REVIEW_STATUS={version:MARK,queue_documents:relevantQueue().length,financial_writer_changed:false,rpc_calls:0,filename_inference:false,manual_review_required:true,permanent_polling:false};
    return true;
  }
  w.__LTS_V149_DOCUMENT_EVIDENCE=evidence;
  w.__LTS_V149_RENDER_DOCUMENT_REVIEW=ensure;
  w.LTS_V149_DOCUMENT_INTERPRETATION_REVIEW=MARK;
  w.__LTS_V149_DOCUMENT_REVIEW_STATUS={version:MARK,queue_documents:0,financial_writer_changed:false,rpc_calls:0,filename_inference:false,manual_review_required:true,permanent_polling:false};
  ensure();
  const root=d.getElementById('A')||d.getElementById('app')||d.body;
  if(root&&typeof MutationObserver==='function'){
    const mo=new MutationObserver(()=>{if(String(w.V)==='Entradas')queueMicrotask(ensure)});mo.observe(root,{childList:true,subtree:true});w.__LTS_V149_DOCUMENT_REVIEW_OBSERVER=mo;
  }
})();
