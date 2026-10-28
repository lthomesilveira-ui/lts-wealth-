/* Financial presentation and source-scoped actions. Values remain owned by the readers. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V365)return;
  const prior=render,priorMaterial=flowDayMaterial,ui=window.__LTS_V168_STATE;
  const amount=x=>x===null||x===undefined||x===''||!Number.isFinite(Number(x))?null:Number(x);
  const money=x=>amount(x)===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x));
  const date=x=>/^\d{4}-\d\d-\d\d/.test(String(x||''))?String(x).slice(0,10).split('-').reverse().join('/'):'Data a confirmar';
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const list=x=>Array.isArray(x)?x:[];
  function go(){V='Atualizações';renderNav();render();document.querySelector('.v168-updates')?.scrollIntoView({block:'start'});}
  const action=()=>'<button type="button" class="v168-btn" data-v365-updates>Atualizações e pendências</button>';
  const pair=(name,value,note='')=>'<div class="v365-pair"><span>'+esc(name)+(note?'<small>'+esc(note)+'</small>':'')+'</span><b>'+money(value)+'</b></div>';
  const kpi=(name,value,note='')=>'<article class="v168-kpi"><span>'+esc(name)+'</span><strong>'+money(value)+'</strong><small>'+esc(note)+'</small></article>';
  const pending=()=>list(FLOWQ?.observed_bank_movements?.pending_projections).filter(e=>ACC==='Consolidado'||e.account===ACC);
  flowDayMaterial=function(day,prev){return priorMaterial(day,prev)||pending().some(e=>e.event_date===day.date);};
  function bridge(day){
   const banks=ACC==='Consolidado'?['Itaú','Bradesco','C6']:[ACC],rows=[];
   for(const bank of banks){
    const b=day[bank]||{},guard=b.cash_position_guard;
    const delta=amount(guard?.unexplained_balance_difference??guard?.position_delta);
    if(!guard||delta===null||Math.abs(delta)<.005)continue;
    const opening=amount(b.opening_balance),net=amount(b.known_movements_net??guard.ledger_reconstruction?.net);
    const reconstructed=opening!==null&&net!==null?opening+net:null;
    rows.push('<section class="v365-bridge"><h3>'+esc(bank)+' · conciliação da posição</h3>'+pair('Saldo anterior do fluxo',opening)+pair('Efeito dos movimentos identificados',net)+pair('Posição reconstituída',reconstructed)+pair('Variação ainda sem movimento identificado',delta)+pair('Saldo disponível recebido do banco',b.observed_balance??b.balance)+'<p>Data efetiva e movimento ainda a confirmar. Esta variação não foi registrada como despesa nem como pagamento.</p>'+action()+'</section>');
   }
   return rows.join('');
  }
  function flow(){
   if(V!=='Fluxo Diário')return;
   const bar=document.querySelector('.flowbar .chips');
   if(bar&&!bar.querySelector('[data-v365-updates]'))bar.insertAdjacentHTML('beforeend',action());
   for(const day of mergedFlowDays()){
    const row=document.getElementById('d-'+day.date);if(!row)continue;
    const headers=[...document.querySelectorAll('.fx87-head>div')].map(x=>x.textContent.trim());[...row.children].forEach((cell,index)=>{if(index>0)cell.dataset.v365Label=headers[index]||'';});
    const obligations=pending().filter(e=>e.event_date===day.date),html=bridge(day);
    if(html){
     row.classList.add('v365-unreconciled');const cell=row.children[4];
     if(cell&&!cell.querySelector('.v365-balance-status'))cell.insertAdjacentHTML('beforeend','<small class="v365-balance-status">Posição a conciliar</small>');
     row.querySelector('.exp')?.setAttribute('aria-label','Conferir a mudança de saldo em '+date(day.date));
    }
    let detail=row.nextElementSibling;
    if(EXP.has(day.date)&&(html||obligations.length)){
     if(!detail?.classList.contains('fx89-details'))continue;
     if(!detail.querySelector('.fx89-detail-row'))detail.querySelector('.mut')?.remove();
     if(html&&!detail.querySelector('.v365-bridge'))detail.insertAdjacentHTML('beforeend',html);
     if(obligations.length&&!detail.querySelector('.v365-obligations')){
      const box=document.createElement('section');box.className='v365-obligations';
      box.innerHTML='<h3>Pagamentos a confirmar</h3>'+obligations.map((e,i)=>'<div class="v365-pair"><span>'+esc(e.description)+'<small>Vencimento '+esc(date(e.event_date))+' · '+esc(e.account)+'. Sem quitação comprovada.</small></span><b>'+money(Math.abs(Number(e.signed_amount)))+'</b><button class="v168-btn" data-v365-invoice="'+i+'">Abrir fatura</button></div>').join('');
      box.querySelectorAll('[data-v365-invoice]').forEach(b=>b.onclick=()=>openCardSettlement(obligations[Number(b.dataset.v365Invoice)]));detail.appendChild(box);
     }
    }else if(obligations.length&&!row.querySelector('.v365-balance-status'))row.firstElementChild.insertAdjacentHTML('beforeend','<small class="v365-balance-status">Pagamento a confirmar</small>');
   }
  }
  function overview(root,j){
   const w=j.wealth||{},s=w.summary||{},p=j.pensions||{},r=j.rsu_summary||{},a=w.assets||{},l=w.liquidity||{};
   const known=amount(s.known_debt_total),gross=amount(j.wealth_v167?.assets_central_including_pensions),complete=s.debt_total_complete===true;
   const current=[['CIPÓ 396',a.cipo_396?.market_central,'Valor de mercado estimado'],['Volvo XC40',a.volvo_xc40?.market_central,'Valor de mercado estimado'],['Contas correntes',l.bank_cash],['Aplicações D0',l.d0],['Ações e corretora disponíveis',r.available_total_brl,'Posição de '+date(r.as_of)],['Previdências',p.total_gross_brl,'Brutas e restritas'],['FGTS',l.fgts_contingency,'Restrito'],['Schiavalli',null,'Posição a informar']];
   const commitments=list(j.financing?.summary?.commitments),docs=list(j.financing?.documentary?.items);
   const debts=commitments.map(c=>{const d=docs.find(x=>x.commitment_id===c.id)||{};return[c.label||c.id,c.current_debt_as_of?c.current_documentary_debt_balance:null,c.current_debt_as_of?'Saldo documental em '+date(c.current_debt_as_of):'Saldo atual a informar'];});
   const tabs=root.querySelector('.v168-tabs');let node=tabs?.nextSibling;while(node){const n=node.nextSibling;node.remove();node=n;}
   root.insertAdjacentHTML('beforeend','<div class="v168-kpis v365-wealth-totals">'+kpi('Patrimônio bruto conhecido',gross,'Ativos e previdências; valores de mercado estimados')+kpi('Passivos documentados',known,'Posições nas datas informadas')+kpi(complete?'Patrimônio líquido':'Patrimônio líquido parcial',complete?j.wealth_v167?.net_worth_central_including_pensions:null,complete?'Ativos menos passivos':'Faltam saldos atuais de dívidas')+'</div>'+(!complete?'<p class="v365-material">Posição parcial. Há ativos e dívidas com saldo a informar. '+action()+'</p>':'')+'<div class="v365-columns"><article class="v168-card"><h2>Ativos atuais</h2>'+current.map(x=>pair(...x)).join('')+'</article><article class="v168-card"><h2>Passivos</h2>'+debts.map(x=>pair(...x)).join('')+'</article></div><article class="v168-card"><h2>Valores a receber no futuro</h2>'+pair('RSUs futuras · bruto',r.future_regular_brl)+pair('Cash RSUs · após reserva projetada',r.future_cash_net_brl)+pair('Total considerado na agenda',r.future_considered_total_brl,'Fora do patrimônio disponível hoje')+'<details><summary>Base e datas</summary><p>Os valores futuros usam a agenda de vestings e as referências de mercado. A reserva fiscal é uma premissa. Retention Award e datas contratuais ficam em RSUs e awards.</p></details></article>');
  }
  function rsu(root,j){
   const m=j.morgan_statement||{},ref=j.brokerage_reference,summary=j.rsu_summary||{};
   const existing=root.querySelector('.v352-brokerage-reference');
   if(existing){
    // Preserve the complete original provenance, under a closed disclosure.
    const origin=document.createElement('details');origin.className='v365-morgan-origin';origin.innerHTML='<summary>Origem e composição em conferência</summary>';
    while(existing.firstChild)origin.appendChild(existing.firstChild);existing.appendChild(origin);
    existing.insertAdjacentHTML('afterbegin','<h2>Referência Morgan Stanley</h2><div class="v365-reference-values">'+pair('Total bruto',ref.total_gross_brl)+pair('Disponível',ref.available_total_brl)+pair('Indisponível bruto',ref.unavailable_total_brl)+'</div><p class="v365-material">Data e composição monetária a confirmar. '+action()+'</p>');
   }
   const primary=root.querySelector('.v168-tabs')?.nextElementSibling;
   const dated=document.createElement('article');dated.className='v168-card v365-dated-morgan';
   dated.innerHTML='<h2>Posição datada · '+esc(date(m.as_of||summary.as_of))+'</h2><div class="v168-kpis">'+kpi('Total bruto',m.gross_total_brl)+kpi('Disponível atualmente',j.current_liquidity?.brokerage_available??summary.available_total_brl)+kpi('Indisponível bruto no extrato',m.unavailable_gross_brl)+kpi('Após reserva projetada no extrato',m.considered_total_after_reserve_brl,'Premissa de planejamento; não é saldo líquido de saque')+'</div><details><summary>Comparar extrato e agenda</summary>'+pair('Total futuro na agenda atual',summary.future_considered_total_brl)+pair('Total futuro após reserva no extrato',m.future_components?.future_after_reserve_brl)+'<p>As duas bases têm referências de preço, câmbio e datas diferentes. Não são somadas.</p></details>';
   if(primary)primary.after(dated);else root.appendChild(dated);
   // Earlier layers exposed several copies of these same comparisons.
   root.querySelectorAll('.v172-morgan,.v183-statement-remainders,.v172-morgan-components').forEach(x=>{const d=document.createElement('details');d.className='v365-morgan-archive';d.innerHTML='<summary>Detalhes da posição e composição</summary>';x.before(d);d.appendChild(x);});
   const top=[...root.children].find(x=>x.classList.contains('v168-kpis'));if(top){const d=document.createElement('details');d.innerHTML='<summary>Projeção por tipo de award</summary>';top.before(d);d.appendChild(top);}
  }
  function wealth(){
   if(V!=='Patrimônio'||!ui.wealth?.data)return;
   const root=document.querySelector('.v168-wealth');if(!root||root.dataset.v365==='true')return;root.dataset.v365='true';
   const j=ui.wealth.data;
   if(ui.wealth.tab==='overview')overview(root,j);
   else if(ui.wealth.tab==='rsu')rsu(root,j);
   else if(ui.wealth.tab==='assets'){
    for(const card of root.querySelectorAll('[data-v309-contract]')){
     const id=card.dataset.v309Contract,docs=list(j.financing?.documentary?.items).filter(x=>x.commitment_id===id).sort((a,b)=>String(b.as_of_date).localeCompare(String(a.as_of_date))),meta=docs[0]?.metadata||{};
     const fmt=x=>new Intl.NumberFormat('pt-BR',{minimumFractionDigits:2,maximumFractionDigits:2}).format(x),rates=[];if(amount(meta.effective_rate_aa_pct)!==null)rates.push('Juros efetivos '+fmt(meta.effective_rate_aa_pct)+'% a.a.');if(amount(meta.nominal_rate_aa_pct)!==null)rates.push('Juros nominais '+fmt(meta.nominal_rate_aa_pct)+'% a.a.');if(amount(meta.cet_aa_pct)!==null)rates.push('CET '+fmt(meta.cet_aa_pct)+'% a.a.');
     const line=document.createElement('p');line.className='v365-rate';line.textContent=rates.length?rates.join(' · ')+(meta.indexer?' + '+meta.indexer:''):'Taxa de juros a informar';card.querySelector('.v168-loanmetrics')?.after(line);
    }
   }
  }
  function expenses(){
   if(V!=='Despesas')return;
   const root=document.querySelector('.v168-expenses');if(!root)return;
   for(const cell of root.querySelectorAll('td,dd,.v168-kpi strong'))if(/^\s*[-−]\s*R\$/.test(cell.textContent))cell.classList.add('v365-negative');
   root.querySelectorAll('.v182-months tr').forEach(row=>{for(const index of [3,5])row.children[index]?.classList.add('v365-consolidated');});
  }
  function updates(){
   if(V!=='Atualizações')return;
   const root=document.querySelector('.v168-updates');if(!root)return;
   const heading=root.querySelector('h1');if(heading)heading.textContent='Atualizações e pendências';
   const recurring=ui.updates?.recurring;
   for(const row of root.querySelectorAll('[data-coverage-key]')){
    const x=list(recurring?.horizon_checks).find(x=>x.key===row.dataset.coverageKey);if(!x||row.querySelector('.v365-reference'))continue;
    const detail=document.createElement('small');detail.className='v365-reference';detail.textContent='Último realizado: '+date(x.historical_last_date)+' · Última previsão: '+date(x.last_future_date)+'. '+(x.review_kind==='covered'?'Cobertura completa no horizonte.':'Confira a vigência e continue a série ou informe seu término.');row.querySelector('div')?.appendChild(detail);
   }
   if(!root.querySelector('#v365WealthTasks')){
    const box=document.createElement('article');box.id='v365WealthTasks';box.className='v168-card';box.innerHTML='<h2>Informações patrimoniais a completar</h2><p>Saldos atuais de Volvo, Coopharma e Pai e Mãe; composição e data da nova posição Morgan; taxas de juros dos contratos ainda sem documento.</p><button class="v168-btn" data-v365-wealth>Bens, dívidas e contratos</button>';root.appendChild(box);box.querySelector('button').onclick=()=>{ui.wealth.tab='assets';V='Patrimônio';renderNav();render();};
   }
   const cardState=window.__LTS_V312_CARD_REVIEW?.state;
   root.querySelectorAll('.lts-card-review-row').forEach((row,i)=>{
    if(row.querySelector('.v365-suggestion-source'))return;const s=cardState?.data?.rows?.[i]?.suggestion;if(!s)return;
    const basis={documentary_receipt:['Comprovante conferido','Moderada'],public_mcc_reference:['Atividade bancária e referência pública','Limitada'],merchant_history:['Histórico classificado do estabelecimento','Moderada'],same_purchase_installments:['Outra parcela da mesma compra','Alta'],bank_business_activity:['Atividade informada pelo banco','Limitada'],insufficient_evidence:['Sem correspondência suficiente','Insuficiente'],platform_purchase_needs_context:['Produto ainda não comprovado','Insuficiente'],conflicting_history:['Histórico com classificações diferentes','Insuficiente']};
    const [origin,confidence]=basis[s.basis]||['Referência a conferir','Limitada'];const d=document.createElement('details');d.className='v365-suggestion-source';d.innerHTML='<summary>Origem e confiança</summary><p>'+esc(origin)+' · Confiança '+esc(confidence.toLowerCase())+'.</p><p>'+esc(s.note||'Confira a finalidade antes de confirmar.')+'</p>'+((s.evidence?.date||s.evidence?.reference_date)?'<p>Referência de '+esc(date(s.evidence.date||s.evidence.reference_date))+' · '+money(s.evidence.amount??s.evidence.receipt_total)+'</p>':'');if(s.evidence?.reference){try{const url=new URL(s.evidence.reference);if(url.protocol==='https:'){const a=document.createElement('a');a.href=url.href;a.textContent='Consultar referência';a.target='_blank';a.rel='noopener noreferrer';d.appendChild(a);}}catch{}}row.firstElementChild.appendChild(d);
   });
  }
  function after(){
   flow();wealth();expenses();updates();document.querySelectorAll('[data-v365-updates]').forEach(b=>b.onclick=go);
  }
  const style=document.createElement('style');style.id='v365-style';style.textContent=`
   .flow-sticky-controls{position:static!important}.flow-shell{height:auto!important;min-height:0!important}.fx87-mesa{max-height:none!important}.fx87-scroll{max-height:calc(100dvh - 220px)!important;min-height:280px;overflow:auto!important}.lts-phase{display:inline-block!important;flex:none!important;width:7px;height:7px;border-radius:50%;padding:0!important;margin:0 3px;background:#6f849a}.lts-phase.forecast{background:#a87b2b}.lts-phase.needs-review{background:#ad493b}.fx87-date{gap:7px!important;flex-wrap:wrap!important}.fx87-cell:has(.v365-balance-status){flex-wrap:wrap;row-gap:4px}.fx87-cell>.v365-balance-status{flex-basis:100%;text-align:right}.v365-balance-status{display:block;font-size:11px;color:#885a1c;font-weight:500;line-height:1.4}.v365-unreconciled{box-shadow:inset 3px 0 #b48232}.v365-bridge,.v365-obligations{max-width:700px;margin:10px 0;padding:14px;border:1px solid #decba7;border-radius:10px;background:#fffcf5;color:#243c52}.v365-bridge h3,.v365-obligations h3{margin:0 0 10px;font-size:16px}.v365-bridge p{font-size:13px;line-height:1.5}.v365-pair{display:flex;justify-content:space-between;align-items:baseline;gap:14px;padding:11px 0;border-bottom:1px solid #e6ebf0;flex-wrap:wrap}.v365-pair>span{flex:1;min-width:160px}.v365-pair small{display:block;font-size:12px;color:#627083;line-height:1.5}.v365-pair>b{white-space:nowrap;font-variant-numeric:tabular-nums}.v365-columns{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:16px 0}.v365-material{font-size:13px;line-height:1.5;color:#825b22}.v365-rate{font-size:12px;line-height:1.6;color:#536174}.v365-negative{color:#b03535!important}.v365-consolidated,.v182-total{background:#eef1f4;font-weight:650}.v365-suggestion-source{font-size:12px;color:#526174;margin:8px 0;line-height:1.5}.v365-suggestion-source summary{cursor:pointer;padding:5px 0}.v365-morgan-origin,.v365-morgan-archive{margin:12px 0;font-size:13px;line-height:1.5}.v365-wealth-totals{grid-template-columns:repeat(3,minmax(0,1fr))!important}.v365-dated-morgan .v168-kpis{margin-bottom:0}.v365-reference{margin-top:8px;color:#526174;font-size:12px}.v365-morgan-origin>h2{font-size:15px}
   .v365-reference-values .v365-pair{padding:10px 0}
   @media(max-width:700px){.fx87-cell[data-v365-label]{flex-direction:column!important;align-items:flex-end!important;justify-content:center!important;gap:4px!important}.fx87-cell[data-v365-label]::before{content:attr(data-v365-label);display:block;font-size:10px;font-weight:500;color:#627083}.fx87-cell>.v365-balance-status{flex-basis:auto}.flowbar>.chips{flex-wrap:wrap!important;overflow:visible!important}.v365-columns{grid-template-columns:1fr}.v365-wealth-totals{grid-template-columns:1fr!important}.v365-bridge,.v365-obligations{padding:12px}.fx87-scroll{max-height:70dvh!important}.v365-pair{gap:6px}.v365-pair>span{min-width:130px}.v365-pair>b{font-size:14px}}
  `;document.head.appendChild(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};
  window.__LTS_V365={installed:true,after,bridge};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V312_CARD_REVIEW||!w?.__LTS_V183_WEALTH_INTEGRITY||!w?.__LTS_V308_REVIEW_LAYOUT)return false;if(!w.__LTS_V365){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V365;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v365-homologation.js',install);
})();
