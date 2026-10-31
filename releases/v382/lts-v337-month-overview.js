/* Source-backed monthly and selected-period balances, alongside current bank cash. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V337_MONTH||!window.__LTS_V312_CARD_REVIEW||!window.parent.LTSV337Month)return;
  const model=window.parent.LTSV337Month,previous=render;
  const state={owner:null,day:null,month:'',followCurrentMonth:true,mode:'month',from:'',to:'',draftFrom:'',draftTo:'',draftError:null,sequence:0,status:'idle',data:null,range:null,scheduled:false,signedOut:false};
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  const visible=()=>!state.signedOut&&!!D&&!N.classList.contains('hidden')&&V==='Dashboard';
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x);
  const date=x=>x.split('-').reverse().join('/');
  const monthName=x=>new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}).format(new Date(x+'-01T12:00:00Z')).replace('.','');
  const selection=()=>JSON.stringify([state.mode,state.month,state.from,state.to]);
  function invalidate(){state.sequence++;state.status='idle';state.data=null;state.range=null;}
  function sync(){
   const current=generation(),businessDay=today();
   if(state.owner!==current||state.day!==businessDay){state.owner=current;state.day=businessDay;invalidate();state.scheduled=false;}
   if(!state.month||state.followCurrentMonth)state.month=businessDay.slice(0,7);
  }
  const selectedRange=()=>state.mode==='period'?model.periodBounds(state.from,state.to,today()):model.bounds(state.month,today());
  function current(ticket){return !state.signedOut&&state.owner===ticket.owner&&generation()===ticket.owner&&state.day===ticket.day&&today()===ticket.day&&state.sequence===ticket.sequence&&selection()===ticket.selection;}
  async function load(force=false){
   sync();if(!visible()||state.status==='loading'||(!force&&state.status!=='idle'))return;
   const range=selectedRange();state.range=range;
   if(!range){state.status='invalid';state.data=null;render();return;}
   if(force)window.__LTS_V227_TRANSPORT?.invalidate(false);
   const ticket={owner:state.owner,day:state.day,sequence:++state.sequence,selection:selection()};
   state.status='loading';state.data=null;render();
   try{
    const result=await S.rpc('lts_browser_monthly_v229',{p_from:range.from,p_to:range.to});
    if(!current(ticket))return;
    const summary=result.error?null:(state.mode==='period'?model.summarizePeriod(result.data,range):model.summarize(result.data,range));
    if(!summary)throw Error('unavailable');state.data=summary;state.status='ready';
   }catch{if(current(ticket)){state.status='error';state.data=null;}}
   finally{if(current(ticket)&&visible())render();}
  }
  function controls(){
   const mode='<div class="v379-balance-modes" role="group" aria-label="Visão do balanço"><button type="button" data-v379-mode="month" aria-pressed="'+(state.mode==='month')+'">Mês</button><button type="button" data-v379-mode="period" aria-pressed="'+(state.mode==='period')+'">Período</button></div>';
   if(state.mode==='month')return mode+'<label class="v337-month-control">Mês<input type="month" aria-label="Mês do resumo" min="2013-10" max="'+today().slice(0,7)+'" value="'+esc(state.month)+'"></label>';
   return mode+'<div class="v379-balance-range"><label>De<input type="date" aria-label="Data inicial do balanço" min="2013-10-10" max="'+today()+'" value="'+esc(state.draftFrom)+'"></label><label>Até<input type="date" aria-label="Data final do balanço" min="2013-10-10" max="'+today()+'" value="'+esc(state.draftTo)+'"></label><button type="button" class="v168-btn primary" data-v379-apply>Aplicar intervalo</button>'+(state.draftError?'<p role="alert">'+esc(state.draftError)+'</p>':'')+'</div>';
  }
  function monthly(){
   const range=selectedRange(),x=state.status==='ready'?state.data:null,isPeriod=state.mode==='period';
   const header='<div class="v168-cardhead"><div><span>Receitas e despesas</span><h2>'+(isPeriod?'Balanço do período':'Resumo do mês')+'</h2></div></div><div class="v379-balance-controls">'+controls()+'</div>';
   const period=range?'<p class="v337-period">'+date(range.from)+' a '+date(range.to)+(range.partial?(isPeriod?' · até hoje':' · mês em andamento'):'')+'</p>':'';
   if(!x)return header+period+'<p class="v337-month-status" role="status">'+(state.status==='invalid'?'Escolha um intervalo válido entre 10/10/2013 e hoje.':state.status==='error'?'Não foi possível conferir este período. Tente novamente.':'Consultando os valores deste período…')+'</p>'+(state.status==='error'?'<button class="v168-btn" data-v337-retry>Tentar novamente</button>':'');
   const metric=(label,value,kind)=>'<div class="v337-metric '+kind+'"><span>'+label+'</span><strong>'+money(value)+'</strong></div>';
   const breakdown=isPeriod?'<details class="v379-months"><summary>Ver mês a mês ('+x.months.length+')</summary><div class="v379-month-table"><table><thead><tr><th>Mês</th><th>Entradas</th><th>Despesas</th><th>Resultado</th></tr></thead><tbody>'+x.months.map(m=>'<tr><th>'+esc(monthName(m.month))+'</th><td>'+money(m.entries)+'</td><td>'+money(m.expenses)+'</td><td class="'+(m.result<0?'negative':'')+'">'+money(m.result)+'</td></tr>').join('')+'</tbody></table></div></details>':'';
   return header+period+(isPeriod?'<p class="v379-accumulated">Acumulado do período</p>':'')+'<div class="v337-metrics">'+metric('Receitas e entradas extraordinárias',x.entries,'income')+metric('Despesas por competência',x.expenses,'expense')+metric('Resultado por competência',x.result,x.result<0?'negative':'result')+'</div>'+breakdown+'<details class="v337-source"><summary>Atualização</summary><p>Período de '+date(x.from)+' a '+date(x.to)+'. Receitas '+money(x.revenue)+' e entradas extraordinárias '+money(x.extraordinary)+'.</p><p>O resultado é a diferença entre essas entradas e as despesas por competência. Transferências entre contas próprias ficam fora; pagamentos de fatura não são uma segunda despesa. O resultado do período não é o saldo bancário.</p></details>';
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
    if(mode==='period'&&!state.from){const r=model.bounds(state.month,today())||model.bounds(today().slice(0,7),today());state.from=r.from;state.to=r.to;state.draftFrom=r.from;state.draftTo=r.to;}
    invalidate();render();
   };
   const control=section.querySelector('[aria-label="Mês do resumo"]');
   if(control)control.onchange=()=>{if(!owns())return;state.month=control.value;state.followCurrentMonth=!control.value||control.value===today().slice(0,7);invalidate();render();};
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
    if(!model.periodBounds(from,to,today())){state.draftError='Informe datas entre 10/10/2013 e hoje, com a data inicial antes da final. O intervalo aplicado foi preservado.';render();return;}
    state.from=from;state.to=to;state.draftError=null;invalidate();render();
   });
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
   @media(max-width:1050px){.v337-overview{grid-template-columns:minmax(0,1fr)}.v337-metric>strong{font-size:24px}}
   @media(max-width:600px){.v379-balance-range{grid-template-columns:repeat(2,minmax(0,1fr))}.v379-balance-range button{grid-column:1/-1}}
   @media(max-width:540px){.v337-metrics{grid-template-columns:minmax(0,1fr)}.v337-metric{flex-direction:row;align-items:center;gap:14px}.v337-metric>span{min-height:0;max-width:48%}.v337-metric>strong{font-size:22px;flex-shrink:0;max-width:60%}.v337-month .v168-cardhead{align-items:flex-start;flex-wrap:wrap;gap:10px}.v337-overview{gap:14px}}
  `;document.head.appendChild(style);
  render=function(){const result=previous.apply(this,arguments);paint();return result;};
  window.addEventListener('lts:data-invalidated',()=>{invalidate();if(visible())render();});
  S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN'){state.signedOut=event==='SIGNED_OUT';state.owner=null;state.month='';state.followCurrentMonth=true;state.mode='month';state.from='';state.to='';state.draftFrom='';state.draftTo='';state.draftError=null;invalidate();document.getElementById('v337Overview')?.remove();}});
  window.__LTS_V337_MONTH={installed:true,state,refresh:()=>load(true)};if(visible())render();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V312_CARD_REVIEW||!window.LTSV337Month)return false;if(!w.__LTS_V337_MONTH){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V337_MONTH;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
 window.LTSV339Boot?.watch('lts-v337-month-overview.js',install);
})();
