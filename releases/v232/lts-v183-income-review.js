/* Candidate-only receipt review. No amount/date mutation and no broad rule. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_INCOME_REVIEW)return;
  const oldBadge=flowClassificationBadge,oldBind=bindFlowEditor;
  const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function receiptKey(e){return JSON.stringify([e.source||e.source_table||'',e.source_ref||'',e.event_date||'',e.account||'',String(e.signed_amount??'')])}
  function isUnclassifiedReceipt(e){return Number(e.signed_amount)>0&&['','a classificar','—','classificação pendente'].includes(String(e.category||'').trim().toLowerCase())}
  function request(e){return {p_source:e.source||e.source_table||'',p_source_ref:String(e.source_ref||''),p_event_date:e.event_date,p_account:e.account,p_amount:Number(e.signed_amount)}}
  function invalidateMonthly(){
   const monthly=window.__LTS_V175_STATE?.monthly;
   if(monthly){monthly.token=(monthly.token||0)+1;monthly.key='';monthly.data=null;monthly.loading=false;monthly.error=null;monthly.progress=''}
  }
  async function openReceipt(e,trigger){
   document.getElementById('v183-income-dialog')?.remove();
   const dialog=document.createElement('dialog');dialog.id='v183-income-dialog';
   dialog.setAttribute('aria-labelledby','v183-income-title');
   dialog.innerHTML='<h2 id="v183-income-title">Revisar esta receita</h2><p><strong>'+safe(e.description||'Recebimento')+'</strong><br>'+safe(e.event_date)+' · '+safe(e.account)+' · '+safe(brl(e.signed_amount))+'</p><p>Somente a categoria deste lançamento. Valor, data, conta e saldo não serão alterados.</p><div class="income-content" aria-live="polite">Conferindo a origem…</div><p class="income-status" role="status"></p><div class="income-actions"><button type="button" class="chip income-close">Fechar</button></div>';
   document.body.appendChild(dialog);let saving=false,preview=null;
   const status=dialog.querySelector('.income-status'),content=dialog.querySelector('.income-content'),close=dialog.querySelector('.income-close');
   const finish=()=>{if(saving)return;dialog.close();dialog.remove();if(trigger?.isConnected)trigger.focus()};
   close.onclick=finish;dialog.oncancel=event=>{event.preventDefault();finish()};dialog.showModal();close.focus();
   try{
    const {data,error}=await S.rpc('lts_browser_income_category_v183',request(e));
    if(!dialog.isConnected)return;
    if(error||!data?.ok)throw Error(error?.message||'Não foi possível conferir a origem.');
    if(!data.editable){content.textContent=(data.reason||'Classificação preservada.')+(data.category?' Categoria: '+data.category+'.':'');return}
    if(!data.token||!Array.isArray(data.options)||!data.options.length)throw Error('Conferência incompleta; nenhuma gravação disponível.');
    preview=data;
    content.innerHTML='<label for="v183-income-category">Categoria da receita</label><select id="v183-income-category"><option value="">Selecione…</option>'+data.options.map(x=>'<option value="'+safe(x)+'">'+safe(x)+'</option>').join('')+'</select><p>Não cria uma regra para outros lançamentos com a mesma descrição.</p>';
    const select=content.querySelector('select'),save=document.createElement('button');save.type='button';save.className='chip';save.textContent='Salvar somente esta categoria';save.disabled=true;
    dialog.querySelector('.income-actions').prepend(save);select.onchange=()=>{save.disabled=!select.value};select.focus();
    save.onclick=async()=>{
     if(saving||!preview.options.includes(select.value))return;
     saving=true;save.disabled=true;select.disabled=true;close.disabled=true;status.textContent='Salvando a categoria…';
     try{
      const result=await S.rpc('lts_browser_income_category_v183',{...request(e),p_category:select.value,p_expected:preview.token});
      if(result.error||!result.data?.saved)throw Error(result.error?.message||result.data?.reason||'A categoria não foi salva.');
      invalidateMonthly();status.textContent='Categoria salva. Valores e saldos preservados.';save.remove();
      // Refresh only the current selected range; never switch to expenses.
      await loadFlowRange(FLOWFROM||e.event_date,FLOWTO||e.event_date);
     }catch(err){
      status.textContent=String(err?.message||err)+' Feche e confira novamente antes de tentar salvar.';
      // No automatic retry after a potentially committed request.
      save.remove();
     }finally{saving=false;close.disabled=false;close.focus()}
    };
   }catch(err){if(dialog.isConnected)content.textContent=String(err?.message||err)}
  }
  flowClassificationBadge=function(e){return isUnclassifiedReceipt(e)?'<button type="button" class="tag flow-unclassified v183-income-review" data-income-key="'+safe(receiptKey(e))+'">Receita a classificar · revisar</button>':oldBadge(e)};
  bindFlowEditor=function(){const result=oldBind();document.querySelectorAll('.v183-income-review').forEach(button=>button.onclick=()=>{
   const matches=mergedFlowEvents().filter(e=>receiptKey(e)===button.dataset.incomeKey);
   if(matches.length===1)openReceipt(matches[0],button);else alert('Lançamento ausente ou ambíguo. Atualize o período antes de revisar.');
  });return result};
  const style=document.createElement('style');style.textContent='#v183-income-dialog{color:#17283c;border:1px solid #cfdae4;border-radius:18px;padding:24px;width:min(520px,calc(100vw - 32px));max-height:calc(100dvh - 32px);overflow:auto;box-sizing:border-box;box-shadow:0 20px 80px #0004}#v183-income-dialog::backdrop{background:#10203388}#v183-income-dialog select{display:block;width:100%;padding:12px;margin:8px 0;border:1px solid #aebdca;border-radius:8px}#v183-income-dialog .income-actions{display:flex;flex-wrap:wrap;justify-content:flex-end;gap:12px}#v183-income-dialog p{line-height:1.5}';document.head.appendChild(style);
  window.__LTS_V183_INCOME_REVIEW={installed:true,source_keyed:true,cash_unchanged:true};
  if(D&&!N.classList.contains('hidden')&&V==='Fluxo Diário')render();
 }
 const shell=document.getElementById('shell');
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V182_FEEDBACK?.installed)return false;if(w.__LTS_V183_INCOME_REVIEW)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);return !!w.__LTS_V183_INCOME_REVIEW}catch{return false}}
 let attempts=0;const timer=setInterval(()=>{if(install()||++attempts>160)clearInterval(timer)},150);
 shell?.addEventListener('load',()=>{attempts=0;const retry=setInterval(()=>{if(install()||++attempts>160)clearInterval(retry)},150)});
})();
