/* Source-backed monthly and selected-period balances, alongside current bank cash. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V337_MONTH||!window.__LTS_V312_CARD_REVIEW||!window.parent.LTSV337Month)return;
  const model=window.parent.LTSV337Month,previous=render;
  const state={owner:null,day:null,month:'',followCurrentMonth:true,mode:'month',from:'',to:'',draftFrom:'',draftTo:'',draftError:null,basis:'cash',stage:'total',detail:null,sequence:0,status:'idle',data:null,range:null,scheduled:false,signedOut:false};
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  const visible=()=>!state.signedOut&&!!D&&!N.classList.contains('hidden')&&V==='Dashboard';
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x);
  const date=x=>x.split('-').reverse().join('/');
  const monthName=x=>new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}).format(new Date(x+'-01T12:00:00Z')).replace('.','');
  const selection=()=>JSON.stringify([state.mode,state.month,state.from,state.to]);
  function invalidate(){state.sequence++;state.status='idle';state.data=null;state.range=null;state.detail=null;document.getElementById('v393MonthDetail')?.remove();}
  function sync(){
   const current=generation(),businessDay=today();
   if(state.owner!==current||state.day!==businessDay){if(state.day&&state.day!==businessDay)window.__LTS_V227_TRANSPORT?.invalidate(false);state.owner=current;state.day=businessDay;invalidate();state.scheduled=false;}
   if(!state.month||state.followCurrentMonth)state.month=businessDay.slice(0,7);
  }
  const selectedRange=()=>state.mode==='period'?model.forecastPeriodBounds(state.from,state.to,today()):model.monthBounds(state.month,today());
  function current(ticket){return !state.signedOut&&state.owner===ticket.owner&&generation()===ticket.owner&&state.day===ticket.day&&today()===ticket.day&&state.sequence===ticket.sequence&&selection()===ticket.selection;}
  async function load(force=false){
   sync();if(!visible()||state.status==='loading'||(!force&&state.status!=='idle'))return;
   const range=selectedRange();state.range=range;
   if(!range){state.status='invalid';state.data=null;render();return;}
   if(force)window.__LTS_V227_TRANSPORT?.invalidate(false);
   const ticket={owner:state.owner,day:state.day,sequence:++state.sequence,selection:selection()};
   state.status='loading';state.data=null;render();
   try{
    const result=await S.rpc('lts_browser_month_overview_v393',{p_from:range.from,p_to:range.to});
    if(!current(ticket))return;
    const summary=result.error?null:model.summarizeOverview(result.data,range,today());
    if(!summary)throw Error('unavailable');state.data=summary;state.status='ready';
   }catch{if(current(ticket)){state.status='error';state.data=null;}}
   finally{if(current(ticket)&&visible())render();}
  }
  function controls(){
   const mode='<div class="v379-balance-modes" role="group" aria-label="Visão do balanço"><button type="button" data-v379-mode="month" aria-pressed="'+(state.mode==='month')+'">Mês</button><button type="button" data-v379-mode="period" aria-pressed="'+(state.mode==='period')+'">Período</button></div>';
   if(state.mode==='month')return mode+'<label class="v337-month-control">Mês<input type="month" aria-label="Mês do resumo" min="2013-10" max="'+(Number(today().slice(0,4))+5)+'-12" value="'+esc(state.month)+'"></label>';
   return mode+'<div class="v379-balance-range"><label>De<input type="date" aria-label="Data inicial do balanço" min="2013-10-10" max="'+(Number(today().slice(0,4))+5)+'-12-31" value="'+esc(state.draftFrom)+'"></label><label>Até<input type="date" aria-label="Data final do balanço" min="2013-10-10" max="'+(Number(today().slice(0,4))+5)+'-12-31" value="'+esc(state.draftTo)+'"></label><button type="button" class="v168-btn primary" data-v379-apply>Aplicar intervalo</button>'+(state.draftError?'<p role="alert">'+esc(state.draftError)+'</p>':'')+'</div>';
  }
  const cardName=r=>!String(r.coverage_mode||'').startsWith('card_')?(r.account_source||r.account||'Outros registros'):/^C6(?:\s|$)/i.test(r.account_source||'')?'C6':({'336':'C6','341':/prime|infinite/i.test(r.account_source||'')?'Itaú Prime':'Itaú Mastercard','237':/prime/i.test(r.account_source||'')?'Bradesco Prime':'Bradesco Aeternum'}[r.institution_code]||r.account_source||r.account||'Outros registros');
  function monthly(){
   const range=selectedRange(),x=state.status==='ready'?state.data:null,isPeriod=state.mode==='period';
   const header='<div class="v168-cardhead"><div><span>Receitas e despesas</span><h2>'+(isPeriod?'Balanço do período':'Resumo do mês')+'</h2></div></div><div class="v379-balance-controls">'+controls()+'</div>';
   const period=range?'<p class="v337-period">'+date(range.from)+' a '+date(range.to)+(range.partial?(isPeriod?' · período em andamento':' · mês em andamento'):'')+'</p>':'';
   if(!x)return header+period+'<p class="v337-month-status" role="status">'+(state.status==='invalid'?'Escolha um intervalo válido desde 10/10/2013.':state.status==='error'?'Não foi possível conferir este período. Tente novamente.':'Consultando os valores deste período…')+'</p>'+(state.status==='error'?'<button class="v168-btn" data-v337-retry>Tentar novamente</button>':'');
   const tabs='<div class="v393-tabs" role="group" aria-label="Critério do resumo"><button data-v393-basis="cash" aria-pressed="'+(state.basis==='cash')+'">Caixa</button><button data-v393-basis="competence" aria-pressed="'+(state.basis==='competence')+'">Competência</button></div>';
   const metric=(label,value,kind)=>'<div class="v337-metric '+kind+'"><span>'+label+'</span><strong>'+money(Number(value))+'</strong></div>';
   const warning=x.sourceIncomplete?'<p class="v393-warning" role="alert">Há valores em conferência. O total projetado pode estar incompleto; confira as faturas antes de decidir.</p>':'';
   if(state.basis==='competence'){
    const groups=new Map();for(const r of x.competence.items){const name=cardName(r);groups.set(name,(groups.get(name)||0)+Number(r.amount));}
    const breakdown=[...groups].sort((a,b)=>b[1]-a[1]).map(([name,total])=>'<div><span>'+esc(name)+'</span><strong>'+money(total)+'</strong></div>').join('');
    return header+period+tabs+warning+'<p class="v393-explanation">Despesas atribuídas aos meses de '+date(x.competence.from)+' a '+date(x.competence.to)+'. Compras feitas antes podem pertencer a este mês. Estes valores não comprovam pagamento. Outros pagamentos previstos estão na visão de caixa.</p><div class="v337-metrics">'+metric('Despesas recebidas',x.competence.received_total,'expense')+metric('Parcelas ainda previstas',x.competence.projected_total,'expense')+metric('Total por competência',x.competence.total,'expense')+'</div>'+(breakdown?'<div class="v393-groups">'+breakdown+'</div>':'<p class="v393-explanation">Ainda não há despesas atribuídas a estes meses nas fontes recebidas.</p>')+'<button class="v168-btn primary" data-v393-detail="competence">Ver composição ('+x.competence.count+' lançamentos)</button><details class="v337-source"><summary>Como este total é calculado</summary><p>As compras e parcelas de cartão entram uma vez, no mês de competência, com suas datas originais disponíveis no detalhamento. O primeiro dia do mês organiza a competência; não é a data de compra ou pagamento.</p><p>O pagamento da fatura aparece apenas na visão de caixa. Não somamos esse pagamento às compras para calcular despesas. Aqui não é calculado um resultado misturando receitas de caixa com despesas por competência. Novas compras e cobranças podem alterar os próximos meses.</p></details>';
   }
   const stage=['total','realized','forecast','unconfirmed'].includes(state.stage)?state.stage:'total',m=x.cash[stage];
   const labels={total:'Mês completo · projeção',realized:'Realizado até '+date(today()),forecast:'Ainda previsto no período',unconfirmed:'Sem confirmação de realização'};
   const choose='<div class="v393-stages" role="group" aria-label="Situação do caixa">'+[['total','Mês completo'],['realized','Realizado'],['forecast','Previsto'],...(x.cash.unconfirmed.count?[['unconfirmed','A confirmar']]:[])].map(([key,label])=>'<button data-v393-stage="'+key+'" aria-pressed="'+(stage===key)+'">'+label+'</button>').join('')+'</div>';
   const undated=x.cash.undated.length?'<div class="v393-warning" role="alert"><b>Cobranças sem data de pagamento</b>'+x.cash.undated.map(r=>'<p>'+esc(r.card_name)+' · '+(r.amount===null||r.amount===undefined?'valor a conferir':money(Number(r.amount)))+'. Confira o vencimento da fatura; este valor ainda não está no total de caixa.</p>').join('')+'</div>':'';
   const rows=[['realized','Realizado até '+date(today())],['forecast','Previsto até '+date(range.to)],...(x.cash.unconfirmed.count?[['unconfirmed','A confirmar']]:[])];
   const breakdown='<div class="v393-cash-split" aria-label="Realizado e previsto separados"><div class="v393-split-head"><span>Situação</span><span>Entradas</span><span>Saídas</span></div>'+rows.map(([key,label])=>'<div><span>'+label+'</span><strong>'+money(Number(x.cash[key].entries))+'</strong><strong>'+money(Number(x.cash[key].payments))+'</strong></div>').join('')+'</div>';
   const monthRows=isPeriod?'<details class="v379-months"><summary>Ver mês a mês ('+x.months.length+')</summary><div class="v379-month-table"><table><thead><tr><th>Mês</th><th>Entradas</th><th>Saídas</th><th>Resultado</th></tr></thead><tbody>'+x.months.map(m=>'<tr><th>'+esc(monthName(m.month.slice(0,7)))+'</th><td>'+money(Number(m.cash.entries))+'</td><td>'+money(Number(m.cash.payments))+'</td><td>'+money(Number(m.cash.result))+'</td></tr>').join('')+'</tbody></table></div></details>':'';
   return header+period+tabs+warning+choose+'<p class="v393-explanation"><b>'+labels[stage]+'</b>. Considera a data em que o dinheiro entra ou sai da conta. O resultado do período não é o saldo bancário.</p><div class="v337-metrics">'+metric('Receitas e outras entradas',m.entries,'income')+metric('Pagamentos e outras saídas',m.payments,'expense')+metric('Resultado em caixa',m.result,Number(m.result)<0?'negative':'result')+'</div>'+breakdown+undated+(x.cash.unconfirmed.count?'<p class="v393-warning">Há '+x.cash.unconfirmed.count+' lançamento(s) sem confirmação. Eles permanecem separados do realizado e entram apenas no total projetado.</p>':'')+'<button class="v168-btn primary" data-v393-detail="cash">Ver lançamentos de caixa ('+x.cash.items.length+')</button>'+monthRows+'<details class="v337-source"><summary>Como este total é calculado</summary><p>Movimentações de '+date(x.from)+' a '+date(x.to)+', com realização conferida até '+date(x.as_of)+'. Agendamentos e previsões não se tornam realizados porque a data chegou. As previsões consideram os lançamentos conhecidos e podem mudar.</p><p>Transferências entre contas próprias e disponibilidade de investimentos não são receitas ou despesas. Faturas aparecem como saída de caixa uma vez; suas compras ficam separadas na visão de competência.</p><p>'+x.cash.excluded.length+' registro(s) de transferências próprias, aplicações ou disponibilidade de recursos ficam fora destes totais.</p></details>';
  }
  function openDetail(kind){
   const x=state.status==='ready'?state.data:null;if(!x)return;
   const owner=state.owner,seq=state.sequence,rows=kind==='cash'?x.cash.items:x.competence.items;
   document.getElementById('v393MonthDetail')?.remove();
   const dialog=document.createElement('dialog');dialog.id='v393MonthDetail';dialog.className='v393-dialog';dialog.setAttribute('aria-label',kind==='cash'?'Lançamentos de caixa':'Composição das despesas');
   let query='',limit=20;state.detail=kind;
   const source=r=>({'lts_open_finance_staging':'Compra recebida pelo Open Finance','lts_card_document_supplement_v234':'Documento da fatura','projected_card_installment':'Parcela prevista a partir da última fatura recebida','card_invoice':'Fatura do cartão','current_event':'Registro do planejamento','legacy_fix86':'Planilha e planejamento originais','historical_workbook_cash':'Planilha original','open_finance':'Movimento recebido do banco'}[r.source_table||r.source]||'Registro financeiro');
   dialog.innerHTML='<div class="v393-dialog-head"><h2>'+(kind==='cash'?'Lançamentos de caixa':'Composição das despesas')+'</h2><button class="v168-btn" data-v393-close aria-label="Fechar detalhamento">Fechar</button></div><p class="v393-dialog-note"></p><label class="v393-search">Buscar lançamento<input type="search" aria-label="Buscar no detalhamento" placeholder="Descrição, categoria ou conta"></label><div class="v393-detail-content"></div>';
   const close=()=>{state.detail=null;dialog.remove();};dialog.querySelector('[data-v393-close]').onclick=close;dialog.addEventListener('cancel',event=>{event.preventDefault();close();});
   function draw(){
    if(state.owner!==owner||state.sequence!==seq||state.status!=='ready'){close();return;}
    const needle=query.toLocaleLowerCase('pt-BR'),found=rows.filter(r=>[r.description,r.category,r.account,r.account_source,cardName(r)].join(' ').toLocaleLowerCase('pt-BR').includes(needle));
    const total=kind==='cash'?x.cash.total.payments:x.competence.total;
    dialog.querySelector('.v393-dialog-note').textContent=(kind==='cash'?'Caixa: '+date(x.from)+' a '+date(x.to)+'. Saídas do período: ':'Competência: '+date(x.competence.from)+' a '+date(x.competence.to)+'. Total das despesas: ')+money(Number(total))+(kind==='cash'?'. Realizado e previsto identificados em cada item.':'. A competência não comprova pagamento; veja a data original de cada compra.');
    const html=found.slice(0,limit).map(r=>{
     const amount=kind==='cash'?Number(r.signed_amount):Number(r.amount),tag=kind==='cash'?({realized:'Realizado',forecast:'Previsto',unconfirmed:'A confirmar'}[r.cash_state]):String(r.coverage_mode).includes('projected')?'Parcela prevista':String(r.coverage_mode).startsWith('card_')?'Compra de cartão recebida':'Registro de despesa';
     const dates=kind==='cash'?date(r.event_date)+' · '+(r.account||'Conta a conferir'):(r.purchase_date||r.transaction_date?'Compra em '+date(r.purchase_date||r.transaction_date)+' · ':'')+'Competência '+monthName(r.competence_month.slice(0,7));
     return '<article class="v393-detail-row"><div class="v393-detail-main"><strong>'+esc(r.description||r.category||'Lançamento')+'</strong><b>'+money(amount)+'</b></div><p>'+esc(dates)+'</p><p><span class="v393-tag">'+tag+'</span> '+esc(kind==='cash'?(r.source==='card_invoice'?'Pagamento de fatura':r.category||''):(cardName(r)+' · '+(r.category||'A classificar')))+'</p><details><summary>Origem</summary><p>'+esc(source(r))+'</p>'+(r.transaction_date?'<p>Data do lançamento recebido: '+date(r.transaction_date)+'.</p>':'')+(r.raw_reference?'<p>'+esc(r.raw_reference)+'</p>':'')+(kind==='competence'&&r.due_date?'<p>Vencimento previsto da fatura: '+date(r.due_date)+'.</p>':'')+'<p>Referência: '+esc(r.source_ref)+'.</p>'+(kind==='competence'?'<p>Valor atribuído à competência; não confirma débito em conta ou pagamento da fatura.</p>':'')+'</details></article>';
    }).join('');
    dialog.querySelector('.v393-detail-content').innerHTML='<p class="v393-detail-count" role="status">Exibindo '+Math.min(limit,found.length)+' de '+found.length+' lançamento(s)'+(query?' encontrados':'')+'.</p>'+html+(found.length>limit?'<button class="v168-btn" data-v393-more>Mostrar mais 20</button>':'')+(found.length?'':'<p>Nenhum lançamento corresponde à busca.</p>');
    dialog.querySelector('[data-v393-more]')?.addEventListener('click',()=>{limit+=20;draw();});
   }
   dialog.querySelector('input').oninput=event=>{query=event.target.value;limit=20;draw();};document.body.appendChild(dialog);draw();dialog.showModal();
  }
  function banks(){
   const cash=window.__LTS_V178_STATE?.cash,positions=cash?.status==='ready'&&window.__LTS_V178_REVIEW.cashComplete(cash)?model.bankPositions(cash.data,today()):null;
   const header='<div class="v168-cardhead"><div><span>Contas correntes · hoje</span><h2>Posição por banco</h2></div></div>';
   if(!positions)return header+'<p class="v337-month-status" role="status">A posição por banco ainda não está disponível.</p><button class="v168-btn" data-v337-banks-retry>Atualizar posições</button>';
   return header+'<div class="v337-bank-list">'+positions.rows.map(x=>'<div class="v337-bank"><span><i class="bank-'+x.code+'">'+(x.code==='341'?'I':x.code==='237'?'B':'C6')+'</i>'+x.name+'</span><strong>'+money(x.balance)+'</strong></div>').join('')+'<div class="v337-bank total"><span>Total em contas</span><strong>'+money(positions.total)+'</strong></div></div><details class="v337-source"><summary>Atualização</summary><p>Posição conferida para '+date(positions.asOf)+'. A data de recebimento de cada saldo está em Atualização, junto às contas correntes. Aplicações, ações e FGTS aparecem separadamente no painel.</p></details>';
  }
  function paint(){
   sync();if(!visible())return;const root=document.querySelector('.v168-dashboard');if(!root)return;
   let section=root.querySelector('#v337Overview');
   if(!section){section=document.createElement('section');section.id='v337Overview';section.className='v337-overview';section.setAttribute('aria-label','Resumo financeiro e bancos');const anchor=root.querySelector('.v168-grid.two');if(anchor)anchor.before(section);else root.querySelector('.v168-kpis')?.after(section);}
   const prior={owner:section.__ltsOwner,active:document.activeElement,from:section.querySelector('[aria-label="Data inicial do balanço"]'),to:section.querySelector('[aria-label="Data final do balanço"]')};
   section.__ltsOwner=state.owner;const paintOwner=state.owner,owns=()=>visible()&&state.owner===paintOwner&&generation()===paintOwner;
   section.innerHTML='<article class="v168-card v337-month">'+monthly()+'</article><article class="v168-card v337-banks">'+banks()+'</article>';
   for(const button of section.querySelectorAll('[data-v379-mode]'))button.onclick=()=>{
    if(!owns())return;const mode=button.dataset.v379Mode;if(mode===state.mode)return;
    state.mode=mode;state.draftError=null;
    if(mode==='period'&&!state.from){const r=model.monthBounds(state.month,today())||model.monthBounds(today().slice(0,7),today());state.from=r.from;state.to=r.to;state.draftFrom=r.from;state.draftTo=r.to;}
    invalidate();render();
   };
   const control=section.querySelector('[aria-label="Mês do resumo"]');
   if(control)control.oninput=control.onchange=()=>{if(!owns()||state.month===control.value)return;state.month=control.value;state.followCurrentMonth=!control.value||control.value===today().slice(0,7);invalidate();render();};
   for(const [key,label,draft]of[['from','Data inicial do balanço','draftFrom'],['to','Data final do balanço','draftTo']]){
    let input=section.querySelector('[aria-label="'+label+'"]');if(!input)continue;
    if(prior.owner===state.owner&&prior[key]){input.replaceWith(prior[key]);input=prior[key];}
    input.oninput=input.onchange=()=>{if(!owns())return;state[draft]=input.value;state.draftError=null;};
    if(prior.active===input)try{input.focus({preventScroll:true});}catch{}
   }
   section.querySelector('[data-v379-apply]')?.addEventListener('click',()=>{
    if(!owns())return;
    const from=section.querySelector('[aria-label="Data inicial do balanço"]').value,to=section.querySelector('[aria-label="Data final do balanço"]').value;
    state.draftFrom=from;state.draftTo=to;
    if(!model.forecastPeriodBounds(from,to,today())){state.draftError='Informe um intervalo válido desde 10/10/2013, com a data inicial antes da final. O intervalo aplicado foi preservado.';render();return;}
    state.from=from;state.to=to;state.draftError=null;invalidate();render();
   });
   for(const button of section.querySelectorAll('[data-v393-basis]'))button.onclick=()=>{if(!owns())return;state.basis=button.dataset.v393Basis;render();};
   for(const button of section.querySelectorAll('[data-v393-stage]'))button.onclick=()=>{if(!owns())return;state.stage=button.dataset.v393Stage;render();};
   for(const button of section.querySelectorAll('[data-v393-detail]'))button.onclick=()=>{if(owns())openDetail(button.dataset.v393Detail);};
   section.querySelector('[data-v337-retry]')?.addEventListener('click',()=>load(true));
   section.querySelector('[data-v337-banks-retry]')?.addEventListener('click',()=>window.__LTS_V178_REVIEW.refreshCashOnly(true));
   if(state.status==='idle'&&!state.scheduled){state.scheduled=true;queueMicrotask(()=>{state.scheduled=false;load(false);});}
  }
  const style=document.createElement('style');style.id='v337-month-style';style.textContent=`
   .v337-overview{display:grid;grid-template-columns:minmax(0,1.7fr) minmax(280px,1fr);gap:18px;margin:18px 0 22px;min-width:0}
   .v337-overview .v168-card{min-width:0;margin:0}.v337-month-control{display:flex;gap:7px;align-items:center;font-size:12px;color:#526174;min-width:0}
   .v337-month-control input,.v379-balance-range input{border:1px solid #d4dee8;border-radius:9px;min-height:44px;background:#fff;padding:8px;box-sizing:border-box;color:#18334e;max-width:100%;min-width:0;font:inherit}
   .v379-balance-controls{display:grid;gap:12px;margin-top:12px}.v379-balance-modes{display:flex;gap:6px}.v379-balance-modes button{border:1px solid #d2dce6;border-radius:9px;background:#fff;color:#35516a;font:inherit;font-size:13px;font-weight:600;line-height:1.4;min-height:40px;padding:8px 16px;cursor:pointer}.v379-balance-modes [aria-pressed=true]{background:#183b60;border-color:#183b60;color:white}
   .v379-balance-range{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr) auto;align-items:end;gap:10px}.v379-balance-range label{display:grid;gap:5px;min-width:0;font-size:12px;color:#526174}.v379-balance-range input{width:100%}.v379-balance-range button{min-height:44px}.v379-balance-range p{grid-column:1/-1;color:#9d3648;font-size:12px;line-height:1.5;margin:0}
   .v337-period{font-size:12px;color:#526174;line-height:1.5;margin:6px 0 16px}.v379-accumulated{font-size:12px;font-weight:650;color:#35516a}.v337-metrics{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}
   .v337-metric{border:1px solid #e2e8ee;border-top:3px solid #3979b2;border-radius:11px;padding:13px 12px;background:#f8fafc;min-width:0;display:flex;flex-direction:column;justify-content:space-between;gap:12px}
   .v337-metric>span{font-size:12px;color:#526174;line-height:1.5;min-height:36px}.v337-metric>strong{font-size:clamp(18px,1.55vw,25px);font-variant-numeric:tabular-nums;letter-spacing:-.035em;line-height:1.25;overflow-wrap:anywhere}
   .v337-metric.expense,.v337-metric.negative{border-top-color:#9d3648}.v337-metric.result{border-top-color:#279677}.v337-metric.result strong{color:#167157}.v337-metric.negative strong{color:#9d3648}
   .v337-source,.v379-months{margin-top:15px;font-size:11px;color:#526174;line-height:1.55}.v337-source>summary,.v379-months>summary{cursor:pointer;display:list-item;min-height:36px;box-sizing:border-box;padding:9px 0;font-weight:600}.v337-source p{margin:6px 0}
   .v379-month-table{min-width:0;max-width:100%;overflow:auto}.v379-month-table table{border-collapse:collapse;width:100%;font-size:12px;white-space:nowrap}.v379-month-table th,.v379-month-table td{padding:10px 8px;border-bottom:1px solid #dfe7ee;text-align:right}.v379-month-table th:first-child{text-align:left}.v379-month-table .negative{color:#9d3648}
   .v337-bank-list{margin-top:8px}.v337-bank{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid #e7ecf1;font-size:13px}
   .v337-bank>span{display:flex;align-items:center;gap:8px}.v337-bank strong{font-variant-numeric:tabular-nums;white-space:nowrap}.v337-bank i{display:grid;place-items:center;width:28px;height:28px;border-radius:7px;color:white;font:800 11px/1 system-ui;font-style:normal}
   .v337-bank .bank-341{background:#e66c13}.v337-bank .bank-237{background:#b91d39}.v337-bank .bank-336{background:#161e29}.v337-bank.total{border:0;padding-top:14px;font-weight:700}
   .v337-month-status{min-height:50px;color:#526174;font-size:13px;line-height:1.6}

   .v393-tabs,.v393-stages{display:flex;flex-wrap:wrap;gap:6px;margin:12px 0}.v393-tabs button,.v393-stages button{font:inherit;font-size:12px;min-height:40px;border:1px solid #cbd8e5;border-radius:9px;background:#fff;padding:8px 12px;color:#294a69;cursor:pointer}.v393-tabs [aria-pressed=true],.v393-stages [aria-pressed=true]{background:#183b60;border-color:#183b60;color:#fff}.v393-explanation{font-size:12px;line-height:1.6;color:#526174;margin:12px 0}.v393-warning{font-size:12px;line-height:1.6;color:#7d4616;background:#fff4df;padding:11px;border-radius:9px}.v393-cash-split{font-size:12px;margin:14px 0;min-width:0}.v393-cash-split>div{display:grid;grid-template-columns:minmax(0,1.2fr) repeat(2,minmax(0,1fr));gap:8px;padding:10px 0;border-bottom:1px solid #e3eaf0;align-items:center}.v393-cash-split strong{text-align:right;font-variant-numeric:tabular-nums;overflow-wrap:anywhere}.v393-split-head{color:#617184;font-size:11px}.v393-split-head>span:not(:first-child){text-align:right}.v393-groups{display:grid;gap:0;margin:12px 0}.v393-groups>div{display:flex;justify-content:space-between;gap:14px;padding:10px 0;border-bottom:1px solid #e3eaf0;font-size:12px}.v393-groups strong{white-space:nowrap}.v393-one{grid-template-columns:minmax(0,1fr)}
   .v393-dialog{color:#20384e;border:1px solid #d9e2ec;border-radius:15px;width:min(720px,calc(100vw - 24px));max-width:calc(100vw - 24px);max-height:88vh;box-sizing:border-box;padding:20px;background:white;overflow:auto}.v393-dialog::backdrop{background:#0b203b88}.v393-dialog-head{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.v393-dialog h2{font-size:19px;margin:4px 0}.v393-dialog-note{font-size:12px;line-height:1.6;color:#526174}.v393-search{display:grid;gap:7px;font-size:12px;margin:16px 0}.v393-search input{font:inherit;padding:10px;border:1px solid #cbd8e5;border-radius:9px;min-height:44px;min-width:0}.v393-detail-row{padding:15px 0;border-bottom:1px solid #e2e9f0;min-width:0}.v393-detail-main{display:flex;justify-content:space-between;gap:14px;font-size:13px}.v393-detail-main strong{overflow-wrap:anywhere;min-width:0}.v393-detail-main b{white-space:nowrap;font-variant-numeric:tabular-nums}.v393-detail-row p,.v393-detail-count{font-size:12px;line-height:1.6;margin:7px 0;color:#526174;overflow-wrap:anywhere}.v393-tag{font-size:11px;background:#eef3f7;border-radius:6px;padding:3px 6px;color:#294c6b}.v393-detail-row details{font-size:11px;color:#617184;margin-top:8px}.v393-detail-row summary{cursor:pointer;min-height:32px;padding:6px 0;box-sizing:border-box}.v393-dialog [data-v393-more]{margin-top:16px}
   @media(max-width:400px){.v393-cash-split>div{grid-template-columns:minmax(0,1fr) repeat(2,minmax(0,1fr));gap:5px;font-size:11px}.v393-dialog{padding:15px}.v393-detail-main{font-size:12px}}
   @media(max-width:1050px){.v337-overview{grid-template-columns:minmax(0,1fr)}.v337-metric>strong{font-size:24px}}
   @media(max-width:600px){.v379-balance-range{grid-template-columns:repeat(2,minmax(0,1fr))}.v379-balance-range button{grid-column:1/-1}}
   @media(max-width:540px){.v337-metrics{grid-template-columns:minmax(0,1fr)}.v337-metric{flex-direction:row;align-items:center;gap:14px}.v337-metric>span{min-height:0;max-width:48%}.v337-metric>strong{font-size:22px;flex-shrink:0;max-width:60%}.v337-month .v168-cardhead{align-items:flex-start;flex-wrap:wrap;gap:10px}.v337-overview{gap:14px}}
  `;document.head.appendChild(style);
  render=function(){const result=previous.apply(this,arguments);paint();return result;};
  window.addEventListener('lts:data-invalidated',()=>{invalidate();if(visible())render();});
  S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN'){state.signedOut=event==='SIGNED_OUT';state.owner=null;state.month='';state.followCurrentMonth=true;state.mode='month';state.from='';state.to='';state.draftFrom='';state.draftTo='';state.draftError=null;state.basis='cash';state.stage='total';invalidate();document.getElementById('v337Overview')?.remove();}});
  window.__LTS_V337_MONTH={installed:true,state,refresh:()=>load(true)};if(visible())render();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V312_CARD_REVIEW||!window.LTSV337Month)return false;if(!w.__LTS_V337_MONTH){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V337_MONTH;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
 window.LTSV339Boot?.watch('lts-v337-month-overview.js',install);
})();
