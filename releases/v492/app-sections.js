/* lts-v384-startup-2.js */
;
/* LTS V384: lts-v225-open-finance.js */
/* Additive integration: existing screen owners and financial writers are preserved. */
(function () {
  'use strict';
  const frame = document.getElementById('shell');
  function runtime() {
    const v233Formatters=[new Intl.DateTimeFormat('pt-BR', {timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'}),new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}),new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'})];

    if (window.__LTS_V225?.installed) return;
    const state = { installed: true, version: 'v225', status: null, loading: false,
      syncing: false, error: '', message: '', started: false, requestedAt: null, timer: null, pending: {key:'',data:null,loading:false,error:''} };
    window.__LTS_V225 = state;
    // BEGIN PURE FRESHNESS MODEL: connection metadata never certifies an account balance.
    function createFreshnessModel() {
      const dayFormat = new Intl.DateTimeFormat('en-CA', {timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'});
      const dateFormat = new Intl.DateTimeFormat('pt-BR', {timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});
      const shortFormat = new Intl.DateTimeFormat('pt-BR', {timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
      const codes = ['341','237','336'], bankNames = {'341':'Itaú','237':'Bradesco','336':'C6'};
      function timestamp(value, now) {
        if (value == null || value === '') return {kind:'missing',time:null};
        if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$/.test(value)) return {kind:'invalid',time:null};
        const civil = new Date(value.slice(0,10)+'T00:00:00Z'), time = Date.parse(value);
        if (!Number.isFinite(time) || !Number.isFinite(civil.getTime()) || civil.toISOString().slice(0,10) !== value.slice(0,10)) return {kind:'invalid',time:null};
        return time > now ? {kind:'future',time:null} : {kind:'valid',time};
      }
      const identity = row => typeof row?.id === 'string' && row.id && row.provider && row.institution_code ? JSON.stringify([row.provider,String(row.institution_code),row.id]) : null;
      const connections = status => Array.isArray(status?.connections) ? status.connections.filter(row=>row&&typeof row==='object') : [];
      function index(status) {
        const map = new Map();
        for (const row of connections(status)) {const key=identity(row); if(key)map.set(key,map.has(key)?null:row);}
        return map;
      }
      function accept(previous, incoming, now) {
        const old=index(previous), next=index(incoming);
        return {...incoming,connections:connections(incoming).map(row=>{
          const key=identity(row), before=key&&next.get(key)&&old.get(key);
          if(!before)return row;
          const a=timestamp(before.last_success_at,now), b=timestamp(row.last_success_at,now);
          // Receipt/source and last-attempt metadata advance independently.
          const accepted={...row};
          if(a.kind==='valid'&&b.kind==='valid'&&b.time<a.time){accepted.last_success_at=before.last_success_at;accepted.provider_item_updated_at=before.provider_item_updated_at;}
          const oldAttempt=timestamp(before.last_attempt_at,now),nextAttempt=timestamp(row.last_attempt_at,now);
          if(oldAttempt.kind==='valid'&&(nextAttempt.kind!=='valid'||nextAttempt.time<oldAttempt.time)){
            for(const field of ['last_attempt_at','last_error_code','last_error_summary','status'])accepted[field]=before[field];
          }
          return accepted;
        })};
      }
      function observe(status, previous, now) {
        const out = new Map(), unique=index(status);
        for(const row of connections(status)) {
          const key=identity(row);if(!key||!unique.get(key))continue;
          const received=timestamp(row.last_success_at,now), source=timestamp(row.provider_item_updated_at,now), before=previous?.get(key);
          let change='unknown';
          if(received.kind==='valid'&&source.kind==='valid'&&source.time<=received.time&&before?.source!=null&&before?.received!=null){
            if(source.time>before.source)change='advanced';
            else if(source.time<before.source)change='regressed';
            else if(received.time>before.received)change='unchanged';
            else if(received.time===before.received)change=before.change;
          }
          out.set(key,{received:received.time,source:source.time,change});
        }
        return out;
      }
      function format(stamp) {return stamp.kind==='valid'?dateFormat.format(new Date(stamp.time))+' BRT':'indisponível';}
      function describe(row, observations, now, ambiguous=false) {
        const received=timestamp(row?.last_success_at,now), origin=timestamp(row?.provider_item_updated_at,now), attempt=timestamp(row?.last_attempt_at,now);
        const sourceConsistent=received.kind==='valid'&&origin.kind==='valid'&&origin.time<=received.time;
        const failed=!!row?.last_error_code&&attempt.kind==='valid'&&(received.kind!=='valid'||attempt.time>received.time);
        const change=ambiguous?'unknown':observations?.get(identity(row))?.change||'unknown';
        let level='unknown', label='Data da origem da conexão indisponível';
        if(ambiguous)label='Identidade da conexão ambígua';
        else if(origin.kind==='future')label='Data da origem da conexão no futuro';
        else if(origin.kind==='invalid')label='Data da origem da conexão inválida';
        else if(origin.kind==='valid'&&!sourceConsistent)label='Datas de recebimento e origem não confirmadas';
        else if(sourceConsistent){
          if(now-origin.time>=86400000){level='aged';label='Origem da conexão há 24h ou mais';}
          else if(dayFormat.format(new Date(origin.time))!==dayFormat.format(new Date(now))){level='previous-day';label='Origem da conexão de dia anterior';}
          else {level='same-day';label='Origem da conexão de hoje';}
        }
        const warning=change==='unchanged'?'Nova coleta, mesma origem; sem nova posição confirmada.':change==='regressed'?'Origem anterior à já observada; nova posição não confirmada.':change==='advanced'?'A conexão avançou; a data de cada saldo continua não informada.':'';
        return {code:String(row?.institution_code||''),level,label,received:format(received),origin:format(origin),originShort:origin.kind==='valid'?shortFormat.format(new Date(origin.time)):'indisponível',ageHours:sourceConsistent?Math.floor((now-origin.time)/3600000):null,change,warning,failed,balanceTime:null,balanceCurrent:false};
      }
      function rows(status, observations, now, selectedCodes=codes) {
        const unique=index(status);
        return selectedCodes.flatMap(code=>{
          const found=connections(status).filter(row=>String(row.institution_code)===code);
          return (found.length?found:[{institution_code:code}]).map((row,i)=>({...describe(row,observations,now,!!identity(row)&&!unique.get(identity(row))),name:bankNames[code]+(found.length>1?' · conexão '+(i+1):'')}));
        });
      }
      function positionRows(cash, complete, now) {
        const today=dayFormat.format(new Date(now)), data=cash?.data;
        if(!complete||cash?.status!=='ready'||cash.date!==today||data?.as_of!==today||data?.status!=='complete'||!Array.isArray(data.bank_positions))return [];
        const positions=data.bank_positions, sourceIds=new Set(), seen=new Set();
        const number=value=>(typeof value==='number'||(typeof value==='string'&&/^-?\d+(?:\.\d+)?$/.test(value.trim())))&&Number.isFinite(Number(value))?Number(value):null;
        if(positions.length!==3)return [];
        for(const p of positions){
          const code=String(p?.institution_code), bank=bankNames[code], value=number(p?.balance);
          if(!bank||p.institution!==bank||seen.has(code)||typeof p.source_id!=='string'||!p.source_id.trim()||p.source_id!==p.source_id.trim()||sourceIds.has(p.source_id)||value===null||number(data.day?.[bank]?.balance)!==value)return [];
          seen.add(code);sourceIds.add(p.source_id);
        }
        if(number(data.cash)===null||Math.abs(positions.reduce((sum,p)=>sum+number(p.balance),0)-number(data.cash))>=0.005)return [];
        return positions.map(p=>{
          const t=timestamp(p.as_of,now), level=t.kind!=='valid'?'unknown':now-t.time>=86400000?'aged':dayFormat.format(new Date(t.time))!==today?'previous-day':'same-day';
          return {code:String(p.institution_code),sourceId:p.source_id,time:t.time,label:format(t),compact:t.kind==='valid'?shortFormat.format(new Date(t.time)):'indisponível',kind:t.kind,level,ageHours:t.kind==='valid'?Math.floor((now-t.time)/3600000):null};
        });
      }
      function collectionComplete(status, baseline, requestedAt, now) {
        const current=connections(status).filter(r=>codes.includes(String(r.institution_code))), expected=connections(baseline).filter(r=>codes.includes(String(r.institution_code)));
        if(!Number.isFinite(requestedAt)||current.length!==3||expected.length!==3)return false;
        return codes.every(code=>{
          const rows=current.filter(r=>String(r.institution_code)===code), before=expected.filter(r=>String(r.institution_code)===code);
          if(rows.length!==1||before.length!==1||!identity(rows[0])||identity(rows[0])!==identity(before[0]))return false;
          const t=timestamp(rows[0].last_success_at,now);return t.kind==='valid'&&t.time>=requestedAt;
        })&&new Set(current.map(r=>r.id)).size===3;
      }
      function collectionMessage(status, baseline, now) {
        return 'Consulta concluída. Confira em Atualização a data de cada saldo.';
      }
      return {timestamp,identity,accept,observe,describe,rows,positionRows,collectionComplete,collectionMessage};
    }
    // END PURE FRESHNESS MODEL
    const freshness = createFreshnessModel();
    state.observations = new Map(); state.refreshBaseline = null; state.statusRead = null; state.epoch = 0; state.refreshExpected = null;
    const generation=()=>typeof BOOT!=='undefined'?BOOT.generation:(typeof D!=='undefined'?D:null);
    state.sessionGeneration=generation();
    const activeSession=(epoch,gen)=>epoch===state.epoch&&gen===generation()&&signedIn();
    const previousRender = render;
    const names = { '341': 'Itaú', '237': 'Bradesco', '336': 'C6' };
    const esc = text => String(text ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const stamp = value => {
      if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return 'indisponível';
      const civil = new Date(value.slice(0,10)+'T00:00:00Z');
      if (!Number.isFinite(civil.getTime()) || civil.toISOString().slice(0,10) !== value.slice(0,10)) return 'indisponível';
      const date = new Date(value), time = date.getTime();
      return Number.isFinite(time) && time <= Date.now() ? v233Formatters[0].format(date)+' BRT' : 'indisponível';
    };
    const signedIn = () => typeof D !== 'undefined' && !!D && !N.classList.contains('hidden');
    async function rpc(name,args) {
      const result = await S.rpc(name,args||{});
      if (result.error || !result.data) throw Error(result.error?.message || 'Não foi possível atualizar agora.');
      return result.data;
    }
    function connections() { return Array.isArray(state.status?.connections) ? state.status.connections : []; }
    function releaseRefreshReads(hold=state.readHold) { if(state.readHold===hold)state.readHold=null;hold?.release(); }
    function freshnessRows(codes) {
      const cash=window.__LTS_V178_STATE?.cash, complete=!!cash&&window.__LTS_V178_REVIEW?.cashComplete?.(cash)===true;
      const positions=freshness.positionRows(cash,complete,Date.now());
      const rows=freshness.rows(state.status,state.observations,Date.now(),codes);
      return rows.map(row=>{const ambiguous=rows.filter(r=>r.code===row.code).length!==1;return {...row,ambiguousConnections:ambiguous,position:ambiguous?null:positions.find(p=>p.code===row.code)||null};});
    }
    function bankRows() {
      return freshnessRows().map(bank=>'<div class="v225-bank"><b>'+esc(bank.name)+'</b><span>'+esc(bank.failed?'Não foi possível atualizar. Tente novamente.':bank.label)+'</span><span style="grid-column:1/-1">Saldo informado pelo banco em <time>'+esc(bank.position?.label||'data indisponível')+'</time><br>Dados recebidos no Wealth em <time>'+esc(bank.received)+'</time><br>Conexão atualizada em <time>'+esc(bank.origin)+'</time><br><small>O horário da conexão pode ser diferente do horário do saldo.</small></span></div>').join('');
    }
    function freshnessMarkup(codes) {
      const rows=[...new Map(freshnessRows(codes).map(row=>[row.code,row.ambiguousConnections?{...row,name:names[row.code],originShort:'vínculo com a posição não confirmado'}:row])).values()], levels=rows.map(row=>row.position?.level||'unknown');
      if(!rows.length)return '<p role="status">A data do saldo está indisponível. Atualize as contas para conferir.</p>';
      const note=levels.includes('aged')?'Há saldos com mais de 24 horas. Atualize as contas antes de decidir.':levels.includes('previous-day')?'Alguns saldos são do dia anterior. Confira a data em Atualização.':levels.includes('unknown')?'A data de alguns saldos não foi informada. Confira em Atualização.':'';
      const cashNote=V==='Fluxo Diário'?document.getElementById('v274ReceivedPosition')?.textContent:'';
      return (note?'<p class="lts-freshness-alert" role="status">'+esc(note)+'</p>':'')+'<details class="lts-update-details"><summary>Atualização</summary><p>Consulta ao Wealth: '+esc(state.consultedAt?stamp(state.consultedAt):'aguardando consulta')+'. Horários de Brasília.</p>'+rows.map(row=>{
        const position=row.position, level=position?.level||'unknown';
        const suffix=level==='aged'?' · '+position.ageHours+'h':level==='previous-day'?' · dia anterior':'';
        return '<div class="v225-freshness-bank" data-bank="'+esc(row.code)+'" data-freshness="'+esc(level)+'"><b>'+esc(row.name)+'</b><span>Saldo informado em <time>'+esc(position?.label||'data indisponível')+'</time>'+esc(suffix)+'</span><span>Recebido no Wealth: '+esc(row.received)+'</span><span>Conexão com o banco: '+esc(row.origin)+'</span></div>';
      }).join('')+(cashNote?'<p>'+esc(cashNote)+'</p>':'')+'<p>Consultar ou coletar dados não garante que o banco tenha fornecido um saldo novo. Os horários acima permitem conferir essa diferença.</p></details>';
    }
    function paintFreshness() {
      document.querySelectorAll('.v225-balance-freshness').forEach(node=>{if(node.dataset.view!==V)node.remove();});
      let anchor=null,codes;
      if(V==='Dashboard'){
        anchor=[...document.querySelectorAll('.v168-dashboard .v168-kpi')].find(node=>/^Contas correntes(?: hoje| · posição recebida)?$/.test(node.querySelector('span')?.textContent?.trim()||''));
      }else if(V==='Fluxo Diário'){
        anchor=document.getElementById('v274ReceivedPosition')||document.getElementById('ltsBankEvidence')||document.querySelector('.flowbar');
        const account=typeof ACC==='string'?ACC:'Consolidado';
        codes=account==='Consolidado'?undefined:Object.keys(names).filter(code=>names[code]===account);
      }
      if(!anchor)return;
      let box=document.querySelector('.v225-balance-freshness');
      if(!box){box=document.createElement('div');box.className='v225-balance-freshness';box.dataset.view=V;box.setAttribute('aria-label','Atualidade da posição bancária recebida');anchor.insertAdjacentElement('afterend',box);}
      if(V==='Dashboard')anchor.querySelector('span').textContent='Contas correntes';
      const expanded=box.querySelector('details')?.open===true,markup=freshnessMarkup(codes);if(box.innerHTML!==markup){box.innerHTML=markup;const details=box.querySelector('details');if(details)details.open=expanded;}
    }
    function paint() {
      if (!signedIn()) return;
      paintFreshness();
      const host = document.querySelector('.v168-dashboard .v168-headmeta, .v168-updates .v168-headmeta');
      if (host) {
        let control = host.querySelector('.v225-sync');
        if (!control) { control = document.createElement('div'); control.className = 'v225-sync'; host.appendChild(control); }
        control.innerHTML = '<button type="button" class="v168-btn blue" data-v225-refresh '+(state.syncing?'disabled':'')+'>'+(state.syncing?(state.requestedAt?'Consultando bancos…':'Preparando consulta…'):'Atualizar contas')+'</button><span role="status">'+esc(state.error || state.message || 'Atualização automática ativa')+'</span>';
        control.querySelector('button').onclick = () => refresh(true);
      }
      if (V === 'Atualizações') {
        const host = document.querySelector('.v168-openfinance');
        if(host){const expanded=host.querySelector('details')?.open===true,failed=freshnessRows().filter(row=>row.failed).map(row=>row.name);
         host.innerHTML=(failed.length?'<p class="lts-freshness-alert" role="status">Não foi possível atualizar '+esc(failed.join(', '))+'. Tente atualizar as contas novamente.</p>':'')+'<details class="lts-update-details"><summary>Atualização</summary><div class="v225-banklist">'+bankRows()+'</div></details>';host.querySelector('details').open=expanded;}
      } else if (V === 'Dashboard') {
        let line = document.querySelector('.v225-bankstatus');
        if (!line && host) { line = document.createElement('details'); line.className='v225-bankstatus'; host.appendChild(line); }
        if(line)line.remove();
      }
    }
    async function readStatus() {
      if(state.sessionGeneration!==generation())clearSession();
      if (state.statusRead) return state.statusRead;
      const epoch=state.epoch,gen=generation();
      state.loading = true;
      const reading=(async()=>{
        try {
          const revision=s=>(s?.connections||[]).map(c=>[freshness.identity(c),c.last_success_at].join(':')).sort().join('|');
          const incoming=await rpc('lts_browser_open_finance_status_v1');
          if(!activeSession(epoch,gen))return;
          const previous=state.status;
          state.status=freshness.accept(previous,incoming,Date.now());
          state.consultedAt=new Date().toISOString();
          state.observations=freshness.observe(state.status,state.observations,Date.now());
          if(state.error==='Não foi possível conferir a atualização das contas.')state.error='';
          if(previous&&revision(previous)!==revision(state.status)&&!state.syncing)refreshScreens();
        }
        catch (error) { if(activeSession(epoch,gen))state.error = 'Não foi possível conferir a atualização das contas.'; }
        finally { if(epoch===state.epoch){if(gen!==generation())clearSession();else{state.loading=false;state.statusRead=null;paint();}} }
      })();
      state.statusRead=reading;return reading;
    }
    async function refreshScreens() {
      const epoch=state.epoch,gen=generation();
      const cashOnly=V==='Fluxo Diário',transport=window.__LTS_V227_TRANSPORT,revision=transport?.revision;
      const product=window.__LTS_V415_REFRESH;
      if(product?.snapshot?.().active&&typeof product.poll==='function'){
        // Collection completion is not complete-product readiness. Join the
        // existing status/job; its verified onProduct owns heavy invalidation.
        await product.poll();
        if(!activeSession(epoch,gen))return;
        if(product.snapshot().pending||(transport&&transport.revision!==revision)){
          const ui=window.__LTS_V168_STATE;if(ui)ui.updates.openFinance=state.status;
          await window.__LTS_V178_REVIEW?.refreshCashOnly?.(true);
          if(activeSession(epoch,gen))render();
          return;
        }
      }
      if(window.__LTS_V172_STATE)window.__LTS_V172_STATE.flowSequence++;FLOWLOADING=false;
      const reports=window.__LTS_V175_STATE;if(reports){for(const key of ['expense','monthly']){if(reports[key]){reports[key].data=null;reports[key].key='';reports[key].token=(reports[key].token||0)+1}}}
      const review=window.__LTS_V181_STATE?.review;if(review){review.status='idle';review.data=null;review.key=''}
      window.__LTS_V226?.invalidate?.();window.__LTS_V226?.refresh?.();
      // Card refresh already invalidates synchronously. Own the fallback only
      // when that reader is absent; never invalidate the same refresh twice.
      if(transport&&transport.revision===revision)transport.invalidate();
      state.pending.key=''; state.pending.data=null; state.pending.loading=false; document.getElementById('v225-pending-dialog')?.remove();
      // Bank ingestion does not rewrite reconciled expenses or wealth positions.
      // Keep their validated values while refreshing today's balances/forecast.
      const ui=window.__LTS_V168_STATE;
      if(ui)ui.updates.openFinance=state.status;
      if(cashOnly)await window.__LTS_V178_REVIEW.refreshCashOnly();
      else await window.__LTS_V178_REVIEW.refresh({alreadyInvalidated:true});
      if(!activeSession(epoch,gen))return;
      if (V==='Fluxo Diário' && typeof FLOWFROM!=='undefined' && FLOWFROM && FLOWTO) loadFlowRange(FLOWFROM,FLOWTO);
      else render();
    }
    async function poll() {
      if (!signedIn()) { clearTimeout(state.timer); releaseRefreshReads(); state.syncing=false; return; }
      const epoch=state.epoch,gen=generation();
      await readStatus();
      if(!activeSession(epoch,gen))return;
      const rows=connections().filter(c=>names[c.institution_code]);
      const fresh=freshness.collectionComplete(state.status,state.refreshExpected,state.requestedAt,Date.now());
      const failed=rows.some(c=>c.last_error_code && new Date(c.last_attempt_at).getTime()>=state.requestedAt && new Date(c.last_success_at).getTime()<state.requestedAt);
      if (fresh) {
        state.syncing=false; state.error=''; state.message=freshness.collectionMessage(state.status,state.refreshBaseline,Date.now()); paint(); refreshScreens(); releaseRefreshReads(); return;
      }
      if (failed || Date.now()-state.requestedAt>90000) {
        state.syncing=false;
        state.error=failed?'Não foi possível atualizar uma das contas. Confira a última data disponível e tente novamente.':'';
        state.message=failed?'':'A atualização está demorando. Os saldos anteriores continuam identificados pelas datas informadas.';
        paint(); releaseRefreshReads(); return;
      }
      state.timer=setTimeout(poll,5000);
    }
    async function refresh(force) {
      if (!signedIn() || state.syncing) return;
      // The opening path just read the owner's bank status. A recent successful
      // collection also covers reopening the installed app in a fresh tab.
      if (!force && state.status?.connections?.length && state.status.connections.every(connection => {
        const age = Date.now() - Date.parse(connection.last_success_at);
        return !connection.last_error_code && age >= 0 && age < 600000;
      })) return;
      if (!force && Number(sessionStorage.getItem('lts_of_open_refresh_at')||0)>Date.now()-600000) { await readStatus(); return; }
      const epoch=state.epoch,gen=generation();
      let readHold=null;
      state.manualRefresh=!!force; state.requestedAt=null; state.syncing=true; state.error=''; state.message=''; paint();
      try {
        // Finish the initial read before asking all banks to reconcile sources.
        const dashboard=window.__LTS_V178_REVIEW;
        await (dashboard?.readyForBankCollection||dashboard?.ready)?.();
        if(!activeSession(epoch,gen)){if(epoch===state.epoch)state.syncing=false;return;}
        if(state.statusRead)await state.statusRead;
        if(!activeSession(epoch,gen))return;
        readHold=window.__LTS_V227_TRANSPORT?.holdHeavyReads?.()||null;state.readHold=readHold;
        const ready=readHold?await readHold.ready:true;
        if(!activeSession(epoch,gen)){releaseRefreshReads(readHold);return;}
        if(ready!==true)throw Error('Consulta anterior ainda não concluída');
        state.refreshBaseline=state.observations;state.refreshExpected=state.status;
        const result=await rpc('lts_browser_open_finance_refresh_v1');
        if(!activeSession(epoch,gen))return;
        if (result.ok!==true || freshness.timestamp(result.requested_at,Date.now()).kind!=='valid') throw Error('Solicitação não confirmada');
        state.requestedAt=new Date(result.requested_at).getTime();
        sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
        await poll();
      } catch(error) { releaseRefreshReads(readHold);if(!activeSession(epoch,gen))return;state.syncing=false; state.error='Não foi possível atualizar as contas. Tente novamente.'; paint(); }
    }
    const brl=value=>v233Formatters[1].format(Number(value));
    const civil=()=>v233Formatters[2].format(new Date());
    function pendingRange() {
      const today=civil(),ytd={p_from:today.slice(0,4)+'-01-01',p_to:today};
      if(V!=='Despesas')return ytd;
      const s=window.__LTS_V168_STATE?.expense||{};
      if(s.key==='all')return {p_from:'2013-10-10',p_to:today};
      if(s.key==='custom')return {p_from:s.customFrom,p_to:s.customTo};
      if(s.key==='6m'||s.key==='12m'){const d=new Date(today.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));return {p_from:d.toISOString().slice(0,10),p_to:today};}
      return ytd;
    }
    function pendingDetails() {
      const data=state.pending.data;if(!data)return;
      document.getElementById('v225-pending-dialog')?.remove();
      const dialog=document.createElement('dialog');dialog.id='v225-pending-dialog';dialog.className='v225-pending-dialog';
      dialog.innerHTML='<header><h2>Compras aguardando confirmação</h2><button type="button" data-close>Fechar</button></header><p>Consumo provisório: '+esc(brl(data.net_expense))+' · '+data.transaction_count+' transações. '+(data.unclassified_count??0)+' precisam identificar a finalidade. Créditos reduzem o total. A posição é revista automaticamente quando o banco confirma, altera ou reverte o registro.</p><div class="v225-pending-table"><table><thead><tr><th>Data</th><th>Banco / cartão</th><th>Descrição</th><th>Categoria</th><th>Despesa provisória</th></tr></thead><tbody>'+data.rows.map(r=>'<tr><td>'+esc(r.date.split('-').reverse().join('/'))+'</td><td>'+esc(names[r.institution_code])+(r.last4?' · '+esc(r.last4):'')+'</td><td>'+esc(r.description)+'</td><td>'+esc(window.LTSCategoryDisplay.category(r.category||'A classificar'))+'</td><td>'+esc(brl(r.expense))+'</td></tr>').join('')+'</tbody></table></div><p>O pagamento continua representado por uma única fatura. Estes itens não criam outro débito bancário.</p>';
      document.body.appendChild(dialog);dialog.querySelector('[data-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove());dialog.showModal();
    }
    async function loadPending(range,key) {
      const p=state.pending;p.key=key;p.loading=true;p.error='';p.data=null;
      try {const data=await rpc('lts_browser_open_finance_pending_v225',range);if(data.version!=='pending-expense-v225')throw Error('Leitura indisponível');if(state.pending===p&&p.key===key)p.data=data;}
      catch(error){if(state.pending===p&&p.key===key)p.error='Despesas provisórias não disponíveis agora.';}
      finally {if(state.pending===p&&p.key===key){p.loading=false;paintPending();}}
    }
    function paintPending() {
      if(V==='Despesas'){document.querySelectorAll('.v225-provisional').forEach(x=>x.remove());return;}
      if(!signedIn()||!['Dashboard','Atualizações'].includes(V))return;
      const range=pendingRange();if(!range.p_from||!range.p_to)return;
      const key=range.p_from+'|'+range.p_to,p=state.pending;
      if(p.key!==key){queueMicrotask(()=>{if(state.pending.key!==key)loadPending(range,key)});return;}
      const data=p.data;
      let host;
      if(V==='Dashboard')host=[...document.querySelectorAll('.v168-kpi')].find(x=>/Total de despesas do período/.test(x.querySelector('span')?.textContent||''));
      else host=document.querySelector('.v168-openfinance');
      if(!host)return;
      let box=V==='Dashboard'?host.querySelector('.v225-provisional'):document.querySelector('.v225-provisional');
      if(!box){box=document.createElement('div');box.className='v225-provisional';if(V==='Dashboard')host.appendChild(box);else host.insertAdjacentElement('afterend',box);}
      const body=p.loading?'Consultando despesas provisórias…':p.error?esc(p.error):!data||!data.transaction_count?'':
        '<button type="button" data-pending-detail>'+esc(brl(data.net_expense))+' em processamento no banco</button><span>'+data.transaction_count+' lançamentos · '+(data.unclassified_count??0)+' com finalidade a identificar. Créditos já abatidos.</span>';
      const report=V==='Dashboard'?window.__LTS_V178_STATE?.dashboardReport.data:V==='Despesas'&&window.__LTS_V175_STATE?.expense.key===key?window.__LTS_V175_STATE.expense.data:null;
      const reconciled=report?.summary?.selected_total;
      const combined=data?.transaction_count&&reconciled!=null&&Number.isFinite(Number(reconciled))?'<span>Gastos confirmados: '+esc(brl(reconciled))+' · Incluindo valores a conferir: '+esc(brl(Number(reconciled)+Number(data.net_expense)))+'</span>':'';
      const updateBody=p.loading?'Consultando compras dos cartões…':p.error?esc(p.error):!data?.transaction_count?'':
        '<b>Compras aguardando confirmação</b><span>'+data.transaction_count+(Number(data.transaction_count)===1?' compra · ':' compras · ')+esc(brl(data.net_expense))+'. O banco ainda pode atualizar esses valores.</span><span>'+ (data.unclassified_count??0)+(Number(data.unclassified_count??0)===1?' compra precisa de categoria.':' compras precisam de categoria.')+'</span><button type="button" data-pending-detail>Conferir compras</button>';
      box.innerHTML=V==='Atualizações'?updateBody:body+combined;box.hidden=!body;box.querySelector('[data-pending-detail]')?.addEventListener('click',pendingDetails);
    }
    function clearSession() { clearTimeout(state.timer);releaseRefreshReads();state.epoch++;state.status=null;state.observations=new Map();state.refreshBaseline=null;state.statusRead=null;state.loading=false;state.requestedAt=null;state.error='';state.message='';state.syncing=false;state.started=false;state.refreshExpected=null;state.pending={key:'',data:null,loading:false,error:''};state.sessionGeneration=generation(); }
    function after() {
      if(state.sessionGeneration!==generation())clearSession();
      if (!signedIn()) { if(state.status||state.statusRead||state.readHold)clearSession();state.started=false; state.syncing=false; state.pending={key:'',data:null,loading:false,error:''}; clearTimeout(state.timer); return; }
      paint(); paintPending();if(!statusTimer)watch();
      if (!state.started) { state.started=true; queueMicrotask(async()=>{if(!signedIn())return;await readStatus();await refresh(false);}); }
    }
    render=function(){const result=previousRender();after();return result;};
    // Refresh only this read after the complete product is installed. Collection,
    // connection polling and any in-progress financial action stay independent.
    window.addEventListener('lts:product-refresh-ready',()=>{
      if(!signedIn())return;
      state.pending={key:'',data:null,loading:false,error:''};paintPending();
    });
    state.refresh=()=>refresh(true);
    state.readStatus=readStatus;
    let statusTimer;function watch(){clearTimeout(statusTimer);if(!signedIn()||document.hidden)return;statusTimer=setTimeout(async()=>{await readStatus();watch();},60000);}
    document.addEventListener('visibilitychange',()=>{if(!document.hidden){readStatus();watch();}else clearTimeout(statusTimer);});
    if(typeof S!=='undefined')S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT'){clearTimeout(statusTimer);clearTimeout(state.timer);clearSession();state.started=false;state.syncing=false;}else watch();});
    watch();
    after();
  }
  let attempts=0;
  function install() {
    try {
      const w=frame?.contentWindow,d=frame?.contentDocument;
      if (!w?.__LTS_V181_REGRESSION_CLOSURE?.installed) return false;
      if (!d.getElementById('v225-style')) { const link=d.createElement('link');link.id='v225-style';link.rel='stylesheet';link.href='lts-v225-consolidated.css';d.head.appendChild(link); }
      if (!w.__LTS_V225?.installed && !d.getElementById('v225-runtime')) { const script=d.createElement('script');script.id='v225-runtime';script.textContent='('+runtime.toString()+')();';d.head.appendChild(script); }
      return !!w.__LTS_V225?.installed;
    } catch { return false; }
  }
  function start(){if(!install() && ++attempts<400)setTimeout(start,100);}
  frame?.addEventListener('load',()=>{attempts=0;start();});start();
 window.LTSV339Boot?.watch('lts-v225-open-finance.js',install);
})();


;
;
/* LTS V384: lts-flow-invoice-target.js */
/* Resolves the documented card_invoice source_ref contract, never due-date month. */
(function(root){
 'use strict';
 const norm=x=>String(x??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/\s+/g,' ').trim();
 // Same precedence as lts_card_family_v226; bank is additionally checked below.
 function family(name,bank){const n=norm(name),b=norm(bank);if(n.includes('aeternum'))return'aeternum';if(n.includes('c6')||n.includes('bandeirado'))return'c6';if(n.includes('visa')&&b.includes('itau'))return'itau_visa';if(n.includes('visa')&&b.includes('bradesco'))return'bradesco_prime';if(n.includes('mastercard')||n.includes('mc black')||n.includes('personnalite'))return'itau_mastercard';return null;}
 const banks={aeternum:'bradesco',bradesco_prime:'bradesco',itau_mastercard:'itau',itau_visa:'itau',c6:'c6'};
 function resolve(event,data){
  const fail=reason=>({ok:false,reason});
  if(event?.source!=='card_invoice')return fail('unsupported_source');
  const m=String(event.source_ref||'').match(/^([^|]+)\|(\d{4}-(?:0[1-9]|1[0-2]))$/);
  if(!m)return fail('missing_identity');
  const f=family(m[1],event.account),month=m[2]+'-01';
  if(!f||norm(event.account)!==banks[f])return fail('conflicting_bank');
  if(event.family&&event.family!==f||event.card_family&&event.card_family!==f)return fail('conflicting_family');
  if(event.card_name&&norm(event.card_name)!==norm(m[1]))return fail('conflicting_card_name');
  for(const key of ['reference_month','competence_month'])if(event[key]&&event[key]!==month&&event[key]!==m[2])return fail('conflicting_month');
  const cards=(data?.cards||[]).filter(c=>c.family===f);
  if(cards.length!==1)return fail(cards.length?'ambiguous_card':'missing_card');
  if(norm(cards[0].bank)!==banks[f])return fail('conflicting_card_bank');
  const cycles=(cards[0].cycles||[]).filter(c=>(c.month||c.reference_month)===month);
  if(cycles.length!==1)return fail(cycles.length?'ambiguous_cycle':'missing_cycle');
  if(cycles[0].month&&cycles[0].reference_month&&cycles[0].month!==cycles[0].reference_month)return fail('conflicting_cycle_month');
  return {ok:true,family:f,month};
 }
 root.LTSFlowInvoiceTarget={resolve};
})(typeof window==='undefined'?globalThis:window);

;
;
/* LTS V384: lts-v226-card-composition.js */
/* V226: authenticated invoice composition, shared by Dashboard and Expenses. */
(function () {
  'use strict';
  const shell=document.getElementById('shell');
  function runtime(){
function documentaryPaymentNote(cycle, esc, formatDate, mode = 'note', sourcePrefix = '') {
  const e = cycle?.documentary_payment_evidence;
  const sourceLabel = sourcePrefix + (cycle?.payment_status === 'payment_not_reported' ? ' · pagamento não informado' : cycle?.payment_status === 'payment_reported' ? ' · pagamento informado' : cycle?.payment_status === 'paid' ? ' · pagamento confirmado' : '');
  const isLabel = mode === 'label';
  if (!e) return isLabel ? sourceLabel : '';
  if (e.status === 'source_changed') return isLabel ? sourceLabel : '<p class="v226-note">A fonte do pagamento mudou. A associação documental precisa ser conferida novamente.</p>';
  const isoDate = value => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) return false;
    const date = new Date(value + 'T12:00:00Z');
    return Number.isFinite(date.valueOf()) && date.toISOString().slice(0, 10) === value;
  };
  const baseValid = e.status === 'identified_in_statement' && e.cash_effect === 'none' && e.currency === 'BRL' && isoDate(e.payment_date) && typeof e.amount === 'number' && Number.isFinite(e.amount) && e.amount > 0;
  if (!baseValid) return isLabel ? sourceLabel : '';
  if (e.basis === 'reviewed_original_link_and_exact_issuer_refresh') {
    const refreshValid = e.issuer_payment_type === 'FULL_PAYMENT' && e.bank_posting_status === 'POSTED' && isoDate(e.issuer_payment_date) && isoDate(e.bank_posting_date) && e.payment_date === e.bank_posting_date && typeof cycle.amount === 'number' && Number.isFinite(cycle.amount) && cycle.amount > 0 && cycle.amount === e.amount;
    if (!refreshValid) return isLabel ? sourceLabel : '';
    if (isLabel) return (sourcePrefix && cycle.basis === 'open_finance_composition' ? 'Compras recebidas' : sourcePrefix) + ' · pagamento integral informado pelo emissor';
    return '<p class="v226-note">Emissor: pagamento integral informado em ' + esc(formatDate(e.issuer_payment_date)) + '. Banco: débito lançado no extrato em ' + esc(formatDate(e.bank_posting_date)) + '. Associação documental conferida; cada data corresponde à sua fonte.</p>';
  }
  if (isLabel) return sourceLabel;
  return '<p class="v226-note">Pagamento identificado no extrato em ' + esc(formatDate(e.payment_date)) + '. Associação documental conferida; o estado informado pelo emissor é apresentado separadamente.</p>';
}
    const v233Formatters=[new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}),new Intl.DateTimeFormat('pt-BR',{month:'short',year:'numeric'}),new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'})];

    if(window.__LTS_V226)return;
    const st=window.__LTS_V226={installed:true,completeness_contract:269,cycles:null,loading:false,error:'',epoch:0,loadedAt:0,loadedDay:null,options:null,history:{key:'',loading:false,data:null,error:''}};
    const previousRender=render,previousNav=renderNav;
    const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const money=x=>x==null||!Number.isFinite(Number(x))?'—':v233Formatters[0].format(Number(x));
    const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'Vencimento a confirmar';
    const month=x=>/^\d{4}-\d{2}/.test(x||'')?v233Formatters[1].format(new Date(x.slice(0,7)+'-01T12:00:00Z')).replace('.',''):'Sem ciclo informado';
    const today=()=>v233Formatters[2].format(new Date());
    const sum=xs=>xs.reduce((n,x)=>n+Number(x||0),0);
    const cycleTotal=xs=>st.cycles?.complete===false||xs.some(x=>x.complete===false||x.amount==null||!Number.isFinite(Number(x.amount)))?null:sum(xs.map(x=>x.amount));
    const totalLabel=x=>x==null?'Total incompleto':money(x);
    const names={aeternum:'Visa Aeternum',bradesco_prime:'Visa Infinite Prime',itau_mastercard:'Mastercard Black',itau_visa:'Visa Infinite',c6:'C6 Carbon'};
    const openCycles=card=>(Array.isArray(card.cycles)?card.cycles:[]).filter(cycle=>cycle&&cycle.settlement_confirmed!==true&&(cycle.amount==null||!Number.isFinite(Number(cycle.amount))||Number(cycle.amount)>0)).slice().sort((a,b)=>String(a.month||a.reference_month||'').localeCompare(String(b.month||b.reference_month||''))||String(a.due_date||'').localeCompare(String(b.due_date||'')));
    const category=x=>window.LTSCategoryDisplay.category(x||'A classificar');
    const source=x=>({incomplete_cycle_identity:'Total incompleto · ciclo em conferência',received_and_projected_installments:'Compras recebidas + parcelas previstas',open_finance_invoice_v263:'Fatura recebida do banco',user_confirmed_recurring_estimate:'Assinatura prevista · fatura ainda não recebida',open_finance_composition:'Em aberto · compras recebidas',bank_document_composition:'Em aberto · banco e fatura parcial',provider_installments:'Parcelas futuras informadas pelo banco',derived_current_installments:'Parcelas restantes das compras recebidas',documented_floor_partial_detail:'Piso documentado · composição parcial',contracted_installments:'Parcelas já contratadas',documented_snapshot:'Última posição documentada'}[x]||'Última posição documentada');
    const active=()=>typeof D!=='undefined'&&D&&!N.classList.contains('hidden');
    async function rpc(name,args={}){const r=await S.rpc(name,args);if(r.error||!r.data)throw Error('Não foi possível carregar esta composição.');return r.data;}
    function period(){
      const s=window.__LTS_V168_STATE?.expense||{},to=today();
      if(s.key==='all')return {p_from:'2013-10-10',p_to:to};
      if(s.key==='custom')return {p_from:s.customFrom,p_to:s.customTo};
      if(s.key==='6m'||s.key==='12m'){const d=new Date(to.slice(0,7)+'-01T12:00:00Z');d.setUTCMonth(d.getUTCMonth()-(s.key==='6m'?5:11));return{p_from:d.toISOString().slice(0,10),p_to:to};}
      return{p_from:to.slice(0,4)+'-01-01',p_to:to};
    }
    function clear(){st.epoch++;st.loadedAt=0;st.loadedDay=null;st.cycles=null;st.loading=false;st.error='';st.options=null;st.history={key:'',loading:false,data:null,error:''};document.getElementById('v226-detail')?.close();}
    st.invalidate=clear;
    async function loadCycles(force=false){
      if(force)window.__LTS_V227_TRANSPORT?.invalidate?.();
      if(st.loading)return st.pending;
      if(!force&&(st.error||(st.cycles&&st.loadedDay===today()&&Date.now()-st.loadedAt<60000)))return;
      st.pending=(async()=>{
      const epoch=st.epoch;st.loading=true;st.error='';
      try{const data=await rpc('lts_browser_card_cycles_v229');if(data.version!=='card-cycles-v226'||!Array.isArray(data.cards))throw Error('Formato incompleto');if(epoch===st.epoch){st.cycles=data;st.loadedAt=Date.now();st.loadedDay=today();}}
      catch{if(epoch===st.epoch)st.error='As próximas faturas não estão disponíveis agora.';}
      finally{if(epoch===st.epoch){st.loading=false;if(['Dashboard','Atualizações'].includes(V))render();else paint();}}
      })();
      return st.pending;
    }
    async function loadHistory(){
      const p=period(),key=p.p_from+'|'+p.p_to,h=st.history;
      if(h.key===key&&(h.loading||h.data||h.error))return;
      h.key=key;h.loading=true;h.data=null;h.error='';const epoch=st.epoch;
      try{const d=await rpc('lts_browser_card_history_v226',p);if(d.version!=='card-history-v226'||!Array.isArray(d.invoices))throw Error('Histórico incompleto');if(epoch===st.epoch&&h.key===key)h.data=d;}
      catch{if(epoch===st.epoch&&h.key===key)h.error='Não foi possível consultar a composição histórica.';}
      finally{if(epoch===st.epoch&&h.key===key){h.loading=false;paint();}}
    }
    function openButton(card,cycle,label,cls=''){
      return '<button type="button" class="v226-link '+cls+'" data-v226-family="'+esc(card.family)+'" data-v226-month="'+esc(cycle.month||cycle.reference_month)+'" aria-label="'+esc('Abrir '+(names[card.family]||card.card_name)+' · '+month(cycle.month||cycle.reference_month))+'">'+label+'</button>';
    }
    const receivedFormatter=new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});
    const estimatedDue=cycle=>cycle?.due_date_basis==='received_personal_invoice_estimate';
    const dueLabel=cycle=>(estimatedDue(cycle)?'Estimado · ':'')+date(cycle?.due_date);
    function sourceStamp(card,cycle){
      const rows=[],add=(label,value)=>{if(/^\d{4}-\d{2}-\d{2}$/.test(value||'')){rows.push('<small class="v232-source-stamp">'+label+esc(date(value))+'</small>');return;}const parsed=new Date(value);if(value&&Number.isFinite(parsed.getTime()))rows.push('<small class="v232-source-stamp">'+label+esc(receivedFormatter.format(parsed))+'</small>');};
      if(cycle?.invoice_source_updated_at){
        add('Fatura atualizada no banco: ',cycle.invoice_source_updated_at);
        add('Recebida pelo LTS: ',cycle.invoice_received_at);
      }else{
        add('Dados do cartão no provedor: ',card.source_updated_at);
        add('Recebidos pelo LTS: ',card.received_at);
      }
      if(cycle?.basis==='bank_document_composition')add('Fatura parcial complementar: ',card.document_source_as_of);
      else if(['documented_snapshot','documented_floor_partial_detail'].includes(cycle?.basis)&&cycle.documentary_as_of)rows.push('<small class="v232-source-stamp">Posição documentada: '+esc(date(cycle.documentary_as_of))+'</small>');
      if(estimatedDue(cycle))rows.push('<p>Dia nominal '+esc(Number(cycle.nominal_due_date?.slice(-2)))+' nas '+esc(cycle.due_estimate_source_count)+' faturas pessoais recebidas. Data prevista com ajuste para dia útil; a futura fatura pode informar outra data.</p>');
      if(cycle?.due_date_basis==='owner_confirmed_cycle_rule')rows.push('<p>Vencimento definido por você para os novos ciclos. A fatura oficial deste ciclo ainda não foi recebida.</p>');
      if(cycle?.due_date_conflict===true)rows.push('<p class="v226-warning">O vencimento recebido do banco difere da mudança informada. Confira a fatura antes de pagar.</p>');
      return rows.length?'<details class="lts-update-details"><summary>Atualização</summary>'+rows.join('')+'</details>':'';
    }
    function upcomingPanel(full){
      const cards=st.cycles?.cards||[];
      const head='<div class="v168-cardhead"><div><span>Por banco e cartão</span><h2>Próximas faturas</h2></div><button type="button" class="v168-btn" data-v226-retry>Atualizar faturas</button></div>';
      if(!st.cycles)return head+'<p role="status">'+esc(st.error||'Consultando os próximos ciclos…')+'</p>';
      const next=cards.flatMap(c=>openCycles(c).length?[{card:c,cycle:openCycles(c)[0]}]:[]).sort((a,b)=>String(a.cycle.due_date||a.cycle.month||a.cycle.reference_month||'').localeCompare(String(b.cycle.due_date||b.cycle.month||b.cycle.reference_month||''))||String(a.card.family).localeCompare(String(b.card.family))),nextTotal=cycleTotal(next.map(x=>x.cycle));
      const future=cards.flatMap(c=>openCycles(c).slice(1)),futureTotal=cycleTotal(future);
      const bankNames=[...new Set(cards.map(c=>c.bank))];
      return head+(st.cycles.complete===false?'<p class="v226-warning" role="status">'+esc(cards.some(c=>c.due_estimate_source_changed===true)?'O vencimento estimado do C6 precisa ser revisto. Confira a nova fatura; o total conjunto está incompleto.':'O C6 tem compras cujo ciclo ou parcela precisa ser conciliado. O total conjunto está incompleto; os demais cartões continuam disponíveis.')+'</p>':'')+(st.loading?'<p role="status">Atualizando faturas…</p>':st.error?'<p role="alert">'+esc(st.error)+' A leitura anterior está indicada abaixo.</p>':'')+'<div class="v226-totals"><div><span>Próximas faturas e valores previstos</span><strong><button class="v226-link" data-v226-overview="next">'+totalLabel(nextTotal)+'</button></strong></div><div><span>Ciclos seguintes conhecidos</span><strong><button class="v226-link" data-v226-overview="future">'+totalLabel(futureTotal)+'</button></strong><small>Valores documentados e parcelas; sem novas compras estimadas</small></div></div>'+
        '<div class="v226-banks">'+bankNames.map(bank=>'<section><h3>'+esc(bank)+'</h3>'+cards.filter(c=>c.bank===bank).map(c=>{
          const cycle=openCycles(c)[0],label=esc(names[c.family]||c.name);
          return '<div class="v226-card-line"><div>'+(cycle?openButton(c,cycle,label):'<b>'+label+'</b>')+'<small>Conta final '+esc(c.last4)+(c.family==='c6'?' · inclui 8304':'')+'</small></div><div>'+(cycle?openButton(c,cycle,totalLabel(cycle.amount),'v226-amount'):'<span>Fatura ainda não disponível</span>')+(cycle?'<small>'+esc(month(cycle.month))+' · '+esc(dueLabel(cycle))+'</small><small>'+esc(documentaryPaymentNote(cycle,null,null,'label',source(cycle.basis)))+'</small>'+sourceStamp(c,cycle)+documentaryPaymentNote(cycle,esc,date):'')+'</div></div>'+unresolvedPanel(c);
        }).join('')+'</section>').join('')+'</div>'+
        '<p class="v226-note">'+st.cycles.active_billing_accounts+' contas de cartão ativas. Cartões adicionais compartilham a fatura; clique no nome ou no valor para abrir as compras.</p>'+
        '<details class="v226-future"><summary>Faturas e parcelas dos próximos meses · '+totalLabel(futureTotal)+'</summary><div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Valor</th><th>Origem</th></tr></thead><tbody>'+cards.flatMap(c=>openCycles(c).slice(1).map(x=>'<tr><td>'+esc(c.bank+' · '+(names[c.family]||c.name))+'</td><td>'+openButton(c,x,esc(month(x.month)))+(estimatedDue(x)?'<small>'+esc(dueLabel(x))+'</small>':'')+'</td><td>'+openButton(c,x,money(x.amount))+'</td><td>'+esc(source(x.basis))+'</td></tr>')).join('')+'</tbody></table></div></details>';
    }
    function unresolvedPanel(card){
      if(card.due_estimate_source_changed===true)return '';
      const rows=card.unresolved_items||[],ambiguous=card.ambiguous_document_candidates||[];
      if(card.complete!==false)return '';
      const item=r=>'<tr><td>'+esc(date(r?.purchase_date||r?.posting_date))+'</td><td>'+esc(r?.last4)+'</td><td>'+esc(r?.description)+'</td><td>'+money(r?.amount)+'</td></tr>';
      return '<details class="v226-alternative"><summary>Evidências em conferência · '+rows.length+' compras sem ciclo · '+ambiguous.length+' correspondências ambíguas</summary><p>Valores de fontes que ainda não podem ser somados como despesas. Nenhum vencimento incerto foi atribuído.</p><div class="v226-scroll"><table><thead><tr><th>Data</th><th>Cartão</th><th>Descrição</th><th>Valor da fonte</th></tr></thead><tbody>'+rows.map(item).join('')+ambiguous.map(a=>'<tr><th colspan="4">Documento '+esc(a.document_id)+' / banco '+esc(a.provider_id)+'</th></tr>'+item(a.document_item)+item(a.provider_item)).join('')+'</tbody></table></div></details>';
    }
    function historyPanel(){
      const h=st.history,head='<div class="v168-cardhead"><div><span>Composição das fontes disponíveis</span><h2>Faturas históricas</h2></div></div>';
      if(!h.data)return head+'<p role="status">'+esc(h.error||'Conferindo faturas do período…')+'</p>';
      const rows=h.data.invoices||[];
      return head+(rows.length?'<div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo / vencimento</th><th>Fatura</th><th>Compras e créditos</th><th>Composição</th></tr></thead><tbody>'+rows.map(r=>'<tr><td>'+openButton(r,r,esc(r.bank+' · '+(names[r.family]||r.card_name)))+'</td><td>'+esc(r.due_date?date(r.due_date):month(r.reference_month))+'</td><td>'+openButton(r,r,money(r.amount))+'</td><td>'+r.item_count+' lançamentos · '+money(r.detail_total)+'</td><td>'+(r.detail_complete?(r.source==='workbook_reconciled'?'Total conferido · planilha':'Total conferido'):'Diferença de '+money(r.difference)+' · fonte parcial')+'</td></tr>').join('')+'</tbody></table></div>':'<p>Nenhuma fatura do Open Finance neste período. O histórico anterior permanece abaixo.</p>');
    }
    function grouped(items,key){const map=new Map();for(const r of items){const k=(key==='category'?category(r[key]):r[key])||'Não informado',v=map.get(k)||{name:k,amount:0,n:0};v.amount+=Number(r.amount);v.n++;map.set(k,v);}return [...map.values()].sort((a,b)=>b.amount-a.amount);}
    function categoryCell(r){
      if(r.category_basis!=='unresolved'||!r.source_id)return esc(category(r.category));
      if(!st.options?.length)return 'A classificar · categorias indisponíveis agora. Atualize as faturas para tentar novamente.';
      return '<details class="v226-classify"><summary>Identificar despesa</summary><form data-v226-classify="'+esc(r.source_id)+'"><label>Categoria<select name="category" required><option value="">Selecione…</option>'+(st.options||[]).map(x=>'<option value="'+esc(x)+'">'+esc(category(x))+'</option>').join('')+'</select></label><label>Para quem?<select name="beneficiary"><option value="">Sem identificação adicional</option>'+['Lucas','Larissa','Benjamin','Rafiki'].map(x=>'<option>'+x+'</option>').join('')+'</select></label><button type="submit" class="v168-btn">Salvar categoria</button><span role="status"></span></form></details>';
    }
    function alternativeSource(data){
      const rows=data.alternative_items||[];if(!rows.length)return '';
      return '<details class="v226-alternative"><summary>Detalhes adicionais do banco · '+rows.length+' lançamentos</summary><p class="v226-note">'+esc(data.alternative_note||'Outra fonte da mesma fatura; não somar novamente.')+'</p><div class="v226-scroll"><table><thead><tr><th>Data</th><th>Cartão</th><th>Descrição</th><th>Categoria</th><th>Parcela</th><th>Valor</th></tr></thead><tbody>'+rows.map(r=>'<tr data-v226-alternative-item><td>'+esc(date(r.purchase_date||r.posting_date))+'</td><td>'+esc(r.last4||'—')+'</td><td>'+esc(r.description)+'</td><td>'+esc(category(r.category))+'</td><td>'+(r.installment_number&&r.total_installments?r.installment_number+'/'+r.total_installments:'—')+'</td><td>'+money(r.amount)+'</td></tr>').join('')+'</tbody></table></div></details>';
    }
    function descriptionCell(row){
      const documented=Number(row.source_document?.amount),received=Number(row.amount);
      const mismatch=row.source_document?.amount!=null&&Number.isFinite(documented)&&Number.isFinite(received)&&Math.abs(documented-received)>=0.005;
      return esc(row.description)+(row.provider_status==='PROJECTED'?'<small class="v226-projected-origin">Parcela prevista · ainda não recebida neste ciclo</small>':'')+(row.source_document?.page?'<small class="v233-document-origin">Fatura parcial · pág. '+esc(row.source_document.page)+'</small>':'')+(mismatch?'<small class="v226-warning">Documento: '+money(documented)+' · banco: '+money(received)+'. Diferença preservada para conferência.</small>':'');
    }
    function formulaSource(data){
      const f=data.formula_resolution;if(!f)return '';
      return '<details class="v226-alternative" data-v237-formula><summary>Conferência da fórmula da planilha</summary><p class="v226-note">'+esc(f.source_note)+'</p><p>As '+Number(f.raw_item_count)+' linhas originais somam '+money(f.raw_detail_total)+'. O total aplicado é '+money(data.detail_total)+'.</p>'+(f.excluded_items||[]).map(r=>'<p data-v237-excluded>'+esc(r.source_sheet)+' · linha '+Number(r.source_row)+' · '+esc(r.category)+' · '+money(r.amount)+' · fora do total da fórmula original</p>').join('')+(f.formula_evidence||[]).map(r=>'<p>'+esc(r.file)+' · '+esc(r.total_cell)+'<br><code>'+esc(r.total_formula)+'</code><br><code>'+esc(r.category_formula)+'</code></p>').join('')+'</details>';
    }
    function compositionEvidence(data,cycle,total){
      const basis=data.basis||cycle?.basis;
      const amount=value=>typeof value==='number'&&Number.isFinite(value)?value:typeof value==='string'&&/^-?\d+(?:\.\d+)?$/.test(value.trim())&&Number.isFinite(Number(value))?Number(value):null;
      const expected=amount(data.invoice_amount??cycle?.amount);
      // A partial composition cannot certify itself by summing its own rows.
      const independentTotal=amount(data.invoice_amount)!=null||(Boolean(cycle?.invoice_source_id)&&amount(cycle?.amount)!=null);
      const mismatch=data.complete===false||cycle?.complete===false||data.document_items_matched===false||cycle?.document_items_matched===false||data.invoice_composition_complete===false||cycle?.invoice_composition_complete===false||data.detail_complete===false||cycle?.detail_complete===false;
      const documentMatched=data.document_items_matched===true||cycle?.document_items_matched===true;
      const providerTotalMatched=data.invoice_composition_complete===true||cycle?.invoice_composition_complete===true;
      const complete=independentTotal&&(documentMatched||providerTotalMatched)&&!mismatch&&expected!=null&&Number.isFinite(total)&&Math.abs(Number(expected)-total)<0.005;
      const projected=['received_and_projected_installments','derived_current_installments','provider_installments','documented_floor_partial_detail','contracted_installments','documented_snapshot','user_confirmed_recurring_estimate'].includes(basis);
      return {expected,complete,independentTotal,
        label:independentTotal?'Valor recebido da fatura':projected?'Valor previsto do ciclo':'Compras recebidas do ciclo',
        coverage:complete?(documentMatched?'itens conferidos com o documento':'total confere com os itens recebidos'):independentTotal?'composição parcial':'composição parcial · total da fatura não recebido'};
    }
    function detailBody(data,cycle){
      const rows=data.items||[],total=sum(rows.map(r=>r.amount)),uncertain=data.complete===false||cycle?.complete===false,detailTotal=uncertain?'Total não consolidado':money(total);
      const {expected,complete,independentTotal,label,coverage}=compositionEvidence(data,cycle,total);
      const documented=rows.filter(r=>r.provider_status==='DOCUMENTED').length;
      return (estimatedDue(cycle)?'<p class="v226-note v391-due-estimate"><b>Vencimento estimado: '+esc(date(cycle.due_date))+'</b>. Confira a futura fatura antes de pagar.</p>':cycle?.due_estimate_source_changed===true?'<p class="v226-warning">O vencimento precisa ser revisto. Confira a nova fatura do C6.</p>':'')+(data.complete===false||cycle?.complete===false?'<p class="v226-warning">Total incompleto. Os itens abaixo são conhecidos, mas ainda existem compras ou parcelas com identidade em conferência.</p>':'')+(data.source_note?'<p class="v226-note">'+esc(data.source_note)+'</p>':'')+(documented&&(data.basis||cycle?.basis)==='bank_document_composition'?'<p class="v226-note" data-v233-document-note>'+documented+(documented===1?' parcela comprovada':' parcelas comprovadas')+' na fatura parcial do banco.</p>':'')+'<div class="v226-totals"><div><span>'+esc(label)+'</span><strong>'+money(expected)+'</strong></div><div><span>Compras e créditos detalhados</span><strong>'+detailTotal+'</strong><small>'+rows.length+' lançamentos · '+coverage+'</small></div></div>'+
        (!uncertain&&independentTotal&&expected!=null&&Math.abs(Number(expected)-total)>=0.005?'<p class="v226-warning">A fonte traz '+money(Number(expected)-total)+' sem composição conciliada. Este valor não foi distribuído entre compras.</p>':'')+
        (uncertain?'':'<div class="v226-breakdown"><section><h3>Por cartão</h3>'+grouped(rows,'last4').map(x=>'<div><span>Final '+esc(x.name)+' · '+x.n+' lançamentos</span><b>'+money(x.amount)+'</b></div>').join('')+'</section><section><h3>Por tipo de despesa</h3>'+grouped(rows,'category').map(x=>'<div><span>'+esc(category(x.name))+'</span><b>'+money(x.amount)+'</b></div>').join('')+'</section></div>')+
        '<label class="v226-search">Buscar nesta fatura <input type="search" data-v226-search placeholder="Compra, cartão ou categoria"></label>'+
        '<div class="v226-scroll"><table><thead><tr><th>Data</th><th>Cartão</th><th>Descrição</th><th>Categoria</th><th>Parcela</th><th>Valor</th></tr></thead><tbody>'+rows.map(r=>'<tr data-v226-item><td>'+esc(r.date_kind==='reference_month'?month(r.reference_month):date(r.purchase_date||r.posting_date))+'</td><td>'+esc(r.last4||'—')+'</td><td>'+descriptionCell(r)+'</td><td>'+categoryCell(r)+'</td><td>'+(r.installment_number&&r.total_installments?r.installment_number+'/'+r.total_installments:'—')+'</td><td>'+money(r.amount)+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="5">Total da composição</th><td>'+detailTotal+'</td></tr></tfoot></table></div>'+
        documentaryPaymentNote(cycle||data,esc,date)+formulaSource(data)+alternativeSource(data)+(data.basis==='user_confirmed_recurring_estimate'?'<p class="v226-note">Assinatura recorrente informada por você. A fatura e seu vencimento ainda precisam ser recebidos; este valor permanece uma previsão.</p>':'')+'<p class="v226-note">Pagamentos da fatura anterior estão separados das compras. Créditos e estornos reduzem o total. Compras em processamento podem ser atualizadas pelo banco.</p>';
    }
    async function openDetail(family,cycleMonth){
      const bootGeneration=typeof BOOT==='undefined'?null:BOOT.generation;
      if(!active())return;
      if(st.cycles&&(st.loadedDay!==today()||Date.now()-st.loadedAt>=60000))await loadCycles();
      if(!active()||(typeof BOOT==='undefined'?null:BOOT.generation)!==bootGeneration)return;
      document.getElementById('v226-detail')?.close();
      const dialog=document.createElement('dialog');dialog.id='v226-detail';dialog.className='v226-dialog';
      const card=st.cycles?.cards.find(c=>c.family===family),cycle=card?.cycles?.find(x=>x.month===cycleMonth);
      dialog.innerHTML='<header><div><small>'+esc(month(cycleMonth))+'</small><h2>'+esc(names[family]||'Fatura')+'</h2></div><button type="button" class="v168-btn" data-v226-close>Fechar</button></header><div data-v226-body><p role="status">Carregando todas as compras…</p></div>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove());dialog.showModal();
      const epoch=st.epoch;
      try{
        const d=cycle?.items?.length?{...cycle,items:cycle.items,basis:cycle.basis}:await rpc('lts_browser_card_detail_v226',{p_family:family,p_month:cycleMonth});
        if(!dialog.isConnected||epoch!==st.epoch)return;
        if(d.items?.some(r=>r.category_basis==='unresolved')){try{const options=window.LTSCategoryRegistry?await window.LTSCategoryRegistry.get(true):await rpc('lts_browser_card_category_options_v226');if(epoch===st.epoch)st.options=options.categories||[];}catch{st.options=[];}}
        if(!dialog.isConnected||epoch!==st.epoch)return;
        const draw=()=>{
          dialog.querySelector('[data-v226-body]').innerHTML=detailBody(d,cycle);
          dialog.querySelectorAll('[data-v226-classify] [name=category]').forEach(select=>window.LTSCategoryRegistry?.attach(select));
          dialog.querySelector('[data-v226-search]').oninput=e=>{const key=e.target.value.toLocaleLowerCase('pt-BR');dialog.querySelectorAll('[data-v226-item],[data-v226-alternative-item]').forEach(r=>r.hidden=!r.textContent.toLocaleLowerCase('pt-BR').includes(key));};
          dialog.querySelectorAll('[data-v226-classify]').forEach(form=>form.onsubmit=async event=>{
            event.preventDefault();const button=form.querySelector('button[type=submit]')||form.querySelector('button:not([data-category-create])'),status=form.querySelector(':scope > [role="status"]'),cat=form.elements.category.value,person=form.elements.beneficiary.value;
            if(!cat||button.disabled)return;button.disabled=true;status.textContent='Salvando…';
            try{
              const saved=await rpc('lts_browser_card_classify_v226',{p_source_id:form.dataset.v226Classify,p_category:cat,p_beneficiary:person||null});
              if(saved.ok!==true)throw Error('Não confirmado');
              if(epoch!==st.epoch||!dialog.isConnected)return;
              for(const row of d.items||[])if(row.source_id===form.dataset.v226Classify){row.category=person&&person!=='Lucas'?person+' — '+cat:cat;row.category_basis='user_decision';}
              st.cycles=null;st.history={key:'',loading:false,data:null,error:''};
              const reports=window.__LTS_V175_STATE;
              for(const key of ['expense','monthly','cards']){const s=reports?.[key];if(s){s.token=(s.token||0)+1;s.key='';s.data=null;s.loading=false;s.error=null;}}
              if(window.__LTS_V225?.pending){window.__LTS_V225.pending.key='';window.__LTS_V225.pending.data=null;}
              draw();loadCycles(true);window.__LTS_V178_REVIEW?.refresh?.();
            }catch{if(dialog.isConnected){button.disabled=false;status.textContent='Não foi possível salvar. Tente novamente.';}}
          });
        };draw();
      }
      catch{if(dialog.isConnected)dialog.querySelector('[data-v226-body]').innerHTML='<p role="alert">Não foi possível abrir a composição. Feche e tente novamente.</p>';}
    }
    function openOverview(kind){
      document.getElementById('v226-detail')?.close();
      const rows=(st.cycles?.cards||[]).flatMap(c=>(kind==='next'?openCycles(c).slice(0,1):openCycles(c).slice(1)).map(cycle=>({card:c,cycle})));
      const dialog=document.createElement('dialog');dialog.id='v226-detail';dialog.className='v226-dialog';
      dialog.innerHTML='<header><h2>'+ (kind==='next'?'Próximas faturas conhecidas':'Ciclos seguintes conhecidos')+'</h2><button class="v168-btn" data-v226-close>Fechar</button></header><div class="v226-scroll"><table><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Vencimento</th><th>Valor</th></tr></thead><tbody>'+rows.map(({card:c,cycle:x})=>'<tr data-v226-overview-row><td>'+openButton(c,x,esc(c.bank+' · '+(names[c.family]||c.name)))+'</td><td>'+esc(month(x.month))+'</td><td>'+esc(dueLabel(x))+'</td><td>'+openButton(c,x,money(x.amount))+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="3">Total</th><td>'+totalLabel(cycleTotal(rows.map(x=>x.cycle)))+'</td></tr></tfoot></table></div><p class="v226-note">Clique no cartão ou no valor para ver as compras e parcelas. Inclui valores recebidos, parcelas documentadas e estimativas identificadas.</p>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove());bind(dialog);dialog.showModal();
    }
    function paint(){
      if(!active())return;
      document.querySelectorAll('[data-mobile-route="Patrimônio"] span').forEach(e=>e.textContent='Patrimônio');
      document.querySelectorAll('.v182-expand-mark').forEach(e=>e.remove());
      if(!['Dashboard','Despesas','Patrimônio'].includes(V))return;
      const full=V==='Despesas'&&window.__LTS_V168_STATE?.expense?.tab==='cards';
      if(V==='Despesas'&&!full)return;
      if(V==='Patrimônio'&&window.__LTS_V168_STATE?.wealth?.tab!=='assets')return;
      let host=document.querySelector('.v226-upcoming');
      if(!host){host=document.createElement('article');host.className='v168-card v226-upcoming';const root=document.querySelector(V==='Dashboard'?'.v168-dashboard':V==='Patrimônio'?'.v168-wealth':'.v168-expenses');if(!root)return;if(V==='Despesas'){const tabs=root.querySelector('.v168-tabs');if(tabs)tabs.after(host);else root.appendChild(host);}else root.appendChild(host);}
      host.innerHTML=upcomingPanel(full);bind(host);
      if(!st.loading&&!st.error&&(!st.cycles||st.loadedDay!==today()||Date.now()-st.loadedAt>=60000))queueMicrotask(()=>loadCycles());
      if(full){let h=document.querySelector('.v226-history');if(!h){h=document.createElement('article');h.className='v168-card v226-history';host.after(h);}h.innerHTML=historyPanel();bind(h);queueMicrotask(loadHistory);}
    }
    function bind(root){root.querySelectorAll('[data-v226-overview]').forEach(b=>b.onclick=()=>openOverview(b.dataset.v226Overview));root.querySelector('[data-v226-retry]')?.addEventListener('click',()=>{clear();loadCycles(true);if(V==='Despesas')loadHistory();paint();});}
    document.addEventListener('click',event=>{const button=event.target.closest?.('[data-v226-family]');if(!button)return;event.preventDefault();openDetail(button.dataset.v226Family,button.dataset.v226Month);});
    // Modern Flow invoices share the exact canonical composition with Dashboard.
    const previousSettlement=openCardSettlement;
    let settlementRequest=0;
    openCardSettlement=async function(event){
      const request=++settlementRequest,epoch=st.epoch;
      if(event?.source!=='card_invoice')return previousSettlement(event);
      const bootGeneration=typeof BOOT==='undefined'?null:BOOT.generation;
      const button=document.activeElement;
      try{await loadCycles(Boolean(st.error));}catch{}
      if(request!==settlementRequest||epoch!==st.epoch||!active()||V!=='Fluxo Diário'||(typeof BOOT==='undefined'?null:BOOT.generation)!==bootGeneration)return;
      const target=window.LTSFlowInvoiceTarget.resolve(event,st.error?null:st.cycles);
      if(target.ok){await openDetail(target.family,target.month);return;}
      document.getElementById('v226-detail')?.close();
      const dialog=document.createElement('dialog');dialog.id='v226-detail';dialog.className='v226-dialog';
      dialog.innerHTML='<header><h2>Composição da fatura</h2><button type="button" class="v168-btn" data-v226-close>Fechar</button></header><div class="v226-scroll"><p role="alert">Não foi possível vincular este movimento a uma única fatura com segurança. A composição precisa ser conferida; nenhuma compra foi presumida.</p></div>';
      document.body.appendChild(dialog);dialog.querySelector('[data-v226-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{dialog.remove();if(button?.isConnected)button.focus({preventScroll:true});});dialog.showModal();
    };
    st.openDetail=openDetail;
    st.refresh=()=>loadCycles(true);
    st.read=()=>loadCycles();
    document.addEventListener('visibilitychange',()=>{if(!document.hidden)paint();});
    window.addEventListener('focus',()=>{if(active()&&!st.loading&&(st.loadedDay!==today()||Date.now()-st.loadedAt>=60000))loadCycles();});
    render=function(){const result=previousRender();paint();return result;};
    renderNav=function(){const result=previousNav();document.querySelectorAll('[data-mobile-route="Patrimônio"] span').forEach(e=>e.textContent='Patrimônio');return result;};
    S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT')clear();});
    paint();
  }
  let tries=0;
  function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V225?.installed)return false;if(!d.getElementById('v226-style')){const s=d.createElement('link');s.id='v226-style';s.rel='stylesheet';s.href='lts-v226-card-composition.css';d.head.appendChild(s);}if(!w.LTSFlowInvoiceTarget){if(!window.LTSFlowInvoiceTarget)return false;w.LTSFlowInvoiceTarget=window.LTSFlowInvoiceTarget;}if(!w.__LTS_V226){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return Boolean(w.__LTS_V226);}catch{return false;}}
  function start(){if(!install()&&++tries<320)setTimeout(start,125);}shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-v226-card-composition.js',install);
})();



;
;
/* LTS V384: lts-v227-layout.js */
/* V227 restores screen ownership and the approved content; only requested order changes. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V227_LAYOUT)return;
  const previousRender=render;
  function dashboardLayout(){
   const root=document.querySelector('.v168-dashboard');if(!root)return;
   const current=root.querySelector('.v168-kpi-section.current');if(!current)return;
   let expense=root.querySelector('.v227-expenses');
   if(!expense){
    const cards=Array.from(root.querySelectorAll('.v168-card'));
    const liquidity=cards.find(e=>/Evolução projetada/.test(e.querySelector('h2')?.textContent||''));
    const decisions=cards.find(e=>/O que exige decisão/.test(e.querySelector('h2')?.textContent||''));
    const groups=cards.find(e=>/Principais grupos/.test(e.querySelector('h2')?.textContent||''));
    const future=cards.find(e=>/O que vem pela frente/.test(e.querySelector('h2')?.textContent||''));
    const grid=document.createElement('div');grid.className='v168-grid two v227-liquidity';
    if(liquidity)grid.appendChild(liquidity);if(decisions)grid.appendChild(decisions);current.after(grid);
    expense=document.createElement('section');expense.className='v227-expenses';expense.setAttribute('aria-label','Despesas');
    expense.innerHTML='<div class="v168-sectionhead"><h2>Despesas</h2><span>Gastos no ano, principais grupos e próximas faturas</span></div>';
    const total=Array.from(root.querySelectorAll('.v168-kpi')).find(e=>/Total de despesas do período/.test(e.querySelector('span')?.textContent||''));
    if(total)expense.appendChild(total);
    if(groups)expense.appendChild(groups);
    const restricted=root.querySelector('.v168-kpi-section.restricted')||Array.from(root.querySelectorAll('.v168-kpi-section')).find(e=>/Recursos restritos e consumo/.test(e.textContent));
    if(restricted){const heading=restricted.querySelector('h2,h3,b');if(heading&&/Recursos restritos/.test(heading.textContent))heading.textContent='Recursos restritos';const subtitle=restricted.querySelector('.v168-sectiontitle span');if(subtitle)subtitle.textContent='Posição previdenciária';}
    if(future)root.appendChild(future);
    root.appendChild(expense);
    root.querySelectorAll('.v168-grid').forEach(e=>{if(!e.children.length)e.remove();});
   }
   const upcoming=root.querySelector('.v226-upcoming');if(upcoming&&upcoming.parentElement!==expense)expense.appendChild(upcoming);
  }
  function wealthLayout(){
   if(V!=='Patrimônio')return;
   const root=document.querySelector('.v168-wealth'),s=window.__LTS_V168_STATE?.wealth;if(!root||!s||s.data)return;
   const tabs=root.querySelector('.v168-tabs');if(!tabs)return;
   let n=tabs.nextSibling;while(n){const next=n.nextSibling;n.remove();n=next;}
   const box=document.createElement('div');box.className='v168-card';box.setAttribute('role','status');
   box.textContent=s.error?'Não foi possível carregar o patrimônio agora.':'Carregando patrimônio…';
   if(s.error){const retry=document.createElement('button');retry.className='v168-btn';retry.textContent='Tentar novamente';retry.onclick=()=>{s.error=null;s.loading=false;render();};box.appendChild(retry);}
   root.appendChild(box);
  }
  function after(){dashboardLayout();wealthLayout();}
  render=function(){const result=previousRender.apply(this,arguments);after();return result;};
  window.__LTS_V227_LAYOUT={installed:true};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V226)return false;if(!d.getElementById('v227-layout-css')){const style=d.createElement('style');style.id='v227-layout-css';style.textContent='.v227-expenses{display:grid;gap:16px;margin-top:24px;padding:20px;border-radius:18px;background:#f8f1f3;border:1px solid #eadce1}.v227-expenses>.v168-kpi{max-width:none}.v227-expenses .v168-sectionhead{display:flex;gap:12px;align-items:baseline;flex-wrap:wrap}.v227-expenses h2{margin:0}.v227-expenses .v168-sectionhead>span{color:#6c5862;font-size:13px}.v227-liquidity{margin:18px 0}@media(max-width:820px){.v227-expenses{padding:12px;gap:12px}}';d.head.appendChild(style);}if(!w.__LTS_V227_LAYOUT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V227_LAYOUT;}catch{return false}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-v227-layout.js',install);
})();

;
;
/* LTS V384: lts-v228-bank-flow.js */
/* Display the opening returned by the observed ledger, including a sliced range. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V228_FLOW)return;
  const previous=flowVals,previousTitle=flowSemanticTitle,previousMeta=flowSemanticMeta,previousRender=render;
  flowVals=function(x,prev){
   const value=previous(x,prev);
   // Historical source positions own both their opening and gross cash columns.
   // Earlier presentation layers may have retained only a subset of the events.
   if(x?.historical){
    const p=x[ACC],consolidated=ACC==='Consolidado',c=x.fix86_columns||{};
    const documented=(p?.workbook_cash_reconciled===true||p?.documentary_reconstruction===true)
     &&(consolidated?x.v170_cash_arithmetic?.balanced===true:!!(p.workbook_evidence_ref||p.documentary_anchor_ref));
    if(documented){
     value.prev=consolidated?(c.saldo_anterior_operacional??c.saldo_anterior??null):(p.opening_balance??null);
     value.en=consolidated?(c.entradas??null):(p.cash_entries??null);
     value.ex=consolidated?(c.saidas??null):(p.cash_exits??null);
     value.fin=consolidated?(c.saldo_final_operacional??p.bank_balance??null):(p.balance??null);
     value.basis=p.balance_basis;
    }else if(p?.balance_basis==='relative_tracked_bank_ledger'||x.relative_balance_display===true){
     value.prev=null;value.fin=null;
    }
   }
   if(ACC==='Consolidado'&&x.Itaú?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=x.fix86_columns.saldo_anterior_operacional;
   }else if(x[ACC]?.balance_basis==='observed_bank_position_and_recent_movements'){
    value.prev=x[ACC].opening_balance??(Number(x[ACC].balance)-Number(x[ACC].net));
   }
   const incomplete=ACC==='Consolidado'?x.movements_complete===false:x[ACC]?.movements_complete===false;
   if(incomplete){value.prev=ACC==='Consolidado'?x.fix86_columns.saldo_anterior:x[ACC].opening_balance;value.en=null;value.ex=null}
   if(x?.projection_complete===false&&(ACC==='C6'||ACC==='Consolidado')){
    if(x[ACC]?.projection_complete===false){value.prev=null;value.fin=null;value.ex=null;value.basis='incomplete_card_cycle';}
    if(ACC==='Consolidado')for(const key of ['liq_d30','d30'])if(key in value)value[key]=null;
   }
   return value;
  };
  flowSemanticTitle=function(e){if(e.asset_movement&&/resgate cofrinh/i.test(e.description||''))return 'Resgate Cofrinho';if(e.internal_transfer&&/^Transferência entre contas/.test(e.description||''))return e.description;return previousTitle(e)};
  flowSemanticMeta=function(e){return e.internal_transfer?'':previousMeta(e)};
  function after(){
   const localToday=typeof today==="function"?today():null;
   if(V==='Fluxo Diário'&&typeof FLOWQ!=='undefined'&&FLOWQ?.observed_bank_movements){const label=document.getElementById('ltsBankEvidence');if(label)label.textContent='';}
   if(V==='Fluxo Diário'&&typeof mergedFlowDays==='function')for(const day of mergedFlowDays()){
    const row=document.getElementById('d-'+day.date);if(!row)continue;
    const incomplete=ACC==='Consolidado'?day.movements_complete===false:day[ACC]?.movements_complete===false;
    if(incomplete)for(const index of [2,3])if(row.children[index]){row.children[index].textContent='—';row.children[index].title='Movimentos deste dia aguardam conferência em Atualizações.'}
    const bank=ACC==='Consolidado'?day.Itaú:day[ACC];
    if(localToday&&day.date===localToday){
     const ending=row.children[4];
     if(ending){
      ending.title='Saldo do dia, considerando os movimentos e as previsões desta linha.';
      ending.querySelector('.v274-ending-label')?.remove();
     }
     if(row.children[1])row.children[1].title='Saldo anterior usado no fluxo; não é a posição bancária recebida agora.';
    }else if(bank?.balance_basis==='observed_bank_position_and_recent_movements'){
     for(const index of [1,4])if(row.children[index])row.children[index].title='Saldo reconstituído com os movimentos recebidos do banco.';
    }
   }
   const evidence=document.getElementById('ltsBankEvidence')||document.querySelector('.flowbar');
   let position=document.getElementById('v274ReceivedPosition');
   if(V==='Fluxo Diário'&&evidence){
    if(!position){position=document.createElement('div');position.id='v274ReceivedPosition';position.hidden=true;evidence.insertAdjacentElement('afterend',position);}
    const cash=window.__LTS_V178_STATE?.cash;
    const valid=!!cash&&window.__LTS_V178_REVIEW?.cashComplete?.(cash)===true;
    const value=valid?(ACC==='Consolidado'?cash.data.cash:cash.data.day?.[ACC]?.balance):null;
    const numeric=typeof value==='number'||(typeof value==='string'&&/^-?\d+(?:\.\d+)?$/.test(value.trim()));
    const amount=numeric&&Number.isFinite(Number(value))?Number(value):null;
    const account=ACC==='Consolidado'?'todas as contas':ACC;
    const pending=cash?.status==='idle'||cash?.status==='loading';
    position.textContent=amount===null?(pending?'Consultando o saldo informado ('+account+')…':'Saldo informado ('+account+'): indisponível.'):
     'Saldo informado pelo banco ('+account+'): '+new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(amount)+'. O fluxo também considera previsões. Confira os lançamentos do dia para comparar os valores.';
   }else position?.remove();
   if(V==='Fluxo Diário')for(const row of document.querySelectorAll('.fx87-row[id^="d-"]')){
    const detail=row.nextElementSibling;if(!detail?.classList.contains('fx89-details'))continue;
    const events=dayEvents(row.id.slice(2));detail.querySelectorAll('.fx89-detail-row').forEach((entry,i)=>{const e=events[i];if(e?.internal_transfer){const label=entry.querySelector('.fx89-detail-desc>span');if(label)label.textContent=(e.account||'Conta')+' · '+(e.asset_movement?'Resgate':'Transferência')}});
   }
   if(V!=='Atualizações')return;
   const gaps=typeof FLOWQ!=='undefined'?FLOWQ?.observed_bank_movements?.documentary_gaps:null;
   const rows=Object.entries(gaps||{}).filter(([,v])=>Math.abs(Number(v))>.005);
   const host=document.querySelector('.v168-openfinance');if(!rows.length){document.querySelector('.v228-bank-review')?.remove();return;}if(!host)return;
   let box=document.querySelector('.v228-bank-review');
   if(!box){box=document.createElement('div');box.className='v228-bank-review v168-note';host.insertAdjacentElement('afterend',box);}
   box.textContent='Conferência de posições anteriores: '+rows.map(([bank,value])=>bank+' · '+new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value)).join('; ')+'. Os saldos atuais vêm dos bancos. Falta o movimento que explique a mudança de posição; o ajuste sem comprovante foi retirado.';
  }
  render=function(){const result=previousRender.apply(this,arguments);after();return result;};
  window.__LTS_V228_FLOW={installed:true,completeness_contract:269};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V227_LAYOUT)return false;if(!w.__LTS_V228_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V228_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-v228-bank-flow.js',install);
})();


;
;
/* LTS V384: lts-v235-history-inventory.js */
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
  const statuses={historical_total:'Histórico por total · anterior ao detalhamento',formula_reconciled:'Composição conciliada pela fórmula original',aggregate_only:'Composição não localizada',partial_source:'Composição disponível com diferença',audit_pending:'Origem ainda a conferir'};
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
  const lineOrigin=r=>'<details class="v235-source"><summary>'+esc(r.source_sheet)+' · linha '+Number(r.source_row)+'</summary><p>'+esc(r.source_file)+'<br>'+esc(r.source_sheet)+' · linha '+Number(r.source_row)+'</p>'+(r.corroboration?.file?'<p>'+esc(r.corroboration.file)+'<br>'+esc(r.corroboration.sheet)+' · linha '+Number(r.corroboration.row)+'</p>':'')+'</details>'+(r.included_in_source_total===false?'<small data-v237-excluded>Fora do total da fórmula original</small>':'');
  const formulaProof=d=>d.formula_evidence?.length?'<details class="v235-source" data-v237-formula><summary>Conferência da fórmula original</summary><p>Total de todas as linhas: <b>'+money(d.raw_detail_total)+'</b><br>Fora do total da fórmula: <b>'+money(Number(d.raw_detail_total)-Number(d.detail_total))+'</b><br>Total aplicado: <b>'+money(d.detail_total)+'</b></p>'+d.formula_evidence.map(f=>'<p>'+esc(f.file)+' · '+esc(f.total_cell)+'<br><code>'+esc(f.total_formula)+'</code><br><code>'+esc(f.category_formula)+'</code><br>Pagamentos e Recebimentos · linha '+Number(f.ledger_row)+'</p>').join('')+'</details>':'';
  async function openRecord(row){
   const host=dialog('Origem e composição da fatura');
   async function load(){
    host.body.innerHTML='<p role="status">Carregando a conferência…</p>';
    try{
     const d=await rpc('lts_browser_card_history_record_v237',{p_source_table:row.source_table,p_source_ref:String(row.source_ref),p_event_date:row.event_date||row.date});
     if(!current(host))return;
     if(d.version!=='card-history-record-v237'||!Array.isArray(d.cycle_records)||!d.cycle_records.length||d.cycle_total==null)throw Error('Conferência incompleta.');
     host.body.innerHTML='<p><b>'+esc(d.bank+' · '+d.card_name)+' · '+month(d.reference_month)+'</b></p><p class="v235-status">'+esc(statuses[d.composition_status]||'Conferência pendente')+'</p><p>'+esc(d.source_note)+'</p>'+
      (d.record?.sign_corrected?'<p class="v235-credit-note">O sinal deste ajuste da planilha foi corrigido de '+money(d.record.original_report_amount)+' para '+money(d.record.amount)+', conforme as duas planilhas originais.</p>':'')+
      formulaProof(d)+'<h3>Pagamentos, créditos e ajustes do ciclo</h3><div class="v226-scroll"><table class="v235-ledger-table"><thead><tr><th>Data do registro</th><th>Origem</th><th>Valor</th></tr></thead><tbody>'+d.cycle_records.map(r=>'<tr data-v235-ledger-row><td data-v235-label="Data do registro">'+date(r.date)+'</td><td data-v235-label="Origem">'+esc(r.kind==='credit_or_adjustment'?'Ajuste negativo':'Pagamento')+' · '+esc(r.description)+origin(r.workbook_evidence||[])+'</td><td data-v235-label="Valor" data-v235-money class="'+(Number(r.amount)<0?'v235-credit':'')+'">'+money(r.amount)+'</td></tr>').join('')+'</tbody><tfoot><tr><th colspan="2">Total líquido do ciclo</th><td data-v235-money>'+money(d.cycle_total)+'</td></tr></tfoot></table></div>'+
      (d.items?.length?'<h3>Composição encontrada na planilha</h3><p>'+Number(d.nonzero_detail_rows)+' registros com valor em '+Number(d.detail_rows)+' linhas de origem. A data das compras não está disponível.</p><div class="v235-partial-totals"><span>Total que entrou na fórmula <b>'+money(d.detail_total)+'</b></span><span>Diferença para o ciclo <b>'+money(d.detail_difference)+'</b></span></div><div class="v226-scroll"><table class="v235-source-table"><thead><tr><th>Categoria original</th><th>Referência</th><th>Valor</th></tr></thead><tbody>'+d.items.map(r=>'<tr data-v235-source-item><td data-v235-label="Categoria original">'+esc(r.category)+'</td><td data-v235-label="Referência">'+lineOrigin(r)+'</td><td data-v235-label="Valor" data-v235-money class="'+(Number(r.amount)<0?'v235-credit':'')+'">'+money(r.amount)+'</td></tr>').join('')+'</tbody></table></div><p class="v226-note">As categorias e os sinais da fonte foram preservados. '+(d.composition_status==='formula_reconciled'?'A composição aplicada confere com o total registrado. As linhas excluídas pela fórmula continuam visíveis.':'A composição permanece pendente de conciliação.')+'</p>':'');
    }catch{if(current(host)){host.body.innerHTML='<p role="alert">A conferência deste registro não está disponível agora.</p><button class="v168-btn" data-v235-retry>Tentar novamente</button>';host.body.querySelector('[data-v235-retry]').onclick=load;}}
   }
   await load();
  }
  async function openInventory(){
   const p=selectedPeriod(),host=dialog('Histórico de cartões e composições conferidas');
   async function load(offset=0){
    host.body.innerHTML='<p role="status">Conferindo os ciclos de '+date(p.p_from)+' a '+date(p.p_to)+'…</p>';
    try{
     const d=await rpc('lts_browser_card_history_inventory_v237',{...p,p_offset:offset,p_limit:50});
     if(!current(host))return;
     if(d.version!=='card-history-inventory-v237'||!Array.isArray(d.cycles)||!d.summary)throw Error('Inventário incompleto.');
     const s=d.summary;
     host.body.innerHTML='<p>Período selecionado: '+date(d.from)+' a '+date(d.to)+'</p><p><b>'+Number(s.record_count)+' registros de pagamento e ajustes em '+Number(s.cycle_count)+' ciclos.</b> Ajustes negativos das planilhas reduzem o total.</p><p>'+Number(s.historical_total_cycles||0)+' ciclos anteriores ao início do detalhamento, preservados por total; '+Number(s.formula_reconciled_cycles||0)+' conciliados pela fórmula original. Esses registros não são pendências de composição.</p><p>'+Number(s.aggregate_only_cycles)+' ciclos posteriores ao início do detalhamento com composição não localizada; '+Number(s.partial_source_cycles)+' com composição disponível e diferença.'+(s.audit_pending_cycles?' '+Number(s.audit_pending_cycles)+' ciclos ainda precisam da conferência de origem.':'')+'</p><p class="v235-inventory-total">Total líquido no período: <b>'+money(s.total)+'</b></p>'+
      (s.detail_boundaries?.length?'<details class="v235-source" data-v237-boundaries><summary>Início do detalhamento nas planilhas</summary>'+s.detail_boundaries.map(b=>'<p>'+esc(({itau_mastercard:'Mastercard Itaú',bradesco_prime:'Visa Prime Bradesco',itau_visa:'Visa Itaú',c6:'C6',aeternum:'Visa Aeternum'})[b.family]||b.family)+' · '+month(b.detail_from)+'</p>').join('')+'</details>':'')+(d.cycles.length?'<div class="v226-scroll"><table class="v235-inventory-table"><thead><tr><th>Banco / cartão</th><th>Ciclo</th><th>Registros</th><th>Valor líquido</th><th>Composição</th></tr></thead><tbody>'+d.cycles.map((r,i)=>'<tr data-v235-cycle-row><td data-v235-label="Banco / cartão"><button class="v226-link" data-v235-cycle="'+i+'">'+esc(r.bank+' · '+r.card_name)+'</button></td><td data-v235-label="Ciclo">'+month(r.reference_month)+'</td><td data-v235-label="Registros">'+Number(r.record_count)+'</td><td data-v235-label="Valor líquido" data-v235-money><button class="v226-link" data-v235-cycle="'+i+'">'+money(r.amount)+'</button></td><td data-v235-label="Composição">'+esc(statuses[r.composition_status]||'Conferência pendente')+'</td></tr>').join('')+'</tbody></table></div><div class="v235-pagination"><button class="v168-btn" data-v235-prev '+(offset===0?'disabled':'')+'>Anterior</button><span>Ciclos '+(offset+1)+' a '+(offset+d.cycles.length)+' de '+Number(s.cycle_count)+'</span><button class="v168-btn" data-v235-next '+(d.next_offset==null?'disabled':'')+'>Próximos</button></div>':'<p>Não há registros históricos por total neste período.</p>');
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
    const b=document.createElement('button');b.className='v168-btn';b.dataset.v235Open='';b.textContent='Conferir histórico e início do detalhamento';b.onclick=openInventory;h.appendChild(b);
   }
   const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let text;
   while((text=walker.nextNode())){
    if(text.parentElement?.closest('script,style'))continue;
    let value=text.nodeValue.replace(/Faturas sem composição individual/g,'Histórico de cartões por total').replace(/faturas sem composição individual/g,'histórico de cartões por total');
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
 window.LTSV339Boot?.watch('lts-v235-history-inventory.js',install);
})();

;
;
/* LTS V384: lts-v257-ui-state.js */
/* Preserve card sections through asynchronous reader renders. No financial state is stored. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w||!d||!w.__LTS_V226?.installed||!d.getElementById('app'))return false;
   if(w.__LTS_V257_UI_STATE?.installed)return true;
   const runtime=function(){
    if(window.__LTS_V257_UI_STATE?.installed)return;
    const saved=new Map(),tracked=new WeakMap(),selector='details.v226-future';
    const key=()=>String(typeof V==='undefined'?'':V)+'|card-future';
    function register(){
     for(const node of document.querySelectorAll(selector)){
      const k=key();tracked.set(node,k);
      if(saved.has(k))node.open=saved.get(k);else saved.set(k,node.open);
     }
    }
    const observer=new MutationObserver(records=>{
     for(const record of records)for(const removed of record.removedNodes){
      if(removed.nodeType!==1)continue;
      for(const node of [removed,...removed.querySelectorAll(selector)]){
       if(tracked.has(node))saved.set(tracked.get(node),node.open);
      }
     }
     register();
    });
    document.addEventListener('toggle',event=>{
     const node=event.target;if(node?.matches?.(selector)&&node.isConnected&&tracked.has(node))saved.set(tracked.get(node),node.open);
    },true);
    register();observer.observe(document.getElementById('app'),{childList:true,subtree:true});
    window.__LTS_V257_UI_STATE={installed:true,financial_data_changed:false};
   };
   const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);return !!w.__LTS_V257_UI_STATE?.installed;
  }catch{return false}
 }
 let tries=0;const timer=setInterval(()=>{if(install()||++tries>200)clearInterval(timer)},100);
 shell?.addEventListener('load',install);
 window.LTSV339Boot?.watch('lts-v257-ui-state.js',install);
})();

;
;
/* LTS V384: lts-v275-overdue-visibility.js */
/* Read-only visibility of overdue forecasts already present in the Flow payload. */
(function () {
  'use strict';
  function makeContract() {
    const owns = (object, key) => !!object && Object.prototype.hasOwnProperty.call(object, key);
    function day(value) {
      if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
      const date = new Date(value + 'T12:00:00Z');
      return Number.isFinite(date.valueOf()) && date.toISOString().slice(0, 10) === value ? value : null;
    }
    function businessDay(now) {
      const parts = new Intl.DateTimeFormat('en-CA', {timeZone:'America/Sao_Paulo', year:'numeric', month:'2-digit', day:'2-digit'}).formatToParts(now || new Date());
      const get = name => parts.find(part => part.type === name).value;
      return get('year') + '-' + get('month') + '-' + get('day');
    }
    function amount(value) {
      if (typeof value !== 'number' && !(typeof value === 'string' && /^-?\d+(?:\.\d+)?$/.test(value.trim()))) return null;
      const number = Number(value);
      return Number.isFinite(number) ? number : null;
    }
    const escape = value => String(value == null ? '' : value).replace(/[&<>"']/g, char => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[char]));
    const money = value => new Intl.NumberFormat('pt-BR', {style:'currency', currency:'BRL'}).format(value);
    function model(flow, context) {
      const current = day(context.today), account = context.account || 'Consolidado';
      const result = (status, rows, extra) => Object.assign({status, rows:rows || [], account, today:current, invalidCount:0}, extra || {});
      if (!current) return result('unavailable');
      if (context.loading) return result('loading');
      if (!flow || typeof flow !== 'object' || flow.error) return result('unavailable');
      if (context.range && (flow.from !== context.range.from || flow.to !== context.range.to)) return result('range_mismatch');
      const source = flow.observed_bank_movements;
      if (!source || !owns(source, 'pending_projections')) return result('source_missing');
      if (!Array.isArray(source.pending_projections)) return result('invalid_source');
      // These are calculation-day contracts, never bank snapshot timestamps.
      const anchors = [flow.current_future && flow.current_future.current_anchor_date,
        flow.projected_operational_anchor && flow.projected_operational_anchor.as_of].filter(value => value != null);
      if (!anchors.length) return result('undated');
      if (anchors.some(value => day(value) !== current)) return result('stale');
      const seen = new Map(), conflicts = new Set();
      let invalidCount = 0;
      for (const event of source.pending_projections) {
        if (!event || typeof event !== 'object' || Array.isArray(event)) { invalidCount++; continue; }
        const due = day(event.event_date), value = amount(event.signed_amount);
        const bank = typeof event.account === 'string' ? event.account.trim() : '';
        const ref = event.financial_event_id || event.id || (event.source && event.source_ref ? event.source + ':' + event.source_ref : null);
        if (!due || value === null || !bank || typeof ref !== 'string' || !ref) { invalidCount++; continue; }
        const row = {key:ref + '|' + due, dueDate:due, account:bank, amount:value,
          confirmed:event.bank_confirmed === true, suppressed:event.is_suppressed === true,
          description:typeof event.description === 'string' && event.description.trim() ? event.description : 'Previsão sem descrição',
          confirmation:value < 0 ? 'pagamento a confirmar' : value > 0 ? 'recebimento a confirmar' : 'movimento a confirmar'};
        const previous = seen.get(row.key);
        if (previous && (previous.amount !== row.amount || previous.account !== row.account || previous.description !== row.description || previous.confirmed !== row.confirmed || previous.suppressed !== row.suppressed)) {
          conflicts.add(row.key);
        } else if (!previous) seen.set(row.key, row);
      }
      for (const key of conflicts) seen.delete(key);
      invalidCount += conflicts.size;
      const rows = Array.from(seen.values()).filter(row => !row.confirmed && !row.suppressed && row.dueDate < current && (account === 'Consolidado' || row.account === account)).map(({confirmed, suppressed, ...row}) => row).sort((a, b) => a.dueDate.localeCompare(b.dueDate) || a.account.localeCompare(b.account) || a.key.localeCompare(b.key));
      return result(invalidCount ? 'partial' : 'ready', rows, {invalidCount});
    }
    function markup(view, expanded) {
      const unavailable = {
        range_mismatch:'Atualize o fluxo para conferir os lançamentos vencidos.',
        source_missing:'Não foi possível conferir os lançamentos vencidos. Atualize o fluxo.',
        invalid_source:'Não foi possível conferir os lançamentos vencidos. Atualize o fluxo.',
        undated:'Atualize o fluxo para conferir os lançamentos vencidos.',
        stale:'Atualize o fluxo para conferir os lançamentos vencidos.',
        unavailable:'Não foi possível conferir os lançamentos vencidos. Atualize o fluxo.'
      };
      if (view.status === 'loading') return '';
      if (unavailable[view.status]) return '<p role="status">' + escape(unavailable[view.status]) + '</p>';
      const caution = view.status === 'partial' ? '<p role="status">Alguns lançamentos não puderam ser conferidos. Atualize o fluxo.</p>' : '';
      if (!view.rows.length) return caution;
      const count = view.rows.length, subject = view.rows.every(row => row.amount > 0) ? 'recebimento' : view.rows.every(row => row.amount < 0) ? 'pagamento' : 'lançamento';
      return caution + '<details' + (expanded ? ' open' : '') + '><summary>' + count + ' ' + subject + (count === 1 ? ' vencido a conferir' : 's vencidos a conferir') + '</summary><ul>' +
        view.rows.map(row => '<li><span><b>' + escape(row.description) + '</b><small>' + escape(row.account) + ' · Vencimento ' + escape(row.dueDate.split('-').reverse().join('/')) + ' · ' + escape(row.confirmation) + '</small></span><strong>' + escape(money(row.amount)) + '</strong></li>').join('') + '</ul></details>';
    }
    return {day, businessDay, model, markup};
  }
  if (typeof module === 'object' && module.exports) { module.exports = makeContract(); return; }
  function runtime(build) {
    if (window.__LTS_FLOW_OVERDUE_PROJECTIONS) return;
    const contract = build(), previousRender = render, previousLoad = typeof loadFlowRange === 'function' ? loadFlowRange : null, expandedByAccount = new Map();
    let scheduled = false;
    const id = 'ltsFlowOverdueProjections';
    const state = window.__LTS_FLOW_OVERDUE_PROJECTIONS = {installed:true, financial_data_changed:false, network_requests_added:false, last_status:null};
    function rememberExpanded() {
      const panel = document.getElementById(id), details = panel && panel.querySelector('details');
      // Native details.open changes before the browser dispatches its queued toggle.
      // Keep the rendered account, even if ACC has already changed for navigation.
      if (details && typeof panel.__ltsAccount === 'string') expandedByAccount.set(panel.__ltsAccount, details.open === true);
    }
    function after() {
      rememberExpanded();
      let panel = document.getElementById(id);
      if (V !== 'Atualizações') { if (panel) panel.remove(); return; }
      const host = document.querySelector('.v168-updates .v168-head');
      if (!host) return;
      const from = typeof FLOWFROM === 'undefined' ? null : FLOWFROM;
      const to = typeof FLOWTO === 'undefined' ? null : FLOWTO;
      const account = 'Consolidado';
      const view = contract.model(typeof FLOWQ === 'undefined' ? null : FLOWQ, {
        today:contract.businessDay(), account,
        loading:typeof FLOWQ==='undefined'||!FLOWQ||(typeof FLOWLOADING !== 'undefined' && FLOWLOADING),
        range:contract.day(from) && contract.day(to) ? {from, to} : null
      });
      state.last_status = view.status;
      const html = contract.markup(view, expandedByAccount.get(account) === true);
      if (!html) { if (panel) panel.remove(); return; }
      if (!panel) {
        panel = document.createElement('section'); panel.id = id; panel.className = 'v168-note lts-overdue-forecasts';
        panel.setAttribute('aria-label', 'Lançamentos vencidos a conferir'); host.insertAdjacentElement('afterend', panel);
      }
      if (panel.__ltsMarkup !== html || panel.__ltsAccount !== account) {
        panel.hidden = !html;
        panel.innerHTML = html; panel.__ltsMarkup = html; panel.__ltsAccount = account;
        const details = panel.querySelector('details');
        if (details) details.addEventListener('toggle', () => {
          // Removed/replaced elements may dispatch an already queued toggle later.
          if (document.getElementById(id) === panel && panel.querySelector('details') === details && panel.__ltsAccount === account) expandedByAccount.set(account, details.open === true);
        });
      }
    }
    if (!document.getElementById('ltsOverdueForecastStyle')) {
      const style = document.createElement('style'); style.id = 'ltsOverdueForecastStyle';
      style.textContent = '.lts-overdue-forecasts{margin:8px 0;overflow-wrap:anywhere}.lts-overdue-forecasts p{margin:4px 0}.lts-overdue-forecasts summary{cursor:pointer;font-weight:600}.lts-overdue-forecasts ul{list-style:none;padding:0;margin:8px 0 0}.lts-overdue-forecasts li{display:flex;gap:12px;justify-content:space-between;align-items:flex-start;padding:7px 0;border-top:1px solid #cbd5e144}.lts-overdue-forecasts li span{min-width:0}.lts-overdue-forecasts small{display:block;font-size:12px}.lts-overdue-forecasts strong{white-space:nowrap;font-variant-numeric:tabular-nums}@media(max-width:430px){.lts-overdue-forecasts li{flex-direction:column;gap:2px}}';
      document.head.appendChild(style);
    }
    function settle() {
      if (scheduled) return; scheduled = true;
      queueMicrotask(() => { scheduled = false; after(); });
    }
    render = function () { rememberExpanded(); const result = previousRender.apply(this, arguments); after(); settle(); return result; };
    if (previousLoad) loadFlowRange = function () {
      rememberExpanded();
      const result = previousLoad.apply(this, arguments);
      if (result && typeof result.then === 'function') return result.then(value => { after(); settle(); return value; }, error => { after(); settle(); throw error; });
      after(); settle(); return result;
    };
    after(); settle();
  }
  const shell = document.getElementById('shell');
  const installState = window.__LTS_V275_OVERDUE_INSTALL || (window.__LTS_V275_OVERDUE_INSTALL = {status:'waiting', attempts:0, budget_ms:60000});
  function install(){
    try{
      const frame=shell?.contentWindow,doc=shell?.contentDocument;
      if(!frame||!doc||!frame.__LTS_V228_FLOW||!frame.__LTS_V235_HISTORY||!frame.__LTS_V257_UI_STATE?.installed)return false;
      if(!frame.__LTS_FLOW_OVERDUE_PROJECTIONS){const script=doc.createElement('script');script.textContent='('+runtime.toString()+')('+makeContract.toString()+');';doc.head.appendChild(script);}
      if(frame.__LTS_FLOW_OVERDUE_PROJECTIONS){installState.status='installed';return true;}
    }catch{}
    return false;
  }
  let generation=0;
  function start(){const current=++generation;let tries=0;installState.status='waiting';installState.attempts=0;
    function attempt(){if(current!==generation)return;installState.attempts=tries+1;if(install())return;if(++tries<240)setTimeout(attempt,250);else installState.status='timed_out';}attempt();
  }
  shell?.addEventListener('load',start);start();
 window.LTSV339Boot?.watch('lts-v275-overdue-visibility.js',install);
})();

;
;
/* LTS V384: lts-v290-usability.js */
/* Defer background rendering while a native category picker is focused. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V290_USABILITY)return;
  const previous=render;let deferred=false,route=null;
  const categoryFocused=()=>{const el=document.activeElement;return window.LTSCategoryRegistry?.busy||el?.matches('input,select,textarea')||!!el?.closest('.lts-new-category');};
  const ready=()=>D&&!N.classList.contains('hidden')&&(typeof BOOT==='undefined'||document.body.dataset.ltsBootState==='ready');
  function after(){
   if(V==='Fluxo Diário'&&typeof mergedFlowDays==='function'){
    const now=typeof today==='function'?today():null;
    for(const day of mergedFlowDays()){
     const row=document.getElementById('d-'+day.date);if(!row?.firstElementChild)continue;
     let phase=row.querySelector('.lts-phase');if(!phase){phase=document.createElement('small');phase.className='lts-phase';row.firstElementChild.appendChild(phase);}
     phase.textContent='';phase.className='lts-phase '+(day.movements_complete===false?'needs-review':day.date>=now?'forecast':'actual');phase.title=day.movements_complete===false?'Saldo a conferir':day.date>now?'Projeção':day.date===now?'Dia em andamento':'Movimentos registrados';phase.setAttribute('aria-label',phase.title);
    }
   }
  }
  render=function(){
   let notice=document.getElementById('ltsDeferredUpdate');
   if(ready()&&categoryFocused()&&(route===null||route===V)){
    deferred=true;route=V;if(!notice){notice=document.createElement('p');notice.id='ltsDeferredUpdate';notice.setAttribute('role','status');notice.className='lts-editing-update';document.getElementById('app')?.before(notice);}
    notice.textContent='Há dados novos. Eles serão exibidos ao concluir a edição.';notice.hidden=false;return;
   }
   if(notice)notice.hidden=true;
   route=V;deferred=false;const out=previous.apply(this,arguments);after();return out;
  };
  // Flush after the click handler has captured its fields; a blur-time render
  // would remove the target button before the user's first click reaches it.
  document.addEventListener('click',()=>setTimeout(()=>{if(deferred&&!categoryFocused())render();},0));
  window.__LTS_V290_USABILITY={installed:true,source_amounts_unchanged:true};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_FLOW_OVERDUE_PROJECTIONS||!w?.LTSCategoryRegistry)return false;if(!w.__LTS_V290_USABILITY){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V290_USABILITY;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-v290-usability.js',install);
})();

;
;
/* LTS V384: lts-v290-source-details.js */
/* User-facing quote provenance, scheduled bank rows and source-scoped classification. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V290_SOURCES)return;
  const previous=render,st={quotes:null,quoteError:false,quoteLoading:false,quoteReadAt:0,quoteDetailsOpen:false,future:null,futureError:false,futureLoading:false,futureReadAt:0};
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=x=>Number.isFinite(Number(x))?new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x)):'—';
  const stamp=x=>{const d=new Date(x);return x&&Number.isFinite(d.getTime())?new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',dateStyle:'short',timeStyle:'short'}).format(d):'não informado';};
  const day=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'—';
  const businessDay=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const active=()=>D&&!N.classList.contains('hidden');
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  let owner=generation(),epoch=0;
  function reset(){if(owner===generation())return;owner=generation();epoch++;Object.assign(st,{quotes:null,quoteError:false,quoteLoading:false,quoteReadAt:0,quoteDetailsOpen:false,future:null,futureError:false,futureLoading:false,futureReadAt:0});}
  function safeLink(url,label){try{if(new URL(url).protocol==='https:')return '<a href="'+esc(url)+'" target="_blank" rel="noopener noreferrer">'+esc(label)+'</a>';}catch{}return esc(label);}
  async function quotes(force=false){
   reset();if(!active()||st.quoteLoading||(!force&&Date.now()-st.quoteReadAt<300000))return;
   const current=epoch;st.quoteLoading=true;
   try{const r=await S.rpc('lts_browser_market_quotes_v290',{});if(r.error||!r.data)throw Error();
    if(current!==epoch||owner!==generation())return;
    const changed=st.quotes&&st.quotes.revision!==r.data.revision;st.quotes=r.data;st.quoteError=false;st.quoteReadAt=Date.now();
    if(changed){window.__LTS_V227_TRANSPORT?.invalidate?.();const ui=window.__LTS_V168_STATE;if(ui){ui.wealth.data=null;ui.dashboard.data=null;}render();}
   }catch{if(current===epoch){st.quoteError=true;st.quoteReadAt=Date.now();}}
   finally{if(current===epoch){st.quoteLoading=false;paintQuotes();}}
  }
  async function mode(value,button){
   st.quoteDetailsOpen=button.closest('details')?.open===true;
   button.disabled=true;
   try{
    const r=await S.rpc('lts_browser_market_mode_v290',{p_mode:value});if(r.error||r.data?.ok!==true)throw Error();
    window.__LTS_V227_TRANSPORT?.invalidate?.();st.quoteReadAt=0;
    const ui=window.__LTS_V168_STATE;if(ui){ui.wealth.data=null;ui.dashboard.data=null;}
    const provenance=window.__LTS_V183_AWARD_PROVENANCE;if(provenance){provenance.token++;provenance.status='idle';provenance.data=null;}
    await quotes(true);render();
   }catch{const status=document.querySelector('#ltsMarketQuotes [role=status]');if(status)status.textContent='Não foi possível alterar o modo. Tente novamente.';}
   finally{button.disabled=false;}
  }
  function quoteMarkup(){
   const q=st.quotes,stock=q?.stock,fx=q?.usd_brl,manual=q?.mode==='manual';
   const failed=st.quoteError||(q?.refresh||[]).some(x=>x.status==='failed');
   const missing=!stock||!fx;
   const aged=[stock,fx].some(x=>x&&Date.now()-new Date(x.quoted_at).getTime()>4*86400000);
   const value=(x,currency)=>x?new Intl.NumberFormat('pt-BR',{style:'currency',currency,minimumFractionDigits:currency==='USD'?2:4,maximumFractionDigits:currency==='USD'?2:4}).format(Number(x.value)):'—';
   return '<div class="v168-cardhead"><div><span>Referências para as projeções</span><h2>Cotações</h2></div></div>'+
    '<div class="lts-market-values"><div><span>Organon · OGN</span><b>'+esc(value(stock,'USD'))+'</b><small>Negócio de '+esc(stamp(stock?.quoted_at))+'</small></div><div><span>Dólar · PTAX venda</span><b>'+esc(value(fx,'BRL'))+'</b><small>Referência de '+esc(stamp(fx?.quoted_at))+'</small></div></div>'+
    (manual?'<p class="lts-freshness-alert" role="status">Simulação manual ativa nas projeções. As referências acima continuam disponíveis para comparação.</p>':missing?'<p class="lts-freshness-alert" role="status">'+(st.quoteLoading?'Consultando as referências de mercado…':'Falta uma referência de mercado. Confira as premissas antes de usar as projeções.')+'</p>':failed?'<p class="lts-freshness-alert" role="status">A última atualização não foi concluída. Mantivemos as cotações disponíveis nas datas acima.</p>':aged?'<p class="lts-freshness-alert" role="status">Há referências com mais de quatro dias. Confira a origem antes de usar as projeções.</p>':'')+
    '<details class="lts-update-details"><summary>Atualização</summary><p>Busca automática a cada hora. O preço pode ter atraso; fora do pregão, mantemos o último negócio informado. A PTAX é uma referência diária, não uma cotação intradiária.</p>'+
    [stock,fx].filter(Boolean).map(x=>'<p>'+safeLink(x.source_url,x.source_name)+'<br>Data da cotação: '+esc(stamp(x.quoted_at))+'<br>Recebida no Wealth: '+esc(stamp(x.received_at))+'</p>').join('')+
    '<p>Consulta desta tela: '+esc(stamp(q?.consulted_at))+'. Horários de Brasília. A atualização das projeções preserva os registros históricos.</p>'+
    '<button type="button" class="v168-btn" data-market-read>Conferir atualização</button> <button type="button" class="v168-btn" data-market-mode="'+(manual?'automatic':'manual')+'">'+(manual?'Usar cotações automáticas':'Simular com premissas manuais')+'</button></details><span role="status"></span>';
  }
  function paintQuotes(){
   reset();if(!active())return;
   const host=document.querySelector(V==='Patrimônio'&&window.__LTS_V168_STATE?.wealth?.tab==='rsu'?'.v168-wealth':V==='Dashboard'?'.v168-dashboard':'#never');
   if(host){let panel=document.getElementById('ltsMarketQuotes');if(!panel){panel=document.createElement('article');panel.id='ltsMarketQuotes';panel.className='v168-card lts-market-panel';host.appendChild(panel);}
    const html=quoteMarkup();if(panel.innerHTML!==html){panel.innerHTML=html;panel.querySelector('details').open=st.quoteDetailsOpen;}
    const details=panel.querySelector('details');details.ontoggle=()=>{if(details.isConnected&&document.getElementById('ltsMarketQuotes')===panel)st.quoteDetailsOpen=details.open;};
    panel.querySelector('[data-market-read]').onclick=()=>quotes(true);
    panel.querySelector('[data-market-mode]').onclick=e=>mode(e.currentTarget.dataset.marketMode,e.currentTarget);
   }
   const automatic=st.quotes?.mode!=='manual';
   document.querySelectorAll('.v170-global-award').forEach(form=>form.hidden=automatic);
   document.querySelectorAll('[data-v168-award-edit]').forEach(button=>button.hidden=automatic);
  }
  async function future(force=false){
   reset();if(!active()||st.futureLoading||(!force&&Date.now()-st.futureReadAt<300000))return;
   const current=epoch,today=businessDay(),start=new Date(today+'T12:00:00Z'),end=new Date(today+'T12:00:00Z');start.setUTCDate(start.getUTCDate()-90);end.setUTCFullYear(end.getUTCFullYear()+1);
   st.futureLoading=true;
   try{const r=await S.rpc('lts_browser_future_bank_v293',{p_from:start.toISOString().slice(0,10),p_to:end.toISOString().slice(0,10)});if(r.error||!Array.isArray(r.data?.rows))throw Error();
    if(current!==epoch||owner!==generation())return;st.future=r.data;st.futureError=false;st.futureReadAt=Date.now();
   }catch{if(current===epoch){st.futureError=true;st.futureReadAt=Date.now();}}
   finally{if(current===epoch){st.futureLoading=false;paintFuture();}}
  }
  function paintFuture(){
   if(!active())return;
   const host=document.querySelector(V==='Atualizações'?'.v168-updates':'#never');if(!host)return;
   let panel=document.getElementById('ltsFutureBank');if(!panel){panel=document.createElement('article');panel.id='ltsFutureBank';panel.className='v168-card lts-future-bank';host.insertAdjacentElement('beforeend',panel);}
   const rows=(st.future?.rows||[]).filter(x=>V!=='Fluxo Diário'||ACC==='Consolidado'||x.bank===ACC||x.identity?.destination_bank===ACC);
   const isOwn=x=>x.identity?.own_identity_proven===true,isIncluded=x=>x.identity?.represented_in_flow===true,isOverdue=x=>x.status==='overdue_unconfirmed';
   const includedOwn=rows.filter(x=>isOwn(x)&&isIncluded(x)).length,represented=rows.filter(x=>!isOwn(x)&&isIncluded(x)).length;
   const ownReview=rows.filter(x=>isOwn(x)&&!isIncluded(x)&&!isOverdue(x)).length,overdue=rows.filter(isOverdue).length,unlinked=rows.filter(x=>!isOwn(x)&&!isIncluded(x)&&!isOverdue(x)).length;
   const count=(n,one,many)=>n+' '+(n===1?one:many);
   const needsReview=ownReview+overdue+unlinked;
   const rowAmount=x=>isOwn(x)?(V==='Fluxo Diário'&&ACC===x.bank?x.amount:Math.abs(x.amount)):x.amount;
   const rowStatus=x=>isOverdue(x)?'Pagamento a confirmar':isIncluded(x)?'Previsto':'Ainda fora da previsão';
   const open=panel.querySelector('.lts-future-list')?.open===true;
   const updateOpen=panel.querySelector('.lts-schedule-update')?.open===true;
   const html='<details class="lts-future-list"><summary>Agendamentos'+(st.future?' · '+rows.length:'')+'</summary>'+
    (rows.length?rows.map(x=>'<section class="lts-future-row"><div><b>'+esc(x.identity?.projection_description||(isOwn(x)?'Transferência entre contas':x.description))+'</b><small>'+esc(day(x.date))+' · '+esc(x.identity?.destination_bank?x.bank+' → '+x.identity.destination_bank:x.bank)+' · '+rowStatus(x)+'</small><details class="lts-update-details"><summary>Origem</summary><p>'+esc(x.description)+'<br>Recebido no Wealth: '+esc(stamp(x.received_at))+'<br>Atualização no banco: '+esc(stamp(x.source_updated_at))+'</p></details></div><strong>'+money(rowAmount(x))+'</strong><button type="button" class="v168-btn" data-future-day="'+esc(x.date)+'">Ver dia no fluxo</button></section>').join(''):st.future?'<p>Nenhum agendamento disponível.</p>':'<p role="status">Carregando agendamentos…</p>')+'</details>'+
    (st.futureError?'<p class="lts-schedule-alert" role="status">Não conseguimos atualizar os agendamentos. Tente novamente em Atualização.</p>':needsReview?'<p class="lts-schedule-alert" role="status">'+count(needsReview,'agendamento a conferir.','agendamentos a conferir.')+' <button type="button" class="v168-btn" data-future-review>Ver agendamentos</button></p>':'')+
    '<details class="lts-update-details lts-schedule-update"><summary>Atualização</summary>'+
    '<p>Consulta desta tela: '+esc(stamp(st.future?.consulted_at))+'. Horários de Brasília.</p>'+
    '<p>Esta lista mostra os agendamentos disponibilizados pelos bancos. Consulte a origem de cada item para ver quando ele foi atualizado.</p>'+
    '<p>Compras e parcelas futuras dos cartões: '+Number(st.future?.card_future_received||0)+'. Consulte em Cartões e faturas.</p>'+
    '<button type="button" class="v168-btn" data-future-read>Atualizar agendamentos</button></details>';
   if(panel.innerHTML!==html){panel.innerHTML=html;panel.querySelector('.lts-future-list').open=open;panel.querySelector('.lts-schedule-update').open=updateOpen;}
   panel.querySelector('[data-future-read]').onclick=()=>future(true);
   panel.querySelector('[data-future-review]')?.addEventListener('click',()=>{panel.querySelector('.lts-future-list').open=true;panel.querySelector('.lts-future-row')?.scrollIntoView({block:'nearest'});});
   panel.querySelectorAll('[data-future-day]').forEach(button=>button.onclick=async()=>{V='Fluxo Diário';renderNav();await loadFlowRange(button.dataset.futureDay,button.dataset.futureDay);});
  }
  async function openClassification(event,trigger){
   document.getElementById('ltsFlowClassification')?.close();
   const dialog=document.createElement('dialog');dialog.id='ltsFlowClassification';dialog.className='v231-classification-dialog';
   dialog.innerHTML='<form><header><h2>Classificar lançamento</h2><button type="button" class="v168-btn" data-close>Fechar</button></header><p><b>'+esc(event.description)+'</b><br>'+esc(day(event.event_date))+' · '+money(event.signed_amount)+'</p><div data-fields>Carregando classificações…</div><p role="status"></p><button type="submit" class="v168-btn primary" disabled>Salvar classificação</button></form>';
   document.body.appendChild(dialog);dialog.querySelector('[data-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{dialog.remove();trigger?.focus();});dialog.showModal();
   try{
    const options=await window.LTSCategoryRegistry.get(true);if(!dialog.isConnected)return;
    const selected=window.LTSCategoryRegistry.canonical(event.category),submit=dialog.querySelector('[type=submit]');
    dialog.querySelector('[data-fields]').innerHTML='<label>Classificação<select name="category" required><option value="">Selecione…</option>'+options.categories.map(x=>'<option value="'+esc(x)+'"'+(selected===x?' selected':'')+'>'+esc(window.LTSCategoryDisplay.category(x))+'</option>').join('')+'</select></label><label>Pessoa/contexto · opcional<select name="beneficiary"><option value="">Preservar identificação atual</option>'+['Lucas','Larissa','Benjamin','Rafiki'].map(x=>'<option value="'+x+'">'+(x==='Lucas'?'Minha / sem prefixo':x)+'</option>').join('')+'</select></label>';
    window.LTSCategoryRegistry.attach(dialog.querySelector('[name=category]'));submit.disabled=false;
    dialog.querySelector('form').onsubmit=async e=>{
     e.preventDefault();if(submit.disabled)return;submit.disabled=true;
     const status=dialog.querySelector('p[role=status]');status.textContent='Salvando…';
     try{
      const r=await S.rpc('lts_browser_flow_classification_v290',{p_source:event.source,p_source_ref:event.open_finance_id||event.source_ref,p_event_date:event.event_date,p_category:dialog.querySelector('[name=category]').value,p_beneficiary:dialog.querySelector('[name=beneficiary]').value||null});
      if(r.error||r.data?.ok!==true)throw Error();
      dialog.close();const review=window.__LTS_V181_STATE?.review;if(review){review.status='idle';review.data=null;review.key='';}
      window.__LTS_V227_TRANSPORT?.invalidate?.();window.__LTS_V226?.invalidate?.();await loadFlowRange(FLOWFROM,FLOWTO);
     }catch{if(dialog.isConnected){status.textContent='Não foi possível salvar. Confira a conexão e tente novamente.';submit.disabled=false;}}
    };
   }catch{dialog.querySelector('[role=status]').textContent='Não foi possível carregar as classificações. Feche e tente novamente.';}
  }
  function classifyFlow(){
   if(V!=='Fluxo Diário'||typeof dayEvents!=='function')return;
   document.querySelectorAll('.fx87-row[id^="d-"]').forEach(row=>{
    const detail=row.nextElementSibling;if(!detail?.classList.contains('fx89-details'))return;
    const events=dayEvents(row.id.slice(2));detail.querySelectorAll('.fx89-detail-row').forEach((entry,index)=>{
     const event=events[index];if(!event||Number(event.signed_amount)>=0||event.internal_transfer||event.asset_movement||event.excluded_from_spend||event.source==='card_invoice'||entry.querySelector('[data-flow-classify]'))return;
     const button=document.createElement('button');button.type='button';button.className='v168-btn';button.dataset.flowClassify='true';button.textContent='Classificar';button.onclick=()=>openClassification(event,button);
     (entry.querySelector('.fx89-detail-desc')||entry).appendChild(button);
    });
   });
  }
  function paint(){reset();if(!active())return;paintQuotes();paintFuture();classifyFlow();
   if(['Dashboard','Patrimônio','Atualizações'].includes(V)){queueMicrotask(()=>quotes());if(V==='Atualizações')queueMicrotask(()=>future());}
  }
  render=function(){const out=previous.apply(this,arguments);paint();return out;};
  window.__LTS_V290_SOURCES={installed:true,state:st,refresh(){quotes(true);future(true);}};
  const style=document.createElement('style');style.textContent='#ltsFutureBank{padding:12px 16px;margin:8px 0}#ltsFutureBank>.lts-future-list>summary{cursor:pointer;font-weight:650;font-size:15px}#ltsFutureBank>.lts-schedule-update{margin-top:6px}#ltsFutureBank>.lts-schedule-update>summary{cursor:pointer;font-size:12px;color:#52657b}#ltsFutureBank .lts-schedule-alert{margin:6px 0 0;line-height:1.4;font-size:13px;color:#7c561e}#ltsFutureBank .lts-schedule-alert .v168-btn{font-size:12px;padding:3px 8px}';document.head.appendChild(style);
  setInterval(()=>{if(active()&&!document.hidden&&['Dashboard','Patrimônio','Atualizações'].includes(V)){quotes();if(V==='Atualizações')future();}},300000);
  paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V290_USABILITY)return false;if(!w.__LTS_V290_SOURCES){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V290_SOURCES;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-v290-source-details.js',install);
})();

;
;
/* LTS V384: lts-v296-classifications.js */
/* Incoming and outgoing classifications share one visible review entry point. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V296_CLASSIFICATIONS)return;
  const oldRender=render,oldNav=renderNav,oldUpdates=atualizacoes;
  const state={generation:null,sequence:0,loading:false,reload:false,error:false,data:null,expense:null,readAt:0,offset:0,query:''};
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const date=x=>String(x||'').split('-').reverse().join('/');
  const current=()=>typeof BOOT==='object'?BOOT.generation:D;
  function session(){
   if(state.generation!==current())Object.assign(state,{generation:current(),sequence:state.sequence+1,loading:false,reload:false,error:false,data:null,expense:null,readAt:0,offset:0,query:''});
  }
  function counts(){
   const review=window.__LTS_V181_STATE?.review;
   const income=state.data?.row_count,expense=review?.status==='ready'?review.data?.row_count:state.expense;
   const card=window.__LTS_V312_CARD_REVIEW,additional=card?.state.data?.additional_count;
   const expected=card?3:2,known=[income,expense,...(card?[additional]:[])].filter(x=>Number.isInteger(x)&&x>=0),n=known.reduce((a,b)=>a+b,0);
   return{n,complete:known.length===expected&&!state.error&&!card?.state.error};
  }
  function go(){V='Atualizações';renderNav();render();document.getElementById('v296IncomeQueue')?.scrollIntoView({block:'start'});}
  function badges(){
   session();
   document.querySelectorAll('.lts-classification-badge').forEach(el=>el.remove());
   const c=counts(),text=c.n?(c.complete?'':'+')+c.n:(c.complete?'':'•');
   document.querySelectorAll('[data-v="Atualizações"],[data-mobile-route="Atualizações"]').forEach(button=>{
    button.classList.add('lts-actions-nav');
    if(text){const badge=document.createElement('span');badge.className='lts-classification-badge';badge.textContent=text;button.appendChild(badge);}
    button.setAttribute('aria-label',c.n?'Ações · '+(c.complete?'':'pelo menos ')+c.n+' classificações pendentes':c.complete?'Ações':'Ações · classificações a conferir');
   });
   document.getElementById('ltsClassificationNotice')?.remove();
   if(V==='Dashboard'&&(c.n||state.error)){
    const head=document.querySelector('.v168-dashboard .v168-head');if(!head)return;
    const notice=document.createElement('button');notice.id='ltsClassificationNotice';notice.className='v168-btn lts-classification-notice';
    notice.textContent=c.n?(c.complete?'':'Pelo menos ')+c.n+' classificações pendentes · Ver em Ações':'Classificações: atualização indisponível · Ver em Ações';
    notice.onclick=go;head.insertAdjacentElement('afterend',notice);
   }
  }
  async function read(name,args,applicable){
   const rpc=S.rpc.bind(S),reader=window.parent.LTSReviewRead;
   const result=reader ? await reader.read(rpc,name,args,applicable) : await rpc(name,args);
   if(result.error||!result.data)throw Error('unavailable');
   return result.data;
  }
  async function load(force=false){
   session();if(!D||N.classList.contains('hidden'))return;if(state.loading){if(force)state.reload=true;return;}if(!force&&Date.now()-state.readAt<300000)return;
   state.loading=true;const sequence=++state.sequence,generation=state.generation;
   if(V==='Atualizações')render();
   const args={p_from:'2013-10-10',p_to:today(),p_offset:state.offset,p_limit:25,p_query:state.query||null};
   const applicable=()=>generation===current()&&sequence===state.sequence&&D&&!N.classList.contains('hidden')
    &&document.visibilityState!=='hidden'&&args.p_offset===state.offset&&args.p_query===(state.query||null);
   const [income,expense]=await Promise.allSettled([
    read('lts_browser_income_review_queue_v296',args,applicable),
    read('lts_browser_expense_review_queue_v229',{p_from:args.p_from,p_to:args.p_to,p_offset:0,p_limit:1,p_query:null},applicable)
   ]);
   if(generation!==current()||sequence!==state.sequence)return;
   state.loading=false;state.readAt=Date.now();state.error=false;
   if(income.status==='fulfilled'&&income.value.ok===true&&Array.isArray(income.value.rows)&&Number.isInteger(income.value.row_count))state.data=income.value;else state.error=true;
   if(expense.status==='fulfilled'&&Number.isInteger(expense.value.row_count))state.expense=expense.value.row_count;else state.error=true;
   if(V==='Atualizações')render();else badges();
   if(state.reload){state.reload=false;queueMicrotask(()=>load(true));}
  }
  function panel(){
   const d=state.data,rows=d?.rows||[],c=counts();
   const header='<article class="v168-card lts-income-queue" id="v296IncomeQueue"><div class="v168-cardhead"><div><span>Classificações</span><h2>Receitas a classificar</h2></div><strong>'+(d?esc(d.row_count):'—')+'</strong></div><p>Recebimentos de todas as datas. Use as mesmas classificações do fluxo e dos cartões.</p>';
   const error=state.error?'<p class="lts-review-alert" role="status">Não foi possível atualizar todas as classificações. A lista anterior pode estar desatualizada.</p><button type="button" class="v168-btn" data-income-retry>Tentar novamente</button>':'';
   if(!d)return header+error+'<p role="status">'+(state.loading?'Carregando receitas…':'A lista ainda não está disponível.')+'</p></article>';
   const filter='<form class="lts-income-search"><label>Buscar recebimentos<input type="search" maxlength="300" name="income-query" value="'+esc(state.query)+'" placeholder="Descrição ou conta"></label><button class="v168-btn" type="submit">Buscar</button></form>';
   const list=rows.map((e,i)=>'<section class="lts-income-row"><div><small>'+esc(date(e.event_date))+' · '+esc(e.account)+'</small><b>'+esc(e.description||'Recebimento')+'</b></div><strong>'+esc(brl(e.signed_amount))+'</strong><button type="button" class="v168-btn primary" data-income-review="'+i+'">'+(e.editable?'Classificar':'Ver no fluxo')+'</button></section>').join('')||'<p>'+(d.row_count?'Nenhum recebimento encontrado nesta busca.':'Nenhuma receita sem classificação.')+'</p>';
   const from=Number(d.offset||0),total=Number(d.matched_count||0);
   const paging='<div class="lts-income-paging"><span>'+(total?((from+1)+'–'+Math.min(from+rows.length,total)+' de '+total):'0 itens')+'</span><div><button type="button" class="v168-btn" data-income-prev '+(from?'':'disabled')+'>Anterior</button><button type="button" class="v168-btn" data-income-next '+(d.next_offset==null?'disabled':'')+'>Próxima</button></div></div>';
   return header+error+filter+list+paging+(state.loading?'<p role="status">Atualizando…</p>':'')+'</article>';
  }
  atualizacoes=function(){session();const t=document.createElement('template');t.innerHTML=oldUpdates();const head=t.content.querySelector('.v168-updates .v168-head');head?.insertAdjacentHTML('afterend',panel());return t.innerHTML;};
  function bind(){
   const retry=document.querySelector('[data-income-retry]'),search=document.querySelector('.lts-income-search'),prev=document.querySelector('[data-income-prev]'),next=document.querySelector('[data-income-next]');
   if(retry)retry.onclick=()=>load(true);
   if(search)search.onsubmit=e=>{e.preventDefault();state.query=e.target.elements['income-query'].value.trim();state.offset=0;load(true);};
   if(prev)prev.onclick=()=>{state.offset=Math.max(0,state.offset-25);load(true);};
   if(next)next.onclick=()=>{state.offset=Number(state.data?.next_offset||0);load(true);};
   document.querySelectorAll('[data-income-review]').forEach(button=>button.onclick=()=>{
    const row=state.data?.rows?.[Number(button.dataset.incomeReview)];if(!row)return;
    if(row.editable)window.__LTS_V183_INCOME_REVIEW.openReceipt(row,button);
    else{V='Fluxo Diário';ACC=row.account;renderNav();loadFlowRange(row.event_date,row.event_date);}
   });
  }
  function reportDetails(){
   if(V==='Despesas'&&window.__LTS_V168_STATE?.expense?.tab==='monthly'&&window.__LTS_V175_STATE?.monthly?.error){const error=document.querySelector('.v168-expenses .v168-error');if(error){error.textContent='Não foi possível conferir o relatório deste período. Tente atualizar antes de usar os totais.';error.setAttribute('role','alert');}}
   const report=document.querySelector('.v175-monthly');if(!report)return;
   const notes=[report.querySelector('.v175-yearbar>small'),report.querySelector('.v175-sale-strip small')].filter(Boolean);
   let details=report.querySelector('.lts-report-update');if(!details){details=document.createElement('details');details.className='lts-report-update';details.innerHTML='<summary>Atualização</summary><p>Receitas do fluxo e despesas por competência. Transferências entre contas próprias não são receita nem despesa; pagamentos de fatura não são uma segunda despesa.</p>';report.appendChild(details);}for(const note of notes){const p=document.createElement('p');p.textContent=note.textContent;details.appendChild(p);note.remove();}
   const coverage=report.querySelector('.v175-coverage span');if(coverage)coverage.textContent=coverage.textContent.replace('Categorias recuperadas do workbook só entram quando o total do mês fecha exatamente.','Os detalhes identificados são conferidos com o total da fatura.');
  }
  render=function(){const r=oldRender();session();bind();badges();reportDetails();if(D&&!N.classList.contains('hidden'))queueMicrotask(()=>load(false));return r;};
  renderNav=function(){const r=oldNav();badges();return r;};
  window.addEventListener('lts:income-classified',()=>{state.offset=0;state.readAt=0;load(true);});
  const style=document.createElement('style');style.textContent=`
   .lts-actions-nav{position:relative}.lts-classification-badge{position:absolute;top:2px;right:3px;border-radius:12px;background:#a33d20;color:white;font-size:10px;font-weight:800;line-height:16px;min-width:16px;padding:0 4px;box-sizing:border-box}
   .lts-classification-notice{display:block;margin:0 0 16px;text-align:left;white-space:normal;line-height:1.45}
   .v168-updates,.v168-updates *{min-width:0}.v168-updates b,.v168-updates p,.v168-updates small,.v168-updates h2,.v168-updates button{overflow-wrap:anywhere}
   .v168-updates .v168-action{align-items:start}.v168-updates .v168-btn{white-space:normal;line-height:1.4;min-height:44px}
   #v237CoverageAudit .v168-action{grid-template-columns:minmax(0,1fr) auto;align-items:start}
   #v237CoverageAudit .v268-periods{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
   #v237CoverageAudit .v268-periods button{min-height:44px;white-space:normal;max-width:100%}
   .lts-income-queue{margin-bottom:16px}.lts-income-queue p{line-height:1.5;color:#526174}.lts-income-search{display:flex;align-items:end;gap:10px;margin:16px 0}
   .lts-income-search label{flex:1;font-size:13px}.lts-income-search input{display:block;box-sizing:border-box;width:100%;min-height:44px;margin-top:6px;border:1px solid #cbd5df;border-radius:8px;padding:10px}
   .lts-income-row{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:12px;align-items:start;padding:15px 0;border-top:1px solid #e1e7ef}.lts-income-row b,.lts-income-row small{display:block;line-height:1.5}.lts-income-row small{color:#526174}.lts-income-row>strong{white-space:nowrap}
   .lts-income-paging{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:10px;margin-top:16px}.lts-income-paging>div{display:flex;gap:8px}.lts-review-alert{border-left:3px solid #b7802d;padding:10px}
   @media(max-width:640px){#v237CoverageAudit .v168-action{grid-template-columns:minmax(0,1fr)}#v237CoverageAudit .v168-action>button{width:100%}.v168-updates .v168-action:not([data-coverage-key]){grid-template-columns:28px minmax(0,1fr)}.v168-updates .v168-action:not([data-coverage-key])>button{grid-column:2;justify-self:start;max-width:100%}.lts-income-row{grid-template-columns:minmax(0,1fr) auto}.lts-income-row>button{grid-column:1/-1;justify-self:start}.lts-income-search{flex-wrap:wrap}.lts-income-search label{flex-basis:100%}.v168-updates .v168-cardhead{flex-wrap:wrap;gap:8px}}
  `;document.head.appendChild(style);
  window.__LTS_V296_CLASSIFICATIONS={installed:true,state,refresh:()=>load(true)};
  window.addEventListener('lts:product-refresh-ready',()=>load(true));
  session();if(D&&!N.classList.contains('hidden')){render();queueMicrotask(()=>load(false));}
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V290_SOURCES?.installed||!w?.__LTS_V183_INCOME_REVIEW)return false;if(!w.__LTS_V296_CLASSIFICATIONS){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}return !!w.__LTS_V296_CLASSIFICATIONS;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
 window.LTSV339Boot?.watch('lts-v296-classifications.js',install);
})();

;
;
/* LTS V384: lts-v308-review-layout.js */
/* Compact projection review. Uses the existing rendered periods; no data reader or writer. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V308_REVIEW_LAYOUT)return;
  const previousRender=render,expanded=new Set(),filters=new Map();
  let generation;
  function scope(){
   const current=typeof BOOT==='object'?BOOT.generation:D;
   if(current!==generation){generation=current;expanded.clear();filters.clear();}
   return document.getElementById('v237CoverageYear')?.value||'';
  }
  function compact(){
   const year=scope(),card=document.getElementById('v237CoverageAudit');
   if(!card||card.dataset.compactReview==='true')return;
   card.dataset.compactReview='true';
   const rows=[...card.querySelectorAll('[data-coverage-key]')];
   if(!rows.length)return;
   const toolbar=document.createElement('div');toolbar.className='lts-coverage-toolbar';
   const label=document.createElement('label');label.textContent='Mostrar ';
   const select=document.createElement('select');select.className='v168-btn';select.setAttribute('aria-label','Filtrar séries de projeção');
   for(const [value,text] of [['issues','Pendências do ano'],['all','Todas as séries'],['gap','Com meses sem previsão'],['awaiting','Com movimentação a confirmar']]){
    const option=document.createElement('option');option.value=value;option.textContent=text;select.appendChild(option);
   }
   select.value=filters.get(year)||'issues';label.appendChild(select);toolbar.appendChild(label);
   const count=document.createElement('span');count.className='lts-coverage-count';count.setAttribute('role','status');count.setAttribute('aria-live','polite');toolbar.appendChild(count);
   const list=card.querySelector('.v168-actions');list.before(toolbar);
   const empty=document.createElement('p');empty.className='v168-empty lts-coverage-empty';empty.textContent='Nenhuma série corresponde ao filtro neste ano.';empty.hidden=true;list.after(empty);
   for(const row of rows){
    const periods=row.querySelector('.v268-periods');if(!periods)continue;
    const key=year+'|'+row.dataset.coverageKey,details=document.createElement('details');details.className='lts-coverage-months';
    const summary=document.createElement('summary');summary.textContent='Ver períodos de '+year;details.appendChild(summary);
    const reference=periods.nextElementSibling;
    periods.before(details);details.appendChild(periods);
    if(reference?.tagName==='SMALL')details.appendChild(reference);
    details.dataset.coverageScope=key;details.open=expanded.has(key);
    const rowGeneration=generation;
    details.ontoggle=()=>{if(rowGeneration!==generation)return;if(details.open)expanded.add(key);else expanded.delete(key);};
   }
   function applyFilter(){
    const filter=select.value;filters.set(year,filter);let visible=0;
    for(const row of rows){
     const matches=filter==='all'||(filter==='issues'?!!row.querySelector('[data-period-state="gap"],[data-period-state="awaiting"],[data-period-state="unknown"]'):!!row.querySelector('[data-period-state="'+filter+'"]'));
     row.hidden=!matches;if(matches)visible++;
    }
    count.textContent=visible+' de '+rows.length+' séries · '+year;empty.hidden=visible!==0;
   }
   select.onchange=applyFilter;applyFilter();
  }
  const style=document.createElement('style');style.id='lts-v308-review-style';
  style.textContent=`
   #v237CoverageAudit .lts-coverage-toolbar{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin:16px 0 8px}
   #v237CoverageAudit .lts-coverage-toolbar label{display:flex;align-items:center;flex-wrap:wrap;gap:8px;min-width:0;font-size:12px;color:#526174}
   #v237CoverageAudit .lts-coverage-toolbar select{max-width:100%;min-height:44px;background:#fff}
   #v237CoverageAudit .lts-coverage-count{font-size:12px;color:#526174;font-variant-numeric:tabular-nums}
   #v237CoverageAudit [data-coverage-key]{padding:14px 16px;gap:12px;border-bottom:1px solid #e6ebf1}
   #v237CoverageAudit [data-coverage-key][hidden]{display:none!important}
   #v237CoverageAudit [data-coverage-key]>div>small{margin-top:5px;line-height:1.5;overflow-wrap:anywhere}
   #v237CoverageAudit .lts-coverage-months{margin-top:8px;border:0;background:transparent;padding:0}
   #v237CoverageAudit .lts-coverage-months>summary{cursor:pointer;display:list-item;min-height:44px;box-sizing:border-box;padding:12px 0;color:#1b527e;font-size:12px;font-weight:700}
   #v237CoverageAudit .lts-coverage-months>summary:focus-visible{outline:2px solid #1b527e;outline-offset:3px;border-radius:4px}
   #v237CoverageAudit .lts-coverage-months .v268-periods{margin-top:0!important;margin-bottom:8px}
   #v237CoverageAudit .lts-coverage-empty[hidden]{display:none}
   @media(max-width:400px){#ltsFutureBank{padding-block:10px}}
   @media(max-width:640px){#v237CoverageAudit .lts-coverage-toolbar{align-items:flex-start;flex-direction:column}#v237CoverageAudit .lts-coverage-toolbar label{width:100%}#v237CoverageAudit .lts-coverage-toolbar select{flex:1;min-width:0}#v237CoverageAudit [data-coverage-key]{gap:6px;padding:14px 12px}}
  `;document.head.appendChild(style);
  render=function(){
   const current=typeof BOOT==='object'?BOOT.generation:D,sameGeneration=current===generation;scope();
   if(sameGeneration)document.querySelectorAll('.lts-coverage-months[data-coverage-scope]').forEach(details=>{
    const key=details.dataset.coverageScope;if(details.open)expanded.add(key);else expanded.delete(key);
   });
   const result=previousRender.apply(this,arguments);compact();return result;
  };
  window.__LTS_V308_REVIEW_LAYOUT={installed:true,read_only:true,compact};compact();
 }
 function install(){try{
  const w=shell?.contentWindow,d=shell?.contentDocument;
  if(!w?.__LTS_V296_CLASSIFICATIONS?.installed)return false;
  if(!w.__LTS_V308_REVIEW_LAYOUT){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);}
  return !!w.__LTS_V308_REVIEW_LAYOUT?.installed;
 }catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}
 shell?.addEventListener('load',()=>{attempts=0;start();});start();
 window.LTSV339Boot?.watch('lts-v308-review-layout.js',install);
})();

;
;
/* LTS V384: lts-v312-card-review.js */
/* Review every received card observation; learning never turns a suggestion into a decision. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V312_CARD_REVIEW)return;
  const oldRender=render,oldUpdates=atualizacoes;
  const state={generation:null,sequence:0,loading:false,reload:false,deferredRender:false,error:false,data:null,readAt:0,startedInUpdates:false,offset:0,query:'',drafts:new Map(),saving:new Set(),message:''};
  const current=()=>typeof BOOT==='object'?BOOT.generation:D;
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const label=x=>window.LTSCategoryDisplay?.category(x)||x||'';
  const date=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')?x.split('-').reverse().join('/'):'Data não informada';
  const today=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const money=r=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:r.currency||'BRL'}).format(Number(r.amount));
  function session(){
   if(state.generation!==current()){
    state.generation=current();state.sequence++;state.loading=false;state.reload=false;state.deferredRender=false;state.error=false;state.data=null;state.readAt=0;state.startedInUpdates=false;state.offset=0;state.query='';state.drafts.clear();state.saving.clear();state.message='';
    document.getElementById('v312CardDialog')?.close();
   }
  }
  function go(){V='Atualizações';renderNav();render();document.getElementById('v312CardReview')?.scrollIntoView({block:'start'});}
  function notice(){
   document.getElementById('v312CardReviewNotice')?.remove();
   const n=state.data?.row_count;if(!n||V!=='Despesas'||window.__LTS_V168_STATE?.expense?.tab!=='cards')return;
   const head=document.querySelector('.v226-upcoming');if(!head)return;
   const b=document.createElement('button');b.id='v312CardReviewNotice';b.className='v168-btn lts-card-review-notice';
   b.textContent=n+' lançamentos de cartão a classificar · Ver em Ações';b.onclick=go;head.insertAdjacentElement('afterend',b);
  }
  async function load(force=false){
   session();if(!D||N.classList.contains('hidden'))return;
   if(state.loading){if(force)state.reload=true;return;}
   const inUpdates=V==='Atualizações';
   const retryOnEntry=inUpdates&&state.error&&!state.startedInUpdates;
   if(!force&&!retryOnEntry&&Date.now()-state.readAt<300000)return;
   const generation=state.generation,sequence=++state.sequence,query=state.query,offset=state.offset;state.loading=true;
   state.startedInUpdates=inUpdates;
   if(inUpdates)render();
   try{
    const args={p_from:'2013-10-10',p_to:today(),p_offset:offset,p_limit:10,p_query:query||null};
    const applicable=()=>generation===current()&&sequence===state.sequence&&query===state.query&&offset===state.offset
     &&D&&!N.classList.contains('hidden')&&document.visibilityState!=='hidden';
    const reader=window.parent.LTSReviewRead,rpc=S.rpc.bind(S);
    const r=reader ? await reader.read(rpc,'lts_browser_card_review_queue_v312',args,applicable) : await rpc('lts_browser_card_review_queue_v312',args);
    if(generation!==current()||sequence!==state.sequence)return;
    if(query!==state.query||offset!==state.offset){state.reload=true;return;}
    if(r.error||r.data?.ok!==true||!Array.isArray(r.data.rows)||!Number.isInteger(r.data.row_count)||!Number.isInteger(r.data.additional_count))throw Error('unavailable');
    state.data=r.data;state.error=false;state.readAt=Date.now();
    if(state.offset>0&&!r.data.rows.length&&r.data.matched_count<state.offset){state.offset=Math.max(0,Math.floor((r.data.matched_count-1)/10)*10);state.readAt=0;}
   }catch{if(generation===current()&&sequence===state.sequence){state.error=true;state.readAt=Date.now();}}
   finally{
    if(generation===current()&&sequence===state.sequence){state.loading=false;if(V==='Atualizações')render();else{renderNav();notice();}if(state.reload||(!state.error&&state.readAt===0)){state.reload=false;queueMicrotask(()=>load(true));}}
   }
  }
  function panel(){
   const d=state.data,rows=d?.rows||[];
   const header='<article class="v168-card lts-card-review" id="v312CardReview"><div class="v168-cardhead"><div><span>Classificações</span><h2>Cartões a classificar</h2></div><strong data-v312-count>'+(d?esc(d.row_count):'—')+'</strong></div><p>Compras recebidas de todas as datas, incluindo o histórico. Suas confirmações orientam as próximas sugestões.</p>';
   const warning=state.error?'<p class="lts-review-alert" role="alert">Não foi possível atualizar a lista. As informações anteriores podem estar desatualizadas.</p><button class="v168-btn" data-v312-retry>Tentar novamente</button>':'';
   if(!d)return header+warning+'<p role="status">'+(state.loading?'Consultando classificações…':'A lista ainda não está disponível.')+'</p></article>';
   const search=(state.message?'<p class="lts-card-saved" role="status">'+esc(state.message)+'</p>':'')+'<form class="lts-card-review-search"><label>Buscar compras<input type="search" name="card-query" maxlength="300" value="'+esc(state.query)+'" placeholder="Descrição, cartão ou final"></label><button type="submit" class="v168-btn">Buscar</button></form>';
   const list=rows.map((r,i)=>'<section class="lts-card-review-row"><div><small>'+esc(date(r.event_date))+' · '+esc(r.account_source)+' · final '+esc(r.last4||'—')+'</small><b>'+esc(r.description)+'</b>'+(r.installment_number?'<small>Parcela '+esc(r.installment_number)+'/'+esc(r.total_installments||'?')+'</small>':'')+(r.suggestion?.category?'<span class="lts-card-review-suggestion">Sugestão: '+esc(label(r.suggestion.category))+'</span>':'<small>Finalidade a identificar</small>')+'</div><strong>'+esc(money(r))+'</strong><div class="lts-card-review-actions">'+(r.suggestion?.category?'<button type="button" class="v168-btn primary" data-v312-confirm="'+i+'" '+(state.saving.has(r.source_ref)?'disabled':'')+'>Confirmar '+esc(label(r.suggestion.category))+'</button>':'')+'<button type="button" class="v168-btn" data-v312-review="'+i+'">'+(r.suggestion?.category?'Alterar':'Classificar')+'</button><span role="status"></span></div></section>').join('')||'<p>'+(d.row_count?'Nenhuma compra encontrada nesta busca.':'Nenhum lançamento de cartão a classificar.')+'</p>';
   const off=d.offset||0,total=d.matched_count||0;
   const paging='<div class="lts-card-review-paging"><span>'+(total?((off+1)+'–'+Math.min(off+rows.length,total)+' de '+total):'0 itens')+'</span><div><button class="v168-btn" data-v312-prev '+(off?'':'disabled')+'>Anterior</button><button class="v168-btn" data-v312-next '+(d.next_offset==null?'disabled':'')+'>Próxima</button></div></div>';
   return header+warning+search+list+paging+(state.loading?'<p role="status">Atualizando…</p>':'')+'<details class="lts-card-review-update"><summary>Atualização</summary><p>Conferido em '+esc(new Date(d.checked_at).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'}))+'. Classificar preserva os valores contabilizados.</p></details></article>';
  }
  function open(row){
   document.getElementById('v312CardDialog')?.close();
   const generation=state.generation,draft=state.drafts.get(row.source_ref),suggested=row.suggestion?.category;
   const selected=draft?.category??suggested??'',person=draft?.beneficiary??'';
   const dialog=document.createElement('dialog');dialog.id='v312CardDialog';dialog.className='lts-card-review-dialog';
   dialog.innerHTML='<header><div><small>'+esc(date(row.event_date))+' · '+esc(money(row))+'</small><h2>Classificar compra</h2></div><button class="v168-btn" data-v312-close>Fechar</button></header><p><b>'+esc(row.description)+'</b><br>'+esc(row.account_source)+' · final '+esc(row.last4||'—')+'</p><form><label>Classificação<select name="category" required><option value="">Selecione…</option>'+(state.data?.category_options||[]).map(c=>'<option value="'+esc(c)+'"'+(c===selected?' selected':'')+'>'+esc(label(c))+'</option>').join('')+'</select></label><label>Pessoa · opcional<select name="beneficiary"><option value="">Sem identificação adicional</option>'+['Lucas','Larissa','Benjamin','Rafiki'].map(p=>'<option value="'+p+'"'+(p===person?' selected':'')+'>'+p+'</option>').join('')+'</select></label>'+(suggested?'<p class="lts-card-review-suggestion">Categoria sugerida. Confira antes de confirmar.</p>':'<p>Escolha a finalidade da compra para orientar novas sugestões.</p>')+'<details><summary>Por que sugerimos</summary><p>'+esc(row.suggestion?.note||'Ainda falta informação para sugerir uma classificação.')+'</p></details><footer class="lts-card-review-footer"><p role="status" aria-live="polite"></p><button type="submit" class="v168-btn primary" '+(selected?'':'disabled')+'>Confirmar classificação</button></footer></form>';
   document.body.appendChild(dialog);dialog.showModal();
   const form=dialog.querySelector('form'),select=form.elements.category,beneficiary=form.elements.beneficiary,save=form.querySelector('[type=submit]'),status=form.querySelector('[role=status]');
   function remember(){state.drafts.set(row.source_ref,{category:select.value,beneficiary:beneficiary.value});save.disabled=!select.value;}
   select.onchange=remember;beneficiary.onchange=remember;
   dialog.querySelector('[data-v312-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>{dialog.remove();if(V==='Atualizações')render();});
   window.LTSCategoryRegistry?.attach(select);remember();
   dialog.addEventListener('cancel',e=>{if(state.saving.has(row.source_ref))e.preventDefault();});
   form.onsubmit=async event=>{
    event.preventDefault();remember();if(save.disabled||generation!==current())return;
    save.disabled=true;dialog.querySelector('[data-v312-close]').disabled=true;
    const ok=await commit(row,select.value,beneficiary.value||null,status);
    if(ok&&dialog.isConnected)dialog.close();
    else if(dialog.isConnected){save.disabled=!select.value;dialog.querySelector('[data-v312-close]').disabled=false;}
   };
  }
  async function commit(row,category,beneficiary,status){
   session();if(!category||state.saving.has(row.source_ref))return false;
   const generation=state.generation;state.saving.add(row.source_ref);if(status)status.textContent='Salvando…';
   try{
    const r=await S.rpc('lts_browser_card_review_save_v312',{p_source_id:row.source_ref,p_expected_raw_hash:row.raw_hash,p_category:category,p_beneficiary:beneficiary});
    if(r.error||r.data?.ok!==true)throw Error('unavailable');if(generation!==current())return false;
    state.drafts.delete(row.source_ref);state.readAt=0;state.message='Classificação salva: '+row.description+'.';
    window.dispatchEvent(new CustomEvent('lts:card-classified'));
    window.__LTS_V296_CLASSIFICATIONS?.refresh();window.__LTS_V178_REVIEW?.refresh?.();
    if(window.__LTS_V226){window.__LTS_V226.cycles=null;window.__LTS_V226.loadedAt=0;}
    return true;
   }catch{if(status?.isConnected&&generation===current())status.textContent='Não foi possível confirmar a gravação. Atualize a lista antes de tentar novamente.';return false;}
   finally{if(generation===current())state.saving.delete(row.source_ref);}
  }

  function bind(){
   const host=document.getElementById('v312CardReview');if(!host)return;
   host.querySelector('[data-v312-retry]')?.addEventListener('click',()=>load(true));
   host.querySelector('form')?.addEventListener('submit',event=>{event.preventDefault();const input=event.target.elements['card-query'];state.query=input.value.trim();state.offset=0;input.blur();load(true);});
   host.querySelector('[data-v312-prev]')?.addEventListener('click',()=>{state.offset=Math.max(0,state.offset-10);load(true);});
   host.querySelector('[data-v312-next]')?.addEventListener('click',()=>{state.offset=Number(state.data?.next_offset||0);load(true);});
   host.querySelectorAll('[data-v312-confirm]').forEach(b=>b.onclick=async()=>{const row=state.data?.rows?.[Number(b.dataset.v312Confirm)];if(!row?.suggestion?.category||b.disabled)return;b.disabled=true;const ok=await commit(row,row.suggestion.category,null,b.parentElement.querySelector('[role=status]'));if(!ok&&b.isConnected)b.disabled=false;});
   host.querySelectorAll('[data-v312-review]').forEach(b=>b.onclick=()=>{const row=state.data?.rows?.[Number(b.dataset.v312Review)];if(row)open(row);});
  }
  atualizacoes=function(){session();const t=document.createElement('template');t.innerHTML=oldUpdates();t.content.querySelector('.v168-updates .v168-head')?.insertAdjacentHTML('afterend',panel());return t.innerHTML;};
  render=function(){
   session();const active=document.activeElement;
   if(V==='Atualizações'&&active?.closest('#v312CardDialog,#v312CardReview')&&['INPUT','SELECT','TEXTAREA'].includes(active.tagName)){state.deferredRender=true;return;}
   state.deferredRender=false;
   const r=oldRender();bind();notice();if(D&&!N.classList.contains('hidden'))queueMicrotask(()=>load(false));return r;
  };
  window.addEventListener('lts:card-classified',()=>{state.readAt=0;load(true);});
  document.addEventListener('focusout',()=>{if(state.deferredRender)queueMicrotask(()=>{if(state.deferredRender)render();});});
  window.addEventListener('lts:categories-changed',e=>{if(state.data&&Array.isArray(e.detail?.categories))state.data.category_options=e.detail.categories;});
  const style=document.createElement('style');style.textContent=`
   .lts-card-review-actions{display:flex;gap:8px;flex-wrap:wrap;max-width:260px}.lts-card-review-actions [role=status]{flex-basis:100%;font-size:12px;color:#8b3b26}.lts-card-saved{color:#235c42!important}.lts-card-review-dialog form{margin:0}.lts-card-review-footer{position:sticky;bottom:-20px;background:#fff;border-top:1px solid #dbe3eb;margin:12px -4px -4px;padding:12px 4px 4px;z-index:1}.lts-card-review-footer>button{width:100%}.lts-card-review-footer [role=status]{margin:0 0 5px;min-height:0!important}

   .lts-card-review{margin-bottom:16px}.lts-card-review>p,.lts-card-review-update{color:#526174;line-height:1.5}
   .lts-card-review-search{display:flex;align-items:end;gap:10px;margin:16px 0}.lts-card-review-search label{flex:1;font-size:13px}
   .lts-card-review-search input{display:block;box-sizing:border-box;width:100%;min-height:44px;margin-top:6px;border:1px solid #cbd5df;border-radius:8px;padding:10px}
   .lts-card-review-row{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:12px;align-items:start;padding:14px 0;border-top:1px solid #e1e7ef}
   .lts-card-review-row b,.lts-card-review-row small{display:block;line-height:1.5;overflow-wrap:anywhere}.lts-card-review-row small{color:#526174}.lts-card-review-row>strong{white-space:nowrap}
   .lts-card-review-suggestion{display:block;color:#8a621f;font-size:13px;line-height:1.5;margin-top:5px}
   .lts-card-review-paging{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap;margin-top:14px}.lts-card-review-paging>div{display:flex;gap:8px}
   .lts-card-review-update{margin-top:14px;font-size:12px}.lts-card-review-notice{margin:0 0 16px;text-align:left;white-space:normal;line-height:1.5}
   .lts-card-review-dialog{box-sizing:border-box;width:min(560px,calc(100vw - 24px));max-height:90dvh;overflow:auto;border:1px solid #d9e1e9;border-radius:16px;padding:20px;color:#20344a;background:white}
   .lts-card-review-dialog::backdrop{background:#14253599}.lts-card-review-dialog header{display:flex;align-items:start;justify-content:space-between;gap:12px}.lts-card-review-dialog h2{font-size:20px;margin:5px 0 12px}
   .lts-card-review-dialog p{line-height:1.5;overflow-wrap:anywhere}.lts-card-review-dialog label{display:block;margin:15px 0;font-size:13px}.lts-card-review-dialog select{box-sizing:border-box;width:100%;min-height:44px;padding:8px;margin-top:6px;border:1px solid #cbd5df;border-radius:8px;background:white;color:#20344a}
   .lts-card-review-dialog details{margin:16px 0;color:#526174;font-size:13px}.lts-card-review-dialog button{min-height:44px;white-space:normal}.lts-card-review-dialog [role=status]{min-height:20px;font-size:13px}
   @media(max-width:640px){.lts-card-review-row{grid-template-columns:minmax(0,1fr) auto}.lts-card-review-row>.lts-card-review-actions{grid-column:1/-1;max-width:none}.lts-card-review-actions>button{min-height:44px}.lts-card-review-search{flex-wrap:wrap}.lts-card-review-search label{flex-basis:100%}.lts-card-review-dialog{padding:16px}}
  `;document.head.appendChild(style);
  window.__LTS_V312_CARD_REVIEW={installed:true,state,refresh:()=>load(true),open};
  window.addEventListener('lts:product-refresh-ready',()=>load(true));
  session();if(D&&!N.classList.contains('hidden')){render();queueMicrotask(()=>load(false));}
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V296_CLASSIFICATIONS?.installed||!w.LTSCategoryRegistry)return false;if(!w.__LTS_V312_CARD_REVIEW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V312_CARD_REVIEW;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();
 window.LTSV339Boot?.watch('lts-v312-card-review.js',install);
})();

;
;
/* LTS V384: lts-v337-month-model.js */
/* Monthly consumption and current bank positions; no invented history or deltas. */
(function(root,factory){
 'use strict';const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV337Month=api;
})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const finite=x=>(typeof x==='number'||typeof x==='string'&&x.trim()!==''&&/^-?\d+(?:\.\d+)?$/.test(x))&&Number.isFinite(Number(x))?Number(x):null;
 function bounds(month,today){
  if(!/^\d{4}-\d{2}$/.test(month||'')||!/^\d{4}-\d{2}-\d{2}$/.test(today||''))return null;
  const start=month+'-01',d=new Date(start+'T12:00:00Z');
  if(!Number.isFinite(d.valueOf())||d.toISOString().slice(0,10)!==start||month<'2013-10'||month>today.slice(0,7))return null;
  d.setUTCMonth(d.getUTCMonth()+1);d.setUTCDate(0);const last=d.toISOString().slice(0,10);
  return{month,from:start<'2013-10-10'?'2013-10-10':start,to:last>today?today:last,partial:last>today};
 }
 function summarize(payload,range){
  if(!range||!payload||!Array.isArray(payload.monthly_totals))return null;
  const integrity=payload.window_integrity||payload;
  if(integrity.from!==range.from||integrity.to!==range.to)return null;
  const rows=payload.monthly_totals;if(rows.length!==1||String(rows[0].month).slice(0,10)!==range.month+'-01')return null;
  const row=rows[0],revenue=finite(row.revenue),extraordinary=finite(row.extraordinary),expenses=finite(row.expenses),result=finite(row.cash_after_extraordinary);
  if([revenue,extraordinary,expenses,result].some(x=>x===null)||Math.abs(revenue+extraordinary-expenses-result)>.021)return null;
  const totals=payload.totals||{};
  if(['revenue','extraordinary','expenses','cash_after_extraordinary'].some(k=>finite(totals[k])===null||Math.abs(Number(totals[k])-Number(row[k]))>.021))return null;
  return{month:range.month,from:range.from,to:range.to,partial:range.partial,revenue,extraordinary,entries:revenue+extraordinary,expenses,result};
 }
 function bankPositions(cash,today){
  if(cash?.status!=='complete'||cash.as_of!==today||finite(cash.cash)===null||!Array.isArray(cash.bank_positions)||cash.bank_positions.length!==3)return null;
  const specs=[['341','Itaú'],['237','Bradesco'],['336','C6']],rows=[];
  for(const [code,name]of specs){const found=cash.bank_positions.filter(x=>x.institution_code===code);if(found.length!==1||finite(found[0].balance)===null)return null;rows.push({code,name,balance:Number(found[0].balance)});}
  const total=rows.reduce((n,x)=>n+x.balance,0);if(Math.abs(total-Number(cash.cash))>.021)return null;
  return{rows,total,asOf:today};
 }
 function validDate(value){
  if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))return false;
  const day=new Date(value+'T12:00:00Z');return Number.isFinite(day.valueOf())&&day.toISOString().slice(0,10)===value;
 }
 function periodBounds(from,to,today){
  if(![from,to,today].every(validDate)||from<'2013-10-10'||to>today||from>to)return null;
  const months=[],day=new Date(from.slice(0,7)+'-01T12:00:00Z');
  while(day.toISOString().slice(0,7)<=to.slice(0,7)){months.push(day.toISOString().slice(0,7));day.setUTCMonth(day.getUTCMonth()+1);}
  return{from,to,months,partial:to===today};
 }
 function summarizePeriod(payload,range){
  if(!range||!payload||!Array.isArray(range.months)||!Array.isArray(payload.monthly_totals))return null;
  const integrity=payload.window_integrity||payload;
  if(integrity.from!==range.from||integrity.to!==range.to||payload.monthly_totals.length!==range.months.length)return null;
  const keys=['revenue','extraordinary','expenses','cash_after_extraordinary'],sums=Object.fromEntries(keys.map(k=>[k,0])),byMonth=new Map();
  for(const row of payload.monthly_totals){
   const month=String(row.month||'').slice(0,7);
   if(String(row.month)!==month+'-01'||!range.months.includes(month)||byMonth.has(month)||keys.some(k=>finite(row[k])===null))return null;
   const revenue=Number(row.revenue),extraordinary=Number(row.extraordinary),expenses=Number(row.expenses),result=Number(row.cash_after_extraordinary);
   if(Math.abs(revenue+extraordinary-expenses-result)>.021)return null;
   keys.forEach(k=>sums[k]+=Number(row[k]));byMonth.set(month,{month,revenue,extraordinary,entries:revenue+extraordinary,expenses,result});
  }
  const totals=payload.totals||{};
  if(keys.some(k=>finite(totals[k])===null||Math.abs(Number(totals[k])-sums[k])>.021))return null;
  const revenue=Number(totals.revenue),extraordinary=Number(totals.extraordinary),expenses=Number(totals.expenses),result=Number(totals.cash_after_extraordinary);
  if(Math.abs(revenue+extraordinary-expenses-result)>.021)return null;
  return{from:range.from,to:range.to,partial:range.partial,revenue,extraordinary,entries:revenue+extraordinary,expenses,result,months:range.months.map(m=>byMonth.get(m))};
 }

 function monthBounds(month,today){
  if(!validDate(today)||!/^\d{4}-\d{2}$/.test(month||''))return null;
  const start=month+'-01';if(!validDate(start))return null;
  const last=new Date(start+'T12:00:00Z');last.setUTCMonth(last.getUTCMonth()+1);last.setUTCDate(0);
  const range=forecastPeriodBounds(start<'2013-10-10'?'2013-10-10':start,last.toISOString().slice(0,10),today);
  return range?{...range,month}:null;
 }
 function forecastPeriodBounds(from,to,today){
  if(![from,to,today].every(validDate)||from<'2013-10-10'||from>to||to>(Number(today.slice(0,4))+5)+'-12-31')return null;
  if((Date.parse(to)-Date.parse(from))/86400000>12000)return null;
  const months=[],d=new Date(from.slice(0,7)+'-01T12:00:00Z');
  while(d.toISOString().slice(0,7)<=to.slice(0,7)){months.push(d.toISOString().slice(0,7));d.setUTCMonth(d.getUTCMonth()+1);}
  return{from,to,months,partial:from<=today&&to>=today};
 }
 function summarizeOverview(payload,range,today){
  if(!range||payload?.version!=='month-overview-v393'||payload.from!==range.from||payload.to!==range.to||payload.as_of!==today||typeof payload.complete!=='boolean'||typeof payload.cash_complete!=='boolean')return null;
  const cash=payload.cash,book=payload.competence;
  if(!cash||!book||!Array.isArray(cash.items)||!Array.isArray(cash.excluded)||!Array.isArray(cash.undated)||!Array.isArray(book.items)||!Array.isArray(payload.months))return null;
  if(cash.undated.length&&payload.cash_complete!==false)return null;
  const cents=x=>finite(x)===null?null:Math.round(Number(x)*100),number=x=>finite(x)===null?null:Number(x);
  const count=x=>Number.isSafeInteger(x)&&x>=0;
  const metrics=items=>{const m=items.reduce((m,r)=>{const n=number(r.signed_amount);m.entries+=Math.max(n,0);m.payments-=Math.min(n,0);m.result+=n;m.count++;return m;},{entries:0,payments:0,result:0,count:0});for(const k of['entries','payments','result'])m[k]=Math.round(m[k]*100);return m;};
  const matches=(m,n)=>m&&count(m.count)&&m.count===n.count&&['entries','payments','result'].every(k=>cents(m[k])===n[k])&&cents(m.entries)-cents(m.payments)===cents(m.result);
  const keys=new Set();
  for(const r of cash.items){
   if(!validDate(r.event_date)||r.event_date<range.from||r.event_date>range.to||cents(r.signed_amount)===null||!['Itaú','Bradesco','C6'].includes(r.account)||!r.source||!r.source_ref||!['realized','forecast','unconfirmed'].includes(r.cash_state))return null;
   if((r.cash_state==='forecast')!==(r.event_date>today))return null;
   if(r.internal_transfer===true||r.source==='internal_transfer'||r.is_asset_movement===true||r.asset_movement===true)return null;
   const key=JSON.stringify([r.source,r.source_ref,r.account,r.event_date]);if(keys.has(key))return null;keys.add(key);
  }
  for(const state of['realized','forecast','unconfirmed'])if(!matches(cash[state],metrics(cash.items.filter(r=>r.cash_state===state))))return null;
  if(!matches(cash.total,metrics(cash.items)))return null;
  if(!validDate(book.from)||!validDate(book.to)||book.from>range.from||book.to<range.to||!count(book.count)||book.count!==book.items.length||cents(book.total)===null||book.basis!=='competence_month'||book.payment_proven!==false)return null;
  const bookKeys=new Set();let sum=0,received=0,projected=0;
  for(const r of book.items){
   if(!r.row_key||bookKeys.has(r.row_key)||!validDate(r.event_date)||r.event_date<book.from||r.event_date>book.to||!validDate(r.competence_month)||r.competence_month!==r.event_date.slice(0,7)+'-01'||cents(r.amount)===null)return null;
   for(const value of[r.transaction_date,r.purchase_date])if(value!==null&&value!==undefined&&!validDate(value))return null;
   bookKeys.add(r.row_key);sum+=number(r.amount);if(r.coverage_mode==='card_installment_projected')projected+=number(r.amount);else received+=number(r.amount);
  }
  if(Math.round(sum*100)!==cents(book.total)||Math.round(received*100)!==cents(book.received_total)||Math.round(projected*100)!==cents(book.projected_total)||payload.months.length!==range.months.length)return null;
  const seen=new Set();
  for(const m of payload.months){const month=String(m.month||'').slice(0,7);if(m.month!==month+'-01'||!range.months.includes(month)||seen.has(month))return null;seen.add(month);
   if(!matches(m.cash,metrics(cash.items.filter(r=>r.event_date.slice(0,7)===month)))||cents(m.competence)!==Math.round(book.items.filter(r=>r.competence_month===m.month).reduce((n,r)=>n+number(r.amount),0)*100))return null;
  }
  return{...payload,month:range.month,partial:range.partial,entries:number(cash.total.entries),expenses:number(cash.total.payments),result:number(cash.total.result),
   sourceIncomplete:payload.cash_complete===false||payload.complete===false||payload.source_complete===false};
 }
 return Object.freeze({bounds,summarize,bankPositions,periodBounds,summarizePeriod,monthBounds,forecastPeriodBounds,summarizeOverview});
});

;
;
/* LTS V384: lts-v337-month-overview.js */
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
   return header+period+tabs+warning+choose+'<p class="v393-explanation"><b>'+labels[stage]+'</b>. Considera a data em que o dinheiro entra ou sai da conta. O resultado do período não é o saldo bancário.</p><div class="v337-metrics">'+metric('Receitas e outras entradas',m.entries,'income')+metric('Pagamentos e outras saídas',m.payments,'expense')+metric('Resultado em caixa',m.result,Number(m.result)<0?'negative':'result')+'</div>'+breakdown+undated+(x.cash.unconfirmed.count?'<p class="v393-warning">Há '+x.cash.unconfirmed.count+' lançamento(s) sem confirmação. Eles permanecem separados do realizado e entram apenas no total projetado.</p>':'')+'<button class="v168-btn primary" data-v393-detail="cash">Ver lançamentos de caixa ('+x.cash.items.length+')</button>'+monthRows+'<details class="v337-source"><summary>Como este total é calculado</summary><p>Movimentações de '+date(x.from)+' a '+date(x.to)+', com realização conferida até '+date(x.as_of)+'. Agendamentos e previsões não se tornam realizados porque a data chegou. As previsões consideram os lançamentos conhecidos e podem mudar.</p><p>Transferências entre contas próprias e disponibilidade de investimentos não são receitas ou despesas. Faturas aparecem como saída de caixa uma vez; suas compras ficam separadas na visão de competência.</p><p>'+x.cash.excluded.length+' registro(s) de transferências próprias, aplicações, retenções já descontadas do salário ou disponibilidade de recursos ficam fora destes totais.</p></details>';
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
   .v337-month [data-v393-detail]{display:inline-flex;align-items:center;justify-content:center;box-sizing:border-box;min-height:44px;max-width:100%;margin:10px 0;background:#183b60;border:1px solid #183b60;color:#fff;border-radius:9px;padding:10px 14px;font:600 12px/1.4 system-ui;white-space:normal;text-align:center;cursor:pointer}
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

;
;
/* LTS V384: lts-v365-homologation.js */
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
     if(cell&&!cell.querySelector('.v365-balance-status'))cell.insertAdjacentHTML('beforeend','<small class="v365-balance-status">Saldo a conferir</small>');
     row.querySelector('.exp')?.setAttribute('aria-label','Conferir a mudança de saldo em '+date(day.date));
    }
    let detail=row.nextElementSibling;
    if(EXP.has(day.date)&&(html||obligations.length)){
     if(!detail?.classList.contains('fx89-details'))continue;
     if(!detail.querySelector('.fx89-detail-row'))detail.querySelector('.mut')?.remove();
     detail.querySelectorAll('.v365-bridge').forEach(node=>node.remove());
     if(obligations.length&&!detail.querySelector('.v365-obligations')){
      const box=document.createElement('section');box.className='v365-obligations';
      box.innerHTML='<h3>Pagamentos a confirmar</h3>'+obligations.map((e,i)=>'<div class="v365-pair"><span>'+esc(e.description)+'<small>Vencimento '+esc(date(e.event_date))+' · '+esc(e.account)+'. Pagamento ainda não identificado.</small></span><b>'+money(Math.abs(Number(e.signed_amount)))+'</b><button class="v168-btn" data-v365-invoice="'+i+'">Abrir fatura</button></div>').join('');
      box.querySelectorAll('[data-v365-invoice]').forEach(b=>b.onclick=()=>openCardSettlement(obligations[Number(b.dataset.v365Invoice)]));detail.appendChild(box);
     }
    }else if(obligations.length&&!row.querySelector('.v365-balance-status'))row.firstElementChild.insertAdjacentHTML('beforeend','<small class="v365-balance-status">Pagamento a confirmar</small>');
   }
  }
  function fgtsPosition(j){
   const f=j.fgts_position||{},valid=f.version==='fgts-position-evidence-v386',dated=valid&&f.status==='dated_documentary_position'&&/^\d{4}-\d\d-\d\d$/.test(String(f.balance_as_of||''))&&amount(f.balance_brl)!==null;
   const fallback=amount(j.wealth?.liquidity?.fgts_contingency),balance=dated?amount(f.balance_brl):!valid&&fallback>0?fallback:null;
   const note=dated?'Posição em '+date(f.balance_as_of)+' · restrito':balance!==null?'Restrito · data da posição a confirmar':'Saldo atual a confirmar no extrato após saques e depósitos';
   let origin='';
   if(valid&&amount(f.last_documented_balance_brl)!==null&&f.last_documented_as_of)origin+=pair('Posição documentada',f.last_documented_balance_brl,'Em '+date(f.document_last_posting_date||f.last_documented_as_of));
   if(valid&&f.withdrawal?.confirmed===true)origin+=pair('Saque recebido',f.withdrawal.amount_brl,'Em '+date(f.withdrawal.date)+' · já incorporado ao caixa');
   return {balance,html:'<section data-v386-fgts>'+pair('FGTS',balance,note)+'<details class="v386-fgts-origin"><summary>Origem do FGTS</summary>'+origin+'<p>O saldo atual depende do extrato após o último saque e dos depósitos recebidos. Aportes previstos ficam separados. O saque já recebido não é somado novamente como ativo.</p></details></section>'};
  }
  function overview(root,j){
   const w=j.wealth||{},s=w.summary||{},p=j.pensions||{},r=j.rsu_summary||{},a=w.assets||{},l=w.liquidity||{},fgts=fgtsPosition(j);
   const known=amount(s.known_debt_total),gross=amount(j.wealth_v167?.assets_central_including_pensions);
   const current=[['CIPÓ 396',a.cipo_396?.market_central,'Valor de mercado estimado'],['Volvo XC40',a.volvo_xc40?.market_central,'Valor de mercado estimado'],['Contas correntes',l.bank_cash],['Aplicações D0',l.d0],['Ações e corretora disponíveis',r.available_total_brl,'Posição de '+date(r.as_of)],['Previdências',p.total_gross_brl,'Brutas e restritas']];
   const commitments=list(j.financing?.summary?.commitments),names={cipo_396:'CIPÓ 396',volvo:'Volvo XC40',coopharma:'Coopharma',pai_mae:'Pai e Mãe'};
   const debts=Object.entries(names).map(([id,label])=>{const c=commitments.find(x=>x.id===id)||{},balance=amount(c.current_documentary_debt_balance),dated=balance!==null&&!!c.current_debt_as_of;return {id,label,balance:dated?balance:null,note:dated?'Posição em '+date(c.current_debt_as_of):'Falta extrato com saldo devedor atual'};});
   const missing=debts.filter(d=>d.balance===null),complete=s.debt_total_complete===true&&!missing.length&&fgts.balance!==null;
   const pending=[...(missing.length?['saldos atuais de '+missing.map(d=>d.label).join(', ')]:[]),...(fgts.balance===null?['saldo atual do FGTS']:[])];
   const net=complete?kpi('Patrimônio líquido',j.wealth_v167?.net_worth_central_including_pensions,'Ativos menos passivos nas posições informadas'):'<article class="v168-kpi"><span>Patrimônio líquido</span><strong class="v386-incomplete-value">Em apuração</strong><small>'+esc(pending.length?'Faltam '+pending.join(' e '):'Posição patrimonial incompleta')+'</small></article>';
   const tabs=root.querySelector('.v168-tabs');let node=tabs?.nextSibling;while(node){const n=node.nextSibling;node.remove();node=n;}
   root.insertAdjacentHTML('beforeend','<div class="v168-kpis v365-wealth-totals">'+kpi('Patrimônio bruto conhecido',gross,fgts.balance===null?'Subtotal conhecido; FGTS atual a confirmar':'Ativos e previdências; valores de mercado estimados')+kpi('Dívidas com saldo informado',known,missing.length?'Parcial · '+(debts.length-missing.length)+' de '+debts.length+' saldos informados':'Posições nas datas informadas')+net+'</div>'+(!complete?'<p class="v365-material">Posição incompleta. '+esc(pending.length?'Faltam '+pending.join(' e ')+'.':'Confira as posições patrimoniais.')+' '+action()+'</p>':'')+'<div class="v365-columns"><article class="v168-card"><h2>Ativos atuais</h2>'+current.map(x=>pair(...x)).join('')+fgts.html+'</article><article class="v168-card"><h2>Dívidas</h2>'+debts.map(d=>'<div data-v386-debt="'+d.id+'">'+pair(d.label,d.balance,d.note)+'</div>').join('')+'</article></div><article class="v168-card"><h2>Valores a receber no futuro</h2>'+pair('RSUs futuras · bruto',r.future_regular_brl)+pair('Cash RSUs · após reserva projetada',r.future_cash_net_brl)+pair('Total considerado na agenda',r.future_considered_total_brl,'Fora do patrimônio disponível hoje')+'<details><summary>Base e datas</summary><p>Os valores futuros usam a agenda de vestings e as referências de mercado. A reserva fiscal é uma premissa. Retention Award e datas contratuais ficam em RSUs e awards.</p></details></article>');
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
   dated.innerHTML='<h2>Posição datada · '+esc(date(m.as_of||summary.as_of))+'</h2><div class="v168-kpis">'+kpi('Total bruto',m.gross_total_brl)+kpi('Disponível na posição datada',m.available_total_brl??summary.available_total_brl)+kpi('Indisponível bruto no extrato',m.unavailable_gross_brl)+kpi('Após reserva projetada no extrato',m.considered_total_after_reserve_brl,'Premissa de planejamento; não é saldo líquido de saque')+'</div><details><summary>Comparar extrato e agenda</summary>'+pair('Total futuro na agenda atual',summary.future_considered_total_brl)+pair('Total futuro após reserva no extrato',m.future_components?.future_after_reserve_brl)+'<p>As duas bases têm referências de preço, câmbio e datas diferentes. Não são somadas.</p></details>';
   if(primary)primary.after(dated);else root.appendChild(dated);
   // Earlier layers exposed several copies of these same comparisons.
   root.querySelectorAll('.v172-morgan,.v183-statement-remainders,.v172-morgan-components').forEach(x=>{const d=document.createElement('details');d.className='v365-morgan-archive';d.innerHTML='<summary>Detalhes da posição e composição</summary>';x.before(d);d.appendChild(x);});
   const agenda=[...root.querySelectorAll('article')].find(x=>x.querySelector('h2')?.textContent==='Vestings e disponibilidade'),help=agenda?.querySelector('.v170-reconciliation');
   if(help){const d=document.createElement('details');d.className='v365-agenda-basis';d.innerHTML='<summary>Base e conferência da agenda</summary>';help.before(d);d.appendChild(help);const notice=document.createElement('p');notice.className='v365-material';notice.textContent='Valores e disponibilidade projetados; permanecem separados da posição do extrato.';d.before(notice);}
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

;
;
/* LTS V384: lts-v366-recurring.js */
/* One confirmed recurrence policy covers future missing periods; variable values stay unresolved. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V366)return;const previous=render,ui=window.__LTS_V168_STATE;
  const st={owner:null,rules:null,loading:false,error:false,readAt:0,sequence:0};
  const generation=()=>typeof BOOT==='object'?BOOT.generation:D;
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const list=x=>Array.isArray(x)?x:[],norm=x=>String(x||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().toLowerCase();
  const day=x=>/^\d{4}-\d\d-\d\d$/.test(x||'')?x.split('-').reverse().join('/'):'A confirmar';
  const now=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const money=x=>x==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(x));
  function session(){if(st.owner!==generation()){st.owner=generation();st.sequence++;st.rules=null;st.loading=false;st.error=false;st.readAt=0;document.getElementById('v366RecurringDialog')?.close();}}
  async function load(force=false){
   session();if(st.loading||!D||N.classList.contains('hidden')||(!force&&Date.now()-st.readAt<300000))return;
   const owner=st.owner,seq=++st.sequence;st.loading=true;
   try{const r=await S.rpc('lts_browser_recurring_plans_v366',{});if(r.error||r.data?.ok!==true||!Array.isArray(r.data.rules))throw Error();if(owner!==generation()||seq!==st.sequence)return;st.rules=r.data.rules;st.error=false;st.readAt=Date.now();}
   catch{if(owner===generation()&&seq===st.sequence){st.error=true;st.readAt=Date.now();}}
   finally{if(owner===generation()&&seq===st.sequence){st.loading=false;if(V==='Atualizações')render();}}
  }
  async function open(item,existing){
   session();const owner=st.owner;
   document.getElementById('v366RecurringDialog')?.close();
   const today=now(),tomorrow=new Date(today+'T12:00:00Z');tomorrow.setUTCDate(tomorrow.getUTCDate()+1);
   const min=tomorrow.toISOString().slice(0,10),dialog=document.createElement('dialog');dialog.id='v366RecurringDialog';dialog.className='v366-dialog';
   const title=existing?.description||item?.description||item?.title||'',direction=existing?.direction||(item?.direction==='income'?'entrada':'saida');
   const candidate=existing||st.rules?.find(r=>norm(r.description)===norm(title)&&r.direction===direction),rule=candidate||null;
   const initialDate=rule?.starts_on&&rule.starts_on>today?rule.starts_on:min;
   dialog.innerHTML='<header><h2>Continuidade da recorrência</h2><button class="v168-btn" type="button" data-close>Fechar</button></header><p><b>'+esc(title)+'</b></p><p class="v366-ref">Último realizado: '+esc(day(item?.historical_last_date))+' · Referência histórica '+money(item?.observed_median_amount_brl)+'. A referência não será aplicada automaticamente.</p><form><div class="v366-fields"><label class="wide">Descrição<input name="description" maxlength="180" required value="'+esc(title)+'"></label><label>Tipo<select name="direction"><option value="saida" '+(direction==='saida'?'selected':'')+'>Despesa</option><option value="entrada" '+(direction==='entrada'?'selected':'')+'>Receita</option></select></label><label>Conta<select name="account" required><option value="">Escolha…</option>'+['Itaú','Bradesco','C6'].map(x=>'<option'+(rule?.account===x?' selected':'')+'>'+x+'</option>').join('')+'</select></label><label>Valores<select name="value_kind"><option value="variable" '+(rule?.value_kind!=='fixed'?'selected':'')+'>Variáveis · sem valor automático</option><option value="fixed" '+(rule?.value_kind==='fixed'?'selected':'')+'>Fixos · valor confirmado</option></select></label><label>Valor fixo em reais<input name="amount" type="number" min="0.01" max="100000000" step="0.01" inputmode="decimal" value="'+esc(rule?.amount??'')+'"></label><label>Frequência<select name="cadence_months"><option value="1" '+(rule?.cadence_months!==12?'selected':'')+'>Mensal</option><option value="12" '+(rule?.cadence_months===12?'selected':'')+'>Anual</option></select></label><label>Dia do vencimento<input name="due_day" type="number" min="1" max="31" required value="'+esc(rule?.due_day??'')+'"></label><label>Primeiro período a manter<input name="starts_on" type="date" min="'+min+'" required value="'+esc(initialDate)+'"></label><label>Última data válida<input name="ends_on" type="date" min="'+min+'" value="'+esc(rule?.ends_on&&rule.ends_on>=min?rule.ends_on:'')+'"></label><label class="wide v366-check"><input name="open_ended" type="checkbox" '+(rule&&!rule.ends_on?'checked':'')+'> Continuar enquanto estiver ativa, sem data final</label><label class="wide">Classificação<select name="category"><option value="">Selecione uma classificação existente…</option></select></label><label class="wide v366-check"><input name="active" type="checkbox" '+(rule?.active===false?'':'checked')+'> Série ativa</label></div><p class="v366-policy">A continuidade cobre os meses futuros sem ocorrência já registrada até o fim de '+(Number(today.slice(0,4))+4)+'. Meses com 28, 29 ou 30 dias usam seu último dia quando necessário. Cancelamentos existentes são preservados. Valores variáveis continuam sem previsão automática.</p><p class="v366-policy">Faturas, salário, bônus e tributos exigem valores por competência. Não aplicamos um valor fixo a essas séries.</p><footer><p role="status" aria-live="polite"></p><button class="v168-btn primary" type="submit">Salvar continuidade</button></footer></form>';
   document.body.appendChild(dialog);dialog.showModal();let busy=false;const form=dialog.querySelector('form'),f=form.elements,save=form.querySelector('[type=submit]'),status=form.querySelector('[role=status]');
   const change=()=>{f.amount.disabled=f.value_kind.value!=='fixed';f.amount.required=f.value_kind.value==='fixed';f.ends_on.disabled=f.open_ended.checked;f.ends_on.required=!f.open_ended.checked;};f.value_kind.onchange=f.open_ended.onchange=change;change();
   dialog.querySelector('[data-close]').onclick=()=>{if(!busy)dialog.close();};dialog.addEventListener('cancel',e=>{if(busy)e.preventDefault();});dialog.addEventListener('close',()=>dialog.remove());
   try{const data=await window.LTSCategoryRegistry.get();if(owner!==generation()||!dialog.isConnected)return;f.category.innerHTML='<option value="">Selecione…</option>'+data.categories.map(c=>'<option value="'+esc(c)+'"'+(rule?.category===c?' selected':'')+'>'+esc(window.LTSCategoryDisplay.category(c))+'</option>').join('');}catch{status.textContent='As classificações não foram carregadas. Feche e tente novamente.';save.disabled=true;return;}
   form.onsubmit=async e=>{
    e.preventDefault();if(busy||owner!==generation()||!form.reportValidity())return;
    busy=true;save.disabled=true;status.textContent='Salvando a regra e conferindo os períodos…';
    const input={description:f.description.value.trim(),direction:f.direction.value,account:f.account.value,value_kind:f.value_kind.value,amount:f.value_kind.value==='fixed'?Number(f.amount.value):null,cadence_months:Number(f.cadence_months.value),due_day:Number(f.due_day.value),starts_on:f.starts_on.value,ends_on:f.open_ended.checked?null:f.ends_on.value,category:f.category.value||null,active:f.active.checked};
    try{
     const r=await S.rpc('lts_browser_recurring_plan_save_v366',{p_expected_revision:rule?.revision||0,p_input:input});if(r.error||r.data?.ok!==true)throw Error();if(owner!==generation())return;
     status.textContent=input.value_kind==='variable'?'Continuidade registrada. Valores variáveis ainda precisam de previsão por período.':input.active?'Continuidade salva. '+Number(r.data.created||0)+' previsão(ões) adicionada(s); ocorrências já existentes foram preservadas.':'Continuidade encerrada a partir de '+day(input.starts_on)+'. Histórico preservado.';
     ui.updates.recurring=null;ui.updates.error=null;ui.dashboard.started=false;window.__LTS_V227_TRANSPORT?.invalidate?.();st.readAt=0;await load(true);save.textContent='Salvo';save.disabled=true;
    }catch{status.textContent='Não foi possível confirmar a gravação. Reabra a série para conferir a situação antes de tentar novamente.';save.disabled=false;}
    finally{busy=false;}
   };
  }
  function paint(){
   session();if(V!=='Atualizações')return;const root=document.querySelector('.v168-updates');if(!root)return;
   const checks=list(ui.updates?.recurring?.horizon_checks);
   for(const button of root.querySelectorAll('[data-v168-action]')){const row=button.closest('.v168-action'),title=row?.querySelector('b')?.textContent,x=checks.find(x=>(x.title||x.description)===title);if(x){button.textContent='Revisar continuidade';button.onclick=()=>open(x);}}
   for(const row of root.querySelectorAll('[data-coverage-key]')){const x=checks.find(x=>x.key===row.dataset.coverageKey);if(!x||row.querySelector('[data-v366-rule]'))continue;const b=document.createElement('button');b.className='v168-btn';b.type='button';b.dataset.v366Rule='true';b.textContent='Continuidade da série';b.onclick=()=>open(x);row.appendChild(b);}
   let card=root.querySelector('#v366Rules');if(!card){card=document.createElement('article');card.id='v366Rules';card.className='v168-card';root.appendChild(card);}
   card.innerHTML='<h2>Continuidade configurada</h2>'+(st.error?'<p role="status">Não foi possível consultar as regras. <button class="v168-btn" data-retry>Tentar novamente</button></p>':st.rules===null?'<p role="status">Consultando séries…</p>':st.rules.length?st.rules.map((r,i)=>'<div class="v365-pair"><span>'+esc(r.description)+'<small>'+esc(r.account)+' · '+(r.active?'Ativa':'Encerrada')+' · '+(r.value_kind==='fixed'?money(r.amount):'Valor variável')+(r.ends_on?' · até '+day(r.ends_on):' · sem data final')+'</small></span><button class="v168-btn" data-rule="'+i+'">Revisar</button></div>').join(''):'<p>Nenhuma continuidade configurada. Revise uma série acima para confirmar frequência, valor e vigência de uma vez.</p>');
   card.querySelector('[data-retry]')?.addEventListener('click',()=>load(true));card.querySelectorAll('[data-rule]').forEach(b=>b.onclick=()=>open(null,st.rules[Number(b.dataset.rule)]));queueMicrotask(()=>load());
  }
  const css=document.createElement('style');css.textContent='.v366-dialog{box-sizing:border-box;width:min(620px,calc(100vw - 24px));max-height:90dvh;overflow:auto;border:1px solid #d6dfe8;border-radius:16px;padding:20px;color:#243c52;background:#fff}.v366-dialog::backdrop{background:#14253599}.v366-dialog header{display:flex;align-items:start;justify-content:space-between;gap:12px}.v366-dialog h2{font-size:20px;margin:0}.v366-fields{display:grid;grid-template-columns:1fr 1fr;gap:14px}.v366-fields label{font-size:13px}.v366-fields input:not([type=checkbox]),.v366-fields select{box-sizing:border-box;width:100%;min-height:44px;margin-top:6px;padding:9px;border:1px solid #c7d2dd;border-radius:8px;background:#fff;color:#243c52}.v366-fields .wide{grid-column:1/-1}.v366-check{display:flex;align-items:center;gap:8px}.v366-policy,.v366-ref{font-size:12px;line-height:1.5;color:#526174}.v366-dialog footer{position:sticky;bottom:-20px;background:white;border-top:1px solid #dbe3eb;margin-top:16px;padding:12px 0 4px}.v366-dialog footer button{width:100%;min-height:44px}.v366-dialog [role=status]{font-size:13px;line-height:1.5}@media(max-width:500px){.v366-fields{grid-template-columns:1fr}.v366-dialog{padding:16px}.v366-dialog footer{bottom:-16px}}';document.head.appendChild(css);
  render=function(){const result=previous.apply(this,arguments);paint();return result;};window.__LTS_V366={installed:true,state:st,open,refresh:()=>load(true)};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365)return false;if(!w.__LTS_V366){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V366;}catch{return false;}}
 let attempts=0;function start(){if(!install()&&++attempts<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{attempts=0;start();});start();window.LTSV339Boot?.watch('lts-v366-recurring.js',install);
})();

;
;
/* LTS V384: lts-v382-flow-layout.js */
/* Presentation only: retain the existing Flow inputs, handlers and financial readers. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V382_FLOW_LAYOUT)return;
  const previous=render;
  let expanded=false,toolsExpanded=false;
  const day=value=>/^\d{4}-\d{2}-\d{2}$/.test(String(value||''))?value.split('-').reverse().join('/'):'Selecione as datas';
  function label(text,node){
   const wrapper=document.createElement('label');wrapper.className='v382-field';
   const caption=document.createElement('span');caption.textContent=text;wrapper.append(caption,node);return wrapper;
  }
  function bindPeriodActions(root){
   root.querySelectorAll('[data-p],#flowDefaultRange,#flowApply,#goToday').forEach(button=>{
    const handler=button.onclick;if(typeof handler!=='function'||handler.__v382ExplicitPeriod)return;
    function explicitPeriod(event){
     const status=window.__LTS_V382_FLOW_LAYOUT,prior=status.explicit_period_action;
     status.explicit_period_action=true;
     try{return handler.call(this,event);}finally{status.explicit_period_action=prior;}
    }
    explicitPeriod.__v382ExplicitPeriod=true;button.onclick=explicitPeriod;
   });
  }
  function decorate(){
   if(V!=='Fluxo Diário')return;
   const root=document.querySelector('.flow-sticky-controls');if(!root)return;
   bindPeriodActions(root);
   const existing=root.querySelector('.v382-period');
   if(existing){
    existing.querySelector('.v382-period-range').textContent=day(FLOWFROM)+' – '+day(FLOWTO);return;
   }
   const from=document.getElementById('flowFrom'),to=document.getElementById('flowTo'),year=document.getElementById('flowYear');
   const bank=root.querySelector('[data-a]')?.closest('.chips'),host=from?.closest('.chips');
   if(!from||!to||!year||!bank||!host||bank===host)return;
   root.classList.add('v382-flow-controls');bank.classList.add('v382-banks');
   const heading=root.querySelector(':scope>.flowbar'),toolbar=heading?.querySelector('.chips');
   if(toolbar){
    heading.classList.add('v382-flow-heading');
    const tools=document.createElement('details');tools.className='v382-tools';tools.open=toolsExpanded;
    const menu=document.createElement('summary');menu.textContent='Opções';
    const panel=document.createElement('div');panel.className='v382-tool-body';panel.appendChild(toolbar);tools.append(menu,panel);heading.appendChild(tools);
    tools.addEventListener('toggle',()=>{if(tools.isConnected)toolsExpanded=tools.open;});
   }
   bank.setAttribute('role','group');bank.setAttribute('aria-label','Contas do Fluxo');
   bank.querySelectorAll('[data-a]').forEach(button=>button.setAttribute('aria-pressed',String(button.classList.contains('active'))));
   const details=document.createElement('details');details.className='v382-period';details.open=expanded;
   const summary=document.createElement('summary'),title=document.createElement('span'),range=document.createElement('span');
   title.className='v382-period-title';title.textContent='Período';range.className='v382-period-range';range.textContent=day(FLOWFROM)+' – '+day(FLOWTO);
   summary.append(title,range);details.appendChild(summary);
   const body=document.createElement('div');body.className='v382-period-body';
   const presets=document.createElement('div');presets.className='v382-presets';presets.setAttribute('role','group');presets.setAttribute('aria-label','Períodos rápidos');
   host.querySelectorAll('[data-p],#flowDefaultRange').forEach(button=>presets.appendChild(button));body.appendChild(presets);
   year.setAttribute('aria-label','Ano do período do Fluxo');body.appendChild(label('Histórico por ano',year));
   const dates=document.createElement('div');dates.className='v382-dates';
   from.setAttribute('aria-label','Data inicial do Fluxo');to.setAttribute('aria-label','Data final do Fluxo');
   dates.append(label('De',from),label('Até',to));body.appendChild(dates);
   const actions=document.createElement('div');actions.className='v382-period-actions';
   for(const id of ['flowApply','flowZero']){const node=document.getElementById(id);if(node)actions.appendChild(node);}
   body.appendChild(actions);
   // Preserve any future controls or meaningful notices added to the legacy host.
   for(const node of [...host.childNodes]){
    if(node.nodeType===3&&!node.textContent.trim())continue;
    if(node.nodeType===1&&node.matches('span.pill')&&node.textContent.includes('Histórico completo:'))continue;
    body.appendChild(node);
   }
   details.appendChild(body);bank.after(details);host.remove();
   details.addEventListener('toggle',()=>{if(details.isConnected)expanded=details.open;});
  }
  render=function(){
   const details=document.querySelector('.v382-period');
   const tools=document.querySelector('.v382-tools');if(tools)toolsExpanded=tools.open;
   if(details)expanded=details.open;
   else if(V!=='Fluxo Diário')expanded=false;
   const result=previous.apply(this,arguments);decorate();return result;
  };
  window.__LTS_V382_FLOW_LAYOUT={installed:true,presentation_only:false,explicit_period_action:false,financial_readers_preserved:true,control_guard_only:true};decorate();
 }
 function install(){
  try{
   const w=shell?.contentWindow,d=shell?.contentDocument;
   if(!w?.__LTS_V365?.installed||!w?.__LTS_V183_FLOW_PERIOD_STATE?.installed||!w?.__LTS_V290_USABILITY?.installed)return false;
   if(w.__LTS_V382_FLOW_LAYOUT)return true;
   const link=d.createElement('link');link.rel='stylesheet';link.href=new URL('lts-v382-flow-layout.css',location.href).href;d.head.appendChild(link);
   const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.appendChild(script);
   return !!w.__LTS_V382_FLOW_LAYOUT;
  }catch{return false;}
 }
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}
 shell?.addEventListener('load',()=>{tries=0;start();});start();
 window.LTSV339Boot?.watch('lts-v382-flow-layout.js',install);
})();

;

;
/* screen-modules.js */
/* lts-v398-family-loan.js */
/* Family debt: balance, correction and planning are separate visible concepts. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,state=window.__LTS_V168_STATE;
  const amount=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?null:Number(v);
  const money=v=>amount(v)===null?'A confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||''))?v.split('-').reverse().join('/'):'a confirmar';
  function line(label,value){const row=document.createElement('div'),name=document.createElement('span'),number=document.createElement('b');row.className='v365-pair';name.textContent=label;number.textContent=money(value);row.append(name,number);return row;}
  function paragraph(text){const p=document.createElement('p');p.textContent=text;return p;}
  function after(){
   if(V==='Atualizações'){
    const task=document.querySelector('#v365WealthTasks>p');if(task)task.textContent='Consulte os saldos e documentos pendentes em Patrimônio.';
   }
   if(V!=='Patrimônio'||state.wealth?.tab!=='overview')return;
   const j=state.wealth?.data,c=j?.financing?.summary?.commitments?.find(x=>x.id==='pai_mae'),p=c?.indexation;
   const root=document.querySelector('.v168-wealth');if(!root||!p||root.querySelector('[data-v398-family]'))return;
   const debt=root.querySelector('[data-v386-debt="pai_mae"] .v365-pair');
   if(debt){let small=debt.querySelector('small');if(!small){small=document.createElement('small');debt.querySelector('span')?.append(small);}small.textContent=p.complete?'Corrigido pela poupança · sem vencimento definido':'Correção a atualizar · sem vencimento definido';}
   const card=document.createElement('article');card.className='v168-card v398-family';card.dataset.v398Family='';
   const title=document.createElement('h2');title.textContent='Empréstimo Pai e Mãe';card.append(title);
   card.append(paragraph('Sem vencimento definido · correção pela poupança'));
   card.append(line('Valor original',p.original_principal_brl),line('Correção acumulada',p.accrued_savings_brl));
   if(amount(p.confirmed_repayments_brl)>0)card.append(line('Pagamentos confirmados',p.confirmed_repayments_brl));
   card.append(line('Saldo devedor',p.balance_brl));
   card.append(paragraph(p.complete?'Correção até '+date(p.corrected_through)+'. O saldo diminui quando um pagamento é confirmado.':'Falta atualizar o índice da poupança para apresentar o saldo corrigido.'));
   const plan=document.createElement('details'),summary=document.createElement('summary');summary.textContent='Planejamento de pagamentos';plan.append(summary);
   plan.append(paragraph(String(c.remaining_events??0)+' parcelas estimadas no fluxo. As datas são uma previsão de planejamento.'));
   if(c.planned_next_payment_date)plan.append(line('Próxima previsão · '+date(c.planned_next_payment_date),c.planned_next_payment_amount));
   plan.append(line('Total previsto no fluxo',c.remaining_scheduled_outflow));
   plan.append(paragraph('As previsões não reduzem o saldo devedor e não são somadas novamente à dívida.'));card.append(plan);
   const origin=document.createElement('details'),originTitle=document.createElement('summary');originTitle.textContent='Origem e atualização';origin.append(originTitle);
   origin.append(paragraph('Valor original e início em '+date(p.starts_on)+' registrados na planilha original e confirmados com você. Correção pelos índices da poupança publicados pelo Banco Central, a cada aniversário mensal completo.'));
   card.append(origin);root.querySelector('.v365-columns')?.after(card);
  }
  const style=document.createElement('style');style.textContent='.v398-family{margin-top:16px}.v398-family p{color:#64748b;font-size:13px;line-height:1.5}.v398-family details{margin-top:12px}.v398-family summary{cursor:pointer;font-size:13px;font-weight:600}.v398-family .v365-pair>span{min-width:0}.v398-family .v365-pair>b{white-space:nowrap}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};
  window.__LTS_V398_FAMILY={installed:true,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V398_FAMILY?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V398_FAMILY?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v398-family-loan.js',install);
})();

;
/* lts-v402-d01-composition.js */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render;let selected='';
  const money=v=>v===null||v===undefined?'A confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const date=v=>/^\d{4}-\d\d-\d\d$/.test(String(v||''))?v.split('-').reverse().join('/'):'a confirmar';
  function time(v){if(!v||Number.isNaN(new Date(v).getTime()))return '';return new Intl.DateTimeFormat('pt-BR',{dateStyle:'short',timeStyle:'short',timeZone:'America/Sao_Paulo'}).format(new Date(v));}
  function pair(root,label,amount){const row=document.createElement('div'),span=document.createElement('span'),b=document.createElement('b');row.className='v402-d01-pair';span.textContent=label;b.textContent=money(amount);row.append(span,b);root.append(row);}
  function after(){
   if(V!=='Fluxo Diário'||ACC!=='Consolidado'||typeof FLOWQ==='undefined')return;
   const controls=document.querySelector('.flow-sticky-controls');if(!controls||document.getElementById('v402-d01-origin'))return;
   const days=[...(FLOWQ?.historical?.days||[]),...(FLOWQ?.current_future?.days||[])].filter(d=>d.fix86_columns?.d0_composition?.has_anchor);
   if(!days.length)return;
   if(!days.some(d=>d.date===selected))selected=days[0].date;
   const box=document.createElement('details'),summary=document.createElement('summary'),select=document.createElement('select'),body=document.createElement('div');
   box.id='v402-d01-origin';summary.textContent='D0/D1 · composição';box.append(summary);
   const label=document.createElement('label');label.textContent='Data ';select.setAttribute('aria-label','Data da composição D0/D1');
   for(const d of days){const o=document.createElement('option');o.value=d.date;o.textContent=date(d.date);select.append(o);}select.value=selected;label.append(select);box.append(label,body);
   function show(){selected=select.value;body.replaceChildren();const d=days.find(x=>x.date===selected),p=d.fix86_columns.d0_composition;
    for(const c of p.components||[])pair(body,'Saldo líquido · '+c.code,c.net_brl);
    pair(body,'Posição do Itaú · '+date(p.snapshot_date),p.snapshot_brl);
    for(const m of p.recorded_movements||[])pair(body,(m.asset_delta_brl<0?'Resgate':'Aplicação')+' · '+date(m.event_date),m.asset_delta_brl);
    for(const x of p.bank_redemptions||[])if(!x.represented_by_recorded_movement&&!x.representation_conflict)pair(body,'Resgate · '+date(x.event_date),-Number(x.bank_amount_brl));
    pair(body,'Cofrinho disponível',p.available_brl);pair(body,'Saldo em conta',d.fix86_columns.saldo_final);pair(body,'Saldo com D0/D1',d.fix86_columns.saldo_apos_d0_1);
    const consulted=time(p.source_observed_at);if(consulted){const line=document.createElement('p');line.textContent='Consultado em '+consulted+'.';body.append(line);}
    const note=document.createElement('p');note.textContent=p.complete?'Ações e FGTS são apresentados separadamente.':'Saldo do Cofrinho a conferir no banco.';body.append(note);
   }
   select.addEventListener('change',show);show();controls.after(box);
   const today=days.find(d=>d.date===new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo'}).format(new Date()));
   const current=today?.fix86_columns?.d0_composition;
   if(current&&(current.complete===false||current.provider_comparison_equal===false||current.daily_provider_position_available===false)){
    const warning=document.createElement('p');warning.id='v402-d01-warning';warning.setAttribute('role','status');warning.textContent=current.complete!==false&&current.daily_provider_position_available===false?'Atualização do saldo do Cofrinho pendente.':'Saldo do Cofrinho a conferir no banco.';box.before(warning);
   }
  }
  const style=document.createElement('style');style.textContent='#v402-d01-origin{margin:8px 0 12px;padding:8px 12px;border:1px solid #dce4ed;border-radius:10px;font-size:13px}#v402-d01-origin summary{cursor:pointer;font-weight:600}#v402-d01-origin label{display:block;margin:10px 0}#v402-d01-origin select{font-size:16px;min-height:44px;max-width:100%}.v402-d01-pair{display:flex;justify-content:space-between;gap:10px;padding:5px 0}.v402-d01-pair span{min-width:0;overflow-wrap:anywhere}.v402-d01-pair b{white-space:nowrap}#v402-d01-origin p{color:#64748b;line-height:1.45;margin:8px 0 2px}#v402-d01-warning{color:#8b4b08;font-size:13px;line-height:1.4;margin:8px 0}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};
  window.__LTS_V402_D01={installed:true,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V402_D01?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V402_D01?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v402-d01-composition.js',install);
})();

;
/* lts-v407-wealth-summary.js */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,ids=['cipo_396','volvo','coopharma','pai_mae'];
  const money=value=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value);
  function cents(value){
   if(value===null||value===undefined||!['string','number'].includes(typeof value)||!/^[-]?\d+(?:\.\d{1,2}0*)?$/.test(String(value)))return null;
   const n=Number(value),c=Math.round(n*100);return Number.isFinite(n)&&Number.isSafeInteger(c)?c:null;
  }
  function validDate(value){return typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value;}
  function assess(j){
   const gross=cents(j?.wealth_v167?.assets_central_including_pensions),known=cents(j?.wealth?.summary?.known_debt_total),commitments=j?.financing?.summary?.commitments,sourceDate=j?.financing?.summary?.as_of,asOf=validDate(sourceDate)?sourceDate:j?.as_of;
   if(gross===null||known===null||known<0||!validDate(asOf)||!Array.isArray(commitments))return {available:false};
   let documented=0,total=0;const missing=[];
   for(const id of ids){
    const rows=commitments.filter(c=>c?.id===id);if(rows.length>1)return {available:false};
    const c=rows[0],value=cents(c?.current_documentary_debt_balance);
    if(value!==null&&value>=0&&validDate(c?.current_debt_as_of)&&c.current_debt_as_of<=asOf){documented++;total+=value;}else missing.push(id);
   }
   const net=gross-known;
   if(!documented||!Number.isSafeInteger(total)||total!==known||!Number.isSafeInteger(net))return {available:false};
   return {available:true,gross:gross/100,known:known/100,net:net/100,documented,missing};
  }
  function pair(root,label,value){const row=document.createElement('div'),name=document.createElement('span'),amount=document.createElement('b');row.className='v407-wealth-pair';name.textContent=label;amount.textContent=money(value);row.append(name,amount);root.append(row);}
  function after(){
   if(V!=='Patrimônio'||window.__LTS_V168_STATE?.wealth?.tab!=='overview')return;
   const card=document.querySelector('.v365-wealth-totals .v386-incomplete-value')?.closest('article');if(!card||card.dataset.v407Partial==='true')return;
   const result=assess(window.__LTS_V168_STATE.wealth.data);if(!result.available)return;
   card.dataset.v407Partial='true';card.querySelector('span').textContent='Patrimônio líquido parcial';
   const value=card.querySelector('strong');value.classList.remove('v386-incomplete-value');value.textContent=money(result.net);
   card.querySelector('small').textContent='Estimativa com os saldos disponíveis. Há dívida a atualizar.';
   const detail=document.createElement('details'),summary=document.createElement('summary');detail.className='v407-wealth-basis';summary.textContent='Composição do subtotal';detail.append(summary);
   pair(detail,'Patrimônio bruto conhecido',result.gross);pair(detail,'Dívidas com saldo informado',result.known);pair(detail,'Patrimônio líquido parcial',result.net);card.append(detail);
  }
  const style=document.createElement('style');style.textContent='[data-v407-partial] strong{white-space:nowrap}.v407-wealth-basis{margin-top:10px;font-size:12px;font-weight:400}.v407-wealth-basis>summary{cursor:pointer;min-height:24px;line-height:1.5;color:#536174}.v407-wealth-pair{display:flex;flex-wrap:wrap;justify-content:space-between;gap:3px 8px;margin-top:7px}.v407-wealth-pair>span{font-size:12px!important;color:#536174}.v407-wealth-pair>b{white-space:nowrap;font-size:12px}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);after();return result;};window.__LTS_V407_WEALTH={installed:true,assess,after};after();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V407_WEALTH?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V407_WEALTH?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v407-wealth-summary.js',install);
})();

;
/* lts-v407-document-review.js */
/* Recover document visibility without approving or posting financial records. */
(function(){
 'use strict';const shell=document.getElementById('shell');
 function runtime(){
  const prior=render,attempts=new Map(),objectURLs=new Set();
  // The embedded client implements Auth/RPC only. Complete only the private-document
  // operations it already exposes in the UI, using the existing session and server checks.
  async function documentRequest(endpoint,{method='GET',body,headers={},binary=false}={}){
   const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),method==='POST'?120000:30000);
   try{
    const {data,error}=await S.auth.getSession(),session=data?.session;if(error||!session?.access_token)throw Error('Sessão expirada. Entre novamente.');
    const response=await fetch(U+endpoint,{method,body,headers:{apikey:K,Authorization:'Bearer '+session.access_token,...headers},signal:controller.signal});
    if(!response.ok)throw Error(response.status===401||response.status===403?'Sessão sem acesso ao documento. Entre novamente.':'Não foi possível concluir a consulta do documento.');
    return {data:binary?await response.blob():await response.json(),error:null};
   }catch(error){return {data:null,error:{message:error?.message||'Não foi possível concluir a consulta do documento.'}};}
   finally{clearTimeout(timer);}
  }
  if(typeof S.auth.getUser!=='function')S.auth.getUser=async()=>{const result=await documentRequest('/auth/v1/user');return result.error?{data:{user:null},error:result.error}:{data:{user:result.data},error:null};};
  if(!S.storage?.from)S.storage={from(bucket){
   function target(path){const parts=String(path||'').split('/');if(bucket!=='lts-documents'||parts.length<2||parts.some(p=>!p||p==='.'||p==='..'||p.includes('\\')))throw Error('Caminho de documento inválido.');return encodeURIComponent(bucket)+'/'+parts.map(encodeURIComponent).join('/');}
   return {
    async upload(path,file,options={}){try{if(options.upsert===true)throw Error('Substituição de documento não permitida.');return await documentRequest('/storage/v1/object/'+target(path),{method:'POST',body:file,headers:{'Content-Type':options.contentType||file.type||'application/octet-stream','x-upsert':'false'}});}catch(error){return {data:null,error:{message:error.message}};}},
    async download(path){try{return await documentRequest('/storage/v1/object/authenticated/'+target(path),{binary:true});}catch(error){return {data:null,error:{message:error.message}};}}
   };
  }};
  const state={open:false,status:'idle',data:null,error:'',promise:null,generation:0};
  let uploadForm = null;
  let documentPanel = null;
  const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
  const date=v=>{const s=String(v||'').slice(0,10);return /^\d{4}-\d\d-\d\d$/.test(s)?s.split('-').reverse().join('/'):'Data a confirmar';};
  const money=v=>v===null||v===undefined||v===''||!Number.isFinite(Number(v))?'Valor a confirmar':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v));
  const phase={received:'Recebido',interpreted:'Leitura disponível',reconciled:'Conciliado',needs_decision:'Revisão pendente',resolved:'Concluído'};
  function confirmed(attempt,id){attempt.confirmed=true;attempt.inboxId=id;attempt.input.disabled=false;attempt.input.value='';attempt.button.disabled=false;attempt.button.textContent='Enviar para revisão';attempt.message.textContent='Arquivo recebido para revisão. Consulte Documentos enviados.';}
  function pair(root,label,value){if(value===undefined||value===null||value==='')return;const row=el('p',undefined,'v407-doc-pair');row.append(el('span',label),el('strong',String(value)));root.append(row);}
  function releaseURLs(){for(const u of objectURLs)URL.revokeObjectURL(u);objectURLs.clear();}
  function reset(){
   state.generation++;state.open=false;state.status='idle';state.data=null;state.error='';state.promise=null;
   attempts.clear();releaseURLs();uploadForm?.remove();uploadForm=null;
   if(documentPanel)documentPanel.open=false;
   paint();
   documentPanel=null;
  }
  async function refresh(){
   if(state.promise)return state.promise;
   const generation=state.generation;state.status='loading';state.error='';paint();
   state.promise=(async()=>{try{
    const {data,error}=await S.rpc('lts_browser_document_review_queue_v1',{p_limit:6});
    if(generation!==state.generation)return;
    if(error||data?.contract!=='v149-evidence-review-readonly-canonical-v1'||data.write_allowed!==false||data.financial_writer_called!==false||!Array.isArray(data.items)||!Number.isSafeInteger(data.queue_documents)||data.queue_documents<data.items.length)throw Error('unavailable');
    state.data=data;state.status='ready';
   }catch{if(generation===state.generation){state.status='error';state.error='Não foi possível atualizar os documentos. Tente consultar novamente.';}}
   finally{if(generation===state.generation){state.promise=null;paint();}}})();return state.promise;
  }
  async function showFile(item,button,box){
   const previousURL=box.querySelector('a[download]')?.href;
   if(previousURL&&objectURLs.delete(previousURL))URL.revokeObjectURL(previousURL);
   const generation=state.generation;button.disabled=true;box.replaceChildren(el('p','Abrindo arquivo…'));
   try{
    const {data:meta,error}=await S.rpc('lts_browser_document_meta_v1',{p_inbox_id:item.inbox_id});
    if(generation!==state.generation)return;
    if(error||meta?.ok!==true||typeof meta.storage_path!=='string')throw Error('unavailable');
    for(const attempt of attempts.values())if(attempt.path===meta.storage_path)confirmed(attempt,item.inbox_id);
    const {data:blob,error:downloadError}=await S.storage.from('lts-documents').download(meta.storage_path);
    if(generation!==state.generation||!box.isConnected)return;
    if(downloadError||!(blob instanceof Blob))throw Error('unavailable');
    const url=URL.createObjectURL(blob);objectURLs.add(url);box.replaceChildren();
    const link=el('a','Baixar arquivo');link.href=url;link.download=String(meta.original_name||item.original_name||'documento');link.className='v168-btn';box.append(link);
    // Raster previews stay inert; SVG/HTML and other formats are downloads only.
    if(/^image\/(png|jpeg|gif|webp|bmp)$/i.test(String(meta.mime_type||''))){const image=el('img');image.src=url;image.alt=String(item.original_name||'Documento enviado');box.append(image);}
   }catch{box.replaceChildren(el('p','Não foi possível abrir o arquivo. Consulte novamente antes de reenviar.'));}
   finally{button.disabled=false;}
  }
  function paint(){
   const host=document.getElementById('v407DocumentsBody');if(!host)return;
   releaseURLs();host.replaceChildren();
   const tools=el('div',undefined,'v407-doc-tools'),button=el('button',state.status==='loading'?'Consultando…':'Atualizar documentos','v168-btn');button.type='button';button.disabled=state.status==='loading';button.onclick=refresh;tools.append(button);host.append(tools);
   if(state.error){const warning=el('p',state.error);warning.setAttribute('role','status');host.append(warning);}
   const data=state.data;if(!data){if(state.status!=='error')host.append(el('p','Consulte os documentos enviados para conferir os arquivos e as informações disponíveis.'));return;}
   const items=data.items;
   if(!data.queue_documents){host.append(el('p','Nenhum documento aguardando revisão nesta consulta.'));return;}
   host.append(el('p',items.length<data.queue_documents?'Mostrando '+items.length+' documentos recentes de '+data.queue_documents+' aguardando revisão.':'Documentos aguardando revisão: '+data.queue_documents+'.'));
   for(const item of items){
    const article=el('article',undefined,'v407-document'),heading=el('h3',String(item.original_name||'Documento enviado'));
    article.append(heading,el('p',(phase[item.phase]||'Em revisão')+' · '+date(item.updated_at)));
    const view=el('button','Ver arquivo','v168-btn'),file=el('div',undefined,'v407-doc-file');view.type='button';view.onclick=()=>showFile(item,view,file);article.append(view,file);
    const detail=el('details'),summary=el('summary','Conferir informações');detail.append(summary);
    const association=item.document_association&&typeof item.document_association==='object'?item.document_association:{};
    const links=el('section');links.append(el('h4','Vínculo informado'));
    const types={bank_statement:'Extrato bancário',card_statement:'Fatura de cartão',card_invoice:'Fatura de cartão',financing_statement:'Financiamento',other_financial_document:'Outro documento'};
    for(const [label,value]of [['Banco',association.institution||association.bank],['Conta',association.account],['Cartão',association.card||association.card_name],['Competência',association.competence||association.competency||association.month],['Data de referência',association.reference_date?date(association.reference_date):null],['Documento',types[association.document_type]],['Observação',association.note]])if(typeof value==='string'||typeof value==='number')pair(links,label,value);
    if(links.children.length===1)links.append(el('p','Vínculo não disponível nesta consulta. Confira o arquivo antes de usar as informações.'));
    detail.append(links);const entries=Array.isArray(item.review_payload?.entries)?item.review_payload.entries:[];
    detail.append(el('h4','Informações extraídas'));
    if(!entries.length)detail.append(el('p','Sem lançamentos extraídos. O arquivo continua disponível para conferência.'));
    for(const entry of entries){const row=el('div',undefined,'v407-doc-entry');row.append(el('strong',String(entry.description||'Lançamento a conferir')));pair(row,'Data',date(entry.event_date));pair(row,'Valor',money(entry.amount));pair(row,'Conta',entry.account);pair(row,'Cartão',entry.card);pair(row,'Categoria',entry.category);detail.append(row);}
    if(item.evidence_truncated||Number(item.entry_count)>entries.length)detail.append(el('p','Mostrando '+entries.length+' de '+item.entry_count+' linhas. Consulte o arquivo para conferir o conteúdo completo.'));
    detail.append(el('p','A consulta não aprova nem cria lançamentos.'));article.append(detail);host.append(article);
   }
  }
  function createUploadForm(){
   const form=el('form',undefined,'v476-upload');
   const typeLabel=el('label','Tipo de documento'),type=el('select');
   for(const [value,label] of [
    ['other_financial_document','Comprovante ou recibo'],['bank_statement','Extrato bancário'],
    ['card_statement','Fatura de cartão'],['financing_statement','Financiamento']
   ]){
    const option=el('option',label);option.value=value;type.append(option);
   }
   typeLabel.append(type);
   const fileLabel=el('label','Arquivo'),input=el('input');
   input.type='file';input.accept='application/pdf,image/*,.pdf,.csv,.txt,.tsv,.xls,.xlsx';
   fileLabel.append(input);
   const button=el('button','Enviar para revisão','v168-btn'),message=el('p');
   button.type='submit';message.setAttribute('role','status');
   form.append(typeLabel,fileLabel,button,message);
   form.onsubmit=async event=>{
    event.preventDefault();
    if(button.disabled)return;
    const file=input.files[0];
    if(!file){message.textContent='Escolha um arquivo.';return;}
    if(!file.size||file.size>52428800){message.textContent='Escolha um arquivo com conteúdo de até 50 MB.';return;}
    const generation=state.generation;
    button.disabled=input.disabled=type.disabled=true;
    message.textContent='Enviando arquivo…';
    try{
     const digest=await crypto.subtle.digest('SHA-256',await file.arrayBuffer());
     if(generation!==state.generation)return;
     const args={p_sha256:Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join(''),
      p_original_name:file.name,p_size_bytes:file.size,p_mime_type:file.type||'application/octet-stream',p_document_type:type.value};
     const register=()=>S.rpc('lts_browser_review_document_file_v476',args);
     let result=await register();
     if(generation!==state.generation)return;
     const wasReceived=result.data?.state==='received';
     if(!result.error&&result.data?.ok&&result.data.state==='upload_required'){
      const path=result.data.storage_path;
      await S.storage.from('lts-documents').upload(path,file,{contentType:args.p_mime_type,upsert:false});
      if(generation!==state.generation)return;
      // A lost upload response or a simultaneous submission is resolved by the private registration.
      result=await register();
     }
     if(generation!==state.generation)return;
     if(result.error||!result.data?.ok||result.data.state!=='received'||!result.data.inbox_id)throw Error();
     input.value='';
     message.textContent=wasReceived?'Este arquivo já foi recebido.':'Arquivo recebido para revisão.';
     if(state.promise)await state.promise;
     if(generation===state.generation)await refresh();
    }catch{
     if(generation===state.generation)message.textContent='Não foi possível confirmar o envio. Tente novamente com o mesmo arquivo.';
    }finally{
     if(generation===state.generation)button.disabled=input.disabled=type.disabled=false;
    }
   };
   return form;
  }
  function mount(){
   if(!D){if(documentPanel||state.data||state.promise||attempts.size)reset();return;}
   if(V!=='Atualizações'){
    if(documentPanel){releaseURLs();documentPanel.remove();documentPanel=null;}
    return;
   }
   const root=document.querySelector('.v168-updates');if(!root)return;
   // The parent can redraw while a private file is opening. Keep the live controls and their pending read.
   if(documentPanel){
    if(documentPanel.parentElement!==root)root.append(documentPanel);
    return;
   }
   root.querySelector('#v407Documents')?.remove();
   const box=el('details',undefined,'v168-card v407-documents');box.id='v407Documents';box.open=state.open;box.append(el('summary','Enviar e consultar documentos'));
   documentPanel=box;
   if(!uploadForm)uploadForm=createUploadForm();
   box.append(uploadForm);
   const body=el('div');body.id='v407DocumentsBody';box.append(body);root.append(box);
   box.addEventListener('toggle',()=>{if(documentPanel!==box)return;state.open=box.open;if(box.open&&state.status==='idle')refresh();});paint();
  }
  // The original parser is retained: review-only structured entries, never a ledger write.
  function structured(rawText){
   const raw=rawText.replace(/^\uFEFF/,'').slice(0,2000000),lines=raw.split(/\r?\n/).filter(x=>x.trim());if(lines.length<2)throw Error('Arquivo sem linhas suficientes.');
   const cand=[',',';','\t','|'],sep=cand.sort((a,b)=>lines[0].split(b).length-lines[0].split(a).length)[0];
   const split=line=>{const out=[];let cur='',q=false;for(let i=0;i<line.length;i++){const ch=line[i];if(ch==='"'){if(q&&line[i+1]==='"'){cur+='"';i++;}else q=!q;}else if(ch===sep&&!q){out.push(cur.trim());cur='';}else cur+=ch;}out.push(cur.trim());return out;};
   const h=split(lines[0]),norm=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim(),find=(o,names)=>{for(const k of Object.keys(o)){const nk=norm(k);if(names.some(w=>nk===w||nk.includes(w)))return o[k];}return null;};
   const amount=v=>{let s=String(v??'').trim().replace(/R\$\s*/gi,'').replace(/\s/g,'');if(!s)return null;if(/^[-+]?\d{1,3}(\.\d{3})*,\d{1,2}$/.test(s))s=s.replace(/\./g,'').replace(',','.');else if(/^[-+]?\d+,\d{1,2}$/.test(s))s=s.replace(',','.');const n=Number(s);return Number.isFinite(n)?n:null;};
   const day=v=>{const s=String(v??'').trim();let m=s.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/);if(m)return `${m[1]}-${m[2].padStart(2,'0')}-${m[3].padStart(2,'0')}`;m=s.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$/);if(m){let y=Number(m[3]);if(y<100)y+=2000;return `${y}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`;}return null;};
   const entries=lines.slice(1,1001).map((line,i)=>{const vals=split(line),o={};h.forEach((k,j)=>o[k||`col_${j+1}`]=vals[j]??'');let value=amount(find(o,['valor','amount','value','total']));const deb=amount(find(o,['debito','débito'])),cred=amount(find(o,['credito','crédito']));if(value==null){if(deb!=null)value=-Math.abs(deb);else if(cred!=null)value=Math.abs(cred);}const desc=String(find(o,['descricao','descrição','description','historico','histórico','memo','estabelecimento','merchant'])||'').trim(),dt=day(find(o,['data','date','dia','lancamento','purchase date','transaction date'])),account=String(find(o,['conta','account','banco','bank'])||'').trim()||null,card=String(find(o,['cartao','cartão','card'])||'').trim()||null,nature=(value??0)<0?'expense':'income',missing=[];if(!dt)missing.push('data');if(value==null||value===0)missing.push('valor');if(!desc)missing.push('descrição');if(!account&&!card)missing.push('conta/cartão');return {source_entry_index:i,event_date:dt,amount:value==null?null:Number(value.toFixed(2)),nature,account,card,category:'A classificar',cost_center:null,counterparty:null,description:desc||`Linha ${i+1}`,missing,requires_review:true,write_allowed:false,parser_version:'browser-delimited-v1'};}).filter(x=>x.event_date||x.amount!=null||x.description);
   return {raw,interpretation:{version:'browser-delimited-v1',kind:'delimited_text',entries,total_rows_seen:Math.max(0,lines.length-1),interpreted_entries:entries.length,review_required:true,write_allowed:false}};
  }
  async function send({input,button,message,context,parseText}){
   const file=input?.files?.[0];if(!file||!button||!message){if(message)message.textContent='Escolha um arquivo.';return;}
   if(button.disabled)return;
   if(!Number.isFinite(file.size)||file.size<=0||file.size>52428800){message.textContent='Escolha um arquivo com conteúdo de até 50 MB.';return;}
   const key=JSON.stringify([file.name,file.size,file.type,file.lastModified,context]),existing=attempts.get(key);
   if(existing){message.textContent=existing.confirmed?'Este arquivo já foi recebido. Consulte Documentos enviados.':'Um envio deste arquivo ainda precisa de confirmação. Consulte Documentos enviados antes de reenviar.';if(existing.confirmed)input.value='';else button.disabled=true;return;}
   const attempt={started:false,confirmed:false,input,button,message};attempts.set(key,attempt);button.disabled=true;input.disabled=true;button.textContent='Enviando…';message.textContent='Enviando arquivo…';
   try{
    const text=parseText&&(file.type.startsWith('text/')||/\.(csv|txt|tsv)$/i.test(file.name))?structured(await file.text()):null;
    const {data:user,error:userError}=await S.auth.getUser();if(userError||!user?.user?.id)throw Error('Sessão expirada. Entre novamente.');
    const safe=String(file.name||'documento').replace(/[^a-zA-Z0-9._-]/g,'_').slice(-120),path=user.user.id+'/'+today()+'/'+crypto.randomUUID()+'-'+safe;
    attempt.started=true;attempt.path=path;
    const {error:uploadError}=await S.storage.from('lts-documents').upload(path,file,{contentType:file.type||'application/octet-stream',upsert:false});if(uploadError)throw Error('O envio não foi confirmado.');
    const args={p_storage_path:path,p_original_name:file.name,p_mime_type:file.type||(text?'text/plain':'application/octet-stream'),p_size_bytes:file.size,p_task_context:context};
    let result,kind;
    if(text)result=await S.rpc('lts_browser_register_structured_text_v2',{...args,p_raw_text:text.raw,p_interpretation:text.interpretation});
    else{kind=file.type==='application/pdf'||/\.pdf$/i.test(file.name)?'pdf':file.type.startsWith('image/')?'photo':'file';result=await S.rpc('lts_browser_register_document_v2',{...args,p_input_type:kind});}
    if(result.error||result.data?.ok!==true||!result.data.inbox_id)throw Error('O registro não foi confirmado.');
    confirmed(attempt,result.data.inbox_id);
    if(parseText&&!text&&kind==='file'){try{await interpretDoc(result.data.inbox_id);}catch{/* The source remains available for manual review. */}}
    // A failed refresh is not a failed upload. The registered source is kept.
    state.status='idle';await refresh();if(parseText){try{await load();}catch{/* Registration was confirmed independently. */}}
   }catch(error){
    if(attempt.started){button.textContent='Confirmação pendente';message.textContent='Não foi possível confirmar o envio. O arquivo foi preservado se recebido. Consulte Documentos enviados antes de reenviar.';state.status='idle';}
    else{attempts.delete(key);input.disabled=false;button.disabled=false;button.textContent='Enviar para revisão';message.textContent=error?.message==='Sessão expirada. Entre novamente.'?error.message:'Não foi possível preparar o arquivo. Confira o formato e tente novamente.';}
   }
  }
  upload=()=>send({input:document.getElementById('file'),button:document.getElementById('ubtn'),message:document.getElementById('up'),context:inputTaskContext(),parseText:true});
  if(typeof u133UploadDocument==='function')u133UploadDocument=button=>send({input:document.getElementById('u133DocFile'),button,message:document.getElementById('u133DocMsg'),context:{source:'updates_document_panel_v133',document_type:document.getElementById('u133DocType')?.value||'other_financial_document',requested_action:'ingest_reconcile'},parseText:false});
  const style=el('style');style.textContent='.v407-documents{margin-top:16px}.v407-documents>summary{cursor:pointer;font-size:16px;font-weight:650;min-height:44px;display:flex;align-items:center}.v407-documents p{font-size:13px;line-height:1.5;color:#526174;overflow-wrap:anywhere}.v407-doc-tools{display:flex;gap:8px;margin:12px 0}.v407-document{border-top:1px solid #dce4ed;padding:14px 0}.v407-document h3{font-size:15px;overflow-wrap:anywhere;margin:0 0 4px}.v407-document h4{font-size:13px;margin:12px 0 4px}.v407-document summary{cursor:pointer;min-height:44px;padding-top:12px}.v407-doc-entry{border-top:1px solid #e8edf3;padding:10px 0}.v407-doc-entry>strong{font-size:13px;overflow-wrap:anywhere}.v407-doc-pair{display:flex;justify-content:space-between;gap:12px;margin:4px 0}.v407-doc-pair>span,.v407-doc-pair>strong{min-width:0;overflow-wrap:anywhere}.v407-doc-pair>strong{text-align:right}.v407-doc-file img{display:block;max-width:100%;max-height:500px;object-fit:contain;margin-top:12px}.v407-documents .v168-btn{min-height:44px;max-width:100%;white-space:normal;overflow-wrap:anywhere}';document.head.append(style);
  render=function(){const result=prior.apply(this,arguments);mount();return result;};
  style.textContent+='.v476-upload{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,13rem),1fr));align-items:end;gap:12px;margin:12px 0}.v476-upload label{display:grid;gap:5px;min-width:0}.v476-upload select,.v476-upload input{box-sizing:border-box;width:100%;min-width:0;min-height:44px;font:inherit}.v476-upload p{grid-column:1/-1;margin:0}.v476-upload p:empty{display:none}';
  for(const name of ['signOut','signInWithPassword'])if(typeof S.auth[name]==='function'){const previous=S.auth[name].bind(S.auth);S.auth[name]=function(){reset();return previous(...arguments);};}
  window.addEventListener('pagehide',()=>{
   releaseURLs();
   documentPanel?.querySelectorAll('.v407-doc-file').forEach(box=>box.replaceChildren());
  });
  window.__LTS_V407_DOCUMENTS={installed:true,refresh,mount};mount();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V365?.installed)return false;if(w.__LTS_V407_DOCUMENTS?.installed)return true;const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);return !!w.__LTS_V407_DOCUMENTS?.installed;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v407-document-review.js',install);
})();

;
/* lts-v408-cipo-source.js */
/* Documentary acquisition groups. This module never changes financial values. */
(function () {
  'use strict';
  function createAPI() {
    const schema = 'cipo-acquisition-documentary-v408';
    function integer(value) {
      const n = Number(value);
      if (!Number.isSafeInteger(n) || n < 1) throw Error('Invalid source row');
      return n;
    }
    function cents(value) {
      if (!/^\d+(?:\.\d{1,2})?$/.test(String(value))) throw Error('Invalid amount');
      const n = Math.round(Number(value) * 100);
      if (!Number.isSafeInteger(n)) throw Error('Amount outside supported range');
      return n;
    }
    function day(value) {
      if (!/^\d{4}-\d\d-\d\d$/.test(String(value))) throw Error('Invalid date');
      const d = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(d.getTime()) || d.toISOString().slice(0, 10) !== value) throw Error('Invalid date');
      return value;
    }
    function build(payload) {
      if (payload == null) return null;
      if (payload.schema !== schema || payload.property_code !== 'cipo396'
        || payload.evidence_kind !== 'workbook_acquisition_composition') throw Error('Unexpected evidence');
      const verifiedOn = day(payload.verified_on);
      if (!Array.isArray(payload.groups) || payload.groups.length !== 32
        || !Array.isArray(payload.residuals) || payload.residuals.length !== 5
        || !Array.isArray(payload.source_files) || payload.source_files.length !== 2) throw Error('Incomplete evidence');
      const files = new Map();
      for (const file of payload.source_files) {
        if (!file.file || files.has(file.file) || !/^[a-f0-9]{64}$/.test(file.sha256 || '')) throw Error('Invalid source file');
        files.set(file.file, file);
      }
      if (payload.source_files.filter(x => x.primary === true).length !== 1) throw Error('Missing primary source');
      const keys = new Set(), sourceRefs = new Set(), sourceRows = new Set(), ids = new Set();
      let count = 0, total = 0, constructor = 0, broker = 0, dateDifferences = 0;
      const groups = payload.groups.map(group => {
        const row = integer(group.source_row), scheduledDate = day(group.scheduled_date);
        if (!group.id || ids.has(group.id) || sourceRows.has(row) || group.source_sheet !== 'Sonho'
          || group.individual_allocation !== null || !Array.isArray(group.cash_rows) || !group.cash_rows.length) throw Error('Invalid acquisition group');
        ids.add(group.id); sourceRows.add(row);
        for (const [key, column] of [['schedule_date', 'W'], ['constructor', 'Y'], ['broker', 'Z'], ['total', 'AA']]) {
          if (group.source_cells?.[key] !== column + row) throw Error('Invalid group source');
        }
        const a = cents(group.constructor_brl), b = cents(group.broker_brl), t = cents(group.total_brl);
        if (a + b !== t || t <= 0) throw Error('Components do not reconcile');
        let cashTotal = 0;
        const cash = group.cash_rows.map(item => {
          const ref = item.source_table + ':' + item.source_ref;
          if (item.source_table !== 'evento_base' || !/^\d+$/.test(String(item.source_ref))
            || !item.row_key || keys.has(item.row_key) || sourceRefs.has(ref)) throw Error('Duplicate or invalid cash identity');
          keys.add(item.row_key); sourceRefs.add(ref);
          const amount = cents(item.amount), date = day(item.event_date);
          if (amount <= 0 || !Array.isArray(item.workbook_rows) || item.workbook_rows.length !== 2) throw Error('Incomplete cash source');
          const seenFiles = new Set();
          for (const evidence of item.workbook_rows) {
            const n = integer(evidence.row);
            if (!files.has(evidence.file) || seenFiles.has(evidence.file)
              || evidence.sheet !== 'Pagamentos e Recebimentos' || evidence.property_label !== 'Cipó 396'
              || evidence.description_cell !== 'A' + n || evidence.amount_cell !== 'B' + n
              || evidence.date_cell !== 'C' + n || evidence.property_cell !== 'G' + n) throw Error('Incomplete workbook identity');
            seenFiles.add(evidence.file);
          }
          count++; cashTotal += amount;
          return { date, cents: amount, sourceRows: item.workbook_rows.map(x => ({ file: x.file, sheet: x.sheet, row: x.row })) };
        });
        const differs = cash.some(item => item.date !== scheduledDate);
        if (cashTotal !== t || group.date_difference !== differs) throw Error('Cash group does not reconcile');
        if (differs) dateDifferences++;
        total += t; constructor += a; broker += b;
        return { id: group.id, sourceRow: row, scheduledDate, constructorCents: a, brokerCents: b, totalCents: t, cash, dateDifference: differs };
      });
      const residuals = payload.residuals.map(item => {
        const ref = item.source_table + ':' + item.source_ref;
        if (!['evento_base', 'financial_events'].includes(item.source_table) || !item.source_ref
          || !item.row_key || keys.has(item.row_key) || sourceRefs.has(ref) || !item.reason) throw Error('Invalid residual identity');
        keys.add(item.row_key); sourceRefs.add(ref);
        const amount = cents(item.amount);
        if (!amount) throw Error('Invalid residual amount');
        return { date: day(item.event_date), cents: amount, description: item.description, reason: item.reason };
      });
      const residualTotal = residuals.reduce((sum, item) => sum + item.cents, 0);
      if (count !== 43 || dateDifferences !== 3 || total !== cents(payload.documented_total_brl)
        || constructor !== cents(payload.constructor_total_brl) || broker !== cents(payload.broker_total_brl)
        || residualTotal !== cents(payload.residual_total_brl)
        || payload.counts?.groups !== 32 || payload.counts?.documented_rows !== 43
        || payload.counts?.residual_rows !== 5 || payload.counts?.date_difference_groups !== 3) throw Error('Evidence totals do not reconcile');
      return { groups, residuals, verifiedOn, totalCents: total, constructorCents: constructor, brokerCents: broker,
        residualTotalCents: residualTotal, rowCount: count, dateDifferences, files: payload.source_files.map(x => ({ ...x })) };
    }
    function renderPanel(document, model) {
      const el = (tag, text, className) => { const e = document.createElement(tag); if (text != null) e.textContent = text; if (className) e.className = className; return e; };
      const money = n => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(n / 100);
      const date = value => value.split('-').reverse().join('/');
      const pair = (label, amount) => { const e = el('div', null, 'v408-pair'); e.append(el('span', label), el('b', money(amount))); return e; };
      const section = el('section', null, 'v408-cipo-source'); section.dataset.v408Cipo = '';
      section.append(el('p', 'Conferência de ' + date(model.verifiedOn) + ': ' + model.rowCount + ' lançamentos documentados. Falta detalhar 5 lançamentos (' + money(model.residualTotalCents) + ').', 'v408-material'));
      const details = el('details'); details.append(el('summary', 'Composição histórica da aquisição'));
      details.append(el('p', 'A planilha separa os pagamentos entre construtora e corretora. Os valores abaixo compõem a aquisição do imóvel.'));
      const totals = el('div', null, 'v408-totals'); totals.append(pair('Construtora', model.constructorCents), pair('Corretora', model.brokerCents), pair('Total documentado', model.totalCents)); details.append(totals);
      details.append(el('p', '32 grupos reúnem os 43 lançamentos. A composição é apresentada por grupo, sem dividir seus componentes entre os pagamentos de caixa.'));
      const list = el('div', null, 'v408-groups');
      for (const group of model.groups) {
        const item = el('details', null, 'v408-group');
        const dates = [...new Set(group.cash.map(x => x.date))].sort();
        const label = dates.length === 1 ? date(dates[0]) : date(dates[0]) + ' a ' + date(dates[dates.length - 1]);
        const title = el('summary'); title.append(el('span', label + ' · ' + group.cash.length + (group.cash.length === 1 ? ' lançamento' : ' lançamentos')), el('b', money(group.totalCents))); item.append(title);
        if (group.constructorCents) item.append(pair('Construtora', group.constructorCents));
        if (group.brokerCents) item.append(pair('Corretora', group.brokerCents));
        if (group.dateDifference) item.append(el('p', 'A grade registra ' + date(group.scheduledDate) + '. As datas originais de caixa são as apresentadas abaixo.', 'v408-date-difference'));
        for (const cash of group.cash) item.append(pair('Caixa · ' + date(cash.date), cash.cents));
        const origin = el('details', null, 'v408-origin'); origin.append(el('summary', 'Origem'));
        origin.append(el('p', 'Sonho · linha ' + group.sourceRow + ' · colunas W, Y, Z e AA.'));
        for (const file of model.files) {
          const rows = group.cash.flatMap(x => x.sourceRows.filter(y => y.file === file.file).map(y => y.row));
          origin.append(el('p', file.file + ' · Pagamentos e Recebimentos · ' + (rows.length === 1 ? 'linha ' : 'linhas ') + rows.join(', ') + '.'));
        }
        item.append(origin); list.append(item);
      }
      details.append(list);
      const residual = el('details', null, 'v408-residuals'); residual.append(el('summary', 'Cinco lançamentos ainda em conferência'));
      for (const item of model.residuals) { const row = el('div', null, 'v408-residual'); row.append(pair(date(item.date), item.cents), el('p', item.reason)); residual.append(row); }
      details.append(residual);
      const origin = el('details', null, 'v408-origin'); origin.append(el('summary', 'Origem e limites'));
      origin.append(el('p', 'Planilha original de julho de 2026 e sua cópia compactada. A cópia confere as mesmas células; não é uma segunda confirmação bancária.'));
      origin.append(el('p', 'Há três grupos com datas diferentes entre a grade e o caixa. Ambas são preservadas. Esta composição não informa principal amortizado ou juros do financiamento bancário.'));
      origin.append(el('p', 'Os 44 pagamentos bancários já documentados e os nove outros itens de aquisição permanecem separados desta composição.'));
      for (const file of model.files) origin.append(el('p', file.file + ' · SHA-256 ' + file.sha256));
      details.append(origin); section.append(details); return section;
    }
    return { build, renderPanel };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V408_CIPO?.installed) return;
    const api = factory(), prior = render, state = window.__LTS_V168_STATE, seen = new WeakMap();
    function after() {
      if (V !== 'Patrimônio' || state.wealth?.tab !== 'assets') return;
      const card = document.querySelector('[data-v309-contract="cipo_396"]');
      if (!card) return;
      const docs = state.wealth?.data?.financing?.documentary?.items || [];
      const entries = docs.filter(x => x.commitment_id === 'cipo_396' && x.metadata?.acquisition_documentary_bridge_v408).map(x => x.metadata.acquisition_documentary_bridge_v408);
      const payload = entries[0];
      if (seen.get(card) === payload && card.querySelector('[data-v408-cipo]')) return;
      card.querySelector('[data-v408-cipo]')?.remove();
      if (!payload) return;
      seen.set(card, payload);
      try {
        if (entries.some(x => JSON.stringify(x) !== JSON.stringify(payload))) throw Error('Conflicting evidence copies');
        card.append(api.renderPanel(document, api.build(payload)));
      } catch {
        const warning = document.createElement('p'); warning.dataset.v408Cipo = ''; warning.className = 'v408-material';
        warning.textContent = 'A composição histórica precisa ser conferida antes de ser exibida. Atualize os dados de patrimônio.'; card.append(warning);
      }
    }
    const style = document.createElement('style'); style.id = 'v408-cipo-style';
    style.textContent = '.v408-cipo-source{margin-top:14px;padding-top:10px;border-top:1px solid #dce3e9}.v408-cipo-source p{font-size:13px;line-height:1.5;color:#536174}.v408-material{font-size:13px;line-height:1.5;color:#825b22!important}.v408-cipo-source details{margin-top:10px}.v408-cipo-source summary{cursor:pointer;font-size:13px;font-weight:600;padding:8px 0}.v408-pair{display:flex;justify-content:space-between;gap:12px;align-items:baseline;padding:7px 0;font-size:13px}.v408-pair b,.v408-group>summary>b{white-space:nowrap;font-variant-numeric:tabular-nums}.v408-groups{margin:12px 0}.v408-group{border-top:1px solid #e5eaf0;padding:3px 0}.v408-group>summary{display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap}.v408-group[open]{padding-bottom:8px}.v408-origin{font-size:12px;overflow-wrap:anywhere}.v408-origin p{font-size:12px}.v408-date-difference{color:#825b22!important}.v408-residual{padding:5px 0;border-bottom:1px solid #e5eaf0}.v408-residual p{margin:2px 0 9px}.v408-totals{margin:10px 0}@media(max-width:700px){.v408-pair{gap:8px}.v408-group>summary span{min-width:0;flex:1}.v408-cipo-source summary{font-size:12px}.v408-pair span{min-width:0}}';
    document.head.append(style);
    render = function () { const result = prior.apply(this, arguments); after(); return result; };
    window.__LTS_V408_CIPO = { installed: true, after }; after();
  }
  function install() {
    try {
      const w = shell?.contentWindow, d = shell?.contentDocument;
      if (!w?.__LTS_V365?.installed) return false;
      if (w.__LTS_V408_CIPO?.installed) return true;
      const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script);
      return !!w.__LTS_V408_CIPO?.installed;
    } catch { return false; }
  }
  let tries = 0;
  function start() { if (!install() && ++tries < 400) setTimeout(start, 100); }
  shell?.addEventListener('load', () => { tries = 0; start(); }); start();
  window.LTSV339Boot?.watch('lts-v408-cipo-source.js', install);
})();

;
/* lts-v411-rsu-policy.js */
/* Gross and estimated net awards. Financial values are supplied by the server. */
(function () {
  'use strict';
  function createAPI() {
    const fail = () => { throw Error('Invalid RSU policy response'); };
    function cents(value, nullable = false) {
      if (nullable && value === null) return null;
      if (typeof value !== 'number' && typeof value !== 'string') return fail();
      const text = String(value);
      if (!/^\d+(?:\.\d{1,2})?$/.test(text)) return fail();
      const [whole, fraction = ''] = text.split('.');
      const result = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
      if (result > BigInt(Number.MAX_SAFE_INTEGER)) return fail();
      return Number(result);
    }
    function quantity(value) {
      if ((typeof value !== 'number' && typeof value !== 'string') || !/^\d+(?:\.\d+)?$/.test(String(value))) return fail();
      const n = Number(value); if (!Number.isFinite(n) || n < 0) return fail(); return n;
    }
    function day(value, nullable = false) {
      if (nullable && value === null) return null;
      if (!/^\d{4}-\d\d-\d\d$/.test(String(value))) return fail();
      const parsed = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) return fail();
      return value;
    }
    function sum(values) {
      const result = values.reduce((a, b) => a + BigInt(b), 0n);
      if (result > BigInt(Number.MAX_SAFE_INTEGER)) return fail(); return Number(result);
    }
    function amounts(source, keys = ['gross_value_brl', 'net_value_brl', 'reserve_value_brl']) {
      const [gross, net, reserve] = keys.map(k => cents(source[k]));
      if (sum([net, reserve]) !== gross) return fail(); return { gross, net, reserve };
    }
    function grant(source) {
      const grantDate = day(source.grant_date, true), eligible = source.acceleration_eligible;
      if (![true, false, null].includes(eligible)) return fail();
      if (eligible === true && (!grantDate || grantDate >= '2026-01-01' || !source.grant_id)) return fail();
      if (grantDate && grantDate >= '2026-01-01' && eligible !== false) return fail();
      if (source.grant_year != null && (!grantDate || Number(source.grant_year) !== Number(grantDate.slice(0, 4)))) return fail();
      return { grantId: source.grant_id || null, grantDate, eligible };
    }
    function build(payload) {
      if (!payload || payload.version !== 'rsu-policy-v411' || payload.schema_version !== 1) return fail();
      const p = payload.policy;
      if (p?.enabled === false) return null;
      if (p?.enabled !== true || Number(p.reserve_rate) !== 0.30 || Number(p.net_factor) !== 0.70
        || p.cash_already_available_untouched !== true || p.retention_award_excluded !== true
        || !Array.isArray(p.scope) || p.scope.length !== 2 || !p.scope.includes('RSU') || !p.scope.includes('Cash RSU')) return fail();
      const keys = new Set(), awardIds = new Set();
      if (!Array.isArray(payload.future_schedule)) return fail();
      const schedule = payload.future_schedule.map(row => {
        if (!row.group_key || keys.has(row.group_key) || !['RSU', 'Cash RSU'].includes(row.asset_type)
          || !Array.isArray(row.components) || !row.components.length || ![true, false, null].includes(row.acceleration_eligible)) return fail();
        keys.add(row.group_key);
        const a = amounts(row), eligibilityDate = day(row.eligibility_date), availableDate = day(row.available_date);
        if (availableDate < eligibilityDate) return fail();
        const components = row.components.map(item => {
          if (!item.award_id || awardIds.has(item.award_id)) return fail(); awardIds.add(item.award_id);
          const c = amounts(item), vesting = day(item.eligibility_date), available = day(item.available_date), g = grant(item);
          if (vesting !== eligibilityDate || available < vesting || available > availableDate) return fail();
          return { ...c, ...g, id: item.award_id, quantity: quantity(item.quantity), vesting, available,
            valuationBasis: item.valuation_basis || null, grantLinkStatus: item.grant_link_status || null };
        });
        if (sum(components.map(x => x.gross)) !== a.gross || sum(components.map(x => x.net)) !== a.net
          || sum(components.map(x => x.reserve)) !== a.reserve
          || row.acceleration_eligible === true && components.some(x => x.eligible !== true)) return fail();
        return { ...a, key: row.group_key, type: row.asset_type, eligibilityDate, availableDate,
          quantity: quantity(row.quantity), eligible: row.acceleration_eligible, components };
      });
      const s = payload.summary || {}, total = amounts(s, ['schedule_gross_brl', 'schedule_net_brl', 'schedule_reserve_brl']);
      const regular = { gross: cents(s.regular_gross_brl), net: cents(s.regular_net_brl) }, cash = { gross: cents(s.cash_gross_brl), net: cents(s.cash_net_brl) };
      if (sum([regular.gross, cash.gross]) !== total.gross || sum([regular.net, cash.net]) !== total.net
        || sum(schedule.map(x => x.gross)) !== total.gross || sum(schedule.map(x => x.net)) !== total.net
        || sum(schedule.filter(x => x.type === 'RSU').map(x => x.gross)) !== regular.gross
        || sum(schedule.filter(x => x.type === 'RSU').map(x => x.net)) !== regular.net) return fail();
      let reference = null;
      if (payload.morgan_reference !== null) {
        const r = payload.morgan_reference;
        if (!r || r.currency !== 'BRL' || r.replaces_dated_position !== false) return fail();
        const asOf = day(r.as_of_date, true);
        if (r.reference_date_known !== (asOf !== null)) return fail();
        const received = r.received_at ? new Date(r.received_at) : null;
        if (received && !Number.isFinite(received.getTime())) return fail();
        reference = { asOf, receivedAt: r.received_at || null, receivedOn: day(r.received_on ?? null, true), gross: cents(r.total_gross_brl), available: cents(r.available_total_brl),
          unavailableGross: cents(r.unavailable_gross_brl), regular: { gross: cents(r.regular_rsu_gross_brl), net: cents(r.regular_rsu_net_brl) },
          cash: { gross: cents(r.cash_rsu_gross_brl), net: cents(r.cash_rsu_net_brl) }, brokerageCash: cents(r.brokerage_cash_brl),
          unallocatedGross: cents(r.unallocated_gross_brl), unallocatedNet: cents(r.unallocated_net_brl, true),
          knownGross: cents(r.known_awards_gross_brl), knownNet: cents(r.known_awards_net_brl), knownAfterReserve: cents(r.known_after_reserve_brl) };
        if (sum([reference.available, reference.unavailableGross]) !== reference.gross
          || sum([reference.regular.gross, reference.cash.gross, reference.unallocatedGross]) !== reference.unavailableGross
          || sum([reference.regular.gross, reference.cash.gross]) !== reference.knownGross
          || sum([reference.regular.net, reference.cash.net]) !== reference.knownNet
          || sum([reference.knownNet, reference.brokerageCash]) !== reference.knownAfterReserve
          || reference.unallocatedGross > 0 && reference.unallocatedNet !== null) return fail();
      }
      let acceleration = null;
      if (payload.acceleration !== null) {
        const a = payload.acceleration;
        if (!a || a.status !== 'conditional' || a.confirmed_date !== null || a.calendar_unchanged !== true
          || a.grant_cutoff !== '2026-01-01' || typeof a.event !== 'string' || !a.event.trim() || !Array.isArray(a.grants)) return fail();
        const ids = new Set();
        const grants = a.grants.map(g => {
          const v = grant(g); if (!v.grantId || ids.has(v.grantId) || !v.grantDate || !['RSU', 'Cash RSU'].includes(g.asset_type)) return fail();
          ids.add(v.grantId); return { ...v, type: g.asset_type, quantity: quantity(g.quantity) };
        });
        const mapped = a.schedule_mapped_count, unmapped = a.schedule_unmapped_count;
        if (![mapped, unmapped].every(n => Number.isInteger(n) && n >= 0)) return fail();
        acceleration = { event: a.event, grants, priceUsd: cents(a.contract_price_usd), eligibleQuantity: quantity(a.eligible_quantity),
          excludedQuantity: quantity(a.excluded_quantity), grossUsd: cents(a.eligible_gross_usd), netUsd: cents(a.eligible_net_usd),
          gross: cents(a.eligible_gross_brl, true), net: cents(a.eligible_net_brl, true),
          fxRate: a.fx_rate == null ? null : quantity(a.fx_rate), fxBasis: a.fx_basis || null, mapped, unmapped };
        if ((acceleration.gross === null) !== (acceleration.net === null)) return fail();
      }
      let payroll = null;
      if (payload.payroll_policy !== null) {
        const p = payload.payroll_policy;
        if (!p || p.coopharma_treatment !== 'subtract_documented_schedule_once' || p.actual_net_preserved !== true || p.forecasts_only !== true) return fail();
        payroll = { base: cents(p.monthly_base_brl) };
      }
      return { total, regular, cash, schedule, reference, acceleration, payroll };
    }
    function matchGroup(row, group) {
      if (!row || !group || row.group_key !== group.key || row.asset_type !== group.type) return false;
      try { return day(row.eligibility_date) === group.eligibilityDate && day(row.available_date) === group.availableDate
        && cents(row.gross_value_brl) === group.gross && cents(row.net_value_brl) === group.net
        && quantity(row.quantity) === group.quantity; } catch { return false; }
    }
    return { build, cents, day, matchGroup };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V411_RSU?.installed) return;
    const api = factory(), prior = render, ui = window.__LTS_V168_STATE;
    const state = { installed: true, version: 'v411', status: 'idle', token: 0, model: null, error: null };
    const identity = () => typeof BOOT === 'object' ? BOOT.generation : D;
    let owner = identity(), marketRevision = null;
    const money = (n, currency = 'BRL') => n === null || n === undefined ? '—' : new Intl.NumberFormat('pt-BR', { style: 'currency', currency }).format(n / 100);
    const number = n => new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 6 }).format(n);
    const date = d => d ? d.split('-').reverse().join('/') : 'não informada';
    const el = (tag, text, cls) => { const e = document.createElement(tag); if (text != null) e.textContent = text; if (cls) e.className = cls; return e; };
    const pair = (label, value) => { const p = el('div', null, 'v411-pair'); p.append(el('span', label), el('b', money(value))); return p; };
    function disclosure(title) { const d = el('details', null, 'v411-origin'); d.append(el('summary', title)); return d; }
    function table(regular, cash, total) {
      const t = el('table', null, 'v411-values'); t.setAttribute('aria-label', 'RSUs: valores brutos e líquidos estimados');
      const head = el('thead'), hr = el('tr'); for (const s of ['Tipo', 'Bruto', 'Líquido estimado']) hr.append(el('th', s)); head.append(hr); t.append(head);
      const body = el('tbody');
      for (const [name, value] of [['RSUs', regular], ['Cash RSUs', cash], ['Total', total]]) {
        const tr = el('tr'); tr.append(el('th', name), el('td', money(value?.gross)), el('td', money(value?.net))); body.append(tr);
      }
      t.append(body); return t;
    }
    function warning(message) { const p = el('p', message, 'v411-warning'); p.setAttribute('role', 'status'); return p; }
    function retry() { const b = el('button', 'Atualizar valores', 'v168-btn'); b.type = 'button'; b.dataset.v411Refresh = ''; b.onclick = () => refresh(); return b; }
    function statusNote() {
      if (state.status === 'error') { const p = warning('Não foi possível conferir os valores líquidos das RSUs. Atualize antes de usar a projeção.'); p.append(document.createTextNode(' '), retry()); return p; }
      return el('p', 'Conferindo valores brutos e líquidos…', 'v411-loading');
    }
    function projection(model) {
      const card = el('article', null, 'v168-card v411-projection'); card.dataset.v411Projection = '';
      card.append(el('h2', 'RSUs e Cash RSUs · agenda normal'), table(model?.regular, model?.cash, model?.total));
      if (!model) card.append(statusNote());
      else card.append(el('p', 'Líquido estimado após reserva de 30% para planejamento. Os vestings futuros permanecem fora do dinheiro disponível hoje.', 'v411-note'));
      return card;
    }
    function referencePanel(r) {
      const card = el('article', null, 'v168-card v411-reference'); card.dataset.v411Reference = '';
      card.append(el('h2', 'Posição informada pela corretora'), pair('Total bruto informado', r.gross));
      const total = { gross: r.knownGross, net: r.knownNet };
      card.append(table(r.regular, r.cash, total), pair('Dinheiro já disponível', r.brokerageCash), pair('Componentes identificados após reserva + dinheiro', r.knownAfterReserve));
      if (!r.asOf) card.append(warning('A data desta posição não foi informada. Ela permanece separada da posição datada.'));
      if (r.unallocatedGross > 0) card.append(warning('Falta identificar ' + money(r.unallocatedGross) + ' do total bruto. O líquido completo ainda está em apuração.'));
      const origin = disclosure('Origem e data');
      origin.append(el('p', 'Data da posição: ' + date(r.asOf) + '.'));
      if (r.receivedAt) origin.append(el('p', 'Recebido em ' + new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'America/Sao_Paulo' }).format(new Date(r.receivedAt)) + ' (Brasília).'));
      else if (r.receivedOn) origin.append(el('p', 'Recebido em ' + date(r.receivedOn) + '.'));
      origin.append(el('p', 'A referência documental e a agenda de vestings usam bases distintas e não são somadas. Dinheiro já disponível não recebe nova reserva. Retention Award permanece separado.')); card.append(origin); return card;
    }
    function accelerationPanel(a) {
      const card = el('article', null, 'v168-card v411-acceleration'); card.dataset.v411Acceleration = '';
      card.append(el('h2', 'Antecipação condicional'), el('p', a.event, 'v411-note'), warning('Data ainda não confirmada. A agenda normal permanece em vigor.'));
      card.append(el('p', 'A quantidade é o saldo ainda não adquirido da referência. Vestings ocorridos antes do fechamento devem ser excluídos; o valor final depende do saldo no fechamento.', 'v411-note'));
      card.append(pair('Bruto elegível no cenário', a.gross), pair('Líquido estimado no cenário', a.net));
      const detail = disclosure('Concessões e premissas do cenário');
      detail.append(el('p', 'Somente concessões anteriores a 2026 participam desta condição. As concessões de 2026 mantêm seus vestings originais.'));
      detail.append(el('p', 'Preço contratual: ' + money(a.priceUsd, 'USD') + '. Valor bruto elegível: ' + money(a.grossUsd, 'USD') + '; líquido estimado: ' + money(a.netUsd, 'USD') + '.'));
      detail.append(el('p', a.fxRate === null ? 'Conversão para reais ainda indisponível.' : 'Câmbio considerado: ' + number(a.fxRate) + ' reais por dólar.'));
      for (const g of a.grants) detail.append(el('p', date(g.grantDate) + ' · ' + g.type + ' · ' + number(g.quantity) + ' unidades · ' + (g.eligible === true ? 'incluída na condição' : g.eligible === false ? 'fora desta antecipação' : 'elegibilidade em conferência')));
      if (a.unmapped > 0) card.append(warning('O cenário usa as concessões documentadas. Ainda falta vincular ' + a.unmapped + ' componente(s) à agenda; nenhuma data foi antecipada.'));
      card.append(detail); return card;
    }
    function componentOrigin(group) {
      const d = disclosure('Origem e composição desta parcela'); d.classList.add('v411-component-origin');
      for (const c of group.components) {
        const line = el('div', null, 'v411-component');
        line.append(el('p', number(c.quantity) + ' unidades · concessão ' + (c.grantDate ? date(c.grantDate) : 'a identificar') + '.'));
        line.append(pair('Bruto', c.gross), pair('Líquido estimado', c.net));
        line.append(el('p', 'Vesting ' + date(c.vesting) + ' · disponibilidade prevista ' + date(c.available) + '.'));
        line.append(el('p', c.eligible === true ? 'Concessão anterior a 2026; participa somente do cenário condicional.' : c.eligible === false ? 'Fora da antecipação; calendário original preservado.' : 'Concessão ainda sem vínculo documental nesta parcela.'));
        d.append(line);
      }
      d.append(el('p', 'Reserva de 30% como premissa de planejamento. Vesting e disponibilidade prevista não comprovam recebimento bancário.')); return d;
    }
    function patchQuoteModal() {
      if (!state.model) return;
      const modal = document.getElementById('v168Modal');
      if (!modal?.querySelector('#v168AwSave')) return;
      const note = [...modal.querySelectorAll('.v168-note')].find(n => /RSU normal|Cash RSU usa/.test(n.textContent));
      if (note) note.textContent = 'RSUs e Cash RSUs usam líquido estimado após reserva de 30% para planejamento. O valor bruto permanece no acompanhamento.';
    }
    function patchAgenda(root, model) {
      const agenda = [...root.querySelectorAll('article')].find(n => n.querySelector('h2')?.textContent === 'Vestings e disponibilidade');
      if (!agenda) return;
      const total = agenda.querySelector('.v168-cardhead strong'); if (total) total.textContent = money(model?.total.net);
      agenda.querySelectorAll('.v183-award-model-note').forEach(n => n.remove());
      const rows = ui.wealth?.data?.rsu?.future_schedule || [];
      [...agenda.querySelectorAll('.v168-award')].forEach((card, index) => {
        const row = rows[index], group = model?.schedule.find(x => x.key === row?.group_key), matches = api.matchGroup(row, group);
        const value = card.children[3];
        if (value) { value.replaceChildren(el('span', 'Bruto'), el('b', money(matches ? group.gross : null)), el('span', 'Líquido estimado'), el('b', money(matches ? group.net : null)), el('small', date(row?.available_date) + ' · disponibilidade prevista')); value.classList.add('v411-award-values'); }
        card.querySelectorAll('[data-v168-award-date]').forEach(input => input.closest('label')?.remove());
        card.querySelectorAll('[data-v168-award-save]').forEach(button => button.remove());
        card.querySelectorAll('.v183-award-source,.v411-component-origin,.v411-group-warning').forEach(n => n.remove());
        if (matches) card.append(componentOrigin(group));
        else { const p = warning(model ? 'Esta parcela precisa ser atualizada para conferir bruto e líquido.' : 'Líquido em conferência.'); p.classList.add('v411-group-warning'); card.append(p); }
      });
    }
    function patchKpi(root, label, value, note, displayedLabel) {
      const k = [...root.querySelectorAll('.v168-kpi')].find(x => x.querySelector('span')?.textContent.trim() === label);
      if (!k) return; const v = k.querySelector('strong'); if (v) v.textContent = money(value); const s = k.querySelector('small'); if (s) s.textContent = note;
      if (displayedLabel) k.querySelector('span').textContent = displayedLabel;
    }
    function patchDashboard(model) {
      const root = document.querySelector('.v168-dashboard'); if (!root) return;
      patchKpi(root, 'RSUs futuras', model?.regular.net, model ? 'Líquido estimado · bruto ' + money(model.regular.gross) : 'Líquido em conferência');
      patchKpi(root, 'Cash RSUs futuras', model?.cash.net, model ? 'Líquido estimado · bruto ' + money(model.cash.gross) : 'Líquido em conferência');
      for (const label of ['Total de posições futuras', 'Compensação futura', 'RSUs e Cash RSUs futuras']) patchKpi(root, label, model?.total.net, model ? 'Após reserva de 30% · bruto ' + money(model.total.gross) + ' · Retention Award separado' : 'Líquido em conferência', 'RSUs e Cash RSUs futuras');
      root.querySelector('[data-v411-dashboard]')?.remove();
      if (!model && state.status === 'error') { const p = statusNote(); p.dataset.v411Dashboard = ''; root.prepend(p); }
    }
    function patchWealth(model) {
      const root = document.querySelector('.v168-wealth'); if (!root) return;
      root.querySelectorAll('[data-v411-projection],[data-v411-reference],[data-v411-acceleration]').forEach(n => n.remove());
      if (ui.wealth?.tab === 'overview') {
        const card = [...root.querySelectorAll('article')].find(n => n.querySelector('h2')?.textContent === 'Valores a receber no futuro');
        if (card) card.replaceWith(projection(model)); return;
      }
      if (ui.wealth?.tab !== 'rsu') return;
      const anchor = root.querySelector('.v168-tabs') || root.querySelector('[role="tablist"]');
      const p = projection(model); if (anchor) anchor.after(p); else root.prepend(p);
      let last = p;
      if (model?.reference) { const card = referencePanel(model.reference); last.after(card); last = card; }
      if (model?.acceleration) { const card = accelerationPanel(model.acceleration); last.after(card); }
      patchAgenda(root, model);
      // Old comparison cards remain documentary history, not the current net policy.
      root.querySelectorAll('.v172-morgan > .v168-note').forEach(n => { n.textContent = 'Posição datada e agenda são bases distintas. A agenda atual considera reserva de 30% para RSUs e Cash RSUs.'; });
      const oldReference = root.querySelector('.v352-brokerage-reference');
      if (oldReference && model?.reference && !oldReference.parentElement?.classList.contains('v411-prior-reference')) {
        const d = disclosure('Referência anteriormente cadastrada'); d.classList.add('v411-prior-reference'); oldReference.before(d); d.append(oldReference);
      }
    }
    function patchFlow(model) {
      document.querySelector('[data-v411-flow-policy]')?.remove();
      const controls = document.querySelector('.flow-sticky-controls'); if (!controls) return;
      if (!model) { if (state.status === 'error') { const p = statusNote(); p.dataset.v411FlowPolicy = ''; controls.after(p); } return; }
      const d = disclosure('Premissas de RSU e salário'); d.dataset.v411FlowPolicy = '';
      d.append(el('p', 'RSUs e Cash RSUs: líquido estimado após reserva de 30%, disponível nas datas da agenda normal. A condição de antecipação permanece separada.'));
      if (model.payroll) d.append(el('p', 'Previsão de salário mensal: base ' + money(model.payroll.base) + ' menos a parcela Coopharma da competência. Valores já líquidos do holerite permanecem preservados.'));
      controls.after(d);
    }
    function after() {
      if (owner !== identity()) { owner = identity(); marketRevision = null; invalidate(); }
      if (!D || N.classList.contains('hidden')) return;
      if (!['Dashboard', 'Patrimônio', 'Fluxo Diário'].includes(V)) return;
      if (state.status === 'idle') queueMicrotask(() => load());
      if (state.status === 'disabled') return;
      if (V === 'Dashboard') patchDashboard(state.model);
      if (V === 'Patrimônio') patchWealth(state.model);
      if (V === 'Fluxo Diário') patchFlow(state.model);
      patchQuoteModal();
    }
    async function load(force = false) {
      if (!D || N.classList.contains('hidden')) return;
      if (state.status === 'loading' || !force && state.status !== 'idle') return;
      const token = ++state.token, requestedOwner = identity(); state.status = 'loading'; state.error = null;
      try {
        const response = await S.rpc('lts_browser_rsu_policy_v411', {});
        if (token !== state.token || requestedOwner !== identity()) return;
        if (response?.error) throw Error('Policy unavailable');
        state.model = api.build(response?.data); state.status = state.model ? 'ready' : 'disabled';
      } catch {
        if (token !== state.token || requestedOwner !== identity()) return;
        state.model = null; state.status = 'error'; state.error = 'unavailable';
      }
      if (['Dashboard', 'Patrimônio', 'Fluxo Diário'].includes(V)) render();
    }
    function invalidate() { state.token++; state.status = 'idle'; state.model = null; state.error = null; }
    function refresh() {
      invalidate();
      if (ui.wealth) { ui.wealth.data = null; ui.wealth.error = null; }
      window.__LTS_V178_REVIEW?.refresh?.(); render(); load();
    }
    const rpc = S.rpc.bind(S), writers = new Set(['lts_browser_save_all_award_assumptions_v1', 'lts_browser_save_award_assumption_v1', 'lts_browser_market_mode_v290']);
    S.rpc = function (name, args, ...rest) {
      const result = rpc(name, args, ...rest);
      if (name === 'lts_browser_market_quotes_v290') return Promise.resolve(result).then(response => {
        if (!response?.error && response?.data?.revision != null) {
          const changed = marketRevision !== null && marketRevision !== response.data.revision;
          marketRevision = response.data.revision;
          if (changed) { invalidate(); queueMicrotask(() => load()); }
        }
        return response;
      });
      if (!writers.has(name)) return result;
      return Promise.resolve(result).then(response => { if (!response?.error && response?.data?.ok) { invalidate(); queueMicrotask(() => load()); } return response; });
    };
    S.auth.onAuthStateChange?.(event => { if (event === 'SIGNED_OUT' || event === 'SIGNED_IN') { invalidate(); document.querySelectorAll('[data-v411-projection],[data-v411-reference],[data-v411-acceleration],[data-v411-flow-policy]').forEach(n => n.remove()); } });
    document.addEventListener('click', event => {
      if (event.target.closest?.('[data-v168-award-edit]')) patchQuoteModal();
    });
    document.addEventListener('click', event => { if (event.target.closest?.('#logout')) invalidate(); }, true);
    const style = el('style'); style.id = 'v411-rsu-style';
    style.textContent = '.v411-projection,.v411-reference,.v411-acceleration{margin:14px 0!important;min-width:0}.v411-values{border-collapse:collapse;width:100%;margin:12px 0;font-size:13px;table-layout:fixed}.v411-values th,.v411-values td{padding:10px 7px;border-bottom:1px solid #e1e7ed;text-align:right;overflow-wrap:anywhere;vertical-align:top}.v411-values th:first-child{text-align:left;width:24%}.v411-values td{font-variant-numeric:tabular-nums;white-space:nowrap}.v411-values tbody tr:last-child{font-weight:700}.v411-pair{display:flex;justify-content:space-between;gap:12px;align-items:baseline;padding:8px 0;font-size:13px}.v411-pair span{min-width:0}.v411-pair b{font-variant-numeric:tabular-nums;white-space:nowrap}.v411-note,.v411-warning,.v411-loading{font-size:13px;line-height:1.5;margin:10px 0;white-space:normal}.v411-warning{color:#875b18}.v411-loading,.v411-note{color:#536174}.v411-origin{margin:10px 0;font-size:12px;line-height:1.5;white-space:normal;overflow-wrap:anywhere}.v411-origin>summary{cursor:pointer;padding:9px 0;font-weight:600}.v411-origin p{margin:8px 0}.v411-component{padding:7px 0;border-top:1px solid #e1e7ed}.v411-component-origin,.v411-group-warning{grid-column:1/-1}.v411-award-values{display:flex;flex-direction:column;gap:3px}.v411-award-values>b{white-space:nowrap}.v411-award-values>span:nth-of-type(2){margin-top:7px}.v411-prior-reference{padding:0 8px}.v411-values th{font-weight:600}@media(max-width:600px){.v411-values{font-size:12px;display:block}.v411-values thead,.v411-values tbody{display:block}.v411-values tr{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);column-gap:8px}.v411-values th,.v411-values td{padding:8px 0;text-align:left}.v411-values th:first-child{width:auto;grid-column:1/-1;padding-bottom:1px;border-bottom:0}.v411-values thead th:first-child{display:none}.v411-values td{font-size:12px}.v411-pair{font-size:12px;gap:7px}.v411-projection h2,.v411-reference h2,.v411-acceleration h2{font-size:16px}.v411-origin>summary{min-height:24px}}';
    document.head.append(style);
    render = function () { const result = prior.apply(this, arguments); after(); return result; };
    Object.assign(state, { after, refresh, load, invalidate }); window.__LTS_V411_RSU = state; after();
  }
  function install() {
    try {
      const w = shell?.contentWindow, d = shell?.contentDocument;
      if (!w?.__LTS_V365?.installed || !w?.__LTS_V183_AWARD_PROVENANCE?.installed) return false;
      if (!w.__LTS_V411_RSU?.installed) { const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script); }
      return !!w.__LTS_V411_RSU?.installed;
    } catch { return false; }
  }
  let generation = 0;
  function start() { const current = ++generation; let tries = 0; function attempt() { if (current !== generation) return; if (!install() && ++tries < 400) setTimeout(attempt, 100); } attempt(); }
  shell?.addEventListener('load', start); start(); window.LTSV339Boot?.watch('lts-v411-rsu-policy.js', install);
})();

;
/* lts-v412-projection-policy.js */
/* Projection amounts come from the owner-scoped server calculation. */
(function () {
  'use strict';
  function createAPI() {
    const invalid = () => { throw Error('Invalid projection response'); };
    const methods = new Set(['history_total_budget', 'fixed', 'salary_net', 'inflated_calendar', 'repeat_calendar']);
    function day(value) {
      if (typeof value !== 'string' || !/^\d{4}-\d\d-\d\d$/.test(value)) return invalid();
      const date = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) return invalid();
      return value;
    }
    function cents(value, nullable = false) {
      if (nullable && value === null) return null;
      if (!['number', 'string'].includes(typeof value) || !/^\d+(?:\.\d{1,2})?$/.test(String(value))) return invalid();
      const [whole, fraction = ''] = String(value).split('.');
      const n = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
      if (n > BigInt(Number.MAX_SAFE_INTEGER)) return invalid();
      return Number(n);
    }
    function windowDates(value) {
      if (!value) return invalid();
      const from = day(value.from), to = day(value.to);
      if (from > to) return invalid();
      return { from, to };
    }
    function annualTotals(row, asOf, horizon) {
      return row.annual_totals.map(year => {
        if (!Number.isInteger(year.year) || year.year < Number(asOf.slice(0, 4)) || year.year > Number(horizon.slice(0, 4))
          || typeof year.partial_year !== 'boolean') return invalid();
        return { year: year.year, total: cents(year.budget_total_brl, true),
          additional: cents(year.additional_brl, true), partial: year.partial_year };
      });
    }
    function approvedBudget(row, asOf, horizon) {
      if (row.method !== 'fixed' || row.direction !== 'expense' || typeof row.uses_history !== 'boolean'
        || row.reference_stale !== false || row.expected_months !== 12 || !Array.isArray(row.coverage)
        || typeof row.account !== 'string' || !row.account.trim()) return invalid();
      const amount = cents(row.reference_amount_brl);
      if (amount <= 0) return invalid();
      const historyWindow = row.reference_window === null ? null : windowDates(row.reference_window);
      let months = null;
      if (historyWindow) {
        const start = new Date(historyWindow.from + 'T12:00:00Z');
        const end = new Date(historyWindow.to + 'T12:00:00Z');
        const after = new Date(end);
        after.setUTCDate(after.getUTCDate() + 1);
        months = (after.getUTCFullYear() - start.getUTCFullYear()) * 12 + after.getUTCMonth() - start.getUTCMonth();
        if (start.getUTCDate() !== 1 || after.getUTCDate() !== 1 || months < 1 || historyWindow.to >= asOf
          || !Number.isInteger(row.coverage_months) || row.coverage_months < 0 || row.coverage_months > months) return invalid();
      } else if (row.coverage_months !== null || row.uses_history) return invalid();
      if (row.uses_history && row.coverage_months !== months) return invalid();
      let previousDate = asOf;
      for (const period of row.coverage) {
        const due = day(period.event_date);
        if (due <= previousDate || due > horizon || typeof period.trusted !== 'boolean') return invalid();
        previousDate = due;
        const known = cents(period.known_brl, true), additional = cents(period.additional_brl, true);
        const budget = cents(period.budget_total_brl);
        if (period.status === 'open_cycle_known_only') {
          if (row.account !== 'Bradesco' || !period.trusted || known === null || budget !== known || additional !== 0) return invalid();
          continue;
        }
        if (budget !== amount) return invalid();
        if (period.trusted ? known === null || additional !== Math.max(amount - known, 0)
          : known !== null || additional !== null || !row.warnings.includes('unreconciled_periods')) return invalid();
      }
      return { key: row.series_key, description: row.description, direction: row.direction, method: row.method,
        account: row.account, amount, rate: 0, historyWindow, referenceStale: false, templateYear: null,
        expected: months, covered: row.coverage_months, observed: null, spendingMonths: null, outliers: [],
        warnings: row.warnings.map(String), dueDayBasis: null, usesHistory: row.uses_history,
        approvedBudget: true, annual: annualTotals(row, asOf, horizon) };
    }
    function build(payload) {
      if (!payload || payload.version !== 'projection-policy-v412') return invalid();
      if (payload.enabled === false) return null;
      if (payload.enabled !== true || payload.schema_version !== 1 || !Array.isArray(payload.series)
        || !Array.isArray(payload.warnings) || payload.card_method !== 'total_budget_floor'
        || payload.outliers_excluded !== false || payload.missing_months_assumed_zero !== false
        || payload.financial_sources_modified !== false) return invalid();
      const asOf = day(payload.as_of), horizon = day(payload.horizon_end), nextReview = day(payload.next_review_on);
      if (horizon !== (Number(asOf.slice(0, 4)) + 5) + '-12-31' || nextReview <= asOf) return invalid();
      const historyWindow = windowDates(payload.history_window), keys = new Set();
      const series = payload.series.map(row => {
        if (!row || typeof row.series_key !== 'string' || !row.series_key.trim() || keys.has(row.series_key)
          || typeof row.description !== 'string' || !row.description.trim()
          || !Array.isArray(row.warnings) || !Array.isArray(row.annual_totals)) return invalid();
        keys.add(row.series_key);
        if (/^(?:owner|recurring)_[a-z][a-z0-9_]*$/.test(row.series_key) && Object.hasOwn(row, 'coverage')) {
          return approvedBudget(row, asOf, horizon);
        }
        const expected = row?.expected_months;
        const cardBudget = row?.method === 'history_total_budget' && /^card_/.test(row?.series_key || '');
        if (!methods.has(row.method)
          || !['income', 'expense'].includes(row.direction) || !(expected === 12 || expected === 3 && cardBudget)
          || !Number.isInteger(row.coverage_months) || row.coverage_months < 0 || row.coverage_months > expected
          || !Number.isInteger(row.observed_months) || row.observed_months < row.coverage_months || row.observed_months > expected
          || !Number.isInteger(row.months_with_spend) || row.months_with_spend < 0 || row.months_with_spend > row.observed_months
          || !Array.isArray(row.outlier_months) || !Array.isArray(row.warnings) || !Array.isArray(row.annual_totals)
          || typeof row.reference_stale !== 'boolean') return invalid();
        const rate = Number(row.annual_rate);
        if (!Number.isFinite(rate) || rate < 0 || rate > .25 || row.method !== 'inflated_calendar' && rate !== 0) return invalid();
        const referenceWindow = windowDates(row.reference_window), amount = cents(row.reference_amount_brl, true);
        let endsOn = null;
        if (row.ends_on !== undefined) {
          if (!cardBudget || row.direction !== 'expense') return invalid();
          endsOn = day(row.ends_on);
        }
        let provision = null;
        if (row.new_spend_provision !== undefined) {
          const value = row.new_spend_provision;
          if (!value || typeof value !== 'object' || Array.isArray(value)
            || !cardBudget || row.direction !== 'expense') return invalid();
          const startsOn = day(value.starts_on), provisionAmount = cents(value.amount_brl);
          if (!startsOn.endsWith('-01') || provisionAmount <= 0 || provisionAmount > 10000000000) return invalid();
          const leadMonths = value.lead_months === undefined ? null : value.lead_months;
          if (leadMonths !== null && (!Number.isInteger(leadMonths) || leadMonths < 0 || leadMonths > 12)) return invalid();
          provision = { startsOn, amount: provisionAmount, active: asOf >= startsOn,
            ...(leadMonths !== null ? { leadMonths, rolling: true } : {}) };
          if (provision.active && (row.uses_history !== false || amount !== provisionAmount)) return invalid();
        }
        if (expected === 3) {
          const start = new Date(referenceWindow.from + 'T12:00:00Z');
          const end = new Date(start); end.setUTCMonth(end.getUTCMonth() + expected); end.setUTCDate(end.getUTCDate() - 1);
          if (!referenceWindow.from.endsWith('-01') || end.toISOString().slice(0, 10) !== referenceWindow.to
            || referenceWindow.to >= asOf.slice(0, 7) + '-01') return invalid();
        }
        if (!provision?.active && !provision?.rolling && (row.method === 'history_total_budget' || row.uses_history === true) && amount !== null && row.coverage_months < expected && !row.reference_stale) return invalid();
        return { key: row.series_key, description: row.description, method: row.method, direction: row.direction,
          account: String(row.account || ''), amount, rate, historyWindow: referenceWindow, referenceStale: row.reference_stale,
          templateYear: Number.isInteger(row.template_year) ? row.template_year : null,
          expected, covered: row.coverage_months, observed: row.observed_months, spendingMonths: row.months_with_spend, outliers: row.outlier_months.map(day),
          warnings: row.warnings.map(String), dueDayBasis: row.due_day_basis || null,
          usesHistory: !provision?.active && !provision?.rolling && (row.uses_history === true || row.method === 'history_total_budget'),
          ...(provision ? { newSpendProvision: provision } : {}),
          ...(endsOn ? { endsOn } : {}),
          annual: annualTotals(row, asOf, horizon) };
      });
      return { asOf, horizon, nextReview, historyWindow, series, partialYear: payload.current_year_partial === true };
    }
    return { build, cents, day };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V412_PROJECTION?.installed) return;
    const api = factory(), previous = render, ui = window.__LTS_V168_STATE;
    const previousRange = loadFlowRange, previousRPC = S.rpc.bind(S);
    const state = { installed: true, status: 'idle', model: null, sequence: 0, readAt: 0, horizonKey: null, explicitRange: false, consumerSequence: 0 };
    let openingFullRange = false;
    const identity = () => typeof BOOT === 'object' ? BOOT.generation : D;
    let owner = identity();
    const date = value => value.split('-').reverse().join('/');
    const money = value => value === null ? '—' : new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value / 100);
    const el = (tag, text, className) => { const node = document.createElement(tag); if (text != null) node.textContent = text; if (className) node.className = className; return node; };
    function reset() {
      if (owner === identity() && D && !N.classList.contains('hidden')) return false;
      owner = identity(); state.sequence++; state.consumerSequence++; state.status = 'idle'; state.model = null; state.readAt = 0; state.horizonKey = null; state.explicitRange = false;
      document.querySelectorAll('[data-v412-policy]').forEach(node => node.remove());
      return true;
    }
    function fullRange(model = state.model) {
      if (!model) return null;
      const from = new Date(model.asOf + 'T12:00:00Z'); from.setUTCDate(from.getUTCDate() - 5);
      return { from: from.toISOString().slice(0, 10), to: model.horizon,
        previousEnd: (Number(model.asOf.slice(0, 4)) + 4) + '-12-31' };
    }
    // Only the old automatic defaults are extended. Explicit user periods keep
    // the exact dates requested by the existing navigation and editor handlers.
    loadFlowRange = function (from, to) {
      const range = fullRange();
      if (window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action && !openingFullRange) state.explicitRange = true;
      if (range && from === range.from && to === range.previousEnd
        && !state.explicitRange && !window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action) to = range.to;
      return previousRange.call(this, from, to);
    };
    S.rpc = function (name, args, ...rest) {
      const range = fullRange();
      if (range && args) {
        if (/^lts_browser_flow_v\d+$/.test(name) && V === 'Dashboard'
          && args.p_from === state.model.asOf && args.p_to === range.previousEnd) args = { ...args, p_to: range.to };
        if (/^lts_browser_recurring_future_gap_audit_v\d+$/.test(name)
          && args.p_as_of === state.model.asOf && args.p_horizon_end === range.previousEnd) args = { ...args, p_horizon_end: range.to };
      }
      return previousRPC(name, args, ...rest);
    };
    function openFullRange() {
      const range = fullRange(); if (!range) return;
      const layout = window.__LTS_V382_FLOW_LAYOUT, prior = layout?.explicit_period_action;
      state.explicitRange = false; openingFullRange = true;
      if (layout) layout.explicit_period_action = true;
      try { return loadFlowRange(range.from, range.to); }
      finally { openingFullRange = false; if (layout) layout.explicit_period_action = prior; }
    }
    async function refreshConsumers() {
      const model = state.model, generation = owner, token = ++state.consumerSequence;
      if (!model) return;
      const stillCurrent = () => generation === identity() && token === state.consumerSequence && state.model?.horizon === model.horizon;
      if (ui?.updates) { ui.updates.token = (ui.updates.token || 0) + 1; ui.updates.loading = false; }
      const forecast = Promise.resolve(window.__LTS_V178_REVIEW?.refreshForecast?.()).catch(() => {});
      try {
        const response = await S.rpc('lts_browser_recurring_future_gap_audit_v5', { p_as_of: model.asOf, p_horizon_end: model.horizon });
        if (!stillCurrent()) return;
        if (response.error || !Array.isArray(response.data?.horizon_checks)) throw Error();
        if (ui?.updates) { ui.updates.recurring = response.data; ui.updates.error = null; }
        if (ui?.dashboard) { ui.dashboard.data ||= {}; ui.dashboard.data.recurring = response.data; }
      } catch { if (stillCurrent() && ui?.updates) ui.updates.error = 'Não foi possível atualizar as revisões. Tente novamente.'; }
      finally { await forecast; if (stillCurrent()) render(); }
    }
    function applyHorizon() {
      const range = fullRange(); if (!range) return;
      if (state.horizonKey !== range.to) {
        // The initial dashboard already requests the scenario's five-year
        // horizon. Loading the matching policy must not restart those readers.
        // A longer horizon, a later change and explicit refresh still recheck
        // every consumer through the existing guarded paths.
        const alignedOpening = state.horizonKey === null
          && window.parent.LTSV421Scenario?.horizon?.(state.model.asOf, null) === range.to;
        state.horizonKey = range.to;
        if (!alignedOpening) {
          if (ui?.dashboard) { ui.dashboard.token = (ui.dashboard.token || 0) + 1; ui.dashboard.started = false; ui.dashboard.loading = false; }
          queueMicrotask(() => { if (state.model?.horizon === range.to) refreshConsumers(); });
        }
      }
      if (V !== 'Fluxo Diário') return;
      for (const id of ['flowDefaultRange', 'goToday']) {
        const button = document.getElementById(id); if (!button) continue;
        if (id === 'flowDefaultRange') { button.textContent = '5 anteriores + fim de ' + range.to.slice(0, 4);
          button.title = 'Cinco dias anteriores e cinco anos futuros completos'; }
        button.onclick = openFullRange;
      }
      const year = document.getElementById('flowYear'), end = document.getElementById('flowTo');
      if (year && ![...year.options].some(option => option.value === range.to.slice(0, 4)))
        year.append(new Option(range.to.slice(0, 4), range.to.slice(0, 4)));
      if (end) end.max = range.to;
      if (!state.explicitRange && FLOWFROM === range.from && FLOWTO === range.previousEnd && !FLOWLOADING)
        queueMicrotask(() => { if (!state.explicitRange && FLOWFROM === range.from && FLOWTO === range.previousEnd && !FLOWLOADING) openFullRange(); });
    }
    function message(text) { const node = el('p', text, 'v412-warning'); node.setAttribute('role', 'status'); return node; }
    function warningTexts(model) {
      const texts = [];
      for (const row of model.series) {
        if (row.referenceStale) texts.push(row.description + ': usando a última média completa.');
        else if (row.warnings.includes('history_unavailable') || row.warnings.includes('partial_history')) texts.push(row.description + ': histórico incompleto.');
        if (row.warnings.includes('unreconciled_periods') || row.warnings.includes('calendar_unavailable')) texts.push(row.description + ': há previsões a conferir.');
      }
      return texts;
    }
    function provisionText(row) {
      const provision = row.newSpendProvision;
      if (provision.rolling) return 'Novos gastos: ' + money(provision.amount) + '/mês desde o ' + provision.leadMonths + 'º mês à frente, além das parcelas conhecidas. Neste cálculo: a partir de ' + date(provision.startsOn) + '.';
      return 'Novos gastos: ' + money(provision.amount) + '/mês a partir de ' + date(provision.startsOn) + ', além das parcelas.';
    }
    function methodText(row) {
      if (row.approvedBudget) return (row.usesHistory ? 'Média de ' + row.expected + ' meses.' : 'Valor mensal definido.')
        + ' Os gastos já previstos abatem a provisão do mês.';
      if (row.newSpendProvision?.active || row.newSpendProvision?.rolling) return provisionText(row);
      if (row.method === 'history_total_budget') return 'Média de ' + row.expected + ' meses completos' + (row.expected === 3 ? ', atualizada com as novas faturas.' : '.');
      if (row.method === 'inflated_calendar') return 'Reajuste estimado de ' + new Intl.NumberFormat('pt-BR', { style: 'percent', maximumFractionDigits: 2 }).format(row.rate) + ' ao ano. Cobranças confirmadas têm prioridade.';
      if (row.method === 'salary_net') return 'Salário previsto após o desconto do empréstimo em folha.';
      if (row.method === 'repeat_calendar') return 'Calendário e valores mantidos, sem aumento automático.';
      return 'Valor mantido, sem aumento automático.';
    }
    function origin(model) {
      const details = el('details', null, 'v412-origin'); details.append(el('summary', 'Premissas das projeções'));
      details.append(el('p', 'Planejamento até ' + date(model.horizon) + ', com extensão anual.'));
      warningTexts(model).forEach(text => details.append(message(text)));
      if (model.partialYear) details.append(el('p', 'O ano corrente considera somente as datas futuras; sua soma é parcial.'));
      for (const row of model.series) {
        const section = el('section', null, 'v412-rule'); section.append(el('h3', row.description));
        if (row.amount !== null && !row.newSpendProvision?.active && !row.newSpendProvision?.rolling) section.append(el('strong', money(row.amount) + (row.method === 'history_total_budget' ? ' · referência mensal' : ' · base nominal')));
        section.append(el('p', methodText(row)));
        if (row.newSpendProvision && !row.newSpendProvision.active && !row.newSpendProvision.rolling) section.append(el('p', provisionText(row)));
        if (row.endsOn) section.append(el('p', 'Projeção de novos gastos até ' + date(row.endsOn) + '; parcelas já existentes continuam.'));
        if (row.templateYear !== null) section.append(el('p', 'Calendário de referência: ' + row.templateYear + '.'));
        if (row.usesHistory) {
          section.append(el('p', 'Janela da média: ' + date(row.historyWindow.from) + ' a ' + date(row.historyWindow.to) + '.'));
          if (row.referenceStale) section.append(el('p', 'Revisão atual com ' + row.covered + ' de ' + row.expected + ' meses cobertos. A última base completa continua em uso.'));
          else if (row.spendingMonths !== null) section.append(el('p', row.covered + ' de ' + row.expected + ' meses cobertos; ' + row.spendingMonths + ' meses com gasto.'));
          if (row.outliers.length) section.append(el('p', 'Valores atípicos foram mantidos na média. Meses: ' + row.outliers.map(x => x.slice(5, 7) + '/' + x.slice(0, 4)).join(', ') + '.'));
        }
        if (String(row.dueDayBasis || '').startsWith('history_modal_day')) section.append(el('p', 'Dia de planejamento estimado pela data mais frequente do histórico; uma data documentada tem prioridade.'));
        details.append(section);
      }
      details.append(el('p', 'Faturas fechadas prevalecem. Parcelas antigas de gastos não recorrentes continuam até terminar; as reservas de novas compras não são somadas duas vezes.'));
      return details;
    }
    function panel(compact) {
      const card = el('article', null, 'v412-policy' + (compact ? ' v412-compact' : ' v168-card'));
      card.dataset.v412Policy = compact ? 'flow' : 'updates';
      const header = el('div', null, 'v412-heading');
      header.append(el(compact ? 'strong' : 'h2', state.model ? 'Projeções até ' + date(state.model.horizon) : 'Projeções futuras'));
      const button = el('button', state.status === 'queued' ? 'Atualização em andamento…' : state.status === 'refreshing' ? 'Solicitando…' : 'Atualizar projeções', 'v168-btn');
      button.type = 'button'; button.dataset.v412Refresh = ''; button.disabled = ['loading', 'refreshing', 'queued'].includes(state.status); button.onclick = () => refresh(); header.append(button); card.append(header);
      if (state.status === 'error') card.append(message('Não foi possível conferir as projeções. Atualize antes de usar as estimativas.'));
      else if (!state.model) card.append(el('p', 'Conferindo as projeções…', 'v412-loading'));
      else { const warnings = warningTexts(state.model); if (warnings.length) card.append(message('Há estimativas a conferir nas premissas.')); card.append(origin(state.model)); }
      return card;
    }
    function patchDialog() {
      const dialog = document.getElementById('v366RecurringDialog'); if (!dialog) return;
      const horizon = state.model?.horizon || (Number(new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric' }).format(new Date())) + 5) + '-12-31';
      for (const node of dialog.querySelectorAll('.v366-policy')) {
        if (node.textContent.startsWith('A continuidade cobre')) {
          const next = node.textContent.replace(/até o fim de \d{4}/, 'até ' + date(horizon));
          if (next !== node.textContent) node.textContent = next;
        }
      }
    }
    function paint() {
      reset(); if (!D || N.classList.contains('hidden')) return;
      document.querySelectorAll('[data-v412-policy]').forEach(node => node.remove());
      if (state.status !== 'disabled') {
        if (V === 'Fluxo Diário') { const parent = document.querySelector('.flow-sticky-controls'); if (parent) parent.after(panel(true)); }
        if (V === 'Atualizações') { const parent = document.querySelector('.v168-updates'); if (parent) parent.prepend(panel(false)); }
        if (V === 'Dashboard' && state.status === 'error') {
          const parent = document.querySelector('.v168-dashboard');
          if (parent) { const warning = panel(false); warning.dataset.v412Policy = 'dashboard-warning'; parent.prepend(warning); }
        }
      }
      applyHorizon();
      patchDialog();
      if (['Dashboard', 'Fluxo Diário', 'Atualizações'].includes(V)) queueMicrotask(() => load());
    }
    async function load(force = false, recalculate = false) {
      reset(); if (!D || N.classList.contains('hidden') || ['loading', 'refreshing', 'queued'].includes(state.status)
        || !force && Date.now() - state.readAt < 300000) return;
      const generation = owner, token = ++state.sequence;
      state.status = recalculate ? 'refreshing' : 'loading';
      if (recalculate) render();
      try {
        const transport = window.__LTS_V227_TRANSPORT;
        const revision = transport?.revision;
        let response = await S.rpc(recalculate ? 'lts_browser_projection_refresh_v412' : 'lts_browser_projection_policy_v412', {});
        // Bank reconciliation invalidates queued reads. Recover that read once
        // for the same session, without replaying a recalculation request.
        if (!recalculate && response.error && transport && revision !== transport.revision &&
            generation === identity() && token === state.sequence) {
          response = await S.rpc('lts_browser_projection_policy_v412', {});
        }
        if (response.error) throw Error();
        if (generation !== identity() || token !== state.sequence) return;
        if (recalculate && response.data?.refresh && window.__LTS_V415_REFRESH) {
          window.__LTS_V415_REFRESH.observeRefresh(response.data.refresh);
          if (!window.LTSV415ProductRefresh.ready(response.data.refresh)) {
            state.status = 'queued'; state.readAt = Date.now();
            if (response.data.version === 'projection-policy-v412') state.model = api.build(response.data);
            if (typeof toast === 'function') toast('Atualização solicitada.');
            return;
          }
        }
        const model = api.build(response.data);
        if (generation !== identity() || token !== state.sequence) return;
        const wasEnabled = !!state.model;
        state.model = model; state.status = model ? (recalculate ? 'refreshing' : 'ready') : 'disabled'; state.readAt = Date.now();
        if (model) applyHorizon();
        if (!model && wasEnabled) {
          state.consumerSequence++; state.horizonKey = null;
          window.__LTS_V227_TRANSPORT?.invalidate?.();
          if (ui?.updates) { ui.updates.token = (ui.updates.token || 0) + 1; ui.updates.recurring = null; ui.updates.loading = false; }
          if (ui?.dashboard?.data) delete ui.dashboard.data.recurring;
          await window.__LTS_V178_REVIEW?.refreshForecast?.();
          if (V === 'Fluxo Diário' && FLOWQ?.from && FLOWQ?.to) await loadFlowRange(FLOWQ.from, FLOWQ.to);
        }
        if (recalculate && model) {
          window.__LTS_V227_TRANSPORT?.invalidate?.();
          await refreshConsumers();
          if (V === 'Fluxo Diário' && typeof loadFlowRange === 'function') {
            const from = FLOWQ?.from, to = FLOWQ?.to;
            if (from && to) await loadFlowRange(from, to);
          }
        }
      } catch {
        if (generation === identity() && token === state.sequence) { state.model = null; state.status = 'error'; state.readAt = Date.now(); }
      } finally { if (generation === identity() && token === state.sequence) {
        if (state.status === 'refreshing') state.status = state.model ? 'ready' : 'disabled';
        render();
      } }
    }
    async function refresh() { return load(true, true); }
    const style = document.createElement('style'); style.textContent = '.v412-policy{box-sizing:border-box;margin:10px 0;padding:12px 14px;border:1px solid #dbe3eb;border-radius:12px;background:#fff;color:#20364b;max-width:100%}.v412-heading{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}.v412-heading h2{font-size:18px;margin:0}.v412-heading>strong{font-size:14px}.v412-heading button{min-height:40px}.v412-origin{font-size:12px;line-height:1.45;margin-top:7px}.v412-origin>summary{cursor:pointer;color:#52677a}.v412-origin p{margin:7px 0}.v412-rule{padding:10px 0;border-bottom:1px solid #e4eaf0}.v412-rule h3{font-size:13px;margin:0 0 5px}.v412-rule strong{white-space:nowrap}.v412-warning{color:#79500a;background:#fff7e5;padding:8px;border-radius:8px;font-size:12px;line-height:1.45;margin:8px 0}.v412-loading{font-size:12px;margin:7px 0}@media(max-width:400px){.v412-policy{padding:10px}.v412-heading{gap:7px}.v412-heading button{font-size:12px}}'; document.head.append(style);
    render = function () { const result = previous.apply(this, arguments); paint(); return result; };
    Object.assign(state, { load, refresh }); window.__LTS_V412_PROJECTION = state;
    window.addEventListener('lts:product-refresh-ready', () => {
      reset(); if (!D || N.classList.contains('hidden')) return;
      state.status = 'idle'; state.readAt = 0;
      load(true, false).then(() => { if (state.model && state.status === 'ready') refreshConsumers(); });
    });
    const observer = new MutationObserver(patchDialog); observer.observe(document.body, { childList: true, subtree: true });
    paint();
  }
  function install() {
    try { const w = shell?.contentWindow, d = shell?.contentDocument; if (!w?.__LTS_V411_RSU) return false;
      if (!w.__LTS_V412_PROJECTION) { const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script); }
      return !!w.__LTS_V412_PROJECTION;
    } catch { return false; }
  }
  let attempts = 0; function start() { if (!install() && ++attempts < 400) setTimeout(start, 100); }
  shell?.addEventListener('load', () => { attempts = 0; start(); }); start();
  window.LTSV339Boot?.watch('lts-v412-projection-policy.js', install);
})();


;
/* lts-v417-clean-reports.js */
/* Shorten only known process notices. Preserve failures, controls and financial content. */
(function () {
  'use strict';
  function clean(doc) {
    for (const p of doc.querySelectorAll('.v168-note.warn')) {
      const b=p.querySelector('[data-v333-actions-refresh]');
      if (!b || !p.textContent.startsWith('Não foi possível atualizar todas as ações.')) continue;
      for (const n of [...p.childNodes]) if (n.nodeType===3 && n.textContent.includes('Não foi possível atualizar todas as ações.')) n.textContent=n.textContent.replace('Não foi possível atualizar todas as ações.', 'Não foi possível atualizar as pendências.');
      b.textContent='Tentar novamente';
    }
    for (const span of doc.querySelectorAll('.v168-loadstatus span')) {
      const text=span.textContent;
      if (/^Resumo já disponível\.\s*Atualizando os detalhes sem apagar os valores exibidos…$/.test(text)) span.textContent='Atualizando…';
      if (/^Resumo preservado\.\s*\d+ leitura\(s\) não atualizaram; nenhuma informação anterior foi apagada\.$/.test(text)) span.textContent='Alguns dados não atualizaram.';
    }
  }
  if (typeof module!=='undefined' && module.exports) { module.exports={clean}; return; }
  const shell=document.getElementById('shell');
  function install() {
    try {
      const doc=shell?.contentDocument, win=shell?.contentWindow;
      if (!doc?.body || win.__LTS_V417_CLEAN_REPORTS?.body===doc.body) return;
      win.__LTS_V417_CLEAN_REPORTS?.observer?.disconnect();
      let queued=false;
      const update=()=>{queued=false;clean(doc);};
      const observer=new MutationObserver(()=>{if(!queued){queued=true;win.requestAnimationFrame(update);}});
      observer.observe(doc.body,{subtree:true,childList:true});
      win.__LTS_V417_CLEAN_REPORTS={installed:true,body:doc.body,observer,clean:()=>clean(doc)};
      update();
    } catch (_) { /* A navigation is retried at its load event. */ }
  }
  shell?.addEventListener('load',install); install();
})();

;
/* lts-v423-clarity.js */
/* Disclose pending bank evidence on demand; never insert a cash movement. */
(function(){'use strict';
 const outer=document.getElementById('shell');let generation=0;
 function runtime(){'use strict';
  if(window.__LTS_V423_CLARITY)return;
  const M=parent.LTSV423Clarity;let memo=null,flight=null,ticket=0,product=D,identity=BOOT?.generation;
  const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const money=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n),date=d=>String(d||'').split('-').reverse().join('/');
  const oldTitle=flowSemanticTitle,oldMeta=flowSemanticMeta;
  flowSemanticTitle=function(e){return M.cardLabel(e)?.title||oldTitle(e)};
  flowSemanticMeta=function(e){return M.cardLabel(e)?.note||oldMeta(e)};
  const style=document.createElement('style');style.textContent='.v423-subgroups{padding:12px 16px;border-bottom:1px solid #dbe3ec}.v423-subgroups h3{margin:0 0 9px;font-size:15px}.v423-group-list{display:grid;gap:7px;max-height:220px;overflow:auto}.v423-group-list button{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;text-align:left;background:#f6f8fa;border:1px solid #dbe3ec;border-radius:9px;padding:10px 12px;min-height:44px;color:inherit}.v423-group-list button[aria-pressed=true]{border-color:#2563eb;background:#eef5ff}.v423-group-list span{min-width:0;overflow-wrap:anywhere}.v423-group-list strong{white-space:nowrap}.v423-group-list small{display:block;font-size:12px;color:#64748b;margin-top:4px}.v423-bank-evidence .v365-pair small{display:block}.v423-bank-evidence p{font-size:13px;margin:9px 0}.v423-bank-evidence details{font-size:12px}.v423-bank-evidence h3{font-size:15px}.v423-bank-evidence .v365-pair{gap:12px}.v423-bank-evidence .v365-pair span{min-width:0;overflow-wrap:anywhere}';document.head.appendChild(style);
  function clear(){ticket++;memo=null;flight=null;}
  const status=window.__LTS_V423_CLARITY={installed:true,financialWrites:0,clear};
  function renderEvidence(day,root){
   if(!memo)return;
   for(const bank of ['Itaú','Bradesco','C6']){
    if(ACC!=='Consolidado'&&ACC!==bank)continue;
    const b=M.bridge(day,memo,bank);if(!b)continue;
    const old=[...root.querySelectorAll('.v365-bridge')].find(x=>x.querySelector('h3')?.textContent.startsWith(bank+' ·'));
    if(!old)continue;
    old.classList.add('v423-bank-evidence');old.dataset.v423='pending';
    const line=(label,value,when='')=>'<div class="v365-pair"><span>'+esc(label)+(when?'<small>'+esc(when)+'</small>':'')+'</span><b>'+money(value)+'</b></div>';
    old.innerHTML='<h3>'+esc(bank)+' · movimentos em confirmação</h3>'+line('Saldo calculado antes da conciliação',b.opening)+b.movements.map(m=>line(m.description,m.amount,date(m.date))).join('')+line('Saldo informado pelo banco',b.observed)+'<p>Os valores explicam a diferença. A confirmação dos lançamentos pelo banco ainda está pendente.</p><details><summary>Origem</summary><p>Posição bancária de '+esc(date(b.sourceDate))+'. Estes movimentos ainda não foram marcados como liquidados.</p></details>';
    const row=document.getElementById('d-'+day.date);const note=row?.querySelector('.v365-balance-status');if(note)note.textContent='Movimentos em confirmação';
   }
  }
  function update(){
   if(product!==D||identity!==BOOT?.generation){product=D;identity=BOOT?.generation;clear();}
   document.querySelectorAll('.v365-bridge,.v423-bank-evidence').forEach(node=>node.remove());
  }
  const previous=render;render=function(...args){const value=previous.apply(this,args);update();return value;};
  for(const name of ['signOut','signInWithPassword']){const prior=S.auth[name];if(typeof prior==='function')S.auth[name]=function(...a){clear();return prior.apply(this,a)};}
  update();
 }
 function install(){try{const w=outer?.contentWindow,d=outer?.contentDocument;if(!w?.__LTS_V365?.installed||!w.__LTS_V178_REVIEW?.installed)return false;if(!w.__LTS_V423_CLARITY){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.appendChild(s);}return !!w.__LTS_V423_CLARITY;}catch{return false}}
 function burst(){const k=++generation;let n=0;function step(){if(k!==generation)return;if(!install()&&++n<320)setTimeout(step,100)}step();}
 outer?.addEventListener('load',burst);burst();
})();

;
/* lts-v425-flow-options.js */
/* Presentation only. Existing readers, amounts, controls and handlers are unchanged. */
(function(){
 'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V425_FLOW_OPTIONS)return;
  const previous=render;let lastView=null,queued=false;
  function materialReasons(){
   const reasons=[],p=window.__LTS_V412_PROJECTION,r=window.__LTS_V411_RSU;
   if(p?.status==='error')reasons.push('Não foi possível atualizar a previsão.');
   else if(p?.model?.series?.some(s=>s.amount===null&&s.usesHistory||s.warnings?.some(w=>['unreconciled_periods','calendar_unavailable'].includes(w))))reasons.push('Há previsões incompletas.');
   if(r?.status==='error')reasons.push('Líquido das ações a conferir.');
   return reasons;
  }
  function paint(){
   queued=false;
   const entering=lastView!=='Fluxo Diário';lastView=V;
   if(V!=='Fluxo Diário'||!D||N.classList.contains('hidden'))return;
   const tools=document.querySelector('.v382-tools'),body=tools?.querySelector('.v382-tool-body'),controls=document.querySelector('.flow-sticky-controls');
   if(!body||!controls)return;
   tools.classList.add('v425-options');body.classList.add('v425-options-body');
   if(entering)tools.open=false;
   const summary=tools.querySelector(':scope>summary');summary.setAttribute('aria-label','Opções do Fluxo');
   function move(node,key){
    if(!node)return;
    const existing=body.querySelector('[data-v425-section="'+key+'"]');
    if(existing&&existing!==node)existing.remove();
    node.dataset.v425Section=key;
    if(node.parentElement!==body){if(node.tagName==='DETAILS')node.open=false;body.appendChild(node);}
   }
   move(controls.querySelector('.v225-balance-freshness>.lts-update-details'),'sources');
   move(document.querySelector('[data-v412-policy="flow"]'),'projection');
   move(document.querySelector('[data-v411-flow-policy]'),'rsu');
   move(document.getElementById('v402-d01-origin'),'applications');
   // Empty provenance containers occupy no vertical space. Their material
   // freshness warnings remain outside the options, with original semantics.
   for(const host of controls.querySelectorAll('.v225-balance-freshness'))host.classList.toggle('v425-empty',!host.textContent.trim());
   const reasons=materialReasons(),signature=reasons.join(' ');let notice=document.getElementById('v425-flow-attention');
   if(!signature){notice?.remove();return;}
   if(!notice){notice=document.createElement('div');notice.id='v425-flow-attention';notice.setAttribute('role','status');controls.after(notice);}
   if(notice.dataset.message!==signature){
    notice.dataset.message=signature;const text=document.createElement('span');text.textContent=signature;
    const button=document.createElement('button');button.type='button';button.textContent='Revisar';
    button.onclick=()=>{const t=document.querySelector('.v382-tools');if(!t)return;t.open=true;const target=t.querySelector('.v412-origin');if(target)target.open=true;t.querySelector(':scope>summary')?.focus();};
    notice.replaceChildren(text,button);
   }
  }
  function schedule(){if(!queued){queued=true;queueMicrotask(paint);}}
  render=function(){const result=previous.apply(this,arguments);paint();return result;};
  const observer=new MutationObserver(schedule);observer.observe(document.body,{subtree:true,childList:true});
  document.addEventListener('keydown',event=>{const tools=document.querySelector('.v382-tools.v425-options');if(event.key==='Escape'&&tools?.open){tools.open=false;tools.querySelector(':scope>summary')?.focus();event.preventDefault();}});
  document.addEventListener('pointerdown',event=>{const tools=document.querySelector('.v382-tools.v425-options');if(tools?.open&&!tools.contains(event.target))tools.open=false;});
  const style=document.createElement('style');style.textContent=`
   .v425-options>.v382-tool-body{width:380px;max-width:calc(100vw - 28px);max-height:65vh;max-height:65dvh;overflow:auto;overscroll-behavior:contain;box-sizing:border-box;text-align:left}
   .v425-options-body>[data-v425-section]{border:0!important;border-top:1px solid #e2e8f0!important;border-radius:0!important;margin:10px 0 0!important;padding:10px 0 0!important;min-width:0;max-width:100%;box-sizing:border-box}
   .v425-options-body>details>summary,.v425-options-body .v412-origin>summary{min-height:44px;display:flex;align-items:center;cursor:pointer;font-size:14px;line-height:1.4}
   .v425-options-body .v412-heading>strong{display:none}
   .v425-options-body .v412-heading{display:block}
   .v425-options-body .v412-heading button{width:100%;min-height:44px}
   .v425-options-body .v412-origin{margin-top:0}
   .v425-options-body p{overflow-wrap:anywhere}
   .v425-options-body .v225-freshness-bank{min-width:0}
   .flow-sticky-controls .v425-empty{display:none!important}
   #v425-flow-attention{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:8px 0;padding:8px 12px;border:1px solid #e7ce95;border-radius:10px;background:#fff8e8;color:#76500d;font-size:13px;line-height:1.4}
   #v425-flow-attention button{min-height:44px;flex:none;padding:8px 12px;border:1px solid #c9d5e2;border-radius:8px;background:#fff;color:#18344f;font-weight:600;cursor:pointer}
   @media(max-width:380px){.v425-options>.v382-tool-body{max-width:calc(100vw - 24px)}#v425-flow-attention{flex-wrap:wrap}}
  `;document.head.appendChild(style);
  window.__LTS_V425_FLOW_OPTIONS={installed:true,presentation_only:true,paint,materialReasons};paint();
 }
 function install(){try{
  const w=shell?.contentWindow,d=shell?.contentDocument;
  if(!w?.__LTS_V382_FLOW_LAYOUT||!w?.__LTS_V412_PROJECTION||!w?.__LTS_V402_D01)return false;
  if(w.__LTS_V425_FLOW_OPTIONS)return true;
  const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.append(script);return !!w.__LTS_V425_FLOW_OPTIONS;
 }catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100)}
 shell?.addEventListener('load',()=>{tries=0;start()});start();window.LTSV339Boot?.watch('lts-v425-flow-options.js',install);
})();

;
/* lts-v441-budget-model.js */
(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV441Budget=api;})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const cents=v=>typeof v!=='number'&&!(typeof v==='string'&&/^[+-]?\d+(\.\d+)?$/.test(v))?null:Number.isFinite(Number(v))&&Number.isSafeInteger(Math.round(Number(v)*100))?Math.round(Number(v)*100):null;
 const sum=xs=>xs.some(x=>x===null)?null:xs.reduce((a,b)=>a+b,0);
 const nullable=(v,positive=false)=>{const n=cents(v);if(v!==null&&(n===null||positive&&n<0))throw Error('invalid amount');return n;};
 function build(p){
  if(!p||p.ok!==true||p.version!=='budget-v441'||!Number.isInteger(p.year)||!/^\d{4}-\d{2}-\d{2}$/.test(p.as_of||'')
   ||!Number.isSafeInteger(p.plan_revision)||p.plan_revision<0||p.flow_provision_included!==false||p.basis!=='canonical_consumption_not_card_payment'
   ||!Array.isArray(p.rows)||!Array.isArray(p.months)||p.months.length!==12||!p.reference)throw Error('budget unavailable');
  const keys=Array.from({length:12},(_,i)=>p.year+'-'+String(i+1).padStart(2,'0')),seen=new Set();
  const rows=p.rows.map(r=>{
   if(typeof r.category!=='string'||!r.category.trim()||r.category.length>120||seen.has(r.category)||!Array.isArray(r.months)||r.months.length!==12)throw Error('invalid category');
   seen.add(r.category);
   return {category:r.category,reference:nullable(r.reference_monthly,true),months:r.months.map((m,i)=>{
    if(m.month!==keys[i]||!['owner','history','proposal'].includes(m.target_basis))throw Error('invalid month');
    return {month:m.month,target:nullable(m.target,true),actual:nullable(m.actual),pending:nullable(m.pending),basis:m.target_basis,strategy:m.strategy||null};
   })};
  });
  const months=p.months.map((m,i)=>{
   if(m.month!==keys[i]||typeof m.started!=='boolean'||typeof m.complete!=='boolean')throw Error('invalid month');
   const v={month:m.month,target:nullable(m.target,true),actual:nullable(m.actual),pending:nullable(m.pending),incomeTarget:nullable(m.income_target,true),
    incomeRegular:nullable(m.income_regular),extra:nullable(m.income_extraordinary),bonus:nullable(m.income_bonus??0),thirteenth:nullable(m.income_thirteenth??0),started:m.started,complete:m.complete};
   if(sum(rows.map(r=>r.months[i].actual))!==v.actual||sum(rows.map(r=>r.months[i].pending))!==v.pending||(rows.length?sum(rows.map(r=>r.months[i].target)):null)!==v.target)throw Error('totals mismatch');
   return v;
  });
  return {year:p.year,asOf:p.as_of,revision:p.plan_revision,proposed:p.proposed===true,rows,months,
   reference:{from:p.reference.from,to:p.reference.to,months:p.reference.months,expected:p.reference.expected_months,salaryMonths:p.reference.salary_months,salaryMonthly:nullable(p.reference.salary_monthly,true)},
   strategy:p.strategy||null,unknown:nullable(p.unclassified_actual),incomeGroups:p.actual_income_groups||[]};
 }
 function view(m,mode,month){
  const indices=mode==='year'?m.months.map((_,i)=>i):[Number(month.slice(5,7))-1];
  if(indices.some(i=>i<0||i>11)||month.slice(0,4)!==String(m.year))throw Error('invalid period');
  const cashUnallocated=(m.strategy?.cash_without_competence||[]).filter(x=>indices.some(i=>String(x.date).slice(0,7)===m.months[i].month)),cashWithoutCompetence=sum(cashUnallocated.map(x=>cents(x.amount)));
  const selected=indices.map(i=>m.months[i]),target=cashUnallocated.length?null:sum(selected.map(x=>x.target)),actual=sum(selected.map(x=>x.actual)),incomeTarget=sum(selected.map(x=>x.incomeTarget)),incomeRegular=sum(selected.map(x=>x.incomeRegular)),extra=sum(selected.map(x=>x.extra));
  const defined=m.rows.flatMap(r=>indices.map(i=>r.months[i].target)).filter(x=>x!==null),proposedSubtotal=defined.length?sum(defined):null;
  return {proposedSubtotal,proposedDeficit:proposedSubtotal!==null&&incomeTarget!==null?Math.max(0,proposedSubtotal-incomeTarget):null,unplannedCategories:m.rows.filter(r=>indices.some(i=>r.months[i].target===null)).length,cashUnallocated,cashWithoutCompetence,cashCoverageGap:cashUnallocated.length&&incomeTarget!==null?Math.max(0,cashWithoutCompetence-incomeTarget):null,hasIncompletePlan:cashUnallocated.length>0||selected.some(x=>x.target===null),target,actual,incomeTarget,incomeRegular,extra,bonus:sum(selected.map(x=>x.bonus)),thirteenth:sum(selected.map(x=>x.thirteenth)),minimum:sum(m.rows.map(r=>sum(indices.map(i=>cents(r.months[i].strategy?.floor??0))))),pending:sum(selected.map(x=>x.pending)),
   plannedBalance:target===null||incomeTarget===null?null:incomeTarget-target,
   operating:incomeRegular===null||actual===null?null:incomeRegular-actual,
   afterExtras:incomeRegular===null||actual===null||extra===null?null:incomeRegular+extra-actual,
   started:selected.some(x=>x.started),complete:selected.every(x=>x.complete),
   rows:m.rows.map(r=>({category:r.category,reference:r.reference,target:sum(indices.map(i=>r.months[i].target)),actual:sum(indices.map(i=>r.months[i].actual)),
    gap:sum(indices.map(i=>r.months[i].target))===null?null:sum(indices.map(i=>r.months[i].target))-sum(indices.map(i=>r.months[i].actual)),
    type:r.months[indices[0]].strategy?.type||'unreviewed',reason:r.months[indices[0]].strategy?.reason||'',minimum:sum(indices.map(i=>cents(r.months[i].strategy?.floor??0))),details:indices.flatMap(i=>r.months[i].strategy?.details||[]),needsReview:indices.some(i=>r.months[i].strategy?.needsReview===true),suggested:indices.some(i=>r.months[i].basis==='history'||r.months[i].basis==='proposal')}))};
 }
 function flow(p,asOf){
  const days=p?.current_future?.days;if(!Array.isArray(days))return null;
  const vals=days.filter(d=>/^\d{4}-\d{2}-\d{2}$/.test(d.date)&&d.date>=asOf).sort((a,b)=>a.date.localeCompare(b.date));
  if(!vals.length)return null;
  const extract=d=>({date:d.date,bank:cents(d.fix86_columns?.saldo_final??d.Consolidado?.bank_balance),liquid:cents(d.fix86_columns?.saldo_apos_d0_1),shares:cents(d.fix86_columns?.saldo_apos_rsu),restricted:cents(d.fix86_columns?.saldo_apos_fgts)});
  const rows=vals.map(extract),limit=new Date(asOf+'T12:00:00Z');limit.setUTCDate(limit.getUTCDate()+90);const end=limit.toISOString().slice(0,10),short=rows.filter(x=>x.date<=end);
  const first=key=>{if(!short.length||short.some(x=>x[key]===null))return {known:false,date:null,amount:null};const r=short.find(x=>x[key]<0);return {known:true,date:r?.date||null,amount:r?.[key]??null};};
  return {asOf,through:short.at(-1)?.date||null,today:rows.find(x=>x.date===asOf)||null,bank:first('bank'),liquid:first('liquid'),shares:first('shares'),restricted:first('restricted')};
 }
 return Object.freeze({build,view,flow,cents,sum});
});

;
/* lts-v442-strategy.js */
(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.LTSV442Strategy=api;})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const norm=x=>String(x||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
 const cents=x=>x===null||x===undefined||!Number.isFinite(Number(x))?null:Math.round(Number(x)*100),money=x=>x===null?null:x/100;
 const sum=xs=>xs.some(x=>x===null)?null:xs.reduce((a,b)=>a+b,0),round=x=>Math.ceil(x/1000)*1000;
 function kind(category){const c=norm(category);
  if(/financiamento|emprestimo|compromissos financeiros|condominio|seguro|assinatura|anuidade|armazenamento|spotify|google/.test(c))return'fixed';
  if(/ipva|iptu|impostos|tributos|licenciamento|viagen|passagem|hotel|duty free|batizado|casamento|eventos|documentos/.test(c))return'seasonal';
  if(/brinquedo|presente|vestuario|restaurante|ifood|rappi|bebida|cabele|cabeler|passeio|lazer|mercado livre|amazon|apple|moveis|decoracao|doacao/.test(c))return'discretionary';
  if(/saude|farmacia|educacao|aulas|mercado$|alimentacao|energia|enel|combustivel|rafiki|moradia|familia|benjamin/.test(c))return'essential';
  return'unreviewed';
 }
 function derive(input,flow,cards){
  if(!input||input.ok!==true||!Array.isArray(input.rows)||!Array.isArray(input.months)||input.months.length!==12)throw Error('budget unavailable');
  const p=structuredClone(input),asOf=p.as_of,current=asOf.slice(0,7),year=p.year,events=flow?.flow?.current_future?.events??flow?.current_future?.events;
  const cf=flow?.flow?.current_future??flow?.current_future,cardRows=cards?.cards;if(!Array.isArray(events)||!Array.isArray(cardRows)||cards.complete===false||!p.income_approvals||!p.category_aliases||Array.isArray(p.category_aliases)||typeof p.category_aliases!=='object')throw Error('commitments or approval metadata unavailable');
  if(year>=Number(asOf.slice(0,4))&&(flow.complete===false||cf.complete===false||!cf.from||cf.from>asOf||!cf.to||cf.to<year+'-12-31'))throw Error('commitment horizon incomplete');
  const amounts=new Map(),cardAmounts=new Map(),evidence=new Map(),withheld=[],unallocatedCash=[],unmapped=[],knownKeys=new Set(p.rows.map(r=>r.category)),seen=new Set(),salary=new Map();
  const key=(m,c)=>m+'\u0000'+c,categoryFor=c=>{if(knownKeys.has(c))return c;if(knownKeys.has(p.category_aliases[c]))return p.category_aliases[c];
   // Two established Portuguese labels for the same mortgage category. This
   // changes only planning assignment, never the original event or its amount.
   if(norm(c)==='financiamento imovel'){const same=[...knownKeys].filter(x=>norm(x)==='financiamento imobiliario');if(same.length===1)return same[0];}return c;};
  // Carry an existing decision only for the same identified purchase. A person
  // prefix or a similar merchant is never authority for a global category alias.
  const cardCategory=item=>{
   // The backend uses this one explicit unknown bucket. This keeps a received
   // unclassified item in that bucket without inventing a purpose or person.
   if(['a classificar','sem categoria','nao identificado','—',''].includes(norm(item.category)))return 'Sem classificação';
   const matches=(p.card_category_evidence||[]).filter(e=>
    typeof item.source_id==='string'&&item.source_id&&e.source_ref===item.source_id&&
    e.raw_category===item.category&&e.purchase_date===(item.purchase_date||item.posting_date)&&
    cents(e.amount)===cents(item.amount)&&typeof e.category==='string'&&e.category.trim());
   const categories=[...new Set(matches.map(e=>e.category))];
   return categories.length===1?categories[0]:item.category;
  };
  const add=(month,category,amount,detail)=>{if(!new RegExp('^'+year+'-(0[1-9]|1[0-2])$').test(month)||amount===0||amount<0&&!['installment','card_commitment'].includes(detail.kind))return;
   category=categoryFor(category);
   if(!category||!knownKeys.has(category)){unmapped.push({month,category:category||'Compromisso sem categoria',amount:money(amount),...detail});return;}
   const k=key(month,category),map=['installment','card_commitment'].includes(detail.kind)?cardAmounts:amounts;map.set(k,(map.get(k)||0)+amount);const a=evidence.get(k)||[];a.push({...detail,amount:money(amount)});evidence.set(k,a);
  };
  for(const e of events){const n=cents(e.signed_amount),description=e.description||'',c=norm(description+' '+e.category),source=String(e.source||'');
   if(n!==null&&n>0&&String(e.event_date)>asOf&&/^(salario( liquido)?|adiantamento quinzenal)$/.test(norm(description))&&!/bonus|13[º°o]?|decimo|ferias/.test(c)){const mk=String(e.event_date).slice(0,7);salary.set(mk,(salary.get(mk)||0)+n);}
   if(n===null||n>=0||e.internal_transfer||e.is_asset_movement||e.excluded_from_spend||/card|invoice|budget|historical_spending|projection_policy|planning_projection/.test(source)||/fatura|aeternum|mastercard|personnalite|c6 carbon/.test(c))continue;
   // Missing, blank, boolean or negative payroll amounts cannot prove a net deduction.
   const payrollAmount=v=>(typeof v==='number'||typeof v==='string'&&v.trim()!=='')&&cents(v)!==null&&cents(v)>=0;
   const payrollProof=(p.planning?.payroll_withholding||[]).find(w=>payrollAmount(w.base_income)&&payrollAmount(w.net_income)&&typeof e.source==='string'&&e.source.length>0&&typeof e.source_ref==='string'&&e.source_ref.length>0&&w.source===e.source&&w.source_ref===e.source_ref&&w.date===e.event_date&&cents(w.amount)===-n&&cents(w.base_income)-cents(w.net_income)===-n&&Array.isArray(w.evidence)&&w.evidence.some(v=>typeof v==='string'&&v.trim()));
   if(payrollProof){withheld.push({description,amount:money(-n),date:e.event_date,evidence:payrollProof.evidence});continue;}
   // A lender name alone is not evidence that net income already includes its payment.

   const proof=/coopharma|consignado|financiamento|emprestimo|condominio|seguro|iptu|ipva|licenciamento|mensalidade|parcela/.test(c)||e.confidence==='user_flow_editable'||e.confidence==='documented_scheduled';
   if(String(e.event_date)<asOf||String(e.event_date)===asOf&&!['user_flow_editable','legacy_projection_adjusted','documented_scheduled','documented_expected'].includes(e.confidence))continue;
   const identity=source+':'+e.source_ref+':'+e.event_date;if(seen.has(identity))continue;seen.add(identity);
   // Payment date is not service competence. Keep uncertain cash visible but separate.
   const competence=String(e.competence_month||'').slice(0,7),hasCompetence=proof&&/^\d{4}-(0[1-9]|1[0-2])$/.test(competence)&&Array.isArray(e.competence_evidence)&&e.competence_evidence.length>0&&e.competence_evidence.every(x=>typeof x==='string'&&x.trim());
   if(!hasCompetence){unallocatedCash.push({description,date:e.event_date,category:e.category,amount:money(-n),source:e.source,source_ref:e.source_ref,reason:'Data de pagamento conhecida; competência do serviço ainda não comprovada.'});continue;}
   add(competence,e.category,-n,{description,date:e.event_date,competence_month:competence,competence_evidence:e.competence_evidence,kind:'scheduled',contracted:/financiamento|emprestimo|parcela/.test(c)});
  }
  for(const card of cardRows)for(const cycle of card.cycles||[])for(const item of cycle.items||[]){
   const installment=Number(item.total_installments)>1;
   const received=['PENDING','POSTED','DOCUMENTED'].includes(item.provider_status);
   if((!installment&&!received)||item.is_payment)continue;
   const itemAmount=cents(item.amount);if(itemAmount===null)throw Error('card commitment amount unavailable');if(itemAmount===0)continue;
   const month=String(item.reference_month||cycle.month||'').slice(0,7),identity=[card.family,month,item.source_id,item.installment_number].join(':');
   if(!item.source_id||seen.has(identity))continue;seen.add(identity);
   add(month,cardCategory(item),itemAmount,{description:item.description,date:item.purchase_date||item.posting_date,source_ref:item.source_id,kind:installment?'installment':'card_commitment',installment:item.installment_number,total_installments:item.total_installments,contracted:true});
  }
  // Unknown obligations remain explicit. They are never silently converted to zero.
  const extraCategories=[...new Set(unmapped.map(x=>x.category))].filter(c=>!knownKeys.has(c));
  for(const category of extraCategories){knownKeys.add(category);p.rows.push({category,reference_monthly:null,commitments_only:true,months:p.months.map(m=>({month:m.month,actual:0,card_actual:0,pending:0,target:null,target_basis:'history'}))});}
  for(const x of unmapped){const k=key(x.month,x.category),map=['installment','card_commitment'].includes(x.kind)?cardAmounts:amounts;map.set(k,(map.get(k)||0)+cents(x.amount));evidence.set(k,[...(evidence.get(k)||[]),x]);}
  const plans=[];
  for(let i=0;i<12;i++){
   const m=p.months[i],past=m.month<current,rows=[];
   const incomeApproved=p.income_approvals.year===true||p.income_approvals.months?.[m.month]===true;
   if(!incomeApproved&&salary.has(m.month))m.income_target=money(salary.get(m.month)+(m.month===current?(cents(m.income_regular)||0):0));
   const income=cents(m.income_target);
   for(const r of p.rows){const x=r.months[i],type=kind(r.category),history=cents(r.reference_monthly),owner=x.target_basis==='owner',scheduled=amounts.get(key(m.month,r.category))||0,card=cardAmounts.get(key(m.month,r.category))||0;
    if(m.month===current&&card>0&&x.card_actual===undefined)throw Error('recorded card coverage unavailable');
    const floor=Math.max(0,m.month===current?(cents(x.actual)||0)+scheduled+Math.max(0,card-(cents(x.card_actual)||0)):scheduled+card),details=evidence.get(key(m.month,r.category))||[];
    let proposed=null,reason='',desired=0;
    if(owner){proposed=cents(x.target);reason='Meta aprovada por você; preservada.';}
    else if(past){reason='Sem orçamento aprovado para este mês encerrado.';}
    else {
     // A reference is descriptive, not a recommendation. A reviewed proposal
     // must carry a reason and source evidence, separately from owner approval.
     const plan=p.planning?.months?.[m.month]?.[r.category];
     const reviewed=plan&&plan.status==='reviewed_proposal'&&typeof plan.reason==='string'&&plan.reason.trim()&&Array.isArray(plan.evidence)&&plan.evidence.length>0&&plan.evidence.every(e=>typeof e==='string'&&e.trim());
     if(reviewed&&cents(plan.target)!==null&&cents(plan.target)>=0){
      proposed=Math.max(floor,cents(plan.target));reason=plan.reason+(cents(plan.target)<floor?' Proposta elevada ao já registrado e aos compromissos conhecidos.':'');
     }else if(type==='fixed'&&details.length&&history===null){
      proposed=null;reason='Compromissos identificados são o piso, não prova de cobertura integral da categoria. Falta proposta revisada.';
     }else{
      proposed=null;reason='Referência histórica e compromissos disponíveis para planejamento. Falta proposta fundamentada por categoria; nenhum corte ou meta zero foi presumido para fechar a renda.';
     }
    }
    rows.push({row:r,value:x,type,owner,floor,proposed,desired,reason,details,history});
   }
   for(const r of rows){let value=r.proposed;
    r.value.target=money(value);r.value.target_basis=r.owner?'owner':'proposal';
    r.value.strategy={type:r.type,reason:r.reason,floor:money(r.floor),history:money(r.history),details:r.details,proposed:!r.owner,needsReview:!r.owner&&r.proposed===null};
   }
   m.target=money(sum(rows.map(r=>cents(r.value.target))));
   plans.push({month:m.month,fixed:money(rows.reduce((a,r)=>a+r.floor,0)),income:money(income),target:m.target,
    balance:m.target===null||income===null?null:money(income-cents(m.target)),covered:!past||rows.some(r=>r.owner)});
  }
  p.strategy={version:'strategic-v442',proposals:true,pastWithoutPlan:plans.filter(x=>!x.covered).length,regular_income_basis:'net_received_without_bonus_or_thirteenth',months:plans,
   payroll_withheld_not_added:withheld,cash_without_competence:unallocatedCash,unmapped_obligations:unmapped,flow_provision_included:false,
   proposal_review:p.planning?.status||'missing',reviewed_at:p.planning?.reviewed_at||null,
   alternatives:['Preservar parcelas e compromissos já assumidos.','Comparar alternativas de redução com valores e consequências; não zerar categorias automaticamente.','Rever gastos essenciais pelo detalhe e renegociar contratos quando possível.','Usar bônus e 13º apenas como cobertura extraordinária, sem incorporá-los ao salário mensal.']};
  p.proposed=p.rows.some(r=>r.months.some(m=>m.target_basis==='proposal'&&m.target!==null));return p;
 }
 return Object.freeze({derive,kind});
});


;
/* lts-v441-budget-ui.js */
(function(){'use strict';
 const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V441_BUDGET||!window.__LTS_V337_MONTH||!window.parent.LTSV441Budget)return;
  const api=window.parent.LTSV441Budget,strategy=window.parent.LTSV442Strategy,previous=render;
  const s={owner:null,month:'',parentMonth:null,mode:'month',status:'idle',data:null,sequence:0,queued:false,dialog:null};
  const day=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const gen=()=>typeof BOOT==='object'?BOOT.generation:D;
  const visible=()=>!!D&&!N.classList.contains('hidden')&&V==='Despesas'&&window.__LTS_V168_STATE?.expense?.tab==='monthly';
  const money=v=>v===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v/100);
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function sync(){
   if(s.owner!==gen()||!D){s.owner=gen();s.sequence++;s.status='idle';s.data=null;s.parentMonth=null;s.dialog?.remove();s.dialog=null;}
   if(!s.month)s.month=day().slice(0,7);
  }
  function setMonth(v){if(!/^\d{4}-\d{2}$/.test(v))return;if(s.month.slice(0,4)!==v.slice(0,4)){s.sequence++;s.status='idle';s.data=null;}s.month=v;}
  async function load(force=false){
   sync();
   // A confirmed save can finish while an older budget read is still in flight.
   // Settle that read before requesting the saved revision; never reuse it.
   if(force&&s.status==='loading'&&s.request){const old=s.request,owner=s.owner;s.sequence++;await Promise.resolve(old).catch(()=>{});if(owner!==gen())return;sync();if(s.request===old)s.status='idle';}
   if(!visible()||s.status==='loading'||!force&&s.status!=='idle')return;
   const owner=s.owner,year=Number(s.month.slice(0,4)),seq=++s.sequence;s.status='loading';paint();
   try{const request=Promise.all([S.rpc('lts_browser_budget_read_v441',{p_year:year}),year>=Number(day().slice(0,4))?S.rpc('lts_browser_flow_v241',{p_from:day(),p_to:year+'-12-31'}):Promise.resolve({data:{flow:{current_future:{events:[]}}}}),S.rpc('lts_browser_card_cycles_v229',{})]);s.request=request;const responses=await request;if(responses.some(r=>r.error))throw Error();const m=api.build(strategy.derive(responses[0].data,responses[1].data,responses[2].data));
    if(owner!==gen()||seq!==s.sequence||year!==Number(s.month.slice(0,4)))return;s.data=m;s.status='ready';
   }catch{if(owner===gen()&&seq===s.sequence)s.status='error';}
   finally{if(owner===gen()&&seq===s.sequence)paint();}
  }
  const typeLabel=t=>({fixed:'Compromissos fixos',essential:'Essencial variável',discretionary:'Discricionário',seasonal:'Sazonal'}[t]||'A conferir');
  function popup(title,html){
   if(s.dialog)return null;const d=document.createElement('dialog');s.dialog=d;d.className='v441-dialog';d.innerHTML='<h2>'+esc(title)+'</h2>'+html+'<button data-close>Fechar</button>';
   const close=()=>{d.remove();if(s.dialog===d)s.dialog=null;};d.querySelector('[data-close]').onclick=close;d.addEventListener('cancel',e=>{e.preventDefault();close();});document.body.append(d);d.showModal();return{d,close};
  }
  function analysis(category){
   if(!s.data)return;const v=api.view(s.data,s.mode,s.month),r=v.rows.find(x=>x.category===category);if(!r)return;
   const x=popup(window.LTSCategoryDisplay?.category(category)||category,'<p>'+esc(typeLabel(r.type))+' · '+(r.target===null?'Plano ainda incompleto':r.suggested?'Proposta fundamentada, não aprovada':'Meta aprovada')+'</p><p>'+esc(r.reason)+'</p><p>Referência histórica mensal: <strong>'+money(r.reference)+'</strong></p><p>Valores já registrados e compromissos conhecidos: <strong>'+money(r.minimum)+'</strong></p>'+(r.minimum>r.target&&r.target!==null?'<p class="v441-warning">A meta aprovada está abaixo dos compromissos conhecidos. Ela não reduz o valor a pagar.</p>':'')+'<div>'+r.details.slice(0,40).map(z=>'<p>'+esc(z.description||'Compromisso')+(z.installment?' · parcela '+z.installment+'/'+z.total_installments:'')+' · '+money(api.cents(z.amount))+'</p>').join('')+'</div><p><button data-entries>Lançamentos do realizado</button> <button data-adjust>Ajustar meta</button></p>');
   if(!x)return;x.d.querySelector('[data-adjust]').onclick=()=>{x.close();edit(category);};x.d.querySelector('[data-entries]').onclick=()=>{x.close();entries(category);};
  }
  async function entries(category){
   const owner=s.owner,seq=s.sequence,year=s.month.slice(0,4),from=s.mode==='year'?year+'-01-01':s.month+'-01',to=s.mode==='year'?year+'-12-31':new Date(Date.UTC(Number(year),Number(s.month.slice(5)),0)).toISOString().slice(0,10);
   const x=popup('Lançamentos · '+(window.LTSCategoryDisplay?.category(category)||category),'<div data-content role="status">Carregando lançamentos…</div>');if(!x)return;
   try{let all=[],offset=0,rounds=0;
    if(from<=day())do{const r=await S.rpc('lts_browser_expense_detail_v353',{p_from:from,p_to:to<day()?to:day(),p_scope:{},p_offset:offset,p_limit:10000,p_query:null});if(r.error)throw Error();if(owner!==gen()||seq!==s.sequence||!x.d.isConnected)return;all.push(...(r.data?.rows||[]));offset=r.data?.next_offset??null;if(++rounds>100)throw Error();}while(offset!==null);
    const label=z=>{const c=z.current_category??z.original_category??z.category,n=String(c||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();return z.coverage_mode==='card_invoice_aggregate_fallback'?'Cartão — categoria não recuperada':!c||['a classificar','sem categoria','nao identificado','—'].includes(n)?'Sem classificação':c;};const seen=new Set(),rows=all.filter(z=>label(z)===category).filter(z=>{if(typeof z.key!=='string'||!z.key)throw Error();if(seen.has(z.key))return false;seen.add(z.key);return true;}),v=api.view(s.data,s.mode,s.month).rows.find(z=>z.category===category),total=rows.reduce((a,z)=>a+(api.cents(z.amount)||0),0);
    x.d.querySelector('[data-content]').innerHTML='<p>'+from+' a '+to+' · '+rows.length+' lançamento(s) · '+money(total)+'</p>'+(v&&total!==v.actual?'<p class="v441-warning">O detalhe difere do orçamento. Atualize os dados antes de decidir.</p>':'')+rows.map(z=>'<article><p><strong>'+esc(z.description||'Lançamento')+'</strong> · '+money(api.cents(z.amount))+'</p><p>'+esc(z.period||z.competence_month||z.event_date||z.date||'')+' · '+esc(z.account_source||'')+'</p></article>').join('')+(rows.length?'':'<p>Nenhum lançamento registrado neste período.</p>');
   }catch{if(x.d.isConnected)x.d.querySelector('[data-content]').textContent='Não foi possível carregar os lançamentos. Feche e tente novamente.';}
  }
  function edit(category){
   if(!s.data||s.status==='loading'||s.dialog)return;
   const year=s.data.year,month=Number(s.month.slice(5)),scope=s.mode,view=api.view(s.data,scope,s.month),row=view.rows.find(r=>r.category===category);
   const initial=category===null?view.incomeTarget:row?.target;
   const amount=initial===null?'':String(Math.round(initial/(scope==='year'?12:1))/100);
   const owner=s.owner,seq=s.sequence,revision=s.data.revision,d=document.createElement('dialog');s.dialog=d;d.className='v441-dialog';d.id='v441BudgetEdit';
   d.innerHTML='<h2>'+esc(category===null?'Renda regular de referência':category)+'</h2><label>Valor mensal em reais<input type="number" min="0" max="100000000" step="0.01" inputmode="decimal" value="'+esc(amount)+'" aria-label="Valor mensal da meta"></label><p>'+(scope==='year'?'Aplicar este valor em cada um dos 12 meses de '+year+'.':'Aplicar somente a '+s.month+'.')+'</p><p>Esta meta não altera pagamentos nem as projeções do Fluxo.</p><p role="status"></p><div><button type="button" data-cancel>Cancelar</button><button type="button" data-save>Aprovar e salvar</button></div>';
   const close=()=>{d.remove();if(s.dialog===d)s.dialog=null;};d.querySelector('[data-cancel]').onclick=close;d.addEventListener('cancel',e=>{e.preventDefault();if(!d.dataset.saving)close();});
   d.querySelector('[data-save]').onclick=async()=>{
    const input=d.querySelector('input'),n=Number(input.value),c=api.cents(input.value),status=d.querySelector('[role=status]');
    if(!input.value||c===null||n<0||n>100000000||Math.abs(n*100-c)>.00001){status.textContent='Informe um valor válido com até duas casas decimais.';return;}
    if(category!==null){const raw=s.data.rows.find(x=>x.category===category),selected=scope==='year'?raw.months:[raw.months[month-1]],minimum=Math.max(...selected.map(x=>api.cents(x.strategy?.floor??0)));if(c<minimum){status.textContent='Há '+money(minimum)+' em valores já registrados ou compromissos conhecidos. Ajuste a meta a partir desse valor; uma renegociação precisa ser refletida nos compromissos.';return;}}
    if(owner!==gen()||seq!==s.sequence){status.textContent='O período mudou. Feche e confira novamente.';return;}
    d.dataset.saving='true';d.querySelectorAll('button,input').forEach(b=>b.disabled=true);status.textContent='Salvando…';
    try{const r=await S.rpc('lts_browser_budget_save_v441',{p_year:year,p_month:scope==='year'?null:month,p_targets:category===null?{}:{[category]:c/100},p_income:category===null?c/100:null,p_expected:revision});
     if(r.error||r.data?.saved!==true)throw Error();if(owner!==gen())return;close();await load(true);
    }catch{if(d.isConnected){status.textContent='Não foi possível confirmar a meta. Feche e atualize o orçamento antes de tentar novamente.';d.querySelector('[data-cancel]').disabled=false;delete d.dataset.saving;s.status='error';paint();}}
   };
   document.body.append(d);d.showModal();d.querySelector('input').focus();
  }
  function paint(){
   sync();let host=document.getElementById('v441Budget');if(!visible()){host?.remove();return;}
   const page=document.querySelector('.v168-expenses'),anchor=page?.querySelector('.v175-monthly');if(!anchor)return;
   if(!host){host=document.createElement('section');host.id='v441Budget';host.className='v168-card v441-budget';anchor.after(host);}
   const year=Number(s.month.slice(0,4)),currentYear=Number(day().slice(0,4));
   let html='<header><div><span class="v441-kicker">Planejamento</span><h2>Orçamento estratégico</h2></div><div class="v441-controls"><button data-mode="month" aria-pressed="'+(s.mode==='month')+'">Mensal</button><button data-mode="year" aria-pressed="'+(s.mode==='year')+'">Anual</button>'+(s.mode==='month'?'<input type="month" aria-label="Mês do orçamento" min="'+(currentYear-1)+'-01" max="'+(currentYear+5)+'-12" value="'+s.month+'">':'<input type="number" aria-label="Ano do orçamento" min="'+(currentYear-1)+'" max="'+(currentYear+5)+'" value="'+year+'">')+'</div></header>';
   if(s.status==='error')html+='<p class="v441-warning" role="status">Não foi possível atualizar o orçamento.'+(s.data?' Os valores anteriores continuam abaixo.':'')+' <button data-retry>Tentar novamente</button></p>';
   if(!s.data)html+='<p role="status">'+(s.status==='error'?'Os valores deste período não estão disponíveis.':'Carregando orçamento…')+'</p>';
   else{
    const v=api.view(s.data,s.mode,s.month),kpi=(label,n)=>'<div><span>'+label+'</span><strong class="'+(n!==null&&n<0?'v441-negative':'')+'">'+money(n)+'</strong></div>';
    html+='<p class="v441-period">'+(s.mode==='year'?year:s.month)+' · '+(v.started?'registrado até '+s.data.asOf.split('-').reverse().join('/'):'período ainda não iniciado')+(s.mode==='year'?' · Orçado para 12 meses; realizado acumulado até a data acima.':'')+'</p>';
    html+='<div class="v441-kpis">'+kpi('Renda líquida recorrente',v.incomeTarget)+kpi(v.hasIncompletePlan?'Propostas definidas':v.rows.some(r=>r.suggested)?'Despesas propostas':'Orçado aprovado',v.hasIncompletePlan?v.proposedSubtotal:v.target)+kpi('Saldo do plano completo',v.plannedBalance)+kpi('Resultado registrado sem extras',v.started?v.operating:null)+'</div>';
    if(s.data.strategy?.proposal_review==='review_required')html+='<p class="v441-warning">Entraram novos dados após a proposta'+(s.data.strategy.reviewed_at?' de '+esc(s.data.strategy.reviewed_at.split('-').reverse().join('/')):'')+'. Confira os limites; os compromissos atuais continuam preservados.</p>';
    if(v.cashUnallocated.length){
     html+='<section class="v441-cash-reserve"><h3>Reservas de caixa por vencimento</h3><p>Calendário sem faturas de cartão: <strong>'+money(v.cashWithoutCompetence)+'</strong>. Reserva de caixa, não um total de consumo.</p>';
     if(v.cashCoverageGap>0)html+='<p class="v441-warning">Estes pagamentos superam a renda prevista em '+money(v.cashCoverageGap)+', antes de outras despesas e faturas. Confira o calendário no Fluxo.</p>';
     html+='<details><summary>Ver pagamentos previstos ('+v.cashUnallocated.length+')</summary><p>A competência ainda precisa de confirmação. Estas reservas permanecem separadas das metas por categoria; não as some como novas despesas.</p>'+v.cashUnallocated.slice(0,100).map(x=>'<p>'+esc(x.date)+' · '+esc(x.description||x.category||'Pagamento previsto')+' · '+money(api.cents(x.amount))+'</p>').join('')+(v.cashUnallocated.length>100?'<p>Exibidos os primeiros 100 pagamentos. Consulte o restante no Fluxo.</p>':'')+'</details></section>';
    }
    if(v.hasIncompletePlan)html+='<p class="v441-warning">O plano ainda não tem cobertura completa por categoria. '+v.unplannedCategories+' categoria(s) sem meta definida. As propostas definidas são um subtotal, não o plano completo. '+(v.proposedDeficit>0?'Este subtotal já supera a renda em '+money(v.proposedDeficit)+'. ':'')+'Piso conhecido: '+money(v.minimum)+'. Não interprete os valores ausentes como zero.</p>';
    if(v.plannedBalance!==null&&v.plannedBalance<0)html+='<p class="v441-warning">O plano supera a renda líquida em <strong>'+money(-v.plannedBalance)+'</strong>. A proposta não cabe na renda recorrente. Avalie alternativas sem apagar os compromissos.</p>';
    if(s.data.reference.months<6||s.data.reference.salaryMonths<1)html+='<p class="v441-warning">A referência histórica está incompleta. Confira as metas e a renda antes de usar este orçamento.</p>';
    if(s.data.strategy?.pastWithoutPlan)html+='<p class="v441-muted">Há '+s.data.strategy.pastWithoutPlan+' mês(es) encerrado(s) sem orçamento aprovado. A visão anual preserva esta ausência.</p>';
    if(s.data.proposed)html+='<p class="v441-muted">Propostas fundamentadas permanecem separadas das metas aprovadas. Valores já registrados e compromissos são o piso, não um orçamento completo.</p>';
    html+='<div class="v441-extras">Renda regular registrada: <strong>'+money(v.started?v.incomeRegular:null)+'</strong> · Bônus registrado: <strong>'+money(v.started?v.bonus:null)+'</strong> · 13º registrado: <strong>'+money(v.started?v.thirteenth:null)+'</strong> · Outras entradas extraordinárias: <strong>'+money(v.started?v.extra-v.bonus-v.thirteenth:null)+'</strong><button data-income>Ajustar renda</button></div>';
    html+='<div class="v441-table" role="table" aria-label="Orçamento por categoria"><div class="v441-row v441-columns" role="row"><b>Categoria</b><b>Orçado</b><b>Realizado registrado</b><b>Diferença</b><span></span></div>';
    for(const r of v.rows)html+='<div class="v441-row" role="row"><strong>'+esc(window.LTSCategoryDisplay?.category(r.category)||r.category)+'<small>'+esc(typeLabel(r.type))+'</small></strong><span data-label="Orçado">'+money(r.target)+(r.target===null?' <small>sem plano completo</small>':r.suggested?' <small>proposta</small>':' <small>aprovado</small>')+'</span><span data-label="Realizado">'+money(v.started?r.actual:null)+'</span><span data-label="Diferença" class="'+(r.gap!==null&&r.gap<0?'v441-negative':'')+'">'+money(v.started?r.gap:null)+'</span><button data-why="'+esc(r.category)+'">Detalhes</button></div>';
    html+='</div>';
    if(v.minimum>v.incomeTarget&&v.incomeTarget!==null)html+='<p class="v441-warning">Valores já registrados e compromissos conhecidos: '+money(v.minimum)+', acima da renda. Rever metas não cancela essas obrigações.</p>';
    if(v.plannedBalance!==null&&v.plannedBalance<0)html+='<details class="v441-premises"><summary>Alternativas para o déficit</summary><p>Preserve as parcelas. Compare reduções viáveis por categoria, confira necessidades pelo detalhe e avalie renegociação de contratos. Um déficit não zera automaticamente gastos recorrentes. Bônus e 13º são extraordinários.</p></details>';
    if(v.pending)html+='<p class="v441-muted">O realizado inclui '+money(v.pending)+' em compras recebidas que ainda aguardam confirmação bancária.</p>';
    if(s.data.unknown)html+='<p class="v441-warning">Há lançamentos sem classificação. Confira seus detalhes antes de decidir.</p>';
    html+='<details class="v441-premises"><summary>Premissas do orçamento</summary><p>Renda líquida recorrente conforme salário previsto e recebimentos regulares; bônus, 13º e demais extraordinárias ficam separados. Obrigações e parcelas conhecidas são mantidas. O histórico descreve gastos passados; não define sozinho quanto deve ser gasto. Categorias sem proposta fundamentada continuam pendentes, sem percentuais genéricos e sem zeros artificiais para fechar a renda.</p><p>Compras entram uma vez por competência. Pagamentos de fatura, descontos já abatidos do salário e a provisão de novas compras do Fluxo não são somados novamente.</p><p>Sazonais sem calendário completo precisam de revisão. Nenhuma meta proposta altera pagamentos. Referência: '+esc(s.data.reference.from)+' a '+esc(s.data.reference.to)+'.</p></details>';
    if(s.status==='loading')html+='<p role="status">Atualizando orçamento…</p>';
   }
   host.innerHTML=html;
   host.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{s.mode=b.dataset.mode;paint();});
   const input=host.querySelector('input');if(input)input.oninput=input.onchange=()=>{const value=s.mode==='year'?input.value+'-'+s.month.slice(5):input.value;
    const y=Number(value.slice(0,4));if(/^\d{4}-(0[1-9]|1[0-2])$/.test(value)&&y>=currentYear-1&&y<=currentYear+5&&value!==s.month){setMonth(value);paint();}};
   host.querySelectorAll('[data-why]').forEach(b=>b.onclick=()=>analysis(b.dataset.why));host.querySelector('[data-income]')?.addEventListener('click',()=>edit(null));host.querySelector('[data-retry]')?.addEventListener('click',()=>load(true));
   if(s.status==='idle'&&!s.queued){s.queued=true;queueMicrotask(()=>{s.queued=false;load();});}
  }
  const style=document.createElement('style');style.textContent='.v441-budget{margin:0 0 18px}.v441-budget header,.v441-controls{display:flex;gap:8px;align-items:center;justify-content:space-between;flex-wrap:wrap}.v441-budget h2{margin:4px 0 10px}.v441-kicker{font-size:11px;text-transform:uppercase;color:#3475cf;font-weight:700}.v441-budget button,.v441-budget input,.v441-dialog button,.v441-dialog input{font:inherit;min-height:42px;box-sizing:border-box;border:1px solid #cad8e7;background:white;border-radius:8px;padding:8px 10px;max-width:100%;color:#173a61}.v441-controls [aria-pressed=true]{background:#eaf2fc;font-weight:700}.v441-controls input{width:155px}.v441-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:16px 0}.v441-kpis>div{background:#f5f8fc;border-radius:10px;padding:12px}.v441-kpis span{display:block;font-size:12px;color:#526174}.v441-kpis strong{display:block;font-size:20px;margin-top:7px;overflow-wrap:anywhere}.v441-warning{background:#fff7e8;border-left:3px solid #bc8b33;padding:10px 12px;font-size:13px}.v441-negative{color:#a13030!important}.v441-extras{font-size:13px;line-height:1.8;margin:12px 0}.v441-extras button{margin-left:10px}.v441-row{display:grid;grid-template-columns:minmax(180px,2fr) repeat(3,minmax(100px,1fr)) auto;gap:12px;align-items:center;padding:12px 0;border-bottom:1px solid #e2e9f1;font-size:13px}.v441-row>span{overflow-wrap:anywhere}.v441-row small{display:block;color:#69788a;font-size:11px}.v441-row>strong{overflow-wrap:anywhere}.v441-columns{font-size:11px;color:#526174}.v441-muted,.v441-period{font-size:12px;color:#617083;line-height:1.6}.v441-premises{margin-top:16px;font-size:12px;color:#526174;line-height:1.6}.v441-premises summary{cursor:pointer}.v441-dialog{color:#17324f;border:1px solid #cad8e7;border-radius:16px;padding:22px;width:min(500px,calc(100vw - 28px));max-height:90vh;overflow:auto;box-sizing:border-box}.v441-dialog::backdrop{background:#11243b77}.v441-dialog label{display:grid;gap:8px}.v441-dialog p{font-size:13px;line-height:1.6}.v441-dialog>div{display:flex;justify-content:flex-end;gap:10px}@media(max-width:800px){.v441-kpis{grid-template-columns:1fr 1fr}.v441-kpis strong{font-size:17px}.v441-row{grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.v441-columns{display:none}.v441-row>strong{grid-column:1/3}.v441-row>button{grid-column:3;grid-row:1}.v441-row>span{grid-row:2;font-size:12px}.v441-row>span:before{content:attr(data-label);display:block;color:#617083;font-size:10px;margin-bottom:5px}.v441-extras button{display:block;margin:8px 0 0}}';document.head.append(style);
  const mobileStyle=document.createElement('style');mobileStyle.textContent='#v441Budget{scroll-margin-top:78px}.v441-budget button,.v441-budget input,.v441-dialog button,.v441-dialog input{min-height:44px}.v441-budget input,.v441-dialog input{font-size:16px}@media(max-width:359px){.v441-kpis{grid-template-columns:1fr}}';document.head.append(mobileStyle);
  render=function(){const r=previous.apply(this,arguments);paint();return r;};
  window.addEventListener('lts:product-refresh-ready',()=>{s.sequence++;s.status='idle';s.data=null;if(visible())paint();});
  window.__LTS_V441_BUDGET={state:s,refresh:()=>load(true)};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V337_MONTH)return false;if(!w.__LTS_V441_BUDGET){const script=d.createElement('script');script.textContent='('+runtime.toString()+')();';d.head.append(script);}return !!w.__LTS_V441_BUDGET;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v441-budget-ui.js',install);
})();

;
/* lts-v441-flow-summary.js */
/* Presentation only. All balances come from the existing canonical Flow response. */
(function(){'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V441_FLOW||!window.parent.LTSV441Budget)return;
  const api=window.parent.LTSV441Budget,previous=render;
  const money=n=>n===null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n/100);
  const date=x=>x?.split('-').reverse().join('/')||'—';
  function paint(){
   const old=document.getElementById('v441FlowSummary');
   if(V!=='Fluxo Diário'||!D||N.classList.contains('hidden')||ACC!=='Consolidado'){old?.remove();return;}
   const body=document.querySelector('.v382-tool-body');if(!body)return;old?.remove();
   let premises=document.getElementById('v441FlowPremises');if(!premises){premises=document.createElement('div');premises.id='v441FlowPremises';premises.dataset.v425Section='liquidity';body.append(premises);}
   premises.innerHTML='<strong>Premissas dos cenários de caixa</strong><p>Os cenários usam as entradas e saídas já previstas no Fluxo, inclusive salários futuros. Não representam dinheiro garantido. O horizonte de curto prazo é de até 90 dias, limitado ao período consultado.</p><p>O cenário com ações depende de venda, câmbio, impostos e transferência. Lotes futuros dependem da liberação. FGTS tem restrições e prazo para saque; a recomposição futura não é caixa disponível hoje.</p><p>Novos gastos: R$ 15 mil por mês somente no Aeternum, desde o terceiro mês à frente. A janela avança a cada mês; antes dela entram apenas faturas e parcelas conhecidas. Essa provisão pertence ao Fluxo e não é somada ao orçamento por categoria.</p>';
  }
  const style=document.createElement('style');style.textContent='#v441FlowSummary{border:1px solid #dce5f0;border-radius:12px;padding:14px;margin:12px 0;background:#fff;color:#173a61}#v441FlowSummary h2{font-size:17px;margin:0 0 12px}#v441FlowSummary h3{font-size:12px;margin:16px 0 6px}.v441-flow-cash{display:grid;grid-template-columns:1fr 1fr;gap:10px}.v441-flow-cash>div{background:#f3f7fc;padding:10px;border-radius:8px}.v441-flow-cash span{display:block;font-size:12px}.v441-flow-cash strong{display:block;margin-top:6px;font-size:21px;overflow-wrap:anywhere}.v441-flow-note{font-size:12px;line-height:1.5;color:#617083;margin:10px 0 0}#v441FlowSummary ul{list-style:none;padding:0;margin:0}#v441FlowSummary li{display:flex;justify-content:space-between;gap:14px;padding:8px 0;border-bottom:1px solid #e6edf4;font-size:13px}#v441FlowSummary li strong{text-align:right;overflow-wrap:anywhere}#v441FlowPremises{font-size:12px;line-height:1.5}@media(max-width:430px){.v441-flow-cash strong{font-size:17px}#v441FlowSummary li{font-size:12px}#v441FlowSummary li>span{max-width:45%}}';document.head.append(style);
  const mobileStyle=document.createElement('style');mobileStyle.textContent='#v441FlowSummary{scroll-margin-top:78px}@media(max-width:359px){.v441-flow-cash{grid-template-columns:1fr}}';document.head.append(mobileStyle);
  render=function(){const r=previous.apply(this,arguments);paint();return r;};window.__LTS_V441_FLOW={installed:true,paint};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V425_FLOW_OPTIONS||!window.LTSV441Budget)return false;if(!w.__LTS_V441_FLOW){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return !!w.__LTS_V441_FLOW;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v441-flow-summary.js',install);
})();

;
/* lts-v442-income-composition.js */
(function(){'use strict';const shell=document.getElementById('shell');function runtime(){
 if(window.__LTS_V442_INCOME_DETAIL||typeof flowEditorInline!=='function')return;const previous=flowEditorInline;
 flowEditorInline=function(day){const html=previous.apply(this,arguments),d=FLOWEDIT?.data;if(!html||FLOWEDIT?.anchor_date!==day||!Array.isArray(d?.composition)||!d.composition.length)return html;
  const rows=d.composition.filter(x=>typeof x.rubric==='string'&&Number.isFinite(Number(x.amount)));if(rows.length!==d.composition.length)return html;
  const detail='<details class="v442-income-composition"><summary>Composição do pagamento previsto</summary><p>Referência: '+esc(d.payroll_reference_date||'—')+'</p>'+rows.map(x=>'<p>'+esc(x.rubric)+' · <strong>'+brl(Number(x.amount))+'</strong></p>').join('')+'<p>Total da previsão: '+brl(Number(d.amount))+'</p>'+(d.composition_document_pending?'<p>Informado por você; demonstrativo a conferir.</p>':'')+'</details>';
  return html.replace('<div class="flowedit-actions">',detail+'<div class="flowedit-actions">');
 };
 const priorBadge=flowClassificationBadge;
 flowClassificationBadge=function(e){
  const today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  if(Number(e.signed_amount)>0&&/^\d{4}-\d{2}-\d{2}$/.test(e.event_date||'')&&e.event_date>today){
   const label=/(^|\D)13[º°o]?|d[eé]cimo terceiro/i.test(e.description||'')?'13º previsto':'Entrada prevista';
   return '<span class="tag">'+label+'</span>';
  }
  return priorBadge.apply(this,arguments);
 };window.__LTS_V442_INCOME_DETAIL=true;
}function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V337_MONTH)return false;if(!w.__LTS_V442_INCOME_DETAIL){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return!!w.__LTS_V442_INCOME_DETAIL;}catch{return false;}}let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',start);start();window.LTSV339Boot?.watch('lts-v442-income-composition.js',install);})();

;
/* lts-v463-debt-model.js */
/* Estimate a fixed-payment loan from the preserved original capital and proved payments. */
(function(root){'use strict';
 const num=x=>(typeof x==='number'||typeof x==='string'&&x.trim()!=='')&&Number.isFinite(Number(x))?Number(x):null;
 const date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x+'T12:00:00Z'))&&new Date(x+'T12:00:00Z').toISOString().slice(0,10)===x;
 const cents=x=>{const n=num(x);return n!==null&&Number.isSafeInteger(Math.round(n*100))?Math.round(n*100):null;};
 function pv(rate,n,payment){return rate===0?n*payment:payment*-Math.expm1(-n*Math.log1p(rate))/rate;}
 function estimate(asset,loan,asOf){
  if(!date(asOf)||!asset||loan?.id!=='volvo'||loan.confidence!=='documented_contract')return null;
  if(num(loan.current_documentary_debt_balance)!==null&&date(loan.current_debt_as_of))return null;
  const principal=cents(asset.documented_financed_balance),payment=cents(loan.installment),n=loan.total_events;
  const paid=Array.isArray(loan.realized_rows)?[...loan.realized_rows].sort((a,b)=>a.installment_number-b.installment_number):null;
  const future=Array.isArray(loan.schedule_rows)?[...loan.schedule_rows].sort((a,b)=>a.installment_number-b.installment_number):null;
  if(principal===null||principal<=0||payment===null||payment<=0||!Number.isSafeInteger(n)||n<1||n>600||principal>n*payment||!paid||!future||paid.length<1||paid.length+future.length!==n||loan.confirmed_paid_installments!==paid.length||loan.remaining_events!==future.length||num(loan.unconfirmed_past_events)!==0)return null;
  const refs=new Set();
  for(let i=0;i<paid.length;i++){
   const p=paid[i];if(p.status!=='paid'||p.installment_number!==i+1||!date(p.paid_date)||p.paid_date>asOf||!date(p.due_date)||!p.source_ref||refs.has(p.source_ref)||p.payment_basis!=='validated_existing_bank_identity'||cents(p.paid_amount)!==payment||cents(p.scheduled_amount)!==payment)return null;
   refs.add(p.source_ref);
  }
  for(let i=0;i<future.length;i++){const p=future[i];if(p.installment_number!==paid.length+i+1||!date(p.due_date)||p.due_date<=asOf||cents(p.amount)!==payment)return null;}
  let rate=0;
  if(principal<n*payment){let low=0,high=1;if(pv(high,n,payment)>principal)return null;for(let i=0;i<90;i++){const mid=(low+high)/2;if(pv(mid,n,payment)>principal)low=mid;else high=mid;}rate=(low+high)/2;}
  const balance=Math.round(pv(rate,future.length,payment));if(!Number.isSafeInteger(balance)||balance<0||balance>principal)return null;
  return {status:'estimated_after_confirmed_payments',balance:balance/100,asOf:paid.at(-1).paid_date,initialPrincipal:principal/100,paidCount:paid.length,totalCount:n,paidAmount:paid.length*payment/100,remainingCount:future.length,nextDue:future[0]?.due_date||null,nextAmount:future.length?payment/100:null,method:'fixed_payment_annuity',inferredMonthlyRate:rate};
 }
 const api={estimate,pv};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.LTSV463Debt=api;
})(typeof window==='undefined'?{}:window);

;
/* lts-v463-debt-ui.js */
/* Preserve source positions; show a dated estimate instead of an empty liability. */
(function(){'use strict';const shell=document.getElementById('shell');
 function runtime(){
  if(window.__LTS_V463_DEBT)return;
  const previous=render,model=parent.LTSV463Debt;
  const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x),date=x=>x?.split('-').reverse().join('/')||'—';
  function data(){const j=window.__LTS_V168_STATE?.wealth?.data,loan=j?.financing?.summary?.commitments?.find(x=>x.id==='volvo'),asOf=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());return{j,estimate:model.estimate(j?.wealth?.assets?.volvo_xc40,loan,asOf)};}
  function basis(x){const d=document.createElement('details');d.className='v463-debt-basis';const title=document.createElement('summary');title.textContent='Base da estimativa';d.append(title);for(const text of ['Valor financiado informado: '+money(x.initialPrincipal)+'.',x.paidCount+' de '+x.totalCount+' parcelas pagas e identificadas no banco, somando '+money(x.paidAmount)+'.','Estimativa após o pagamento de '+date(x.asOf)+', pelas parcelas fixas do contrato. O extrato atualizado confirma juros, encargos e o valor para quitação.']){const p=document.createElement('p');p.textContent=text;d.append(p);}return d;}
  function paint(){
   const {j,estimate:x}=data();if(!x)return;
   if(V==='Patrimônio'){
    const row=document.querySelector('[data-v386-debt="volvo"]');
    if(row){row.querySelector('b').textContent=money(x.balance);const note=row.querySelector('small');if(note)note.textContent='Estimado após a parcela de '+date(x.asOf);row.querySelector('.v463-debt-basis')?.remove();row.append(basis(x));}
    const assessment=window.__LTS_V407_WEALTH?.assess(j),totals=document.querySelector('.v365-wealth-totals');
    if(totals&&assessment?.available&&assessment.missing?.length===1&&assessment.missing[0]==='volvo'){
     const cards=totals.querySelectorAll(':scope>article'),debt=cards[1],net=cards[2];
     if(debt){debt.querySelector('span').textContent='Dívidas';debt.querySelector('strong').textContent=money(assessment.known+x.balance);debt.querySelector('small').textContent='Inclui a estimativa do financiamento da Volvo';}
     if(net){net.querySelector('span').textContent='Patrimônio líquido estimado';net.querySelector('strong').textContent=money(assessment.gross-assessment.known-x.balance);net.querySelector('small').textContent='Ativos menos dívidas, incluindo a estimativa da Volvo';net.querySelectorAll('details').forEach(e=>e.remove());net.append(basis(x));}
     const warning=document.querySelector('.v365-material');if(warning&&/Volvo/.test(warning.textContent)){const action=warning.querySelector('button');warning.replaceChildren(document.createTextNode('Saldo da Volvo estimado. Você pode atualizar o extrato em Ações. '));if(action)warning.append(action);}
    }
    const vehicle=[...document.querySelectorAll('.v168-asset')].find(a=>a.querySelector('h3')?.textContent==='Volvo XC40');
    if(vehicle){const market=Number(j.wealth.assets.volvo_xc40.market_central);if(Number.isFinite(market))vehicle.querySelector('strong').textContent=money(market-x.balance);const fact=[...vehicle.querySelectorAll('.v168-fact')].find(a=>/Financiamento na contratação|Saldo para quitação/.test(a.querySelector('span')?.textContent||''));if(fact){fact.querySelector('span').textContent='Saldo devedor estimado';fact.querySelector('b').textContent=money(x.balance);}vehicle.querySelectorAll('.v463-debt-basis').forEach(a=>a.remove());vehicle.append(basis(x));}
   }
   if(V==='Atualizações'){
    const task=document.getElementById('v365WealthTasks');if(task){const h=task.querySelector('h2'),p=task.querySelector('p'),button=task.querySelector('button');h.textContent='Atualizar extrato do financiamento da Volvo';p.textContent='Usamos a base anterior e '+x.paidCount+' parcelas pagas para estimar o saldo. Envie uma posição recente quando estiver disponível.';if(button){button.textContent='Enviar extrato atualizado';button.onclick=()=>window.__LTS_V168_COMPLETE_REVIEW.openVolvoStatement();}}
   }
  }
  render=function(){const result=previous.apply(this,arguments);paint();return result;};window.__LTS_V463_DEBT={installed:true,paint};paint();
 }
 function install(){try{const w=shell?.contentWindow,d=shell?.contentDocument;if(!w?.__LTS_V407_WEALTH||!window.LTSV463Debt)return false;if(!w.__LTS_V463_DEBT){const s=d.createElement('script');s.textContent='('+runtime.toString()+')();';d.head.append(s);}return !!w.__LTS_V463_DEBT;}catch{return false;}}
 let tries=0;function start(){if(!install()&&++tries<400)setTimeout(start,100);}shell?.addEventListener('load',()=>{tries=0;start();});start();window.LTSV339Boot?.watch('lts-v463-debt-ui.js',install);
})();


