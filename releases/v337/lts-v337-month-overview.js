/* Source-backed monthly summary alongside current per-bank cash. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V337_MONTH||!window.__LTS_V312_CARD_REVIEW||!window.parent.LTSV337Month)return;
  const model=window.parent.LTSV337Month,previous=render;
  const state={owner:null,day:null,month:'',sequence:0,status:'idle',data:null,range:null,scheduled:false,signedOut:false};
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  const visible=()=>!state.signedOut&&!!D&&!N.classList.contains('hidden')&&V==='Dashboard';
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x);
  const date=x=>x.split('-').reverse().join('/');
  function sync(){
   const current=generation(),businessDay=today();if(state.owner!==current||state.day!==businessDay){state.owner=current;state.day=businessDay;state.sequence++;state.status='idle';state.data=null;state.range=null;state.scheduled=false;}
   if(!state.month)state.month=today().slice(0,7);
  }
  function current(ticket){return !state.signedOut&&state.owner===ticket.owner&&generation()===ticket.owner&&state.day===ticket.day&&today()===ticket.day&&state.sequence===ticket.sequence&&state.month===ticket.month;}
  async function load(force=false){
   sync();if(!visible()||state.status==='loading'||(!force&&state.status!=='idle'))return;
   const range=model.bounds(state.month,today());state.range=range;
   if(!range){state.status='invalid';state.data=null;render();return;}
   if(force)window.__LTS_V227_TRANSPORT?.invalidate(false);
   const ticket={owner:state.owner,day:state.day,sequence:++state.sequence,month:state.month};
   state.status='loading';state.data=null;render();
   try{
    const result=await S.rpc('lts_browser_monthly_v229',{p_from:range.from,p_to:range.to});
    if(!current(ticket))return;
    const summary=result.error?null:model.summarize(result.data,range);
    if(!summary)throw Error('unavailable');state.data=summary;state.status='ready';
   }catch{if(current(ticket)){state.status='error';state.data=null;}}
   finally{if(current(ticket)&&visible())render();}
  }
  function monthly(){
   const range=model.bounds(state.month,today()),x=state.status==='ready'?state.data:null;
   const header='<div class="v168-cardhead"><div><span>Receitas e despesas</span><h2>Resumo do mês</h2></div><label class="v337-month-control">Mês<input type="month" aria-label="Mês do resumo" min="2013-10" max="'+today().slice(0,7)+'" value="'+esc(state.month)+'"></label></div>';
   const period=range?'<p class="v337-period">'+date(range.from)+' a '+date(range.to)+(range.partial?' · mês em andamento':'')+'</p>':'';
   if(!x){const invalid=state.status==='invalid';return header+period+'<p class="v337-month-status" role="status">'+(invalid?'Escolha um mês entre outubro de 2013 e o mês atual.':state.status==='error'?'Não foi possível conferir este mês. Tente novamente.':'Consultando os valores deste mês…')+'</p>'+(state.status==='error'?'<button class="v168-btn" data-v337-retry>Tentar novamente</button>':'');}
   const metric=(label,value,kind)=>'<div class="v337-metric '+kind+'"><span>'+label+'</span><strong>'+money(value)+'</strong></div>';
   return header+period+'<div class="v337-metrics">'+metric('Receitas e entradas extraordinárias',x.entries,'income')+metric('Despesas por competência',x.expenses,'expense')+metric('Resultado por competência',x.result,x.result<0?'negative':'result')+'</div><details class="v337-source"><summary>Atualização</summary><p>Período de '+date(x.from)+' a '+date(x.to)+'. Receitas '+money(x.revenue)+' e entradas extraordinárias '+money(x.extraordinary)+'.</p><p>O resultado é a diferença entre essas entradas e as despesas por competência. Transferências entre contas próprias ficam fora; pagamentos de fatura não são uma segunda despesa. O resultado do mês não é o saldo bancário.</p></details>';
  }
  function banks(){
   const cash=window.__LTS_V178_STATE?.cash,positions=cash?.status==='ready'&&window.__LTS_V178_REVIEW.cashComplete(cash)?model.bankPositions(cash.data,today()):null;
   const header='<div class="v168-cardhead"><div><span>Contas correntes · hoje</span><h2>Posição por banco</h2></div></div>';
   if(!positions)return header+'<p class="v337-month-status" role="status">A posição por banco ainda não está disponível.</p><button class="v168-btn" data-v337-banks-retry>Atualizar posições</button>';
   return header+'<div class="v337-bank-list">'+positions.rows.map(x=>'<div class="v337-bank"><span><i class="bank-'+x.code+'">'+(x.code==='341'?'I':x.code==='237'?'B':'C6')+'</i>'+x.name+'</span><strong>'+money(x.balance)+'</strong></div>').join('')+'<div class="v337-bank total"><span>Total em contas</span><strong>'+money(positions.total)+'</strong></div></div><details class="v337-source"><summary>Atualização</summary><p>Posição conferida para '+date(positions.asOf)+'. A data de recebimento de cada saldo está em Atualização, junto às contas correntes. Aplicações, ações e FGTS aparecem separadamente no painel.</p></details>';
  }
  function paint(){
   sync();if(!visible())return;const root=document.querySelector('.v168-dashboard');if(!root)return;
   let section=root.querySelector('#v337Overview');if(!section){section=document.createElement('section');section.id='v337Overview';section.className='v337-overview';section.setAttribute('aria-label','Resumo mensal e bancos');const anchor=root.querySelector('.v168-grid.two');if(anchor)anchor.before(section);else root.querySelector('.v168-kpis')?.after(section);}
   section.innerHTML='<article class="v168-card v337-month">'+monthly()+'</article><article class="v168-card v337-banks">'+banks()+'</article>';
   const control=section.querySelector('[aria-label="Mês do resumo"]');control.onchange=()=>{state.month=control.value;state.sequence++;state.status='idle';state.data=null;state.range=null;render();};
   section.querySelector('[data-v337-retry]')?.addEventListener('click',()=>load(true));
   section.querySelector('[data-v337-banks-retry]')?.addEventListener('click',()=>window.__LTS_V178_REVIEW.refreshCashOnly(true));
   if(state.status==='idle'&&!state.scheduled){state.scheduled=true;queueMicrotask(()=>{state.scheduled=false;load(false);});}
  }
  const style=document.createElement('style');style.id='v337-month-style';style.textContent=`
   .v337-overview{display:grid;grid-template-columns:minmax(0,1.7fr) minmax(280px,1fr);gap:18px;margin:18px 0 22px;min-width:0}
   .v337-overview .v168-card{min-width:0;margin:0}.v337-month-control{display:flex;gap:7px;align-items:center;font-size:12px;color:#526174;min-width:0}
   .v337-month-control input{border:1px solid #d4dee8;border-radius:9px;min-height:44px;background:#fff;padding:8px;box-sizing:border-box;color:#18334e;max-width:100%;font:inherit}
   .v337-period{font-size:12px;color:#526174;line-height:1.5;margin:6px 0 16px}.v337-metrics{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}
   .v337-metric{border:1px solid #e2e8ee;border-top:3px solid #3979b2;border-radius:11px;padding:13px 12px;background:#f8fafc;min-width:0;display:flex;flex-direction:column;justify-content:space-between;gap:12px}
   .v337-metric>span{font-size:12px;color:#526174;line-height:1.5;min-height:36px}.v337-metric>strong{font-size:clamp(18px,1.55vw,25px);font-variant-numeric:tabular-nums;letter-spacing:-.035em;line-height:1.25;overflow-wrap:anywhere}
   .v337-metric.expense,.v337-metric.negative{border-top-color:#9d3648}.v337-metric.result{border-top-color:#279677}.v337-metric.result strong{color:#167157}.v337-metric.negative strong{color:#9d3648}
   .v337-source{margin-top:15px;font-size:11px;color:#526174;line-height:1.55}.v337-source>summary{cursor:pointer;display:list-item;min-height:28px;box-sizing:border-box;padding:6px 0;font-weight:600}.v337-source p{margin:6px 0}
   .v337-bank-list{margin-top:8px}.v337-bank{display:flex;justify-content:space-between;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid #e7ecf1;font-size:13px}
   .v337-bank>span{display:flex;align-items:center;gap:8px}.v337-bank strong{font-variant-numeric:tabular-nums;white-space:nowrap}.v337-bank i{display:grid;place-items:center;width:28px;height:28px;border-radius:7px;color:white;font:800 11px/1 system-ui;font-style:normal}
   .v337-bank .bank-341{background:#e66c13}.v337-bank .bank-237{background:#b91d39}.v337-bank .bank-336{background:#161e29}.v337-bank.total{border:0;padding-top:14px;font-weight:700}
   .v337-month-status{min-height:50px;color:#526174;font-size:13px;line-height:1.6}
   @media(max-width:1050px){.v337-overview{grid-template-columns:minmax(0,1fr)}.v337-metric>strong{font-size:24px}}
   @media(max-width:540px){.v337-metrics{grid-template-columns:minmax(0,1fr)}.v337-metric{flex-direction:row;align-items:center;gap:14px}.v337-metric>span{min-height:0;max-width:48%}.v337-metric>strong{font-size:22px;flex-shrink:0}.v337-month .v168-cardhead{align-items:flex-start;flex-wrap:wrap;gap:10px}.v337-overview{gap:14px}}
  `;document.head.appendChild(style);
  render=function(){const result=previous.apply(this,arguments);paint();return result;};
  window.addEventListener('lts:data-invalidated',()=>{state.sequence++;state.status='idle';state.data=null;state.range=null;if(visible())render();});
  S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'||event==='SIGNED_IN'){state.signedOut=event==='SIGNED_OUT';state.owner=null;state.month='';state.sequence++;state.status='idle';state.data=null;document.getElementById('v337Overview')?.remove();}});
  window.__LTS_V337_MONTH={installed:true,state,refresh:()=>load(true)};if(visible())render();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V312_CARD_REVIEW||!window.LTSV337Month)return false;if(!w.__LTS_V337_MONTH){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V337_MONTH;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
})();
