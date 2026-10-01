/* Traceable historical invoice audit. Reads only; no financial reclassification. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V235_HISTORY)return;
  const moneyFormat=new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'});
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>x==null?'—':moneyFormat.format(Number(x));
  const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'—';
  const month=x=>/^\d{4}-\d{2}/.test(x||'')?x.slice(5,7)+'/'+x.slice(0,4):'—';
  const statuses={aggregate_only:'Composição não localizada',partial_source:'Composição disponível com diferença',audit_pending:'Origem ainda a conferir'};
  const state={dialog:null,sequence:0};
  async function rpc(name,args){const r=await S.rpc(name,args);if(r.error||!r.data)throw Error('Não foi possível carregar a conferência.');return r.data;}
  function selectedPeriod(){
   const s=window.__LTS_V168_STATE?.expense||{};
   const t=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
   if(s.key==='all')return{p_from:'2013-10-10',p_to:t};
   if(s.key==='custom')return{p_from:s.customFrom,p_to:s.customTo};
   if(s.key==='6m'||s.key==='12m'){const d=new Date(t.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));return{p_from:d.toISOString().slice(0,10),p_to:t};}
   return{p_from:t.slice(0,4)+'-01-01',p_to:t};
  }
  function dialog(title){
   state.dialog?.close();
   const d=document.createElement('dialog');d.className='v226-dialog v235-dialog';d.id='v235-history-dialog';
   d.innerHTML='<header><h2>'+esc(title)+'</h2><button type="button" class="v168-btn" data-v235-close>Fechar</button></header><div data-v235-body role="status">Carregando a conferência…</div>';
   const sequence=++state.sequence;state.dialog=d;document.body.appendChild(d);
   d.querySelector('[data-v235-close]').onclick=()=>d.close();
   d.addEventListener('close',()=>{d.remove();if(state.dialog===d){state.dialog=null;state.sequence++;}});
   d.showModal();return{dialog:d,body:d.querySelector('[data-v235-body]'),sequence};
  }
  const current=x=>x.dialog.isConnected&&state.sequence===x.sequence;
  const origin=ev=>'<details class="v235-source"><summary>Origem conferida nas planilhas</summary>'+ev.map(s=>'<p>'+esc(s.file)+'<br>'+esc(s.sheet)+' · linha '+esc(s.row)+' · '+date(s.date)+' · '+money(s.source_amount)+'</p>').join('')+'</details>';
  async function openRecord(row){
   const host=dialog('Origem e composição da fatura');
   async function load(){
    host.body.innerHTML='<p role="status">Carregando a conferência…</p>';
    try{
     const d=await rpc('lts_browser_card_history_record_v235',{p_source_table:row.source_table,p_source_ref:String(row.source_ref),p_event_date:row.event_date||row.date});
     if(!current(host))return;
     if(d.version!=='card-history-record-v235'||!Array.isArray(d.cycle_records)||!d.cycle_records.length||d.cycle_total==null)throw Error('Conferência incompleta.');
     host.body.innerHTML='<p><b>'+esc(d.bank+' · '+d.card_name)+' · '+month(d.reference_month)+'</b></p><p class="v235-status">'+esc(statuses[d.composition_status]||'Conferência pendente')+'</p><p>'+esc(d.source_note)+'</p>'+
      (d.record?.sign_corrected?'<p class="v235-credit-note">O sinal deste ajuste da planilha foi corrigido de '+money(d.record.original_report_amount)+' para '+money(d.record.amount)+', conforme as duas planilhas originais.</p>':'')+
      '<h3>Pagamentos, créditos e ajustes do ciclo</h3><div class="v226-scroll"><table class="v235-ledger-table"><thead><tr><th>Data do registro</th><th>Origem</th><th>Valor</th></tr></thead><tbody>'+d.cycle_records.map(r=>'<tr data-v235-ledger-row><td data-v235-label="Data do registro">'+date(r.date)+'</td><td data-v235-label="Origem">'+esc(r.kind==='credit_or_adjustment'?'Ajuste negativo':'Pagamento')+' · '+esc(r.description)+origin(r.workbook_evidence||[])+'</td><td data-v235-label="Valor" data-v235-money class="'+(Number(r.amount)<0?'v235-credit':'')+'">'+money(r.amount)+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="2">Total líquido do ciclo</th><td data-v235-money>'+money(d.cycle_total)+'</td></tr></tfoot></table></div>'+
      (d.items?.length?'<h3>Composição encontrada na planilha</h3><p>'+Number(d.nonzero_detail_rows)+' registros com valor em '+Number(d.detail_rows)+' linhas de origem. A data das compras não está disponível.</p><div class="v235-partial-totals"><span>Total encontrado <b>'+money(d.detail_total)+'</b></span><span>Diferença para o ciclo <b>'+money(d.detail_difference)+'</b></span></div><div class="v226-scroll"><table class="v235-source-table"><thead><tr><th>Categoria original</th><th>Referência</th><th>Valor</th></tr></thead><tbody>'+d.items.map(r=>'<tr data-v235-source-item><td data-v235-label="Categoria original">'+esc(r.category)+'</td><td data-v235-label="Referência">'+esc(r.source_sheet)+' · linha '+Number(r.source_row)+'</td><td data-v235-label="Valor" data-v235-money class="'+(Number(r.amount)<0?'v235-credit':'')+'">'+money(r.amount)+'</td></tr>').join('')+'</tbody></table></div><p class="v226-note">As categorias e os sinais da fonte foram preservados. A composição permanece pendente de conciliação.</p>':'');
    }catch{if(current(host)){host.body.innerHTML='<p role="alert">A conferência deste registro não está disponível agora.</p><button class="v168-btn" data-v235-retry>Tentar novamente</button>';host.body.querySelector('[data-v235-retry]').onclick=load;}}
   }
   await load();
  }
  async function openInventory(){
   const p=selectedPeriod(),host=dialog('Faturas com composição pendente');
   async function load(offset=0){
    host.body.innerHTML='<p role="status">Conferindo os ciclos de '+date(p.p_from)+' a '+date(p.p_to)+'…</p>';
    try{
     const d=await rpc('lts_browser_card_history_inventory_v235',{...p,p_offset:offset,p_limit:50});
     if(!current(host))return;
     if(d.version!=='card-history-inventory-v235'||!Array.isArray(d.cycles)||!d.summary)throw Error('Inventário incompleto.');
     const s=d.summary;
     host.body.innerHTML='<p>Período selecionado: '+date(d.from)+' a '+date(d.to)+'</p><p><b>'+Number(s.record_count)+' registros de pagamento e ajustes em '+Number(s.cycle_count)+' ciclos.</b> Ajustes negativos das planilhas reduzem o total.</p><p>'+Number(s.aggregate_only_cycles)+' ciclos com composição não localizada nas fontes disponíveis; '+Number(s.partial_source_cycles)+' com composição disponível e diferença.'+(s.audit_pending_cycles?' '+Number(s.audit_pending_cycles)+' ciclos ainda precisam da conferência de origem.':'')+'</p><p class="v235-inventory-total">Total líquido no período: <b>'+money(s.total)+'</b></p>'+
      (d.cycles.length?'<div class="v226-scroll"><table class="v235-inventory-table"><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Registros</th><th>Valor líquido</th><th>Composição</th></tr></thead><tbody>'+d.cycles.map((r,i)=>'<tr data-v235-cycle-row><td data-v235-label="Banco / cartão"><button class="v226-link" data-v235-cycle="'+i+'">'+esc(r.bank+' · '+r.card_name)+'</button></td><td data-v235-label="Ciclo">'+month(r.reference_month)+'</td><td data-v235-label="Registros">'+Number(r.record_count)+'</td><td data-v235-label="Valor líquido" data-v235-money><button class="v226-link" data-v235-cycle="'+i+'">'+money(r.amount)+'</button></td><td data-v235-label="Composição">'+esc(statuses[r.composition_status]||'Conferência pendente')+'</td></tr>').join('')+'</tbody></table></div><div class="v235-pagination"><button class="v168-btn" data-v235-prev '+(offset===0?'disabled':'')+'>Anterior</button><span>Ciclos '+(offset+1)+' a '+(offset+d.cycles.length)+' de '+Number(s.cycle_count)+'</span><button class="v168-btn" data-v235-next '+(d.next_offset==null?'disabled':'')+'>Próximos</button></div>':'<p>Não há composição pendente neste período.</p>');
     host.body.querySelector('[data-v235-prev]')?.addEventListener('click',()=>load(Math.max(0,offset-50)));
     host.body.querySelector('[data-v235-next]')?.addEventListener('click',()=>{if(d.next_offset!=null)load(d.next_offset);});
     host.body.querySelectorAll('[data-v235-cycle]').forEach(b=>b.onclick=()=>openRecord(d.cycles[Number(b.dataset.v235Cycle)]));
    }catch{if(current(host)){host.body.innerHTML='<p role="alert">Não foi possível conferir as faturas do período.</p><button class="v168-btn" data-v235-retry>Tentar novamente</button>';host.body.querySelector('[data-v235-retry]').onclick=()=>load(offset);}}
   }
   await load();
  }
  function paint(){
   if(typeof D==='undefined'||!D||N.classList.contains('hidden'))return;
   const h=document.querySelector('.v226-history');
   if(V==='Despesas'&&h&&!h.querySelector('[data-v235-open]')){
    const b=document.createElement('button');b.className='v168-btn';b.dataset.v235Open='';b.textContent='Conferir todas as composições pendentes';b.onclick=openInventory;h.appendChild(b);
   }
   const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let text;
   while((text=walker.nextNode())){
    if(text.parentElement?.closest('script,style'))continue;
    let value=text.nodeValue.replace(/Faturas sem composição individual/g,'Faturas com composição pendente').replace(/faturas sem composição individual/g,'faturas com composição pendente');
    if(text.parentElement?.closest('.v172-coverage,.v178-coverage'))value=value.replace(/ciclo\(s\)/g,'registro(s) de pagamento ou ajuste');
    if(value!==text.nodeValue)text.nodeValue=value;
   }
  }
  const previous=render;render=function(){const result=previous();paint();return result;};
  let scheduled=false;const observer=new MutationObserver(()=>{if(!scheduled){scheduled=true;requestAnimationFrame(()=>{scheduled=false;paint();});}});
  observer.observe(document.body,{childList:true,subtree:true});
  window.__LTS_V235_HISTORY={openRecord,openInventory};paint();
 }
 let attempts=0;
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V181_REGRESSION_CLOSURE||!w?.__LTS_V226)return false;
  if(!d.getElementById('v235-style')){const s=d.createElement('style');s.id='v235-style';s.textContent='.v235-dialog{max-height:90vh;width:min(1040px,94vw);box-sizing:border-box;padding:0}.v235-dialog[open]{display:flex;flex-direction:column}.v235-dialog>header{position:static;flex:none;margin:0;padding:18px}.v235-dialog [data-v235-body]{padding:18px;overflow:auto;min-height:0;flex:1}.v235-dialog table{font-size:14px}.v235-dialog td{vertical-align:top}.v235-dialog td:last-child{white-space:nowrap}.v235-dialog h3{margin-top:22px}.v235-source{margin-top:8px;max-width:400px;font-size:13px;overflow-wrap:anywhere}.v235-source p{margin:8px 0}.v235-status{font-weight:700}.v235-credit,.v235-credit-note{color:#157347}.v235-partial-totals,.v235-pagination{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:14px;margin:16px 0}.v235-partial-totals span{display:grid;gap:5px}.v235-inventory-total{font-size:17px}.v235-dialog .v226-scroll{max-width:100%}@media(max-width:520px){.v235-dialog{width:96vw}.v235-dialog [data-v235-body]{padding:12px}.v235-dialog header{padding:12px}.v235-dialog header h2{font-size:18px}.v235-dialog h3{font-size:17px}.v235-dialog .v226-scroll{overflow:visible}.v235-dialog table,.v235-dialog tbody,.v235-dialog tfoot{display:block;min-width:0;width:100%}.v235-dialog thead{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%)}.v235-dialog tbody tr{display:grid;grid-template-columns:minmax(0,1fr) max-content;gap:12px;padding:14px 0;border-bottom:1px solid #dbe5f0}.v235-dialog td{display:block;min-width:0;max-width:100%;border:0;padding:0;white-space:normal;overflow-wrap:anywhere}.v235-dialog td[data-v235-label]:before{content:attr(data-v235-label);display:block;color:#687c91;font-size:11px;line-height:1.4;margin-bottom:4px}.v235-dialog td[data-v235-money]{font-weight:700;white-space:nowrap}.v235-dialog .v235-ledger-table tbody td:nth-child(2),.v235-dialog .v235-source-table tbody td:nth-child(2){grid-column:1/-1;grid-row:2}.v235-dialog .v235-source{max-width:100%}.v235-dialog tfoot tr{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 0}.v235-dialog tfoot th{min-width:0;border:0;padding:0;text-align:left}.v235-dialog .v235-inventory-table tbody tr{grid-template-columns:repeat(2,minmax(0,1fr))}.v235-dialog .v235-inventory-table tbody td:nth-child(1),.v235-dialog .v235-inventory-table tbody td:nth-child(4),.v235-dialog .v235-inventory-table tbody td:nth-child(5){grid-column:1/-1}}';d.head.appendChild(s);}
  if(!w.__LTS_V235_HISTORY){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return Boolean(w.__LTS_V235_HISTORY);
 }catch{return false;}}
 function start(){if(!install()&&++attempts<400)setTimeout(start,75);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
})();
