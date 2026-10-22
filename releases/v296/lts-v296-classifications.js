/* Incoming and outgoing classifications share one visible review entry point. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V296_CLASSIFICATIONS)return;
  const oldRender=render,oldNav=renderNav,oldUpdates=atualizacoes;
  const state={generation:null,sequence:0,loading:false,error:false,data:null,expense:null,readAt:0,offset:0,query:''};
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const date=x=>String(x||'').split('-').reverse().join('/');
  const current=()=>typeof BOOT==='object'?BOOT.generation:D;
  function session(){
   if(state.generation!==current())Object.assign(state,{generation:current(),sequence:state.sequence+1,loading:false,error:false,data:null,expense:null,readAt:0,offset:0,query:''});
  }
  function counts(){
   const review=window.__LTS_V181_STATE?.review;
   const income=state.data?.row_count,expense=review?.status==='ready'?review.data?.row_count:state.expense;
   const known=[income,expense].filter(x=>Number.isInteger(x)&&x>=0),n=known.reduce((a,b)=>a+b,0);
   return{n,complete:known.length===2&&!state.error};
  }
  function go(){V='Atualizações';renderNav();render();document.getElementById('v296IncomeQueue')?.scrollIntoView({block:'start'});}
  function badges(){
   session();
   document.querySelectorAll('.lts-classification-badge').forEach(el=>el.remove());
   const c=counts(),text=c.n?(c.complete?'':'+')+c.n:(c.complete?'':'•');
   document.querySelectorAll('[data-v="Atualizações"],[data-mobile-route="Atualizações"]').forEach(button=>{
    button.classList.add('lts-actions-nav');
    if(text){const badge=document.createElement('span');badge.className='lts-classification-badge';badge.textContent=text;button.appendChild(badge);}
    button.setAttribute('aria-label',c.n?'Ações · '+(c.complete?'':'pelo menos ')+c.n+' classificações pendentes':c.complete?'Ações':'Ações · classificações a conferir');
   });
   document.getElementById('ltsClassificationNotice')?.remove();
   if(V==='Dashboard'&&(c.n||state.error)){
    const head=document.querySelector('.v168-dashboard .v168-head');if(!head)return;
    const notice=document.createElement('button');notice.id='ltsClassificationNotice';notice.className='v168-btn lts-classification-notice';
    notice.textContent=c.n?(c.complete?'':'Pelo menos ')+c.n+' classificações pendentes · Ver em Ações':'Classificações: atualização indisponível · Ver em Ações';
    notice.onclick=go;head.insertAdjacentElement('afterend',notice);
   }
  }
  async function read(name,args){const r=await S.rpc(name,args);if(r.error||!r.data)throw Error('unavailable');return r.data;}
  async function load(force=false){
   session();if(!D||N.classList.contains('hidden')||state.loading||(!force&&Date.now()-state.readAt<300000))return;
   state.loading=true;const sequence=++state.sequence,generation=state.generation;
   if(V==='Atualizações')render();
   const args={p_from:'2013-10-10',p_to:today(),p_offset:state.offset,p_limit:25,p_query:state.query||null};
   const [income,expense]=await Promise.allSettled([
    read('lts_browser_income_review_queue_v296',args),
    read('lts_browser_expense_review_queue_v229',{p_from:args.p_from,p_to:args.p_to,p_offset:0,p_limit:1,p_query:null})
   ]);
   if(generation!==current()||sequence!==state.sequence)return;
   state.loading=false;state.readAt=Date.now();state.error=false;
   if(income.status==='fulfilled'&&income.value.ok===true&&Array.isArray(income.value.rows)&&Number.isInteger(income.value.row_count))state.data=income.value;else state.error=true;
   if(expense.status==='fulfilled'&&Number.isInteger(expense.value.row_count))state.expense=expense.value.row_count;else state.error=true;
   if(V==='Atualizações')render();else badges();
  }
  function panel(){
   const d=state.data,rows=d?.rows||[],c=counts();
   const header='<article class="v168-card lts-income-queue" id="v296IncomeQueue"><div class="v168-cardhead"><div><span>Classificações</span><h2>Receitas a classificar</h2></div><strong>'+(d?esc(d.row_count):'—')+'</strong></div><p>Recebimentos de todas as datas. Use as mesmas classificações do fluxo e dos cartões.</p>';
   const error=state.error?'<p class="lts-review-alert" role="status">Não foi possível atualizar todas as classificações. A lista anterior pode estar desatualizada.</p><button type="button" class="v168-btn" data-income-retry>Tentar novamente</button>':'';
   if(!d)return header+error+'<p role="status">'+(state.loading?'Carregando receitas…':'A lista ainda não está disponível.')+'</p></article>';
   const filter='<form class="lts-income-search"><label>Buscar recebimentos<input type="search" maxlength="300" name="income-query" value="'+esc(state.query)+'" placeholder="Descrição ou conta"></label><button class="v168-btn" type="submit">Buscar</button></form>';
   const list=rows.map((e,i)=>'<section class="lts-income-row"><div><small>'+esc(date(e.event_date))+' · '+esc(e.account)+'</small><b>'+esc(e.description||'Recebimento')+'</b></div><strong>'+esc(brl(e.signed_amount))+'</strong><button type="button" class="v168-btn primary" data-income-review="'+i+'">'+(e.editable?'Classificar':'Ver no fluxo')+'</button></section>').join('')||'<p>'+(d.row_count?'Nenhum recebimento encontrado nesta busca.':'Nenhuma receita sem classificação.')+'</p>';
   const from=Number(d.offset||0),total=Number(d.matched_count||0);
   const paging='<div class="lts-income-paging"><span>'+(total?((from+1)+'–'+Math.min(from+rows.length,total)+' de '+total):'0 itens')+'</span><div><button type="button" class="v168-btn" data-income-prev '+(from?'':'disabled')+'>Anterior</button><button type="button" class="v168-btn" data-income-next '+(d.next_offset==null?'disabled':'')+'>Próxima</button></div></div>';
   return header+error+filter+list+paging+(state.loading?'<p role="status">Atualizando…</p>':'')+'</article>';
  }
  atualizacoes=function(){session();const t=document.createElement('template');t.innerHTML=oldUpdates();const head=t.content.querySelector('.v168-updates .v168-head');head?.insertAdjacentHTML('afterend',panel());return t.innerHTML;};
  function bind(){
   const retry=document.querySelector('[data-income-retry]'),search=document.querySelector('.lts-income-search'),prev=document.querySelector('[data-income-prev]'),next=document.querySelector('[data-income-next]');
   if(retry)retry.onclick=()=>load(true);
   if(search)search.onsubmit=e=>{e.preventDefault();state.query=e.target.elements['income-query'].value.trim();state.offset=0;load(true);};
   if(prev)prev.onclick=()=>{state.offset=Math.max(0,state.offset-25);load(true);};
   if(next)next.onclick=()=>{state.offset=Number(state.data?.next_offset||0);load(true);};
   document.querySelectorAll('[data-income-review]').forEach(button=>button.onclick=()=>{
    const row=state.data?.rows?.[Number(button.dataset.incomeReview)];if(!row)return;
    if(row.editable)window.__LTS_V183_INCOME_REVIEW.openReceipt(row,button);
    else{V='Fluxo Diário';ACC=row.account;renderNav();loadFlowRange(row.event_date,row.event_date);}
   });
  }
  render=function(){const r=oldRender();session();bind();badges();if(D&&!N.classList.contains('hidden'))queueMicrotask(()=>load(false));return r;};
  renderNav=function(){const r=oldNav();badges();return r;};
  window.addEventListener('lts:income-classified',()=>{state.offset=0;state.readAt=0;load(true);});
  const style=document.createElement('style');style.textContent=`
   .lts-actions-nav{position:relative}.lts-classification-badge{position:absolute;top:2px;right:3px;border-radius:12px;background:#a33d20;color:white;font-size:10px;font-weight:800;line-height:16px;min-width:16px;padding:0 4px;box-sizing:border-box}
   .lts-classification-notice{display:block;margin:0 0 16px;text-align:left;white-space:normal;line-height:1.45}
   .v168-updates,.v168-updates *{min-width:0}.v168-updates b,.v168-updates p,.v168-updates small,.v168-updates h2,.v168-updates button{overflow-wrap:anywhere}
   .v168-updates .v168-action{align-items:start}.v168-updates .v168-btn{white-space:normal;line-height:1.4;min-height:44px}
   #v237CoverageAudit .v168-action{grid-template-columns:minmax(0,1fr) auto;align-items:start}
   #v237CoverageAudit .v268-periods{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
   #v237CoverageAudit .v268-periods button{min-height:44px;white-space:normal;max-width:100%}
   .lts-income-queue{margin-bottom:16px}.lts-income-queue p{line-height:1.5;color:#526174}.lts-income-search{display:flex;align-items:end;gap:10px;margin:16px 0}
   .lts-income-search label{flex:1;font-size:13px}.lts-income-search input{display:block;box-sizing:border-box;width:100%;min-height:44px;margin-top:6px;border:1px solid #cbd5df;border-radius:8px;padding:10px}
   .lts-income-row{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:12px;align-items:start;padding:15px 0;border-top:1px solid #e1e7ef}.lts-income-row b,.lts-income-row small{display:block;line-height:1.5}.lts-income-row small{color:#526174}.lts-income-row>strong{white-space:nowrap}
   .lts-income-paging{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:10px;margin-top:16px}.lts-income-paging>div{display:flex;gap:8px}.lts-review-alert{border-left:3px solid #b7802d;padding:10px}
   @media(max-width:640px){#v237CoverageAudit .v168-action{grid-template-columns:minmax(0,1fr)}#v237CoverageAudit .v168-action>button{width:100%}.v168-updates .v168-action:not([data-coverage-key]){grid-template-columns:28px minmax(0,1fr)}.v168-updates .v168-action:not([data-coverage-key])>button{grid-column:2;justify-self:start;max-width:100%}.lts-income-row{grid-template-columns:minmax(0,1fr) auto}.lts-income-row>button{grid-column:1/-1;justify-self:start}.lts-income-search{flex-wrap:wrap}.lts-income-search label{flex-basis:100%}.v168-updates .v168-cardhead{flex-wrap:wrap;gap:8px}}
  `;document.head.appendChild(style);
  window.__LTS_V296_CLASSIFICATIONS={installed:true,state,refresh:()=>load(true)};
  session();if(D&&!N.classList.contains('hidden')){render();queueMicrotask(()=>load(false));}
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V290_SOURCES?.installed||!w?.__LTS_V183_INCOME_REVIEW)return false;if(!w.__LTS_V296_CLASSIFICATIONS){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V296_CLASSIFICATIONS;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
})();
