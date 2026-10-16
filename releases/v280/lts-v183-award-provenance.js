/* Candidate-only: statement != model. Display provenance without repricing. */
(function(){
 'use strict';
 function runtime(){
  if(window.__LTS_V183_AWARD_PROVENANCE)return;
  const v168=window.__LTS_V168_STATE,previousWealth=patrimonio,previousRender=render;
  const state=window.__LTS_V183_AWARD_PROVENANCE={installed:true,status:'idle',token:0,data:null,error:null};
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const finite=x=>x==null||x===''?null:Number.isFinite(Number(x))?Number(x):null;
  const money=x=>finite(x)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x));
  const number=x=>finite(x)==null?'—':Number(x).toLocaleString('pt-BR',{maximumFractionDigits:6});
  const date=x=>/^\d{4}-\d\d-\d\d/.test(String(x||''))?String(x).slice(0,10).split('-').reverse().join('/'):'não informada';
  const arr=x=>Array.isArray(x)?x:[];
  function scheduleSummary(rows){
   if(!Array.isArray(rows)||!rows.length)return null;
   let regular=0,cash=0,regularQuantity=0,cashQuantity=0;
   for(const row of rows){
    if(!/^(RSU|Cash RSU)$/i.test(String(row.asset_type||'')))return null;
    const isCash=/cash/i.test(String(row.asset_type||''));
    const value=finite(isCash?row.net_value_brl:row.gross_value_brl),quantity=finite(row.quantity);
    if(value===null||quantity===null)return null;
    if(isCash){cash+=Math.round(value*100);cashQuantity+=quantity}else{regular+=Math.round(value*100);regularQuantity+=quantity}
   }
   return {regular:regular/100,cash:cash/100,total:(regular+cash)/100,regularQuantity,cashQuantity};
  }
  function matches(row,group){
   if(!row||!group||row.group_key!==group.group_key)return false;
   const considered=/cash/i.test(String(row.asset_type))?row.net_value_brl:row.gross_value_brl;
   const valuesMatch=[[row.quantity,group.quantity],[row.gross_value_brl,group.gross_value_brl],[considered,group.considered_value_brl]]
    .every(([a,b])=>finite(a)!==null&&finite(b)!==null&&Math.abs(Number(a)-Number(b))<0.005);
   const parts=arr(group.components);
   return valuesMatch&&parts.length>0&&['unit_price_usd','fx_rate'].every(key=>{
    const values=parts.map(x=>finite(x[key]));if(values.some(x=>x===null))return false;
    const unique=[...new Set(values)];return unique.length>1?finite(row[key])===null:finite(row[key])===unique[0];
   });
  }
  function origin(component){
   if(component.provenance==='manual')return 'Premissa manual · registrada em '+date(component.assumption_recorded_at);
   return component.provenance==='historical_assumption'?'Premissa histórica importada · data da cotação não informada':'Premissa cadastrada · origem e data da cotação não comprovadas';
  }
  function componentHtml(component,isCash){
   const manual=origin(component),delta=finite(component.calculation_delta_brl);
   return '<li><b>'+esc(manual)+'</b><br>'+number(component.quantity)+' × US$ '+number(component.unit_price_usd)+' × câmbio '+number(component.fx_rate)+' = '+money(component.calculated_gross_brl)+' bruto.'+
    (isCash?' Considerado após reserva de 30%: '+money(component.considered_value_brl)+'.':' Considerado a 100%.')+
    (delta!==null&&Math.abs(delta)>=0.005?' Valor registrado: '+money(component.gross_value_brl)+'; diferença de cálculo '+money(delta)+', preservada para conferência.':'')+
    '<br><small>Registro de origem atualizado em '+date(component.source_updated_at)+'. Essa data não é a data de mercado da cotação. Disponibilidade projetada pelo prazo cadastrado de '+esc(component.settlement_days??'não informado')+' dias corridos; não comprova liquidação ou recebimento bancário.</small></li>';
  }
  async function load(force=false){
   if(state.status==='loading'||(!force&&state.status!=='idle'))return;
   const token=++state.token;state.status='loading';state.error=null;
   try{
    const response=await S.rpc('lts_browser_award_provenance_v183');
    if(token!==state.token)return;
    if(response.error||response.data?.financial_effect!=='none'||!Array.isArray(response.data?.groups))throw Error('Não foi possível conferir a origem das premissas.');
    state.data=response.data;state.status='ready';
   }catch(error){if(token!==state.token)return;state.status='error';state.data=null;state.error=String(error?.message||error)}
   if(V==='Patrimônio'&&v168.wealth.tab==='rsu')render();
  }
  function invalidate(){state.token++;state.status='idle';state.data=null;state.error=null}
  function decorate(html){
   if(v168.wealth.tab!=='rsu')return html;
   const rows=arr(v168.wealth.data?.rsu?.future_schedule),summary=scheduleSummary(rows);
   const t=document.createElement('template');t.innerHTML=html;
   const root=t.content.querySelector('.v168-wealth');if(!root)return html;
   const agenda=[...root.querySelectorAll('article')].find(x=>x.querySelector('h2')?.textContent==='Vestings e disponibilidade');
   if(agenda){
    const total=agenda.querySelector('.v168-cardhead strong');if(total)total.textContent=money(summary?.total);
    const help=agenda.querySelector('.v170-reconciliation');
    if(help){
     const note=document.createElement('p');note.className='v183-award-model-note';
     note.textContent=summary?'Total da agenda: '+money(summary.total)+' = RSUs '+money(summary.regular)+' + Cash RSUs após reserva '+money(summary.cash)+'. Quantidades da agenda: '+number(summary.regularQuantity)+' RSUs e '+number(summary.cashQuantity)+' Cash RSUs. Não substitui o extrato nem comprova a quantidade da posição atual.':'Total da agenda indisponível: falta valor ou quantidade em pelo menos um vesting. Nenhuma soma parcial é apresentada.';
     help.prepend(note);
    }
    const cards=[...agenda.querySelectorAll('.v168-award')];
    cards.forEach((card,index)=>{
     const row=rows[index],group=arr(state.data?.groups).find(x=>x.group_key===row?.group_key);
     const available=card.children[3]?.querySelector('small');
     if(available)available.textContent=date(row?.available_date)+' · disponibilidade projetada';
     const detail=document.createElement('details');detail.className='v183-award-source';
     detail.innerHTML='<summary>Origem e cálculo desta premissa</summary>'+
      (state.status==='ready'&&matches(row,group)?'<ul>'+arr(group.components).map(x=>componentHtml(x,/cash/i.test(String(row.asset_type)))).join('')+'</ul>':
       '<p>'+esc(state.status==='ready'?'A agenda mudou desde a leitura. Atualize a conferência antes de usar esta composição.':state.status==='error'?'Origem indisponível. A cotação não está sendo apresentada como preço de mercado atual.':'Conferindo a origem da cotação e do câmbio…')+'</p>');
     card.appendChild(detail);
    });
   }
   const form=root.querySelector('.v170-global-award');
   if(form){const note=document.createElement('div');note.className='v168-note v183-award-provenance-note';
    note.innerHTML='<b>Premissas de planejamento, não cotação ao vivo.</b> Preço e câmbio atualizam somente a agenda; não reescrevem o extrato ou as quantidades e não lançam dinheiro no banco. A data de origem aparece em cada vesting; quando ausente, permanece explicitamente desconhecida. <button type="button" class="v168-btn" data-v183-award-refresh>Atualizar conferência</button>';
    form.appendChild(note);
   }
   return t.innerHTML;
  }
  patrimonio=function(){return decorate(previousWealth())};
  render=function(){const out=previousRender();
   if(V==='Patrimônio'&&v168.wealth.tab==='rsu'){
    if(state.status==='idle')queueMicrotask(()=>load());
    const retry=document.querySelector('[data-v183-award-refresh]');if(retry)retry.onclick=()=>load(true);
   }
   return out;
  };
  // Preserve the existing audited writers. Observe only successful, explicit
  // writes so this reader cannot retain old provenance after a quote/date edit.
  const rpc=S.rpc.bind(S),writers=new Set(['lts_browser_save_all_award_assumptions_v1','lts_browser_save_award_assumption_v1','lts_browser_save_vesting_anticipation_v1']);
  S.rpc=function(name,args,...rest){const result=rpc(name,args,...rest);if(!writers.has(name))return result;
   return Promise.resolve(result).then(response=>{if(!response.error&&response.data?.ok){invalidate();queueMicrotask(()=>window.__LTS_V178_REVIEW?.refresh?.())}return response});
  };
  S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT')invalidate()});
  const css=document.createElement('style');css.textContent='.v183-award-source{grid-column:1/-1;min-width:0;max-width:100%;font-size:12px;line-height:1.55}.v183-award-source summary{cursor:pointer;color:#425e7b}.v183-award-source ul{padding-left:20px;white-space:normal;overflow-wrap:anywhere}.v183-award-source li+li{margin-top:10px}.v183-award-model-note{margin:0 0 8px;white-space:normal}.v183-award-provenance-note{white-space:normal;line-height:1.5}';document.head.appendChild(css);
  if(D&&!N.classList.contains('hidden')&&V==='Patrimônio')render();
 }
 const shell=document.getElementById('shell');let generation=0;
 function burst(){const current=++generation;let attempts=0;function install(){
  if(current!==generation)return;
  try{const w=shell?.contentWindow,d=shell?.contentDocument;
   if(w?.__LTS_V183_WEALTH_INTEGRITY?.installed){if(!w.__LTS_V183_AWARD_PROVENANCE){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s)}return}
  }catch{}
  if(++attempts<160)setTimeout(install,150);
 }install()}
 shell?.addEventListener('load',burst);burst();
})();
