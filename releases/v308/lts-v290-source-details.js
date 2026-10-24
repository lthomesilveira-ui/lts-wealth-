/* User-facing quote provenance, scheduled bank rows and source-scoped classification. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V290_SOURCES)return;
  const previous=render,st={quotes:null,quoteError:false,quoteLoading:false,quoteReadAt:0,quoteDetailsOpen:false,future:null,futureError:false,futureLoading:false,futureReadAt:0};
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>Number.isFinite(Number(x))?new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x)):'—';
  const stamp=x=>{const d=new Date(x);return x&&Number.isFinite(d.getTime())?new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',dateStyle:'short',timeStyle:'short'}).format(d):'não informado';};
  const day=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'—';
  const businessDay=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const active=()=>D&&!N.classList.contains('hidden');
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  let owner=generation(),epoch=0;
  function reset(){if(owner===generation())return;owner=generation();epoch++;Object.assign(st,{quotes:null,quoteError:false,quoteLoading:false,quoteReadAt:0,quoteDetailsOpen:false,future:null,futureError:false,futureLoading:false,futureReadAt:0});}
  function safeLink(url,label){try{if(new URL(url).protocol==='https:')return '<a href="'+esc(url)+'" target="_blank" rel="noopener noreferrer">'+esc(label)+'</a>';}catch{}return esc(label);}
  async function quotes(force=false){
   reset();if(!active()||st.quoteLoading||(!force&&Date.now()-st.quoteReadAt<300000))return;
   const current=epoch;st.quoteLoading=true;
   try{const r=await S.rpc('lts_browser_market_quotes_v290',{});if(r.error||!r.data)throw Error();
    if(current!==epoch||owner!==generation())return;
    const changed=st.quotes&&st.quotes.revision!==r.data.revision;st.quotes=r.data;st.quoteError=false;st.quoteReadAt=Date.now();
    if(changed){window.__LTS_V227_TRANSPORT?.invalidate?.();const ui=window.__LTS_V168_STATE;if(ui){ui.wealth.data=null;ui.dashboard.data=null;}render();}
   }catch{if(current===epoch){st.quoteError=true;st.quoteReadAt=Date.now();}}
   finally{if(current===epoch){st.quoteLoading=false;paintQuotes();}}
  }
  async function mode(value,button){
   st.quoteDetailsOpen=button.closest('details')?.open===true;
   button.disabled=true;
   try{
    const r=await S.rpc('lts_browser_market_mode_v290',{p_mode:value});if(r.error||r.data?.ok!==true)throw Error();
    window.__LTS_V227_TRANSPORT?.invalidate?.();st.quoteReadAt=0;
    const ui=window.__LTS_V168_STATE;if(ui){ui.wealth.data=null;ui.dashboard.data=null;}
    const provenance=window.__LTS_V183_AWARD_PROVENANCE;if(provenance){provenance.token++;provenance.status='idle';provenance.data=null;}
    await quotes(true);render();
   }catch{const status=document.querySelector('#ltsMarketQuotes [role=status]');if(status)status.textContent='Não foi possível alterar o modo. Tente novamente.';}
   finally{button.disabled=false;}
  }
  function quoteMarkup(){
   const q=st.quotes,stock=q?.stock,fx=q?.usd_brl,manual=q?.mode==='manual';
   const failed=st.quoteError||(q?.refresh||[]).some(x=>x.status==='failed');
   const missing=!stock||!fx;
   const aged=[stock,fx].some(x=>x&&Date.now()-new Date(x.quoted_at).getTime()>4*86400000);
   const value=(x,currency)=>x?new Intl.NumberFormat('pt-BR',{style:'currency',currency,minimumFractionDigits:currency==='USD'?2:4,maximumFractionDigits:currency==='USD'?2:4}).format(Number(x.value)):'—';
   return '<div class="v168-cardhead"><div><span>Referências para as projeções</span><h2>Cotações</h2></div></div>'+
    '<div class="lts-market-values"><div><span>Organon · OGN</span><b>'+esc(value(stock,'USD'))+'</b><small>Negócio de '+esc(stamp(stock?.quoted_at))+'</small></div><div><span>Dólar · PTAX venda</span><b>'+esc(value(fx,'BRL'))+'</b><small>Referência de '+esc(stamp(fx?.quoted_at))+'</small></div></div>'+
    (manual?'<p class="lts-freshness-alert" role="status">Simulação manual ativa nas projeções. As referências acima continuam disponíveis para comparação.</p>':missing?'<p class="lts-freshness-alert" role="status">'+(st.quoteLoading?'Consultando as referências de mercado…':'Falta uma referência de mercado. Confira as premissas antes de usar as projeções.')+'</p>':failed?'<p class="lts-freshness-alert" role="status">A última atualização não foi concluída. Mantivemos as cotações disponíveis nas datas acima.</p>':aged?'<p class="lts-freshness-alert" role="status">Há referências com mais de quatro dias. Confira a origem antes de usar as projeções.</p>':'')+
    '<details class="lts-update-details"><summary>Atualização</summary><p>Busca automática a cada hora. O preço pode ter atraso; fora do pregão, mantemos o último negócio informado. A PTAX é uma referência diária, não uma cotação intradiária.</p>'+
    [stock,fx].filter(Boolean).map(x=>'<p>'+safeLink(x.source_url,x.source_name)+'<br>Data da cotação: '+esc(stamp(x.quoted_at))+'<br>Recebida no Wealth: '+esc(stamp(x.received_at))+'</p>').join('')+
    '<p>Consulta desta tela: '+esc(stamp(q?.consulted_at))+'. Horários de Brasília. A atualização das projeções preserva os registros históricos.</p>'+
    '<button type="button" class="v168-btn" data-market-read>Conferir atualização</button> <button type="button" class="v168-btn" data-market-mode="'+(manual?'automatic':'manual')+'">'+(manual?'Usar cotações automáticas':'Simular com premissas manuais')+'</button></details><span role="status"></span>';
  }
  function paintQuotes(){
   reset();if(!active())return;
   const host=document.querySelector(V==='Patrimônio'?'.v168-wealth':V==='Dashboard'?'.v168-dashboard':'#never');
   if(host){let panel=document.getElementById('ltsMarketQuotes');if(!panel){panel=document.createElement('article');panel.id='ltsMarketQuotes';panel.className='v168-card lts-market-panel';host.appendChild(panel);}
    const html=quoteMarkup();if(panel.innerHTML!==html){panel.innerHTML=html;panel.querySelector('details').open=st.quoteDetailsOpen;}
    const details=panel.querySelector('details');details.ontoggle=()=>{if(details.isConnected&&document.getElementById('ltsMarketQuotes')===panel)st.quoteDetailsOpen=details.open;};
    panel.querySelector('[data-market-read]').onclick=()=>quotes(true);
    panel.querySelector('[data-market-mode]').onclick=e=>mode(e.currentTarget.dataset.marketMode,e.currentTarget);
   }
   const automatic=st.quotes?.mode!=='manual';
   document.querySelectorAll('.v170-global-award').forEach(form=>form.hidden=automatic);
   document.querySelectorAll('[data-v168-award-edit]').forEach(button=>button.hidden=automatic);
  }
  async function future(force=false){
   reset();if(!active()||st.futureLoading||(!force&&Date.now()-st.futureReadAt<300000))return;
   const current=epoch,today=businessDay(),start=new Date(today+'T12:00:00Z'),end=new Date(today+'T12:00:00Z');start.setUTCDate(start.getUTCDate()-90);end.setUTCFullYear(end.getUTCFullYear()+1);
   st.futureLoading=true;
   try{const r=await S.rpc('lts_browser_future_bank_v293',{p_from:start.toISOString().slice(0,10),p_to:end.toISOString().slice(0,10)});if(r.error||!Array.isArray(r.data?.rows))throw Error();
    if(current!==epoch||owner!==generation())return;st.future=r.data;st.futureError=false;st.futureReadAt=Date.now();
   }catch{if(current===epoch){st.futureError=true;st.futureReadAt=Date.now();}}
   finally{if(current===epoch){st.futureLoading=false;paintFuture();}}
  }
  function paintFuture(){
   if(!active())return;
   const host=document.querySelector(V==='Fluxo Diário'?'.flowbar':V==='Dashboard'?'.v168-dashboard':'#never');if(!host)return;
   let panel=document.getElementById('ltsFutureBank');if(!panel){panel=document.createElement('article');panel.id='ltsFutureBank';panel.className='v168-card lts-future-bank';host.insertAdjacentElement(V==='Fluxo Diário'?'afterend':'beforeend',panel);}
   const rows=(st.future?.rows||[]).filter(x=>V!=='Fluxo Diário'||ACC==='Consolidado'||x.bank===ACC||x.identity?.destination_bank===ACC);
   const isOwn=x=>x.identity?.own_identity_proven===true,isIncluded=x=>x.identity?.represented_in_flow===true,isOverdue=x=>x.status==='overdue_unconfirmed';
   const includedOwn=rows.filter(x=>isOwn(x)&&isIncluded(x)).length,represented=rows.filter(x=>!isOwn(x)&&isIncluded(x)).length;
   const ownReview=rows.filter(x=>isOwn(x)&&!isIncluded(x)&&!isOverdue(x)).length,overdue=rows.filter(isOverdue).length,unlinked=rows.filter(x=>!isOwn(x)&&!isIncluded(x)&&!isOverdue(x)).length;
   const count=(n,one,many)=>n+' '+(n===1?one:many);
   const needsReview=ownReview+overdue+unlinked;
   const rowAmount=x=>isOwn(x)?(V==='Fluxo Diário'&&ACC===x.bank?x.amount:Math.abs(x.amount)):x.amount;
   const rowStatus=x=>isOverdue(x)?'Pagamento a confirmar':isIncluded(x)?'Previsto':'Ainda fora da previsão';
   const open=panel.querySelector('.lts-future-list')?.open===true;
   const updateOpen=panel.querySelector('.lts-schedule-update')?.open===true;
   const html='<details class="lts-future-list"><summary>Agendamentos'+(st.future?' · '+rows.length:'')+'</summary>'+
    (rows.length?rows.map(x=>'<section class="lts-future-row"><div><b>'+esc(x.identity?.projection_description||(isOwn(x)?'Transferência entre contas':x.description))+'</b><small>'+esc(day(x.date))+' · '+esc(x.identity?.destination_bank?x.bank+' → '+x.identity.destination_bank:x.bank)+' · '+rowStatus(x)+'</small><details class="lts-update-details"><summary>Origem</summary><p>'+esc(x.description)+'<br>Recebido no Wealth: '+esc(stamp(x.received_at))+'<br>Atualização no banco: '+esc(stamp(x.source_updated_at))+'</p></details></div><strong>'+money(rowAmount(x))+'</strong><button type="button" class="v168-btn" data-future-day="'+esc(x.date)+'">Ver dia no fluxo</button></section>').join(''):st.future?'<p>Nenhum agendamento disponível.</p>':'<p role="status">Carregando agendamentos…</p>')+'</details>'+
    (st.futureError?'<p class="lts-schedule-alert" role="status">Não conseguimos atualizar os agendamentos. Tente novamente em Atualização.</p>':needsReview?'<p class="lts-schedule-alert" role="status">'+count(needsReview,'agendamento a conferir.','agendamentos a conferir.')+' <button type="button" class="v168-btn" data-future-review>Ver agendamentos</button></p>':'')+
    '<details class="lts-update-details lts-schedule-update"><summary>Atualização</summary>'+
    '<p>Consulta desta tela: '+esc(stamp(st.future?.consulted_at))+'. Horários de Brasília.</p>'+
    '<p>Esta lista mostra os agendamentos disponibilizados pelos bancos. Consulte a origem de cada item para ver quando ele foi atualizado.</p>'+
    '<p>Compras e parcelas futuras dos cartões: '+Number(st.future?.card_future_received||0)+'. Consulte em Cartões e faturas.</p>'+
    '<button type="button" class="v168-btn" data-future-read>Atualizar agendamentos</button></details>';
   if(panel.innerHTML!==html){panel.innerHTML=html;panel.querySelector('.lts-future-list').open=open;panel.querySelector('.lts-schedule-update').open=updateOpen;}
   panel.querySelector('[data-future-read]').onclick=()=>future(true);
   panel.querySelector('[data-future-review]')?.addEventListener('click',()=>{panel.querySelector('.lts-future-list').open=true;panel.querySelector('.lts-future-row')?.scrollIntoView({block:'nearest'});});
   panel.querySelectorAll('[data-future-day]').forEach(button=>button.onclick=async()=>{V='Fluxo Diário';renderNav();await loadFlowRange(button.dataset.futureDay,button.dataset.futureDay);});
  }
  async function openClassification(event,trigger){
   document.getElementById('ltsFlowClassification')?.close();
   const dialog=document.createElement('dialog');dialog.id='ltsFlowClassification';dialog.className='v231-classification-dialog';
   dialog.innerHTML='<form><header><h2>Classificar lançamento</h2><button type="button" class="v168-btn" data-close>Fechar</button></header><p><b>'+esc(event.description)+'</b><br>'+esc(day(event.event_date))+' · '+money(event.signed_amount)+'</p><div data-fields>Carregando classificações…</div><p role="status"></p><button type="submit" class="v168-btn primary" disabled>Salvar classificação</button></form>';
   document.body.appendChild(dialog);dialog.querySelector('[data-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{dialog.remove();trigger?.focus();});dialog.showModal();
   try{
    const options=await window.LTSCategoryRegistry.get(true);if(!dialog.isConnected)return;
    const selected=window.LTSCategoryRegistry.canonical(event.category),submit=dialog.querySelector('[type=submit]');
    dialog.querySelector('[data-fields]').innerHTML='<label>Classificação<select name="category" required><option value="">Selecione…</option>'+options.categories.map(x=>'<option value="'+esc(x)+'"'+(selected===x?' selected':'')+'>'+esc(window.LTSCategoryDisplay.category(x))+'</option>').join('')+'</select></label><label>Pessoa/contexto · opcional<select name="beneficiary"><option value="">Preservar identificação atual</option>'+['Lucas','Larissa','Benjamin','Rafiki'].map(x=>'<option value="'+x+'">'+(x==='Lucas'?'Minha / sem prefixo':x)+'</option>').join('')+'</select></label>';
    window.LTSCategoryRegistry.attach(dialog.querySelector('[name=category]'));submit.disabled=false;
    dialog.querySelector('form').onsubmit=async e=>{
     e.preventDefault();if(submit.disabled)return;submit.disabled=true;
     const status=dialog.querySelector('p[role=status]');status.textContent='Salvando…';
     try{
      const r=await S.rpc('lts_browser_flow_classification_v290',{p_source:event.source,p_source_ref:event.open_finance_id||event.source_ref,p_event_date:event.event_date,p_category:dialog.querySelector('[name=category]').value,p_beneficiary:dialog.querySelector('[name=beneficiary]').value||null});
      if(r.error||r.data?.ok!==true)throw Error();
      dialog.close();const review=window.__LTS_V181_STATE?.review;if(review){review.status='idle';review.data=null;review.key='';}
      window.__LTS_V227_TRANSPORT?.invalidate?.();window.__LTS_V226?.invalidate?.();await loadFlowRange(FLOWFROM,FLOWTO);
     }catch{if(dialog.isConnected){status.textContent='Não foi possível salvar. Confira a conexão e tente novamente.';submit.disabled=false;}}
    };
   }catch{dialog.querySelector('[role=status]').textContent='Não foi possível carregar as classificações. Feche e tente novamente.';}
  }
  function classifyFlow(){
   if(V!=='Fluxo Diário'||typeof dayEvents!=='function')return;
   document.querySelectorAll('.fx87-row[id^="d-"]').forEach(row=>{
    const detail=row.nextElementSibling;if(!detail?.classList.contains('fx89-details'))return;
    const events=dayEvents(row.id.slice(2));detail.querySelectorAll('.fx89-detail-row').forEach((entry,index)=>{
     const event=events[index];if(!event||Number(event.signed_amount)>=0||event.internal_transfer||event.asset_movement||event.excluded_from_spend||event.source==='card_invoice'||entry.querySelector('[data-flow-classify]'))return;
     const button=document.createElement('button');button.type='button';button.className='v168-btn';button.dataset.flowClassify='true';button.textContent='Classificar';button.onclick=()=>openClassification(event,button);
     (entry.querySelector('.fx89-detail-desc')||entry).appendChild(button);
    });
   });
  }
  function paint(){reset();if(!active())return;paintQuotes();paintFuture();classifyFlow();
   if(['Dashboard','Patrimônio','Fluxo Diário'].includes(V)){queueMicrotask(()=>quotes());if(V!=='Patrimônio')queueMicrotask(()=>future());}
  }
  render=function(){const out=previous.apply(this,arguments);paint();return out;};
  window.__LTS_V290_SOURCES={installed:true,state:st,refresh(){quotes(true);future(true);}};
  const style=document.createElement('style');style.textContent='#ltsFutureBank{padding:12px 16px;margin:8px 0}#ltsFutureBank>.lts-future-list>summary{cursor:pointer;font-weight:650;font-size:15px}#ltsFutureBank>.lts-schedule-update{margin-top:6px}#ltsFutureBank>.lts-schedule-update>summary{cursor:pointer;font-size:12px;color:#52657b}#ltsFutureBank .lts-schedule-alert{margin:6px 0 0;line-height:1.4;font-size:13px;color:#7c561e}#ltsFutureBank .lts-schedule-alert .v168-btn{font-size:12px;padding:3px 8px}';document.head.appendChild(style);
  setInterval(()=>{if(active()&&!document.hidden&&['Dashboard','Patrimônio','Fluxo Diário'].includes(V)){quotes();if(V!=='Patrimônio')future();}},300000);
  paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V290_USABILITY)return false;if(!w.__LTS_V290_SOURCES){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V290_SOURCES;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
})();
