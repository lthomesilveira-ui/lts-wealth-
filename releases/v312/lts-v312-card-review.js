/* Review every received card observation; learning never turns a suggestion into a decision. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V312_CARD_REVIEW)return;
  const oldRender=render,oldUpdates=atualizacoes;
  const state={generation:null,sequence:0,loading:false,reload:false,deferredRender:false,error:false,data:null,readAt:0,offset:0,query:'',drafts:new Map()};
  const current=()=>typeof BOOT==='object'?BOOT.generation:D;
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const label=x=>window.LTSCategoryDisplay?.category(x)||x||'';
  const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'Data não informada';
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const money=r=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:r.currency||'BRL'}).format(Number(r.amount));
  function session(){
   if(state.generation!==current()){
    state.generation=current();state.sequence++;state.loading=false;state.reload=false;state.deferredRender=false;state.error=false;state.data=null;state.readAt=0;state.offset=0;state.query='';state.drafts.clear();
    document.getElementById('v312CardDialog')?.close();
   }
  }
  function go(){V='Atualizações';renderNav();render();document.getElementById('v312CardReview')?.scrollIntoView({block:'start'});}
  function notice(){
   document.getElementById('v312CardReviewNotice')?.remove();
   const n=state.data?.row_count;if(!n||V!=='Despesas'||window.__LTS_V168_STATE?.expense?.tab!=='cards')return;
   const head=document.querySelector('.v226-upcoming');if(!head)return;
   const b=document.createElement('button');b.id='v312CardReviewNotice';b.className='v168-btn lts-card-review-notice';
   b.textContent=n+' lançamentos de cartão a classificar · Ver em Ações';b.onclick=go;head.insertAdjacentElement('afterend',b);
  }
  async function load(force=false){
   session();if(!D||N.classList.contains('hidden'))return;
   if(state.loading){if(force)state.reload=true;return;}
   if(!force&&Date.now()-state.readAt<300000)return;
   const generation=state.generation,sequence=++state.sequence,query=state.query,offset=state.offset;state.loading=true;
   if(V==='Atualizações')render();
   try{
    const r=await S.rpc('lts_browser_card_review_queue_v312',{p_from:'2013-10-10',p_to:today(),p_offset:offset,p_limit:10,p_query:query||null});
    if(generation!==current()||sequence!==state.sequence)return;
    if(query!==state.query||offset!==state.offset){state.reload=true;return;}
    if(r.error||r.data?.ok!==true||!Array.isArray(r.data.rows)||!Number.isInteger(r.data.row_count)||!Number.isInteger(r.data.additional_count))throw Error('unavailable');
    state.data=r.data;state.error=false;state.readAt=Date.now();
    if(state.offset>0&&!r.data.rows.length&&r.data.matched_count<state.offset){state.offset=Math.max(0,Math.floor((r.data.matched_count-1)/10)*10);state.readAt=0;}
   }catch{if(generation===current()&&sequence===state.sequence){state.error=true;state.readAt=Date.now();}}
   finally{
    if(generation===current()&&sequence===state.sequence){state.loading=false;if(V==='Atualizações')render();else{renderNav();notice();}if(state.reload||(!state.error&&state.readAt===0)){state.reload=false;queueMicrotask(()=>load(true));}}
   }
  }
  function panel(){
   const d=state.data,rows=d?.rows||[];
   const header='<article class="v168-card lts-card-review" id="v312CardReview"><div class="v168-cardhead"><div><span>Classificações</span><h2>Cartões a classificar</h2></div><strong data-v312-count>'+(d?esc(d.row_count):'—')+'</strong></div><p>Compras recebidas de todas as datas, incluindo o histórico. Suas confirmações orientam as próximas sugestões.</p>';
   const warning=state.error?'<p class="lts-review-alert" role="alert">Não foi possível atualizar a lista. As informações anteriores podem estar desatualizadas.</p><button class="v168-btn" data-v312-retry>Tentar novamente</button>':'';
   if(!d)return header+warning+'<p role="status">'+(state.loading?'Consultando classificações…':'A lista ainda não está disponível.')+'</p></article>';
   const search='<form class="lts-card-review-search"><label>Buscar compras<input type="search" name="card-query" maxlength="300" value="'+esc(state.query)+'" placeholder="Descrição, cartão ou final"></label><button type="submit" class="v168-btn">Buscar</button></form>';
   const list=rows.map((r,i)=>'<section class="lts-card-review-row"><div><small>'+esc(date(r.event_date))+' · '+esc(r.account_source)+' · final '+esc(r.last4||'—')+'</small><b>'+esc(r.description)+'</b>'+(r.installment_number?'<small>Parcela '+esc(r.installment_number)+'/'+esc(r.total_installments||'?')+'</small>':'')+(r.suggestion?.category?'<span class="lts-card-review-suggestion">Sugestão: '+esc(label(r.suggestion.category))+'</span>':'<small>Finalidade a identificar</small>')+'</div><strong>'+esc(money(r))+'</strong><button type="button" class="v168-btn primary" data-v312-review="'+i+'">Revisar</button></section>').join('')||'<p>'+(d.row_count?'Nenhuma compra encontrada nesta busca.':'Nenhum lançamento de cartão a classificar.')+'</p>';
   const off=d.offset||0,total=d.matched_count||0;
   const paging='<div class="lts-card-review-paging"><span>'+(total?((off+1)+'–'+Math.min(off+rows.length,total)+' de '+total):'0 itens')+'</span><div><button class="v168-btn" data-v312-prev '+(off?'':'disabled')+'>Anterior</button><button class="v168-btn" data-v312-next '+(d.next_offset==null?'disabled':'')+'>Próxima</button></div></div>';
   return header+warning+search+list+paging+(state.loading?'<p role="status">Atualizando…</p>':'')+'<details class="lts-card-review-update"><summary>Atualização</summary><p>Conferido em '+esc(new Date(d.checked_at).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'}))+'. Classificar preserva os valores contabilizados.</p></details></article>';
  }
  function open(row){
   document.getElementById('v312CardDialog')?.close();
   const generation=state.generation,draft=state.drafts.get(row.source_ref),suggested=row.suggestion?.category;
   const selected=draft?.category??suggested??'',person=draft?.beneficiary??'';
   const dialog=document.createElement('dialog');dialog.id='v312CardDialog';dialog.className='lts-card-review-dialog';
   dialog.innerHTML='<header><div><small>'+esc(date(row.event_date))+' · '+esc(money(row))+'</small><h2>Classificar compra</h2></div><button class="v168-btn" data-v312-close>Fechar</button></header><p><b>'+esc(row.description)+'</b><br>'+esc(row.account_source)+' · final '+esc(row.last4||'—')+'</p><form><label>Classificação<select name="category" required><option value="">Selecione…</option>'+(state.data?.category_options||[]).map(c=>'<option value="'+esc(c)+'"'+(c===selected?' selected':'')+'>'+esc(label(c))+'</option>').join('')+'</select></label><label>Pessoa · opcional<select name="beneficiary"><option value="">Sem identificação adicional</option>'+['Lucas','Larissa','Benjamin','Rafiki'].map(p=>'<option value="'+p+'"'+(p===person?' selected':'')+'>'+p+'</option>').join('')+'</select></label>'+(suggested?'<p class="lts-card-review-suggestion">Categoria sugerida. Confira antes de confirmar.</p>':'<p>Escolha a finalidade da compra para orientar novas sugestões.</p>')+'<details><summary>Por que sugerimos</summary><p>'+esc(row.suggestion?.note||'Ainda falta informação para sugerir uma classificação.')+'</p></details><button type="submit" class="v168-btn primary" '+(selected?'':'disabled')+'>Confirmar classificação</button><p role="status" aria-live="polite"></p></form>';
   document.body.appendChild(dialog);dialog.showModal();
   const form=dialog.querySelector('form'),select=form.elements.category,beneficiary=form.elements.beneficiary,save=form.querySelector('[type=submit]'),status=form.querySelector('[role=status]');
   function remember(){state.drafts.set(row.source_ref,{category:select.value,beneficiary:beneficiary.value});save.disabled=!select.value;}
   select.onchange=remember;beneficiary.onchange=remember;
   dialog.querySelector('[data-v312-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{dialog.remove();if(V==='Atualizações')render();});
   window.LTSCategoryRegistry?.attach(select);
   form.onsubmit=async event=>{
    event.preventDefault();if(save.disabled||generation!==current())return;save.disabled=true;status.textContent='Salvando…';
    try{
     const r=await S.rpc('lts_browser_card_review_save_v312',{p_source_id:row.source_ref,p_expected_raw_hash:row.raw_hash,p_category:select.value,p_beneficiary:beneficiary.value||null});
     if(r.error||r.data?.ok!==true)throw Error('unavailable');if(generation!==current())return;
     state.drafts.delete(row.source_ref);dialog.close();state.readAt=0;
     window.dispatchEvent(new CustomEvent('lts:card-classified'));
     window.__LTS_V296_CLASSIFICATIONS?.refresh();window.__LTS_V178_REVIEW?.refresh?.();
     if(window.__LTS_V226){window.__LTS_V226.cycles=null;window.__LTS_V226.loadedAt=0;}
    }catch{if(dialog.isConnected&&generation===current()){status.textContent='Não foi possível salvar. Atualize a lista se a compra mudou e tente novamente.';save.disabled=!select.value;}}
   };
  }
  function bind(){
   const host=document.getElementById('v312CardReview');if(!host)return;
   host.querySelector('[data-v312-retry]')?.addEventListener('click',()=>load(true));
   host.querySelector('form')?.addEventListener('submit',event=>{event.preventDefault();const input=event.target.elements['card-query'];state.query=input.value.trim();state.offset=0;input.blur();load(true);});
   host.querySelector('[data-v312-prev]')?.addEventListener('click',()=>{state.offset=Math.max(0,state.offset-10);load(true);});
   host.querySelector('[data-v312-next]')?.addEventListener('click',()=>{state.offset=Number(state.data?.next_offset||0);load(true);});
   host.querySelectorAll('[data-v312-review]').forEach(b=>b.onclick=()=>{const row=state.data?.rows?.[Number(b.dataset.v312Review)];if(row)open(row);});
  }
  atualizacoes=function(){session();const t=document.createElement('template');t.innerHTML=oldUpdates();t.content.querySelector('.v168-updates .v168-head')?.insertAdjacentHTML('afterend',panel());return t.innerHTML;};
  render=function(){
   session();const active=document.activeElement;
   if(V==='Atualizações'&&active?.closest('#v312CardDialog,#v312CardReview')&&['INPUT','SELECT','TEXTAREA'].includes(active.tagName)){state.deferredRender=true;return;}
   state.deferredRender=false;
   const r=oldRender();bind();notice();if(D&&!N.classList.contains('hidden'))queueMicrotask(()=>load(false));return r;
  };
  window.addEventListener('lts:card-classified',()=>{state.readAt=0;load(true);});
  document.addEventListener('focusout',()=>{if(state.deferredRender)queueMicrotask(()=>{if(state.deferredRender)render();});});
  window.addEventListener('lts:categories-changed',e=>{if(state.data&&Array.isArray(e.detail?.categories))state.data.category_options=e.detail.categories;});
  const style=document.createElement('style');style.textContent=`
   .lts-card-review{margin-bottom:16px}.lts-card-review>p,.lts-card-review-update{color:#526174;line-height:1.5}
   .lts-card-review-search{display:flex;align-items:end;gap:10px;margin:16px 0}.lts-card-review-search label{flex:1;font-size:13px}
   .lts-card-review-search input{display:block;box-sizing:border-box;width:100%;min-height:44px;margin-top:6px;border:1px solid #cbd5df;border-radius:8px;padding:10px}
   .lts-card-review-row{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:12px;align-items:start;padding:14px 0;border-top:1px solid #e1e7ef}
   .lts-card-review-row b,.lts-card-review-row small{display:block;line-height:1.5;overflow-wrap:anywhere}.lts-card-review-row small{color:#526174}.lts-card-review-row>strong{white-space:nowrap}
   .lts-card-review-suggestion{display:block;color:#8a621f;font-size:13px;line-height:1.5;margin-top:5px}
   .lts-card-review-paging{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap;margin-top:14px}.lts-card-review-paging>div{display:flex;gap:8px}
   .lts-card-review-update{margin-top:14px;font-size:12px}.lts-card-review-notice{margin:0 0 16px;text-align:left;white-space:normal;line-height:1.5}
   .lts-card-review-dialog{box-sizing:border-box;width:min(560px,calc(100vw - 24px));max-height:90dvh;overflow:auto;border:1px solid #d9e1e9;border-radius:16px;padding:20px;color:#20344a;background:white}
   .lts-card-review-dialog::backdrop{background:#14253599}.lts-card-review-dialog header{display:flex;align-items:start;justify-content:space-between;gap:12px}.lts-card-review-dialog h2{font-size:20px;margin:5px 0 12px}
   .lts-card-review-dialog p{line-height:1.5;overflow-wrap:anywhere}.lts-card-review-dialog label{display:block;margin:15px 0;font-size:13px}.lts-card-review-dialog select{box-sizing:border-box;width:100%;min-height:44px;padding:8px;margin-top:6px;border:1px solid #cbd5df;border-radius:8px;background:white;color:#20344a}
   .lts-card-review-dialog details{margin:16px 0;color:#526174;font-size:13px}.lts-card-review-dialog button{min-height:44px;white-space:normal}.lts-card-review-dialog [role=status]{min-height:20px;font-size:13px}
   @media(max-width:640px){.lts-card-review-row{grid-template-columns:minmax(0,1fr) auto}.lts-card-review-row>button{grid-column:1/-1;justify-self:start}.lts-card-review-search{flex-wrap:wrap}.lts-card-review-search label{flex-basis:100%}.lts-card-review-dialog{padding:16px}}
  `;document.head.appendChild(style);
  window.__LTS_V312_CARD_REVIEW={installed:true,state,refresh:()=>load(true),open};
  session();if(D&&!N.classList.contains('hidden')){render();queueMicrotask(()=>load(false));}
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V296_CLASSIFICATIONS?.installed||!w.LTSCategoryRegistry)return false;if(!w.__LTS_V312_CARD_REVIEW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V312_CARD_REVIEW;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
})();
