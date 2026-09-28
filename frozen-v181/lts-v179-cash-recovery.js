/* V178 replaces the V177 polling/drawer layer. Financial facts stay server-side. */
(function(){
 'use strict';
 const outer=document.getElementById('shell'); let generation=0;
 function runtime(){
  'use strict';
  if(window.__LTS_V178_REVIEW?.installed||!window.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed)return;
  const v168=window.__LTS_V168_STATE,v175=window.__LTS_V175_STATE;
  const previousRender=render,previousNav=renderNav,previousDashboard=dashboard,previousExpenses=despesas;
  const rawFetch=window.fetch.bind(window),inflight=new Map(),cache=new Map();
  const state=window.__LTS_V178_STATE={cash:{status:'idle'},wealth:{status:'idle'},forecast:{status:'idle'},awards:{status:'idle'},dashboardReport:{status:'idle'},detail:null,errors:[],diagnostics:[],date:null};
  let dashboardFlight=null,dashboardSerial=0;
  const arr=x=>Array.isArray(x)?x:[],finite=x=>x==null||x===''?null:(Number.isFinite(Number(x))?Number(x):null);
  const money=x=>finite(x)==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x));
  const escape=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const normalize=x=>String(x??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const day=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const dateLabel=x=>/^\d{4}-\d{2}-\d{2}$/.test(String(x))?x.split('-').reverse().join('/'):String(x||'—');
  const monthLabel=x=>/^\d{4}-\d{2}/.test(String(x))?new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit'}).format(new Date(String(x).slice(0,7)+'-01T12:00:00Z')):'Histórico';
  const total=xs=>xs.reduce((a,b)=>a+(finite(b)||0),0);
  const template=html=>{const t=document.createElement('template');t.innerHTML=html;return t};
  const yearRange=()=>({from:day().slice(0,4)+'-01-01',to:day(),label:'Ano atual'});
  function reportRange(){
   const s=v168.expense,t=day();let from=t.slice(0,4)+'-01-01';
   if(s.key==='all')from='2013-10-10';
   else if(s.key==='6m'||s.key==='12m'){const d=new Date(t.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));from=d.toISOString().slice(0,10)}
   else if(s.key==='custom')return{from:s.customFrom||from,to:s.customTo||t,label:'Período personalizado'};
   return{from,to:t,label:s.key==='all'?'Desde 2013':s.key==='6m'?'6 meses':s.key==='12m'?'12 meses':'Ano atual'};
  }
  const safeMessage=error=>String(error?.message||error||'Falha').replace(/Bearer\s+\S+/gi,'Bearer [redacted]').replace(/eyJ[A-Za-z0-9._-]+/g,'[redacted]').slice(0,240);
  function cashReasons(s){
   const x=s?.data,reasons=[];
   if(s?.status!=='ready')reasons.push('reader_'+String(s?.status||'missing'));
   if(s?.date!==day())reasons.push('client_date_mismatch');
   if(x?.as_of!==day())reasons.push('server_date_mismatch');
   if(x?.status!=='complete')reasons.push('payload_not_complete');
   const fields=['cash','d0','brokerage_available','available_total'];
   for(const field of fields)if(finite(x?.[field])==null)reasons.push('non_finite_'+field);
   if(fields.every(field=>finite(x?.[field])!=null)&&Math.abs(total([x.cash,x.d0,x.brokerage_available])-Number(x.available_total))>=0.02)reasons.push('sum_mismatch');
   return reasons;
  }
  function publishCashDiagnostic(){
   const s=state.cash,x=s?.data,last=state.diagnostics.filter(d=>d.name==='lts_browser_cash_today_v178').slice(-5);
   const summary={build:'v179-cash-recovery-1',local_day:day(),reader_status:s?.status||'missing',state_date:s?.date||null,error:s?.error||null,reasons:cashReasons(s),payload:x?{server_status:x.status||null,server_as_of:x.as_of||null,fields:{cash:finite(x.cash)!=null,d0:finite(x.d0)!=null,brokerage_available:finite(x.brokerage_available)!=null,available_total:finite(x.available_total)!=null},sum_consistent:[x.cash,x.d0,x.brokerage_available,x.available_total].every(v=>finite(v)!=null)?Math.abs(total([x.cash,x.d0,x.brokerage_available])-Number(x.available_total))<0.02:null}:null,history:last,concurrent:state.diagnostics.slice(-20).map(d=>({name:d.name,outcome:d.outcome,http_status:d.http_status,duration_ms:d.duration_ms}))};
   document.documentElement.setAttribute('data-lts-v179-cash-diagnostic',JSON.stringify(summary));
  }
  function recordDiagnostic(entry){state.diagnostics.push({...entry,at:new Date().toISOString()});state.diagnostics=state.diagnostics.slice(-50);publishCashDiagnostic()}
  function logError(name,error){state.errors.push({reader:name,message:safeMessage(error),code:error?.code||null,http_status:error?.httpStatus||null,at:new Date().toISOString()});state.errors=state.errors.slice(-30)}
  async function request(name,args={},timeout=20000,force=false){
   const started=Date.now();let httpStatus=null,serverCode=null;
   const auth=await S.auth.getSession(),token=auth?.data?.session?.access_token;
   if(!token){const error=Error('Sessão indisponível. Entre novamente.');error.code='SESSION_UNAVAILABLE';recordDiagnostic({name,outcome:'session_unavailable',http_status:null,server_code:null,duration_ms:Date.now()-started,message:safeMessage(error)});throw error}
   const key=token+'|'+name+'|'+JSON.stringify(args),stored=cache.get(key);
   if(!force&&stored&&Date.now()-stored.time<2000)return structuredClone(stored.data);
   if(!force&&inflight.has(key))return structuredClone(await inflight.get(key));
   const job=(async()=>{
    const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),timeout);
    try{
     const res=await rawFetch(U+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:K,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(args),signal:abort.signal});
     httpStatus=res.status;let data;
     try{data=await res.json()}catch(parseError){const error=Error('Resposta inválida do serviço.');error.code='INVALID_JSON';error.httpStatus=res.status;throw error}
     serverCode=data?.code||null;
     if(!res.ok){const error=Error(data?.message||'Falha na leitura.');error.code=serverCode||'HTTP_ERROR';error.httpStatus=res.status;throw error}
     recordDiagnostic({name,outcome:'success',http_status:res.status,server_code:serverCode,duration_ms:Date.now()-started,message:null});
     cache.set(key,{time:Date.now(),data});return data;
    }catch(error){const outcome=error?.name==='AbortError'?'client_timeout':error?.code==='SESSION_UNAVAILABLE'?'session_unavailable':error?.httpStatus?'http_error':'network_error';try{error.ltsOutcome=outcome}catch{}recordDiagnostic({name,outcome,http_status:error?.httpStatus||httpStatus,server_code:error?.code||serverCode,duration_ms:Date.now()-started,message:safeMessage(error)});logError(name,error);throw error}finally{clearTimeout(timer)}
   })();
   inflight.set(key,job);try{return structuredClone(await job)}finally{if(inflight.get(key)===job)inflight.delete(key)}
  }
  window.fetch=async function(input,init){
   const url=typeof input==='string'?input:input?.url||'',name=url.split('/').pop();
   let target=null;
   if(/^lts_browser_expense_executive_v\d+$/.test(name))target='lts_browser_expenses_v178';
   if(/^lts_browser_monthly_balance_v\d+$/.test(name))target='lts_browser_monthly_v178';
   if(!target)return rawFetch(input,init);
   try{const args=JSON.parse(init?.body||'{}'),data=await request(target,args,22000);return new Response(JSON.stringify(data),{status:200,headers:{'Content-Type':'application/json'}})}
   catch(error){return new Response(JSON.stringify({message:'Não foi possível atualizar este relatório.'}),{status:503,headers:{'Content-Type':'application/json'}})}
  };
  async function loadState(key,name,args={},force=false){
   const s=state[key];if(s.status==='loading'||(!force&&s.status!=='idle'))return;
   const token=(s.token||0)+1;s.token=token;s.status='loading';s.error=null;s.outcome=null;s.code=null;s.httpStatus=null;
   try{const value=await request(name,args,20000,force);if(s.token!==token)return;s.data=value;s.date=day();s.status='ready'}
   catch(e){if(s.token===token){s.status='error';s.error=String(e.message||e);s.outcome=e?.ltsOutcome||null;s.code=e?.code||null;s.httpStatus=e?.httpStatus||null}}
   finally{if(s.token===token){publishCashDiagnostic();queueMicrotask(()=>{if(D&&!N.classList.contains('hidden'))render()})}}
   return true;
  }
  function mergeForecast(parts){
   const days=new Map(),events=new Map();
   for(const part of parts){const f=part?.flow?.current_future||{};for(const d of arr(f.days))days.set(d.date,d);for(const e of arr(f.events))events.set([e.source,e.source_ref,e.event_date].join('|'),e)}
   return{ok:true,flow:{current_future:{days:[...days.values()].sort((a,b)=>a.date.localeCompare(b.date)),events:[...events.values()]}}};
  }
  async function loadForecast(force=false){
   const s=state.forecast;if(s.status==='loading'||(!force&&s.status!=='idle'))return;
   const token=(s.token||0)+1;s.token=token;s.status='loading';s.date=day();s.parts=[];s.data=null;s.error=null;
   const now=day(),year=Number(now.slice(0,4)),ranges=[{p_from:now,p_to:year+'-12-31'},{p_from:(year+1)+'-01-01',p_to:(year+1)+'-12-31'}];
   try{
    for(const r of ranges){const p=await request('lts_browser_flow_v12',r,24000,force);if(s.token!==token)return;
     if(!arr(p?.flow?.current_future?.days).length)throw Error('Projeção sem dias retornados.');s.parts.push(p);s.data=mergeForecast(s.parts);render();}
    s.status='ready';
   }catch(e){if(s.token===token){s.status=s.parts.length?'partial':'error';s.error=String(e.message||e)}}
   finally{if(s.token===token&&D&&!N.classList.contains('hidden'))render()}
  }
  function retryableCashFailure(s){return s?.status==='error'&&(s.outcome==='client_timeout'||s.outcome==='network_error'||String(s.code)==='57014'||[408,429,500,502,503,504].includes(Number(s.httpStatus)))}
  async function priorityCash(force=false,serial){
   const s=state.cash,shouldStart=s.status!=='loading'&&(force||s.status==='idle');
   if(!shouldStart)return false;
   const first=loadState('cash','lts_browser_cash_today_v178',{},force);
   queueMicrotask(()=>{if(serial===dashboardSerial&&D&&!N.classList.contains('hidden'))render()});
   await first;
   if(serial!==dashboardSerial)return true;
   if(retryableCashFailure(s)){
    const retry=loadState('cash','lts_browser_cash_today_v178',{},true);
    queueMicrotask(()=>{if(serial===dashboardSerial&&D&&!N.classList.contains('hidden'))render()});
    await retry;
   }
   return true;
  }
  function startDashboard(force=false){
   const t=day();
   const changed=state.date!==t;
   if(changed){state.date=t;dashboardSerial++;for(const k of ['cash','forecast','dashboardReport']){state[k].token=(state[k].token||0)+1;state[k].status='idle';state[k].data=null}cache.clear()}
   if(dashboardFlight)return changed?dashboardFlight.then(()=>startDashboard(force)):dashboardFlight;
   const serial=++dashboardSerial,r=yearRange();
   const job=(async()=>{
    await priorityCash(force,serial);
    if(serial!==dashboardSerial)return;
    await Promise.allSettled([
     loadState('dashboardReport','lts_browser_expenses_v178',{p_from:r.from,p_to:r.to},force),
     loadState('wealth','lts_browser_wealth_detail_v4',{},force),
     loadState('awards','lts_browser_awards_v178',{},force),
     loadForecast(force)
    ]);
   })().catch(error=>logError('dashboard_orchestration',error));
   dashboardFlight=job;job.finally(()=>{if(dashboardFlight===job)dashboardFlight=null});return job;
  }
  function cashComplete(s){const x=s.data;return s.status==='ready'&&s.date===day()&&x?.as_of===day()&&x.status==='complete'&&[x.cash,x.d0,x.brokerage_available,x.available_total].every(v=>finite(v)!=null)&&Math.abs(total([x.cash,x.d0,x.brokerage_available])-Number(x.available_total))<0.02}
  function kpi(root,label,value,note,newLabel){
   const el=[...root.querySelectorAll('.v168-kpi')].find(x=>normalize(x.querySelector('span')?.textContent).trim()===normalize(label));
   if(!el)return;
   if(newLabel)el.querySelector('span').textContent=newLabel;
   el.querySelector('strong').textContent=money(value);
   if(el.querySelector('small'))el.querySelector('small').textContent=note||'';
  }
  function reportRank(data,limit=99){
   const list=arr(data?.management_groups).filter(g=>g.name!=='Faturas conciliadas pelo total').slice(0,limit),max=Math.max(1,...list.map(g=>Math.abs(g.total)));
   return '<div class="v178-rank">'+list.map((g,i)=>'<div class="v178-rankrow"><span>'+(i+1)+'</span><div><button type="button" class="v178-open title" data-group="'+escape(g.name)+'">'+escape(g.name)+'</button><i><u style="width:'+Math.max(1,Math.abs(g.total)/max*100)+'%"></u></i></div><button type="button" class="v178-open amount" data-group="'+escape(g.name)+'">'+money(g.total)+'</button></div>').join('')+'</div>';
  }
  function dashboard178(){
   const ds=v168.dashboard;ds.started=true;ds.loading=false;ds.error=null;ds.detailErrors=[];
   ds.data=ds.data||{};
   if(state.wealth.data)ds.data.wealth=state.wealth.data;
   if(state.dashboardReport.data)ds.data.expense=state.dashboardReport.data;
   const f=state.forecast.date===day()?state.forecast.data:null;
   ds.data.flow=f?structuredClone(f):{flow:{current_future:{days:[],events:[]}}};
   if(cashComplete(state.cash)){
    const days=ds.data.flow.flow.current_future.days.filter(d=>d.date!==day());days.unshift(state.cash.data.day);ds.data.flow.flow.current_future.days=days;
   }
   const saved=v175.expense.data;
   v175.expense.data=state.dashboardReport.data||null;
   let html;try{html=previousDashboard()}finally{v175.expense.data=saved}
   const t=template(html),root=t.content.querySelector('.v168-dashboard');if(!root)return html;
   root.querySelectorAll('.v168-loadstatus').forEach(x=>x.remove());
   const complete=cashComplete(state.cash),c=complete?state.cash.data:null;
   const pendingCash=state.cash.status==='idle'||state.cash.status==='loading';
   const note=pendingCash?'Carregando a posição de hoje':complete?'Posição calculada no Fluxo · '+dateLabel(c.as_of):'Posição indisponível';
   kpi(root,'Contas correntes hoje',c?.cash,note);
   kpi(root,'Aplicações D0',c?.d0,complete?'Disponibilidade de curto prazo':'Aguardando posição completa');
   kpi(root,'RSUs já disponíveis',c?.brokerage_available,complete?'Ações disponíveis + saldo em corretora':'Aguardando posição completa');
   kpi(root,'FGTS',c?.fgts,'Recurso restrito');
   kpi(root,'Total disponível hoje',c?.available_total,complete?'Contas + D0 + corretora · posição calculada':'Não calculado sem a posição completa');
   const warnings=[];
   if(!complete)warnings.push(pendingCash?'Atualizando a posição de caixa…':'Não foi possível obter a posição completa de caixa.');
   if(state.wealth.status==='error')warnings.push('Posições patrimoniais não atualizadas.');
   if(state.dashboardReport.status==='error')warnings.push('Relatório de despesas não atualizado.');
   if(warnings.length)(root.querySelector('.v168-pagehead')||root.firstElementChild)?.insertAdjacentHTML('afterend','<div class="v178-notice" role="status">'+escape(warnings.join(' '))+' <button class="v178-refresh">Tentar novamente</button></div>');
   const cards=[...root.querySelectorAll('.v168-card')];
   const forecastReady=!!f&&state.forecast.date===day();
   if(!forecastReady){for(const card of cards.filter(x=>/Evolução projetada|O que exige decisão/.test(x.querySelector('h2')?.textContent||''))){const head=card.querySelector('.v168-cardhead')?.outerHTML||'';card.innerHTML=head+'<div class="v178-empty">'+(state.forecast.status==='loading'?'Carregando a projeção…':'Projeção indisponível. Nenhuma data de falta de caixa foi calculada.')+'</div><button class="v178-refresh">Atualizar projeção</button>'}}
   else if(state.forecast.status!=='ready'){
    const last=arr(f.flow.current_future.days).at(-1)?.date;
    cards.find(x=>/Evolução projetada/.test(x.querySelector('h2')?.textContent||''))?.insertAdjacentHTML('beforeend','<div class="v178-notice">Projeção disponível até '+escape(dateLabel(last))+'. O restante ainda não foi atualizado.</div>');
   }
   const exp=cards.find(x=>/Principais grupos/.test(x.querySelector('h2')?.textContent||''));
   if(exp){const head=exp.querySelector('.v168-cardhead')?.outerHTML||'';exp.innerHTML=head+(state.dashboardReport.data?reportRank(state.dashboardReport.data,12):'<div class="v178-empty">'+(state.dashboardReport.status==='error'?'Despesas indisponíveis.':'Carregando despesas…')+'</div>');exp.dataset.v178Scope='dashboard'}
   kpi(root,'Total de despesas do período',state.dashboardReport.data?.summary?.selected_total,dateLabel(yearRange().from)+' a '+dateLabel(yearRange().to));
   publishCashDiagnostic();return t.innerHTML;
  }
  function expenses178(){
   const html=previousExpenses(),t=template(html),root=t.content.querySelector('.v168-expenses');if(!root)return html;
   root.querySelectorAll('.v175-property,.v174-property-note,.v175-sale-strip,.v174-audit-strip').forEach(e=>e.remove());
   root.querySelectorAll('.v175-open-issues').forEach(e=>{e.innerHTML='<div class="v178-notice">Há movimentações aguardando confirmação. Consulte Atualizações.</div>'});
   root.querySelectorAll('.v175-coverage,.v172-coverage,.v174-coverage,.v171-reconciliation').forEach(e=>e.remove());
   const data=v175.expense.data,tab=v168.expense.tab;
   if(['overview','categories'].includes(tab)&&data?.version==='expense-executive-v20-v178-review'){
    const cards=[...root.querySelectorAll('.v168-card')],target=tab==='categories'?root.querySelector('.v175-categories'):cards.find(x=>/maiores grupos/i.test(x.querySelector('h2')?.textContent||''));
    if(target){const head=target.querySelector('.v168-cardhead')?.outerHTML||'';target.innerHTML=head+reportRank(data,tab==='overview'?15:99);target.dataset.v178Scope='expenses'}
   }
   root.querySelectorAll('.v168-cardhead span').forEach(e=>{if(/^Composição auditada$/i.test(e.textContent.trim()))e.textContent='Composição'});
   return t.innerHTML;
  }
  let sequence=0,lastFocus=null;
  const apartment='Apartamento · CIPÓ 396';
  function closeDetail(){sequence++;state.detail=null;document.getElementById('v178Drawer')?.remove();lastFocus?.focus?.()}
  function shellDetail(){
   document.getElementById('v178Drawer')?.remove();
   const d=state.detail,host=document.createElement('div');host.id='v178Drawer';
   host.innerHTML='<div class="v178-backdrop"></div><aside class="v178-drawer" role="dialog" aria-modal="true" aria-labelledby="v178DetailTitle"><header><div><span>Detalhamento</span><h2 id="v178DetailTitle">'+escape(d.subgroup||d.group||'Lançamentos')+'</h2><small>'+escape(dateLabel(d.range.from)+' a '+dateLabel(d.range.to))+'</small></div><button class="v178-close" aria-label="Fechar">×</button></header><div class="v178-detail-summary"></div><div class="v178-components"></div><div class="v178-filter"><input type="search" placeholder="Filtrar histórico, conta, cartão ou pessoa" disabled></div><div class="v178-detail-scroll" tabindex="0"><table><thead><tr><th>Data / mês</th><th>Histórico</th><th>Conta ou cartão</th><th>Pessoa</th><th>Valor</th></tr></thead><tbody></tbody></table></div><footer><span role="status">Carregando lançamentos…</span><button class="v178-retry" hidden>Atualizar lista</button></footer></aside>';
   document.body.appendChild(host);
   host.querySelector('.v178-close').onclick=closeDetail;host.querySelector('.v178-backdrop').onclick=closeDetail;
   host.querySelector('.v178-filter input').oninput=e=>{if(state.detail){state.detail.query=e.target.value;drawRows()}};
   host.querySelector('.v178-retry').onclick=()=>openDetail(d.group,d.subgroup,d.range,d.expected);
   host.addEventListener('keydown',e=>{if(e.key==='Escape')closeDetail();if(e.key==='Tab'){const els=[...host.querySelectorAll('button:not([hidden]),input:not(:disabled),[tabindex="0"]')];const first=els[0],last=els.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}}});
   host.querySelector('.v178-close').focus();
  }
  function drawRows(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||!host)return;
   const q=normalize(d.query),rows=d.rows.filter(r=>!q||normalize([r.description,r.account_source,r.beneficiary,r.component,r.category].join(' ')).includes(q)),tbody=host.querySelector('tbody');
   tbody.innerHTML=rows.map(r=>'<tr data-row-key="'+escape(r.key)+'"><td>'+escape(r.date_kind==='day'?dateLabel(r.date):r.date_kind==='historical'?'Histórico':monthLabel(r.period))+(r.date_kind==='day'&&r.period&&r.date?.slice(0,7)!==r.period.slice(0,7)?'<small>Fatura '+escape(monthLabel(r.period))+'</small>':'')+'</td><td><b>'+escape(r.description)+'</b>'+(d.group===apartment&&!d.subgroup?'<small>'+escape(r.component||'')+'</small>':'')+'</td><td>'+escape(r.account_source||'—')+'</td><td>'+escape(r.beneficiary||'—')+'</td><td>'+money(r.amount)+'</td></tr>').join('')||'<tr><td colspan="5">'+(d.loading?'Carregando…':'Nenhum lançamento neste filtro.')+'</td></tr>';
   host.querySelector('footer span').textContent=d.error||((q?rows.length+' exibidos · ':'')+d.rows.length+' de '+(d.count??'…')+' itens'+(d.loading?' · carregando':' · lista completa'));
   host.querySelector('.v178-filter input').disabled=d.loading;
   host.querySelector('.v178-retry').hidden=!d.error;
   host.querySelector('.v178-detail-summary').innerHTML='<span>'+escape(d.archive?'Investimentos históricos documentados':'Total do período')+'<b>'+money(d.total)+'</b></span><span>Itens<b>'+(d.count??'—')+'</b></span>';
  }
  function drawComponents(){
   const d=state.detail,host=document.getElementById('v178Drawer');if(!d||!host||d.subgroup||d.archive)return;
   const box=host.querySelector('.v178-components'),cs=d.components||[];
   if(d.group===apartment){
    const standard=['Aquisição do imóvel','Obra e reforma','Custos de moradia','Impostos do imóvel'];const names=[...standard,...cs.map(c=>c.name).filter(n=>!standard.includes(n))];
    box.innerHTML=names.map(n=>{const c=cs.find(x=>x.name===n);return'<button data-component="'+escape(n)+'"><span>'+escape(n)+'</span><b>'+money(c?.total||0)+'</b></button>'}).join('')+'<button class="v178-archive"><span>Histórico de investimentos</span><small>Obra e consórcio</small></button><button class="v178-all-rows">Ver todos os lançamentos do período</button>';
    host.querySelector('.v178-detail-scroll').hidden=true;host.querySelector('.v178-filter').hidden=true;
    box.querySelector('.v178-all-rows').onclick=()=>{host.querySelector('.v178-detail-scroll').hidden=false;host.querySelector('.v178-filter').hidden=false};
    box.querySelector('.v178-archive').onclick=()=>openArchive(d.range);
   }else if(cs.length>1)box.innerHTML=cs.map(c=>'<button data-component="'+escape(c.name)+'"><span>'+escape(c.name)+'</span><b>'+money(c.total)+'</b></button>').join('');
   box.querySelectorAll('[data-component]').forEach(b=>b.onclick=()=>openDetail(d.group,b.dataset.component,d.range,cs.find(c=>c.name===b.dataset.component)?.total));
  }
  async function openDetail(group,subgroup,range,expected){
   lastFocus=document.activeElement;const token=++sequence;
   const d=state.detail={group,subgroup,range:{...range},expected,rows:[],loading:true,error:null,query:'',count:null,total:null};shellDetail();drawRows();
   try{
    let offset=0,revision=null,keys=new Set();
    do{
     const p=await request('lts_browser_expense_detail_v178',{p_from:range.from,p_to:range.to,p_group:group,p_subgroup:subgroup||null,p_offset:offset,p_limit:500,p_query:null},22000);
     if(token!==sequence)return;
     if(revision&&p.revision!==revision)throw Error('Os dados mudaram durante a leitura. Atualize a lista.');revision=p.revision;
     for(const row of arr(p.rows)){if(keys.has(row.key))throw Error('A lista precisa ser atualizada antes da conferência.');keys.add(row.key);d.rows.push(row)}
     d.total=p.total;d.count=p.row_count;d.components=p.components;
     offset=p.next_offset;drawRows();if(p.offset===0)drawComponents();
    }while(offset!=null);
    if(d.rows.length!==d.count||Math.abs(total(d.rows.map(x=>x.amount))-d.total)>0.02)throw Error('A lista não fechou com o total. Atualize antes de conferir.');
    if(finite(expected)!=null&&Math.abs(d.total-expected)>0.02)throw Error('O total mudou desde a leitura do relatório. Atualize o relatório.');
   }catch(e){if(token===sequence)d.error=String(e.message||e)}
   finally{if(token===sequence){d.loading=false;drawRows()}}
  }
  async function openArchive(range,component=null){
   const token=++sequence,d=state.detail={group:'Histórico de investimentos',subgroup:null,range,archive:true,rows:[],loading:true,query:'',count:null,total:null};shellDetail();drawRows();
   try{const p=await request('lts_browser_property_archive_v178',{});if(token!==sequence)return;d.rows=arr(p.rows).filter(r=>!component||r.component===component);d.total=total(d.rows.map(x=>x.amount));d.count=d.rows.length;
    const cs=new Map();for(const row of d.rows)cs.set(row.component,(cs.get(row.component)||0)+row.amount);
    const box=document.querySelector('#v178Drawer .v178-components');box.innerHTML=[...cs].map(([name,value])=>'<button data-archive-component="'+escape(name)+'"><span>'+escape(name)+'</span><b>'+money(value)+'</b></button>').join('');
    box.querySelectorAll('[data-archive-component]').forEach(b=>b.onclick=()=>openArchive(range,b.dataset.archiveComponent));
   }catch(e){if(token===sequence)d.error=String(e.message||e)}finally{if(token===sequence){d.loading=false;drawRows()}}
  }
  function decorateFlow(){
   if(V!=='Fluxo Diário')return;
   document.querySelectorAll('.v176-rsu-delta').forEach(x=>x.remove());
   document.querySelectorAll('.v178-award-detail').forEach(x=>x.remove());
   const a=state.awards.data,ready=state.awards.status==='ready'&&a?.as_of&&finite(a.vested_shares)!=null;
   document.querySelectorAll('.fx87-row.fx87-cons[id^="d-"]').forEach(row=>{
    const date=row.id.slice(2),cell=row.children[7];if(!cell)return;
    cell.classList.remove('v176-rsu-active');
    if(!ready){cell.textContent='—';cell.title='Posição vested indisponível';return;}
    if(date<a.as_of)return;
    const vested=total(arr(a.events).filter(e=>e.regular_rsu&&e.vesting_date<=date).map(e=>e.value));
    cell.textContent=money(a.vested_shares+vested);cell.title='Ações com vesting ocorrido. Disponibilidade para caixa permanece no cenário de liquidez.';
    cell.classList.toggle('v178-vested-change',arr(a.events).some(e=>e.regular_rsu&&e.vesting_date===date));
    if(!EXP.has(date))return;
    const events=arr(a.events).filter(e=>e.vesting_date===date||e.available_date===date);
    if(!events.length)return;
    const details=row.nextElementSibling;
    if(!details?.classList.contains('fx89-details'))return;
    const section=document.createElement('section');section.className='v178-award-detail';
    section.innerHTML='<b>Ações e RSUs · sem movimento bancário</b>'+events.map(e=>'<div><span>'+escape(e.vesting_date===date?(e.regular_rsu?'Vesting de RSU':'Direito à premiação'):'Disponibilidade prevista na corretora')+'<small>'+escape(e.type)+' · vesting '+dateLabel(e.vesting_date)+' · disponibilidade '+dateLabel(e.available_date)+'</small></span><strong>'+money(e.value)+'</strong></div>').join('');
    details.appendChild(section);
   });
  }
  function cleanTechnical(){
   document.querySelectorAll('.v175-property,.v174-property-note').forEach(x=>x.remove());
   document.querySelectorAll('.v175-rank-title small').forEach(x=>{if(/fonte reconciliada/i.test(x.textContent))x.remove()});
  }
  function after(){
   if(!D||N.classList.contains('hidden'))return;
   if(V==='Dashboard')queueMicrotask(()=>startDashboard(false));
   if(V==='Fluxo Diário'&&state.awards.status==='idle')loadState('awards','lts_browser_awards_v178');
   document.querySelectorAll('[data-v178-scope]').forEach(parent=>{
    const range=parent.dataset.v178Scope==='dashboard'?yearRange():reportRange();
    const data=parent.dataset.v178Scope==='dashboard'?state.dashboardReport.data:v175.expense.data;
    parent.querySelectorAll('.v178-open').forEach(b=>b.onclick=()=>openDetail(b.dataset.group,null,range,arr(data?.management_groups).find(g=>g.name===b.dataset.group)?.total));
   });
   document.querySelectorAll('.v178-refresh,[data-v168-dashboard-refresh]').forEach(b=>b.onclick=()=>{startDashboard(true);render()});
   if(V==='Dashboard')document.querySelectorAll('[data-v168-go="Despesas"]').forEach(b=>{const old=b.onclick;b.onclick=e=>{v168.expense.key='ytd';v175.expense.key='';v175.expense.data=null;return old?.call(b,e)}});
   cleanTechnical();decorateFlow();
  }
  v168.dashboard.token=(v168.dashboard.token||0)+1;v168.dashboard.started=true;v168.dashboard.loading=false;
  v175.expense.token=(v175.expense.token||0)+1;v175.expense.data=null;v175.expense.key='';v175.expense.loading=false;
  v175.monthly.token=(v175.monthly.token||0)+1;v175.monthly.data=null;v175.monthly.key='';v175.monthly.loading=false;
  dashboard=dashboard178;despesas=expenses178;
  render=function(){const out=previousRender();after();return out};
  renderNav=function(){const out=previousNav();return out};
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&V==='Dashboard'&&state.date!==day())startDashboard(true)});
  S.auth.onAuthStateChange?.((event)=>{if(event==='SIGNED_OUT'){cache.clear();inflight.clear();closeDetail();state.date=null;for(const k of ['cash','wealth','forecast','awards','dashboardReport'])state[k]={status:'idle'}}});
  window.__LTS_V178_REVIEW={installed:true,version:'v179-cash-recovery',baseline:'v178',cashComplete,retryableCashFailure,openDetail,closeDetail,refresh:()=>startDashboard(true)};
  publishCashDiagnostic();
  if(D&&!N.classList.contains('hidden'))render();
 }
 function install(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w?.__LTS_V176_FLOW_EXPENSE_AUDIT?.installed)return false;
  if(!d.getElementById('v178-style')){const link=d.createElement('link');link.id='v178-style';link.rel='stylesheet';link.href='lts-v178-integrated-review.css?v=20260920';d.head.appendChild(link)}
  if(!w.__LTS_V178_REVIEW?.installed&&!d.getElementById('v178-runtime')){const script=d.createElement('script');script.id='v178-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script)}
  if(w.__LTS_V178_REVIEW?.installed){document.getElementById('gate')?.remove();return true}return false;
 }catch{return false}}
 function burst(){const gen=++generation;let count=0;function step(){if(gen!==generation)return;if(!install()&&++count<320)setTimeout(step,100)}step()}
 outer?.addEventListener('load',burst);burst();
})();
