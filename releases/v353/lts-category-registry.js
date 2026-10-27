/* One shared registry. Creating a category never classifies or changes a financial event. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.LTSCategoryRegistry)return;
  let data=null,reading=null,readAt=0,epoch=0,creating=0;
  const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  let owner=generation();
  function session(){
   if(owner!==generation()){owner=generation();data=null;reading=null;readAt=0;epoch++;}
  }
  const canonical=value=>{session();return data?.aliases?.[value]||value;};
  function populate(select,selected,force=false){
   if(!select?.isConnected||!data)return;
   if(document.activeElement===select&&!force){
    select.addEventListener('blur',()=>populate(select,select.value),{once:true});return;
   }
   const empty=select.options[0]?.value===''?select.options[0].textContent:'Selecione…';
   const value=canonical(selected??select.value);
   select.innerHTML='<option value="">'+esc(empty)+'</option>'+data.categories.map(c=>'<option value="'+esc(c)+'"'+(c===value?' selected':'')+'>'+esc(window.LTSCategoryDisplay.category(c))+'</option>').join('');
  }
  async function get(force=false){
   session();if(!force&&data&&Date.now()-readAt<60000)return data;
   if(reading)return reading;
   const current=epoch;
   reading=(async()=>{
    const result=await S.rpc('lts_browser_card_category_options_v226',{});
    if(result.error||!Array.isArray(result.data?.categories))throw Error('As classificações não foram carregadas. Tente novamente.');
    if(current!==epoch||owner!==generation())throw Error('A sessão mudou. Abra novamente.');
    data=result.data;readAt=Date.now();return data;
   })().finally(()=>{if(current===epoch)reading=null;});
   return reading;
  }
  function changed(result){
   const review=window.__LTS_V181_STATE?.review;
   if(review?.data)review.data.category_options=result.categories;
   if(window.__LTS_V226)window.__LTS_V226.options=result.categories;
   document.querySelectorAll('select[data-lts-category]').forEach(select=>populate(select));
   window.dispatchEvent(new CustomEvent('lts:categories-changed',{detail:{categories:result.categories}}));
  }
  function attach(select){
   session();
   if(!select||select.dataset.ltsCategory)return;
   select.dataset.ltsCategory='shared';
   const details=document.createElement('details');details.className='lts-new-category';
   details.innerHTML='<summary>Criar nova classificação</summary><label>Nome da classificação<input type="text" minlength="2" maxlength="80" autocomplete="off" placeholder="Ex.: Manutenção"></label><button type="button" class="v168-btn" data-category-create>Criar classificação</button><span role="status" aria-live="polite"></span>';
   const anchor=select.parentElement?.tagName==='LABEL'?select.parentElement:select;
   anchor.insertAdjacentElement('afterend',details);
   const input=details.querySelector('input'),button=details.querySelector('button'),status=details.querySelector('[role=status]');
   details.addEventListener('toggle',()=>{if(details.open)input.focus();});
   input.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();button.click();}});
   button.onclick=async()=>{
    const name=input.value.trim();if(button.disabled)return;
    if(name.length<2||name.length>80){status.textContent='Informe um nome entre 2 e 80 caracteres.';return;}
    button.disabled=true;status.textContent='Criando…';const current=epoch,reviewKey=select.closest('[data-v181-review-key]')?.dataset.v181ReviewKey,cardKey=select.closest('[data-v226-classify]')?.dataset.v226Classify,dialogId=select.closest('dialog')?.id;creating++;
    try{
     const saved=await S.rpc('lts_browser_category_create_v1',{p_category:name});
     if(saved.error||saved.data?.ok!==true)throw Error(saved.error?.message||'Tente novamente.');
     if(current!==epoch||owner!==generation())return;
     // The creation response is authoritative. Do not let an older in-flight
     // options request or an asynchronous row refresh discard this choice.
     if(Array.isArray(saved.data.categories)){data={...(data||{}),categories:saved.data.categories,revision:saved.data.revision};readAt=Date.now();}
     else await get(true);
     const review=window.__LTS_V181_STATE?.review;
     if(reviewKey&&review?.drafts)review.drafts.set(reviewKey,{...(review.drafts.get(reviewKey)||{}),category:saved.data.category});
     changed(data);
     const target=select.isConnected?select:reviewKey?[...document.querySelectorAll('[data-v181-review-key]')].find(row=>row.dataset.v181ReviewKey===reviewKey)?.querySelector('[data-v181-category]'):cardKey?[...document.querySelectorAll('[data-v226-classify]')].find(form=>form.dataset.v226Classify===cardKey)?.querySelector('[name=category]'):document.getElementById(dialogId||'')?.querySelector('[name=category]');
     if(target){populate(target,saved.data.category,true);target.value=saved.data.category;target.dispatchEvent(new Event('change',{bubbles:true}));target.focus();}
     details.open=false;input.value='';status.textContent='Classificação criada e disponível no fluxo e nos cartões.';
    }catch{if(details.isConnected)status.textContent='Não foi possível criar a classificação. Confira a conexão e tente novamente.';}
    finally{creating=Math.max(0,creating-1);button.disabled=false;}
   };
   if(data)populate(select);
   else get().then(()=>populate(select)).catch(()=>{status.textContent='Não foi possível carregar a lista. Reabra para tentar novamente.';});
  }
  window.LTSCategoryRegistry={get,attach,canonical,get busy(){return creating>0;},reset(){epoch++;data=null;reading=null;readAt=0;}};
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V178_REVIEW_ACTIONS?.installed)return false;if(!w.LTSCategoryRegistry){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.LTSCategoryRegistry;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-category-registry.js',install);
})();
