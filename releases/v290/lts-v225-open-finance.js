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
        const current=observe(status,baseline,now), models=rows(status,current,now);
        const unchanged=[...new Set(models.filter(x=>x.change==='unchanged').map(x=>x.name))];
        if(unchanged.length)return 'Coleta concluída; mesma origem de conexão em '+unchanged.join(', ')+'. A coleta, sozinha, não confirma nova posição de saldo.';
        if(models.length&&models.every(x=>x.change==='advanced'))return 'Coleta concluída; as conexões avançaram. Consulte a data de cada posição do provedor.';
        return 'Coleta concluída; nova posição bancária não confirmada pelas datas disponíveis.';
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
        control.innerHTML = '<button type="button" class="v168-btn blue" data-v225-refresh '+(state.syncing?'disabled':'')+'>'+(state.syncing?'Coletando dados…':'Coletar dados disponíveis')+'</button><span role="status">'+esc(state.error || state.message || 'Coleta automática de dados disponíveis')+'</span>';
        control.querySelector('button').onclick = () => refresh(true);
      }
      if (V === 'Atualizações') {
        const host = document.querySelector('.v168-openfinance');
        if (host) host.innerHTML = '<div class="v225-banklist" style="grid-column:1/-1">'+bankRows()+'</div>';
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
          if(state.error==='Não foi possível consultar o estado das coletas.')state.error='';
          if(previous&&revision(previous)!==revision(state.status)&&!state.syncing)refreshScreens();
        }
        catch (error) { if(activeSession(epoch,gen))state.error = 'Não foi possível consultar o estado das coletas.'; }
        finally { if(epoch===state.epoch){if(gen!==generation())clearSession();else{state.loading=false;state.statusRead=null;paint();}} }
      })();
      state.statusRead=reading;return reading;
    }
    async function refreshScreens() {
      const epoch=state.epoch,gen=generation();
      const cashOnly=V==='Fluxo Diário',transport=window.__LTS_V227_TRANSPORT,revision=transport?.revision;
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
      if (!signedIn()) { clearTimeout(state.timer); state.syncing=false; return; }
      const epoch=state.epoch,gen=generation();
      await readStatus();
      if(!activeSession(epoch,gen))return;
      const rows=connections().filter(c=>names[c.institution_code]);
      const fresh=freshness.collectionComplete(state.status,state.refreshExpected,state.requestedAt,Date.now());
      const failed=rows.some(c=>c.last_error_code && new Date(c.last_attempt_at).getTime()>=state.requestedAt && new Date(c.last_success_at).getTime()<state.requestedAt);
      if (fresh) {
        state.syncing=false; state.error=''; state.message=freshness.collectionMessage(state.status,state.refreshBaseline,Date.now()); paint(); refreshScreens(); return;
      }
      if (failed || Date.now()-state.requestedAt>90000) {
        state.syncing=false;
        state.error=failed?'A coleta de um banco falhou. Consulte o último recebimento confirmado.':'';
        state.message=failed?'':'Solicitação enviada; a coleta ainda não foi confirmada.';
        paint(); return;
      }
      state.timer=setTimeout(poll,5000);
    }
    async function refresh(force) {
      if (!signedIn() || state.syncing) return;
      if (!force && Number(sessionStorage.getItem('lts_of_open_refresh_at')||0)>Date.now()-600000) { await readStatus(); return; }
      const epoch=state.epoch,gen=generation();
      state.manualRefresh=!!force; state.syncing=true; state.error=''; state.message=''; paint();
      try {
        // Finish the initial read before asking all banks to reconcile sources.
        await window.__LTS_V178_REVIEW?.ready?.();
        if(!activeSession(epoch,gen)){if(epoch===state.epoch)state.syncing=false;return;}
        if(state.statusRead)await state.statusRead;
        if(!activeSession(epoch,gen))return;
        state.refreshBaseline=state.observations;state.refreshExpected=state.status;
        const result=await rpc('lts_browser_open_finance_refresh_v1');
        if(!activeSession(epoch,gen))return;
        if (result.ok!==true || freshness.timestamp(result.requested_at,Date.now()).kind!=='valid') throw Error('Solicitação não confirmada');
        state.requestedAt=new Date(result.requested_at).getTime();
        sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
        await poll();
      } catch(error) { if(!activeSession(epoch,gen))return;state.syncing=false; state.error='Não foi possível solicitar a coleta. Tente novamente.'; paint(); }
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
      try {const data=await rpc('lts_browser_open_finance_pending_v225',range);if(data.version!=='pending-expense-v225')throw Error('Leitura indisponível');if(p.key===key)p.data=data;}
      catch(error){if(p.key===key)p.error='Despesas provisórias não disponíveis agora.';}
      finally {if(p.key===key){p.loading=false;paintPending();}}
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
      const combined=data?.transaction_count&&reconciled!=null&&Number.isFinite(Number(reconciled))?'<span>Reconciliadas: '+esc(brl(reconciled))+' · Com provisórias: '+esc(brl(Number(reconciled)+Number(data.net_expense)))+'</span>':'';
      const updateBody=p.loading?'Consultando compras dos cartões…':p.error?esc(p.error):!data?.transaction_count?'':
        '<b>Compras aguardando confirmação</b><span>'+data.transaction_count+' compras · '+esc(brl(data.net_expense))+'. O banco ainda pode atualizar esses valores.</span><span>'+ (data.unclassified_count??0)+' compras precisam de categoria.</span><button type="button" data-pending-detail>Conferir compras</button>';
      box.innerHTML=V==='Atualizações'?updateBody:body+combined;box.hidden=!body;box.querySelector('[data-pending-detail]')?.addEventListener('click',pendingDetails);
    }
    function clearSession() { clearTimeout(state.timer);state.epoch++;state.status=null;state.observations=new Map();state.refreshBaseline=null;state.statusRead=null;state.loading=false;state.requestedAt=null;state.error='';state.message='';state.syncing=false;state.started=false;state.refreshExpected=null;state.pending={key:'',data:null,loading:false,error:''};state.sessionGeneration=generation(); }
    function after() {
      if(state.sessionGeneration!==generation())clearSession();
      if (!signedIn()) { if(state.status||state.statusRead)clearSession();state.started=false; state.syncing=false; state.pending={key:'',data:null,loading:false,error:''}; clearTimeout(state.timer); return; }
      paint(); paintPending();if(!statusTimer)watch();
      if (!state.started) { state.started=true; queueMicrotask(async()=>{if(!signedIn())return;await readStatus();await refresh(false);}); }
    }
    render=function(){const result=previousRender();after();return result;};
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
})();

