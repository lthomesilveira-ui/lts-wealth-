(function(){
  const w=window,d=document;
  const MARK='guided-document-association-v1';
  if(w.LTS_V147_DOCUMENT_ASSOCIATION===MARK)return;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const uniq=xs=>[...new Set((xs||[]).map(x=>String(x||'').trim()).filter(Boolean))];
  const allowed=new Set(['bank_statement','card_statement','financing_statement','other_financial_document']);

  function currentTask(){return (w.INPUTCTX&&typeof w.INPUTCTX==='object')?w.INPUTCTX:null}
  function knownAccounts(){
    const a=[];
    (w.D?.wealth?.accounts||[]).forEach(x=>a.push(x?.institution||x?.account_name));
    (w.D?.flow?.accounts||[]).forEach(x=>a.push(x?.institution||x?.account));
    return uniq(a);
  }
  function knownCards(){
    const a=[];
    (w.D?.card_operating?.open_cycles||[]).forEach(x=>a.push(x?.card_name));
    (w.D?.card_history?.units||[]).forEach(x=>a.push(x?.card_name||x?.name));
    (w.D?.card_history?.cards||[]).forEach(x=>a.push(x?.card_name||x?.name));
    return uniq(a);
  }
  function knownCommitments(){
    const a=[];
    (w.D?.commitments?.commitments||[]).forEach(x=>a.push(x?.label||x?.id));
    (w.D?.documentary_commitments?.items||[]).forEach(x=>a.push(x?.label||x?.commitment_label||x?.commitment_id));
    return uniq(a);
  }
  function datalist(id,values){return `<datalist id="${id}">${values.map(x=>`<option value="${esc(x)}"></option>`).join('')}</datalist>`}

  function css(){
    if(d.getElementById('wip35-v147-document-association-css'))return;
    const s=d.createElement('style');s.id='wip35-v147-document-association-css';s.textContent=`
      .v147-doc{background:#fff;border:1px solid #d8c7a6;border-radius:16px;padding:13px 14px;box-shadow:0 7px 24px rgba(20,42,70,.045);margin-bottom:10px}.v147-dochead{display:flex;justify-content:space-between;gap:14px;align-items:flex-start}.v147-eye{display:block;font-size:8px;letter-spacing:.08em;text-transform:uppercase;font-weight:900;color:#98713a}.v147-doc h2{font-size:18px;margin:3px 0 4px}.v147-doc p{font-size:9px;color:var(--mut);line-height:1.45;margin:0;max-width:760px}.v147-step{font-size:8px;font-weight:900;background:#fff7e8;color:#7b5b29;border-radius:999px;padding:6px 9px;white-space:nowrap}.v147-method{display:flex;align-items:center;gap:5px;flex-wrap:wrap;margin:10px 0}.v147-method span{font-size:8px;font-weight:850;padding:5px 7px;border-radius:999px;background:#f2f5f8;color:#667384}.v147-method i{font-style:normal;color:#a2acb7}.v147-grid{display:grid;grid-template-columns:.9fr 1.15fr .8fr;gap:8px;align-items:end}.v147-field label{display:block;font-size:8px;text-transform:uppercase;font-weight:900;color:var(--mut);margin-bottom:4px}.v147-field select,.v147-field input{width:100%;border:1px solid var(--bd);border-radius:10px;padding:9px 10px;background:#fff;color:var(--ink);font-size:10px;min-height:38px}.v147-field.wide{grid-column:span 2}.v147-preview{margin-top:9px;border:1px solid #e3e8ed;background:#f8fafc;border-radius:10px;padding:9px 10px;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;align-items:center}.v147-preview b{font-size:9px}.v147-preview span{display:block;font-size:8px;color:var(--mut);line-height:1.4;margin-top:2px}.v147-status{font-size:8px;font-weight:900;border-radius:999px;padding:5px 7px;white-space:nowrap}.v147-status.ok{background:#eaf6f0;color:#32694f}.v147-status.wait{background:#fff5df;color:#86601f}.v147-guard{font-size:8px;line-height:1.4;color:var(--mut);margin-top:8px}.v147-history{margin-top:10px;border-top:1px solid #edf0f4;padding-top:8px}.v147-history>span{display:block;font-size:8px;text-transform:uppercase;font-weight:900;color:var(--mut);margin-bottom:3px}.v147-hrow{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;padding:6px 0;border-top:1px solid #f0f2f5}.v147-hrow:first-of-type{border-top:0}.v147-hrow b{font-size:9px}.v147-hrow small{display:block;font-size:7px;color:var(--mut);margin-top:2px}.v147-hrow em{font-style:normal;font-size:8px;color:#526273;white-space:nowrap}.v147-msg{font-size:9px;line-height:1.4;margin-top:7px}.v147-msg.err{color:#9b3a36}.v147-msg.ok{color:#32694f}
      @media(max-width:820px){.v147-grid{grid-template-columns:1fr}.v147-field.wide{grid-column:auto}.v147-dochead{flex-direction:column}.v147-preview{grid-template-columns:1fr}.v147-step{white-space:normal}}
    `;(d.head||d.documentElement).appendChild(s);
  }

  function explicitSeed(){
    const x=currentTask()||{},a=(x.document_association&&typeof x.document_association==='object')?x.document_association:{};
    const type=allowed.has(String(x.document_type||a.document_type||''))?String(x.document_type||a.document_type):'';
    return {
      document_type:type,
      target:String(a.entity_label||a.target_label||'').trim(),
      competence:String(a.competence||'').slice(0,7),
      as_of_date:String(a.as_of_date||'').slice(0,10),
      note:String(a.note||'').trim()
    };
  }

  function fieldHtml(type,seed){
    const acc=knownAccounts(),cards=knownCards(),com=knownCommitments();
    if(type==='bank_statement')return `<div class="v147-field wide"><label>Conta / instituição do extrato</label><input id="v147DocTarget" list="v147Accounts" autocomplete="off" placeholder="Escolha ou informe exatamente" value="${esc(seed.target)}">${datalist('v147Accounts',acc)}</div><div class="v147-field"><label>Competência</label><input id="v147DocCompetence" type="month" value="${esc(seed.competence)}"></div>`;
    if(type==='card_statement')return `<div class="v147-field wide"><label>Cartão da fatura</label><input id="v147DocTarget" list="v147Cards" autocomplete="off" placeholder="Escolha ou informe exatamente" value="${esc(seed.target)}">${datalist('v147Cards',cards)}</div><div class="v147-field"><label>Competência</label><input id="v147DocCompetence" type="month" value="${esc(seed.competence)}"></div>`;
    if(type==='financing_statement')return `<div class="v147-field wide"><label>Compromisso / financiamento</label><input id="v147DocTarget" list="v147Commitments" autocomplete="off" placeholder="Escolha ou informe exatamente" value="${esc(seed.target)}">${datalist('v147Commitments',com)}</div><div class="v147-field"><label>Data da posição</label><input id="v147DocAsOf" type="date" value="${esc(seed.as_of_date)}"></div>`;
    if(type==='other_financial_document')return `<div class="v147-field wide"><label>Vínculo / finalidade documental</label><input id="v147DocNote" autocomplete="off" placeholder="Opcional — descreva sem criar regra financeira" value="${esc(seed.note)}"></div><div class="v147-field"><label>Período / posição</label><input value="Revisão manual" disabled></div>`;
    return `<div class="v147-field wide"><label>Vínculo</label><input value="Escolha primeiro o tipo do documento" disabled></div><div class="v147-field"><label>Período</label><input value="—" disabled></div>`;
  }

  function typeLabel(t){return ({bank_statement:'Extrato bancário',card_statement:'Fatura de cartão',financing_statement:'Financiamento / saldo devedor',other_financial_document:'Outro documento financeiro'})[t]||'Tipo não escolhido'}
  function readAssociation(){
    const type=String(d.getElementById('v147DocType')?.value||'');
    const target=String(d.getElementById('v147DocTarget')?.value||'').trim();
    const competence=String(d.getElementById('v147DocCompetence')?.value||'').slice(0,7);
    const asOf=String(d.getElementById('v147DocAsOf')?.value||'').slice(0,10);
    const note=String(d.getElementById('v147DocNote')?.value||'').trim();
    const missing=[];
    if(!allowed.has(type))missing.push('tipo do documento');
    if(type==='bank_statement'){if(!target)missing.push('conta/instituição');if(!/^\d{4}-\d{2}$/.test(competence))missing.push('competência')}
    if(type==='card_statement'){if(!target)missing.push('cartão');if(!/^\d{4}-\d{2}$/.test(competence))missing.push('competência')}
    if(type==='financing_statement'){if(!target)missing.push('compromisso/financiamento');if(!/^\d{4}-\d{2}-\d{2}$/.test(asOf))missing.push('data da posição')}
    const entityType=type==='bank_statement'?'bank_account':type==='card_statement'?'card':type==='financing_statement'?'financial_commitment':'other';
    const association={
      version:MARK,
      document_type:type||null,
      entity_type:allowed.has(type)?entityType:null,
      entity_label:target||null,
      competence:competence||null,
      as_of_date:asOf||null,
      note:note||null,
      provided_by_user:true,
      review_required:true
    };
    const state={valid:missing.length===0,missing,document_type:type,association};
    w.__LTS_V147_DOCUMENT_ASSOCIATION_STATE=state;
    return state;
  }

  function refreshPreview(){
    const s=readAssociation(),box=d.getElementById('v147DocPreview');if(!box)return;
    const a=s.association,period=a.competence?`competência ${a.competence}`:a.as_of_date?`posição ${a.as_of_date}`:'sem período obrigatório';
    const target=a.entity_label||a.note||'sem vínculo específico';
    box.innerHTML=`<div><b>${esc(typeLabel(s.document_type))}</b><span>${esc(target)} · ${esc(period)}. O vínculo será salvo como contexto documental; nenhum lançamento será criado pelo upload.</span></div><span class="v147-status ${s.valid?'ok':'wait'}">${s.valid?'pronto para enviar':'falta '+esc(s.missing.join(' + '))}</span>`;
    const msg=d.getElementById('v147DocAssocMsg');if(msg&&!s.valid){msg.className='v147-msg';msg.textContent=''}
  }

  function associatedQueue(){
    const q=w.D?.input?.queue||[];
    return q.map(it=>{const tc=it?.interpretation?.task_context||{},a=tc?.document_association;return a&&a.version===MARK?{it,a}:null}).filter(Boolean).slice(0,5);
  }
  function historyHtml(){
    const xs=associatedQueue();if(!xs.length)return '';
    return `<div class="v147-history"><span>Já associados nesta fila</span>${xs.map(({it,a})=>{const target=a.entity_label||a.note||'revisão manual',period=a.competence||a.as_of_date||'—';return `<div class="v147-hrow"><div><b>${esc(it.original_name||'Documento')}</b><small>${esc(typeLabel(a.document_type))} · ${esc(target)} · ${esc(period)}</small></div><em>${esc(it.status||'needs_review')}</em></div>`}).join('')}</div>`;
  }

  function panel(){
    const seed=explicitSeed();
    const el=d.createElement('section');el.id='v147DocAssociation';el.className='v147-doc';
    el.innerHTML=`<div class="v147-dochead"><div><span class="v147-eye">Associação documental</span><h2>Diga ao LTS o que este arquivo representa.</h2><p>O nome do arquivo não decide conta, cartão, competência ou saldo. Primeiro associe explicitamente; depois envie e revise.</p></div><span class="v147-step">1 vínculo → 2 upload → 3 revisão</span></div><div class="v147-method"><span>Tipo</span><i>›</i><span>Identidade</span><i>›</i><span>Competência / posição</span><i>›</i><span>Revisão manual</span></div><div class="v147-grid"><div class="v147-field"><label>Tipo do documento</label><select id="v147DocType"><option value="">Escolher…</option><option value="bank_statement" ${seed.document_type==='bank_statement'?'selected':''}>Extrato bancário</option><option value="card_statement" ${seed.document_type==='card_statement'?'selected':''}>Fatura de cartão</option><option value="financing_statement" ${seed.document_type==='financing_statement'?'selected':''}>Financiamento / saldo devedor</option><option value="other_financial_document" ${seed.document_type==='other_financial_document'?'selected':''}>Outro documento financeiro</option></select></div><div id="v147DocDynamic" style="display:contents">${fieldHtml(seed.document_type,seed)}</div></div><div id="v147DocPreview" class="v147-preview"></div><div id="v147DocAssocMsg" class="v147-msg"></div><div class="v147-guard">Extrato e fatura exigem identidade + competência. Financiamento exige compromisso + data da posição. O arquivo continua em revisão; associação documental não é conciliação, classificação nem write financeiro.</div>${historyHtml()}`;
    return el;
  }

  function setDynamic(){
    const type=String(d.getElementById('v147DocType')?.value||''),host=d.getElementById('v147DocDynamic');if(!host)return;
    const prev=readAssociation().association;
    const seed={document_type:type,target:prev.entity_label||'',competence:prev.competence||'',as_of_date:prev.as_of_date||'',note:prev.note||''};
    host.innerHTML=fieldHtml(type,seed);bindFields();refreshPreview();
  }
  function bindFields(){
    ['v147DocTarget','v147DocCompetence','v147DocAsOf','v147DocNote'].forEach(id=>{const x=d.getElementById(id);if(x&&!x.__V147_BOUND){x.__V147_BOUND=true;x.addEventListener('input',refreshPreview);x.addEventListener('change',refreshPreview)}});
  }
  function ensurePanel(){
    if(String(w.V)!=='Entradas')return false;
    css();
    const file=d.getElementById('file');if(!file)return false;
    let el=d.getElementById('v147DocAssociation');
    if(!el){el=panel();const grid=file.closest('.grid2');if(grid?.parentNode)grid.parentNode.insertBefore(el,grid);else file.parentNode?.insertBefore(el,file)}
    const type=d.getElementById('v147DocType');if(type&&!type.__V147_BOUND){type.__V147_BOUND=true;type.addEventListener('change',setDynamic)}
    bindFields();refreshPreview();
    const btn=d.getElementById('ubtn');if(btn&&typeof w.upload==='function'&&btn.onclick!==w.upload)btn.onclick=w.upload;
    return true;
  }

  const baseInput=typeof w.inputTaskContext==='function'?w.inputTaskContext:null;
  if(baseInput&&!w.__LTS_V147_BASE_INPUT_TASK_CONTEXT){
    w.__LTS_V147_BASE_INPUT_TASK_CONTEXT=baseInput;
    const wrapped=function(){
      let ctx={};try{ctx=baseInput.apply(this,arguments)||{}}catch(e){}
      const s=readAssociation();
      if(!s.valid)return ctx;
      return {...ctx,document_type:s.document_type,document_association:s.association,document_association_status:'explicit_user_input_pending_review'};
    };
    try{w.inputTaskContext=wrapped;inputTaskContext=wrapped}catch(e){w.inputTaskContext=wrapped}
  }

  const baseUpload=typeof w.upload==='function'?w.upload:null;
  if(baseUpload&&!w.__LTS_V147_BASE_UPLOAD){
    w.__LTS_V147_BASE_UPLOAD=baseUpload;
    w.__LTS_V147_BASE_UPLOAD_CALLS=0;w.__LTS_V147_BLOCKED_UPLOADS=0;
    const wrapped=async function(){
      const s=readAssociation(),msg=d.getElementById('v147DocAssocMsg');
      if(!s.valid){w.__LTS_V147_BLOCKED_UPLOADS++;if(msg){msg.className='v147-msg err';msg.textContent='Antes de enviar, complete: '+s.missing.join(', ')+'.'}refreshPreview();return}
      w.__LTS_V147_BASE_UPLOAD_CALLS++;if(msg){msg.className='v147-msg ok';msg.textContent='Associação completa. Enviando para revisão…'}
      return baseUpload.apply(this,arguments);
    };
    try{w.upload=wrapped;upload=wrapped}catch(e){w.upload=wrapped}
  }

  w.__LTS_V147_READ_DOCUMENT_ASSOCIATION=readAssociation;
  w.__LTS_V147_ENSURE_DOCUMENT_ASSOCIATION=ensurePanel;
  w.LTS_V147_DOCUMENT_ASSOCIATION=MARK;
  w.__LTS_V147_DOCUMENT_ASSOCIATION_STATUS={version:MARK,backend_contract:'task_context-additive',financial_writer_changed:false,filename_inference:false,requires_explicit_identity_period:true,permanent_polling:false};
  ensurePanel();
  const root=d.getElementById('A')||d.getElementById('app')||d.body;
  if(root&&typeof MutationObserver==='function'){
    const mo=new MutationObserver(()=>{
      if(String(w.V)==='Entradas'&&!d.getElementById('v147DocAssociation'))queueMicrotask(ensurePanel);
      else if(String(w.V)==='Entradas'){const btn=d.getElementById('ubtn');if(btn&&typeof w.upload==='function'&&btn.onclick!==w.upload)btn.onclick=w.upload}
    });mo.observe(root,{childList:true,subtree:true});w.__LTS_V147_DOCUMENT_OBSERVER=mo;
  }
})();
