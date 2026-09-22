/* V181 closes the card-flow regression and turns pending identifications into an authenticated review workflow. */
(function(){
 'use strict';
 const outer=document.getElementById('shell');let generation=0;
 function runtime(){
  'use strict';
  if(window.__LTS_V181_REGRESSION_CLOSURE?.installed||!window.__LTS_V180_DOCUMENTARY_REFRESH?.installed||!window.__LTS_V178_REVIEW_ACTIONS?.installed)return;
  const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE,v178=window.__LTS_V178_STATE,detailApi=window.__LTS_V178_REVIEW;
  const previousRender=render,previousNav=renderNav,previousExpenses=despesas,previousUpdates=atualizacoes;
  const state=window.__LTS_V181_STATE={
   review:{status:'idle',data:null,error:null,key:'',offset:0,query:'',saving:null,notice:''},
   reconciliation:{status:'idle',data:null,error:null,key:''},
   categoryView:'beneficiary',focusQueue:false
  };
  const arr=value=>Array.isArray(value)?value:[];
  const finite=value=>value===null||value===undefined||value===''?null:(Number.isFinite(Number(value))?Number(value):null);
  const sum=values=>arr(values).reduce((total,value)=>total+(finite(value)||0),0);
  const escape=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const normalize=value=>String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
  const money=value=>finite(value)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',minimumFractionDigits:2,maximumFractionDigits:2}).format(Number(value));
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const dateLabel=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''))?String(value).split('-').reverse().join('/'):String(value||'—');
  const monthLabel=value=>{const key=String(value||'').slice(0,7);return /^\d{4}-\d{2}$/.test(key)?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}).format(new Date(key+'-01T12:00:00Z')).replace('.',''):key||'—'};
  const template=html=>{const node=document.createElement('template');node.innerHTML=html;return node};
  function addDays(value,days){const date=new Date(String(value).slice(0,10)+'T12:00:00Z');date.setUTCDate(date.getUTCDate()+days);return date.toISOString().slice(0,10)}
  function expenseRange(){
   const source=v168?.expense||{},end=today(),year=end.slice(0,4);let from=year+'-01-01',label='Ano atual';
   if(source.key==='all'){from='2013-10-10';label='Desde 2013'}
   else if(source.key==='6m'||source.key==='12m'){const date=new Date(end.slice(0,7)+'-01T12:00:00Z');date.setUTCMonth(date.getUTCMonth()-(source.key==='6m'?5:11));from=date.toISOString().slice(0,10);label=source.key==='6m'?'6 meses':'12 meses'}
   else if(source.key==='custom'){from=source.customFrom||from;label='Período personalizado'}
   return{from,to:source.key==='custom'?(source.customTo||end):end,label};
  }
  async function rpc(name,args,timeoutMs=22000){
   let timer;const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Tempo de leitura excedido.')),timeoutMs)});
   try{const result=await Promise.race([S.rpc(name,args||{}),timeout]);if(result?.error||result?.data==null)throw Error(result?.error?.message||name+' indisponível');return result.data}
   finally{clearTimeout(timer)}
  }
  function optionRows(values,empty){
   const seen=new Set(),items=[];
   for(const raw of arr(values)){const value=String(typeof raw==='string'?raw:(raw?.value??raw?.label??'')).trim(),label=String(typeof raw==='string'?raw:(raw?.label??raw?.value??'')).trim();if(!value||seen.has(value)||/^(a classificar|identifica[cç][oõ]es pendentes)$/i.test(value))continue;seen.add(value);items.push({value,label:label||value})}
   return '<option value="">'+escape(empty)+'</option>'+items.map(item=>'<option value="'+escape(item.value)+'">'+escape(item.label)+'</option>').join('');
  }
  async function ensureReview(force=false){
   const range=expenseRange(),s=state.review,key=[range.from,range.to,s.offset,s.query].join('|');
   if(s.status==='loading'||(!force&&s.status==='ready'&&s.key===key))return;
   s.status='loading';s.error=null;s.key=key;render();
   try{s.data=await rpc('lts_browser_expense_review_queue_v181',{p_from:range.from,p_to:range.to,p_offset:s.offset,p_limit:25,p_query:s.query||null});s.status='ready'}
   catch(error){s.status='error';s.error=String(error?.message||error)}
   finally{render()}
  }
  async function ensureReconciliation(force=false){
   const s=state.reconciliation,from=today(),to=addDays(from,730),key=from+'|'+to;
   if(s.status==='loading'||(!force&&s.status==='ready'&&s.key===key))return;
   s.status='loading';s.error=null;s.key=key;render();
   try{s.data=await rpc('lts_browser_invoice_flow_reconciliation_v181',{p_from:from,p_to:to});s.status='ready'}
   catch(error){s.status='error';s.error=String(error?.message||error)}
   finally{render()}
  }
  function reviewFields(row,data){
   const person=optionRows(data?.beneficiary_options,'Selecione a pessoa/contexto'),property=optionRows(data?.property_options,'Selecione o imóvel'),category=optionRows(data?.category_options,'Selecione a categoria');
   if(row.question_kind==='person')return '<label>Pessoa/contexto<select data-v181-beneficiary>'+person+'</select></label>';
   if(row.question_kind==='property')return '<label>Imóvel<select data-v181-property>'+property+'</select></label>';
   if(row.question_kind==='property_purpose')return '<label>Finalidade/categoria<select data-v181-category>'+category+'</select></label>';
   return '<label>Pessoa/contexto <small>opcional</small><select data-v181-beneficiary>'+person+'</select></label><label>Categoria <small>opcional</small><select data-v181-category>'+category+'</select></label>';
  }
  function reviewPanel(){
   const s=state.review,data=s.data||{},rows=arr(data.rows),busy=s.status==='loading';
   const head='<article class="v168-card v181-review" id="v181ReviewQueue"><div class="v168-cardhead"><div><span>Classificação assistida</span><h2>Identificações pendentes</h2></div><strong>'+(data.row_count??'—')+'</strong></div><p class="v181-lead">Escolha somente o que você reconhece. Para despesas suas, use <b>Minha / sem prefixo</b>; a categoria aparecerá como “Saúde”, “Vestuário” etc., sem seu nome na frente.</p>';
   if(s.status==='idle'||(busy&&!s.data))return head+'<div class="v181-loading">Carregando as decisões abertas…</div></article>';
   if(s.status==='error'&&!s.data)return head+'<div class="v168-error">'+escape(s.error)+'</div><button class="v168-btn primary" data-v181-review-retry>Tentar novamente</button></article>';
   const notice=s.notice?'<div class="v181-success" role="status">'+escape(s.notice)+'</div>':'';
   const search='<div class="v181-review-search"><input type="search" data-v181-review-query value="'+escape(s.query)+'" placeholder="Buscar descrição, conta ou categoria"><button class="v168-btn" data-v181-review-search>Buscar</button></div>';
   const body=rows.map(row=>'<section class="v181-review-row" data-v181-review-key="'+escape(row.key)+'"><div class="v181-review-fact"><span>'+escape(dateLabel(row.date))+' · '+escape(row.account_source||'Origem não informada')+'</span><b>'+escape(row.description||'Lançamento')+'</b><small>Atual: '+escape(row.beneficiary||'pessoa não identificada')+' · '+escape(row.category||'categoria não identificada')+'</small></div><strong>'+money(row.amount)+'</strong><div class="v181-question"><b>'+escape(row.review_question||'Confirme a classificação correta.')+'</b><div class="v181-fields">'+reviewFields(row,data)+'</div><small data-v181-choice-note>Nenhuma opção é presumida.</small></div><button class="v168-btn primary" data-v181-review-save disabled>Salvar classificação</button></section>').join('')||'<div class="v168-empty">Nenhuma identificação pendente neste recorte.</div>';
   const start=Number(data.offset||0),matched=Number(data.matched_count??data.row_count??0),prev=start>0,next=data.next_offset!=null;
   const paging='<div class="v181-paging"><span>'+(matched?((start+1)+'–'+Math.min(start+rows.length,matched)+' de '+matched):'0 itens')+'</span><div><button class="v168-btn" data-v181-review-prev '+(prev?'':'disabled')+'>Anterior</button><button class="v168-btn" data-v181-review-next '+(next?'':'disabled')+'>Próxima</button></div></div>';
   return head+notice+search+'<div class="v181-review-list">'+body+'</div>'+paging+'<div class="v181-separation"><b>Classificação e documento são pendências diferentes.</b><span>“Faturas sem composição individual” exige a fatura da competência; não é resolvido escolhendo uma categoria.</span></div></article>';
  }
  function updates181(){
   const t=template(previousUpdates()),root=t.content.querySelector('.v168-updates');if(!root)return t.innerHTML;
   const head=root.querySelector('.v168-head'),kpis=root.querySelector('.v168-kpis');(head||kpis)?.insertAdjacentHTML('afterend',reviewPanel());
   return t.innerHTML;
  }
  function reconciliationPanel(){
   const s=state.reconciliation,data=s.data||{},rows=arr(data.rows);
   if(s.status==='idle'||(s.status==='loading'&&!s.data))return '<article class="v168-card v181-reconciliation"><div class="v168-cardhead"><div><span>Conciliação financeira</span><h2>Faturas documentadas × Fluxo</h2></div></div><div class="v181-loading">Conferindo cada cartão e vencimento…</div></article>';
   if(s.status==='error'&&!s.data)return '<article class="v168-card v181-reconciliation"><div class="v168-cardhead"><div><span>Conciliação financeira</span><h2>Faturas documentadas × Fluxo</h2></div></div><div class="v168-error">'+escape(s.error)+'</div><button class="v168-btn primary" data-v181-reconciliation-retry>Tentar novamente</button></article>';
   const ok=Number(data.issue_count||0)===0;
   return '<article class="v168-card v181-reconciliation"><div class="v168-cardhead"><div><span>Conciliação financeira</span><h2>Faturas documentadas × Fluxo</h2></div><strong class="'+(ok?'positive':'negative')+'">'+(ok?'Sem divergências':escape(data.issue_count+' divergência(s)'))+'</strong></div><div class="v181-tablewrap"><table class="v181-table"><thead><tr><th>Cartão</th><th>Competência / vencimento</th><th>Documentado</th><th>No Fluxo</th><th>Diferença</th><th>Situação</th><th></th></tr></thead><tbody>'+rows.map(row=>{const reconciled=row.reconciliation_status==='reconciled'&&Math.abs(Number(row.difference)||0)<=0.02;return '<tr><td><b>'+escape(row.card_name||'Cartão')+'</b></td><td>'+escape(monthLabel(row.reference_month))+'<small>'+escape(dateLabel(row.due_date))+'</small></td><td>'+money(row.documented_amount)+'</td><td>'+money(row.flow_amount)+'</td><td class="'+(reconciled?'positive':'negative')+'">'+money(row.difference)+'</td><td><span class="v181-status '+(reconciled?'ok':'issue')+'">'+(reconciled?'Conciliada':escape(row.reconciliation_status||'Revisar'))+'</span></td><td><button class="v168-btn" data-v181-flow-date="'+escape(row.due_date)+'">Abrir no Fluxo</button></td></tr>'}).join('')+'</tbody></table></div><div class="v181-rule"><b>Regra aplicada</b><span>Para o mesmo cartão e competência, a fatura documentada substitui a projeção antiga. Parcelas futuras continuam apenas como planejamento quando ainda não existe fatura.</span></div></article>';
  }
  function decorateCards(root){
   const host=root.querySelector('.v175-cards');if(!host)return;
   host.querySelector('.v175-inventory')?.remove();
   const first=host.firstElementChild;first?.insertAdjacentHTML('beforebegin',reconciliationPanel());
   const planning=[...host.children].find(node=>node.matches?.('article.v168-card')&&!node.classList.contains('v181-reconciliation'));
   if(planning){const kicker=planning.querySelector('.v168-cardhead span'),title=planning.querySelector('.v168-cardhead h2'),small=planning.querySelector('.v168-cardhead small');if(kicker)kicker.textContent='Planejamento';if(title)title.textContent='Parcelas e estimativas futuras';if(small)small.textContent='não substitui a conciliação acima';planning.insertAdjacentHTML('afterbegin','<div class="v181-plan-note">Valores futuros sem fatura documentada são cenários de planejamento, não uma segunda obrigação no caixa.</div>')}
  }
  function monthlySummary(data){
   const selected=String(v175?.monthly?.year||''),rows=arr(data?.monthly_totals).filter(row=>String(row.month||'').slice(0,4)===selected);
   if(!rows.length)return'';
   const totals={entries:0,expenses:0,result:0};
   const body=rows.map(row=>{const entries=(finite(row.revenue)||0)+(finite(row.extraordinary)||0),expenses=finite(row.expenses)||0,result=finite(row.cash_after_extraordinary)??(entries-expenses);totals.entries+=entries;totals.expenses+=expenses;totals.result+=result;return '<tr><th>'+escape(monthLabel(row.month))+'</th><td>'+money(entries)+'<small>operacionais '+money(row.revenue)+' · extraordinárias '+money(row.extraordinary)+'</small></td><td>'+money(expenses)+'</td><td class="'+(result<0?'negative':'positive')+'">'+money(result)+'</td></tr>'}).join('');
   return '<article class="v175-section v181-month-summary"><div class="v168-cardhead"><div><span>'+escape(selected)+'</span><h2>Resumo de cada mês</h2></div><small>entradas − despesas = resultado</small></div><div class="v181-tablewrap"><table class="v181-table"><thead><tr><th>Mês</th><th>Entradas</th><th>Despesas</th><th>Resultado</th></tr></thead><tbody>'+body+'<tr class="total"><th>Total de '+escape(selected)+'</th><td>'+money(totals.entries)+'</td><td>'+money(totals.expenses)+'</td><td class="'+(totals.result<0?'negative':'positive')+'">'+money(totals.result)+'</td></tr></tbody></table></div><div class="v181-rule"><b>Resultado do mês</b><span>É a diferença entre entradas e despesas do mês; não é o saldo bancário acumulado.</span></div></article>';
  }
  function decorateMonthly(root){
   const host=root.querySelector('.v175-monthly');if(!host)return;
   for(const section of host.querySelectorAll('.v175-section'))if(normalize(section.querySelector('h2')?.textContent)==='resultado anual')section.remove();
   const kpis=host.querySelector('.v168-kpis'),html=monthlySummary(v175?.monthly?.data);if(kpis&&html)kpis.insertAdjacentHTML('afterend',html);
  }
  function categorySourceRows(data){
   const groups=arr(data?.management_groups),coverage=groups.find(group=>normalize(group.name)==='faturas conciliadas pelo total'),rows=[];
   for(const group of groups){
    if(group===coverage)continue;
    const property=/apartamento|moradia|im[oó]vel/i.test(String(group.name||'')),children=property?arr(group.subgroups).filter(child=>child?.name&&finite(child.total)!=null):[];
    const childTotal=sum(children.map(child=>child.total)),canSplit=children.length>1&&Math.abs(childTotal-(finite(group.total)||0))<=0.02;
    if(canSplit)for(const child of children)rows.push({group:group.name,subgroup:child.name,total:Number(child.total),property:true});
    else rows.push({group:group.name,subgroup:null,total:Number(group.total)||0,property});
   }
   return{rows,coverage};
  }
  function categoryDimensions(data){
   const source=categorySourceRows(data),options=arr(state.review.data?.beneficiary_options),named=new Set(options.filter(item=>!/sem prefixo|minha/i.test(String(item?.label||''))).map(item=>normalize(item?.value||item?.label)).filter(Boolean));
   const enriched=source.rows.map(row=>{
    const raw=String(row.group||''),parts=raw.split(/\s+—\s+/),property=row.property||/apartamento|moradia|im[oó]vel/i.test(raw),exactNamed=named.has(normalize(raw));
    let beneficiary,nature;
    if(property){beneficiary='Casa';nature=row.subgroup||raw}
    else if(parts.length>1){beneficiary=parts.shift();nature=parts.join(' — ')}
    else if(exactNamed){beneficiary=raw;nature='Outras despesas'}
    else if(/a classificar|identifica[cç][oõ]es pendentes/i.test(raw)){beneficiary='A confirmar';nature='A classificar'}
    else{beneficiary='Minhas despesas (sem prefixo)';nature=row.subgroup||raw}
    if(normalize(nature)==='custos de moradia')nature='Apartamento – custos recorrentes';
    return{...row,beneficiary,nature};
   });
   return{...source,rows:enriched};
  }
  function groupDimension(rows,key){const map=new Map();for(const row of rows){const label=row[key],item=map.get(label)||{label,total:0,rows:[]};item.total+=row.total;item.rows.push(row);map.set(label,item)}return[...map.values()].sort((a,b)=>Math.abs(b.total)-Math.abs(a.total))}
  function categorySections(data){
   const dimensions=categoryDimensions(data),key=state.categoryView==='nature'?'nature':'beneficiary',groups=groupDimension(dimensions.rows,key);
   return groups.map(group=>'<section class="v181-category-group"><header><div><span>'+(key==='nature'?'Natureza':'Pessoa/contexto')+'</span><h3>'+escape(group.label)+'</h3></div><strong>'+money(group.total)+'</strong></header><div>'+group.rows.sort((a,b)=>Math.abs(b.total)-Math.abs(a.total)).map(row=>{const label=key==='nature'?row.beneficiary:row.nature;return '<button type="button" data-v181-detail-group="'+escape(row.group)+'" '+(row.subgroup?'data-v181-detail-subgroup="'+escape(row.subgroup)+'"':'')+'><span>'+escape(label)+'<small>'+escape(row.subgroup?row.group:'Ver lançamentos')+'</small></span><b>'+money(row.total)+'</b></button>'}).join('')+'</div></section>').join('');
  }
  function decorateCategories(root){
   const host=root.querySelector('.v175-categories'),data=v175?.expense?.data;if(!host||!data)return;
   const dimensions=categoryDimensions(data),organized=sum(dimensions.rows.map(row=>row.total)),coverage=finite(dimensions.coverage?.total)||0,selected=finite(data?.summary?.selected_total),difference=selected==null?null:selected-organized-coverage;
   host.classList.add('v181-category-panel');host.innerHTML='<div class="v168-cardhead"><div><span>Leituras alternativas do mesmo total</span><h2>Despesas por pessoa/contexto ou natureza</h2></div><strong>'+money(selected)+'</strong></div><div class="v181-category-toggle" role="tablist"><button class="v168-btn '+(state.categoryView==='beneficiary'?'primary':'')+'" data-v181-category-view="beneficiary">Por pessoa/contexto</button><button class="v168-btn '+(state.categoryView==='nature'?'primary':'')+'" data-v181-category-view="nature">Por natureza</button></div><p class="v181-lead">As duas visões reorganizam os mesmos lançamentos; elas não são blocos a somar entre si. Categorias sem nome de pessoa são suas e aparecem sem prefixo pessoal.</p><div class="v181-category-grid">'+categorySections(data)+'</div><div class="v181-total-check"><span>Grupos e identificações <b>'+money(organized)+'</b></span><span>Faturas sem composição individual <b>'+money(coverage)+'</b></span><span>Total do período <b>'+money(selected)+'</b></span><strong class="'+(difference!=null&&Math.abs(difference)<=0.02?'ok':'issue')+'">'+(difference==null?'Conferência indisponível':Math.abs(difference)<=0.02?'Fechamento sem dupla contagem':'Diferença '+money(difference))+'</strong></div>'+(dimensions.coverage?'<button class="v168-btn v181-coverage-button" data-v181-detail-group="'+escape(dimensions.coverage.name)+'">Abrir faturas sem composição individual</button>':'');
  }
  function expenses181(){
   const t=template(previousExpenses()),root=t.content.querySelector('.v168-expenses');if(!root)return t.innerHTML;
   const tab=v168?.expense?.tab;if(tab==='cards')decorateCards(root);if(tab==='monthly')decorateMonthly(root);if(tab==='categories')decorateCategories(root);
   return t.innerHTML;
  }
  function goFlow(date){
   V='Fluxo Diário';renderNav();render();setTimeout(()=>{const row=document.getElementById('d-'+date);row?.scrollIntoView({behavior:'smooth',block:'center'});const button=row?.querySelector('button');if(button&&window.EXP instanceof Set&&!EXP.has(date))button.click()},120);
  }
  function goReview(){state.focusQueue=true;V='Atualizações';renderNav();render()}
  function invalidateExpense(){
   if(v175){v175.expense.token=(v175.expense.token||0)+1;v175.expense.data=null;v175.expense.key='';v175.monthly.token=(v175.monthly.token||0)+1;v175.monthly.data=null;v175.monthly.key=''}
   if(v178?.dashboardReport){v178.dashboardReport.token=(v178.dashboardReport.token||0)+1;v178.dashboardReport.status='idle';v178.dashboardReport.data=null}
   detailApi.refresh?.();
  }
  function updateReviewChoice(row){
   const selected=[row.querySelector('[data-v181-beneficiary]')?.value,row.querySelector('[data-v181-property]')?.value,row.querySelector('[data-v181-category]')?.value].filter(Boolean),button=row.querySelector('[data-v181-review-save]'),note=row.querySelector('[data-v181-choice-note]');if(button)button.disabled=!selected.length||Boolean(state.review.saving);if(note)note.textContent=selected.length?'Será salva somente esta decisão; nenhuma outra linha será alterada.':'Nenhuma opção é presumida.';
  }
  async function saveReview(button){
   const host=button.closest('[data-v181-review-key]'),key=host?.dataset.v181ReviewKey,row=arr(state.review.data?.rows).find(item=>String(item.key)===String(key));if(!row)return;
   const beneficiary=host.querySelector('[data-v181-beneficiary]')?.value||null,property=host.querySelector('[data-v181-property]')?.value||null,category=host.querySelector('[data-v181-category]')?.value||null;if(!beneficiary&&!property&&!category)return;
   state.review.saving=key;button.disabled=true;button.textContent='Salvando…';
   try{await rpc('lts_browser_expense_review_decision_v181',{p_source_table:row.source_table,p_source_ref:row.source_ref,p_beneficiary:beneficiary,p_property_code:property,p_category_label:category});state.review.notice='Classificação salva e removida da fila.';state.review.status='idle';state.review.data=null;invalidateExpense();await ensureReview(true)}
   catch(error){state.review.notice='Não foi possível salvar: '+String(error?.message||error);state.review.saving=null;render()}
   finally{state.review.saving=null}
  }
  function decorateDrawer(){
   const host=document.getElementById('v178Drawer'),detail=v178?.detail;if(!host||!detail)return;
   const title=host.querySelector('#v178DetailTitle'),period=host.querySelector('.v178-drawer>header small'),summary=host.querySelector('.v178-detail-summary span:first-child'),property=/apartamento/i.test(String(detail.group||''));
   const setText=(node,value)=>{if(node&&node.textContent!==value)node.textContent=value};
   setText(period,detail.archive?'Histórico completo documentado · independente do filtro atual':'Período selecionado: '+dateLabel(detail.range?.from)+' a '+dateLabel(detail.range?.to));
   setText(summary?.firstChild,detail.archive?'Investimentos documentados no histórico completo':'Despesas no período selecionado');
   if(property){host.classList.add('v181-property-drawer');for(const button of host.querySelectorAll('.v178-components button')){const span=button.querySelector('span');if(normalize(span?.textContent)==='custos de moradia')setText(span,'Apartamento – custos recorrentes')}setText(host.querySelector('.v178-archive small'),'Histórico completo documentado · independente do filtro atual')}
   if(detail.archive)setText(title,'Histórico completo de investimentos');
   const byKey=new Map(arr(detail.rows).map(row=>[String(row.key),row]));
   const aggregateGroup=normalize(detail.group)==='faturas conciliadas pelo total';
   for(const tr of host.querySelectorAll('tr[data-row-key]')){if(tr.dataset.v181Row)return;tr.dataset.v181Row='1';const row=byKey.get(String(tr.dataset.rowKey));if(!row)continue;if(aggregateGroup||/consolidado hist[oó]rico dos cart[oõ]es/i.test(String(row.account_source||''))){const note=document.createElement('small');note.className='v181-aggregate-note';note.textContent='Agregado mensal — envie a fatura desta competência para individualizar as compras.';tr.children[1]?.appendChild(note)}}
  }
  function decorateVersion(){
   document.querySelectorAll('.brand small').forEach(node=>node.setAttribute('aria-label','V181 · Homologação'));
   document.querySelectorAll('.v168-headmeta').forEach(node=>{if(!node.querySelector('.v181-release'))node.insertAdjacentHTML('beforeend','<span class="v181-release">V181 · Homologação</span>')});
   try{const scope=window.parent.document.getElementById('scope');if(scope)scope.setAttribute('aria-label','V181 · '+(V==='Fluxo Diário'?'Fluxo de caixa':V)+' · Homologação')}catch{}
  }
  function bind(){
   decorateVersion();decorateDrawer();
   if(V==='Atualizações'&&state.review.status==='idle')queueMicrotask(()=>ensureReview(false));
   if(V==='Despesas'&&v168?.expense?.tab==='categories'&&state.review.status==='idle')queueMicrotask(()=>ensureReview(false));
   if(V==='Despesas'&&v168?.expense?.tab==='cards'&&state.reconciliation.status==='idle')queueMicrotask(()=>ensureReconciliation(false));
   document.querySelectorAll('.v178-pending-open').forEach(button=>{button.textContent=button.textContent.replace('Identificações pendentes','Classificar identificações');button.onclick=goReview});
   document.querySelectorAll('.v178-coverage-open').forEach(button=>{button.textContent=button.textContent.replace('Faturas a detalhar','Faturas sem composição individual')});
   document.querySelectorAll('[data-v181-review-key] select').forEach(select=>select.onchange=()=>updateReviewChoice(select.closest('[data-v181-review-key]')));
   document.querySelectorAll('[data-v181-review-save]').forEach(button=>button.onclick=()=>saveReview(button));
   document.querySelector('[data-v181-review-retry]')?.addEventListener('click',()=>{state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-review-search]')?.addEventListener('click',()=>{state.review.query=document.querySelector('[data-v181-review-query]')?.value.trim()||'';state.review.offset=0;state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-review-query]')?.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();document.querySelector('[data-v181-review-search]')?.click()}});
   document.querySelector('[data-v181-review-prev]')?.addEventListener('click',()=>{state.review.offset=Math.max(0,state.review.offset-25);state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-review-next]')?.addEventListener('click',()=>{state.review.offset=Number(state.review.data?.next_offset||state.review.offset);state.review.status='idle';ensureReview(true)});
   document.querySelector('[data-v181-reconciliation-retry]')?.addEventListener('click',()=>{state.reconciliation.status='idle';ensureReconciliation(true)});
   document.querySelectorAll('[data-v181-flow-date]').forEach(button=>button.onclick=()=>goFlow(button.dataset.v181FlowDate));
   document.querySelectorAll('[data-v181-category-view]').forEach(button=>button.onclick=()=>{state.categoryView=button.dataset.v181CategoryView;render()});
   document.querySelectorAll('[data-v181-detail-group]').forEach(button=>button.onclick=()=>detailApi.openDetail(button.dataset.v181DetailGroup,button.dataset.v181DetailSubgroup||null,expenseRange(),null));
   document.querySelectorAll('.v181-category-panel .v178-review-actions').forEach(node=>node.remove());
   if(state.focusQueue&&V==='Atualizações'){state.focusQueue=false;setTimeout(()=>document.getElementById('v181ReviewQueue')?.scrollIntoView({behavior:'smooth',block:'start'}),80)}
  }
  despesas=expenses181;atualizacoes=updates181;
  render=function(){const result=previousRender();bind();return result};
  renderNav=function(){const result=previousNav();decorateVersion();return result};
  const observer=new MutationObserver(()=>decorateDrawer());observer.observe(document.body,{childList:true,subtree:true});
  window.__LTS_V181_REGRESSION_CLOSURE={installed:true,version:'v181-regression-closure',baseline:'v180-documentary-refresh',contracts:{one_invoice_per_card_cycle:true,review_has_no_default:true,owner_category_has_no_prefix:true,category_views_are_alternatives:true,aggregate_only_rows_disclosed:true,drawer_decoration_idempotent:true,protected_root_unchanged:true},state};
  if(D&&!N.classList.contains('hidden'))render();
 }
 function install(){try{
  const frameWindow=outer?.contentWindow,frameDocument=outer?.contentDocument;if(!frameWindow?.__LTS_V180_DOCUMENTARY_REFRESH?.installed||!frameWindow?.__LTS_V178_REVIEW_ACTIONS?.installed)return false;
  if(!frameDocument.getElementById('v181-style')){const link=frameDocument.createElement('link');link.id='v181-style';link.rel='stylesheet';link.href='lts-v181-regression-closure.css?v=20260922-v181a';frameDocument.head.appendChild(link)}
  if(!frameWindow.__LTS_V181_REGRESSION_CLOSURE?.installed&&!frameDocument.getElementById('v181-runtime')){const script=frameDocument.createElement('script');script.id='v181-runtime';script.textContent='('+runtime.toString()+')();';frameDocument.head.appendChild(script)}
  if(frameWindow.__LTS_V181_REGRESSION_CLOSURE?.installed){document.getElementById('gate')?.remove();return true}return false;
 }catch{return false}}
 function burst(){const current=++generation;let count=0;function step(){if(current!==generation)return;if(!install()&&++count<320)setTimeout(step,100)}step()}
 outer?.addEventListener('load',burst);burst();
})();
