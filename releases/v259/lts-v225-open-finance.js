/* Additive integration: existing screen owners and financial writers are preserved. */
(function () {
  'use strict';
  const frame = document.getElementById('shell');
  function runtime() {
    const v233Formatters=[new Intl.DateTimeFormat('pt-BR', {timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}),new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}),new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'})];

    if (window.__LTS_V225?.installed) return;
    const state = { installed: true, version: 'v225', status: null, loading: false,
      syncing: false, error: '', message: '', started: false, requestedAt: null, timer: null, pending: {key:'',data:null,loading:false,error:''} };
    window.__LTS_V225 = state;
    const previousRender = render;
    const names = { '341': 'Itaú', '237': 'Bradesco', '336': 'C6' };
    const esc = text => String(text ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const stamp = value => value ? v233Formatters[0].format(new Date(value)) : 'Sem atualização confirmada';
    const signedIn = () => typeof D !== 'undefined' && !!D && !N.classList.contains('hidden');
    async function rpc(name,args) {
      const result = await S.rpc(name,args||{});
      if (result.error || !result.data) throw Error(result.error?.message || 'Não foi possível atualizar agora.');
      return result.data;
    }
    function connections() { return Array.isArray(state.status?.connections) ? state.status.connections : []; }
    function bankRows() {
      return ['341','237','336'].map(code => {
        const bank = connections().find(c => c.institution_code === code);
        const failed = bank?.last_error_code && (!bank.last_success_at || new Date(bank.last_attempt_at) > new Date(bank.last_success_at));
        const label = failed ? 'Falha na última atualização' : bank?.status === 'connected' ? 'Conectado' : bank ? 'Verificar conexão' : 'Consultando conexão';
        return '<div class="v225-bank"><b>'+names[code]+'</b><span>'+esc(label)+'</span><time>'+esc(stamp(bank?.last_success_at))+'</time></div>';
      }).join('');
    }
    function paint() {
      if (!signedIn()) return;
      const host = document.querySelector('.v168-dashboard .v168-headmeta, .v168-updates .v168-headmeta');
      if (host) {
        let control = host.querySelector('.v225-sync');
        if (!control) { control = document.createElement('div'); control.className = 'v225-sync'; host.appendChild(control); }
        control.innerHTML = '<button type="button" class="v168-btn blue" data-v225-refresh '+(state.syncing?'disabled':'')+'>'+(state.syncing?'Atualizando bancos…':'Atualizar agora')+'</button><span role="status">'+esc(state.error || state.message || 'Atualização automática a cada hora')+'</span>';
        control.querySelector('button').onclick = () => refresh(true);
      }
      if (V === 'Atualizações') {
        const host = document.querySelector('.v168-openfinance');
        if (host) host.innerHTML = '<div class="v225-banklist">'+bankRows()+'</div>';
      } else if (V === 'Dashboard') {
        let line = document.querySelector('.v225-bankstatus');
        if (!line && host) { line = document.createElement('details'); line.className='v225-bankstatus'; host.appendChild(line); }
        if (line) { const open=line.open; line.innerHTML='<summary>Última atualização por banco</summary><div class="v225-banklist">'+bankRows()+'</div>'; line.open=open; }
      }
    }
    async function readStatus() {
      if (state.loading) return;
      state.loading = true;
      try {
        const revision=s=>(s?.connections||[]).map(c=>c.institution_code+':'+c.last_success_at).sort().join('|');
        const previous=state.status;state.status = await rpc('lts_browser_open_finance_status_v1');
        if(state.error==='Não foi possível consultar a atualização dos bancos.')state.error='';
        if(previous&&revision(previous)!==revision(state.status)&&!state.syncing)refreshScreens();
      }
      catch (error) { state.error = 'Não foi possível consultar a atualização dos bancos.'; }
      finally { state.loading = false; paint(); }
    }
    async function refreshScreens() {
      window.__LTS_V227_TRANSPORT?.invalidate?.();if(window.__LTS_V172_STATE)window.__LTS_V172_STATE.flowSequence++;FLOWLOADING=false;
      const reports=window.__LTS_V175_STATE;if(reports){for(const key of ['expense','monthly']){if(reports[key]){reports[key].data=null;reports[key].key='';reports[key].token=(reports[key].token||0)+1}}}
      const review=window.__LTS_V181_STATE?.review;if(review){review.status='idle';review.data=null;review.key=''}
      window.__LTS_V226?.invalidate?.();window.__LTS_V226?.refresh?.();
      state.pending.key=''; state.pending.data=null; state.pending.loading=false; document.getElementById('v225-pending-dialog')?.remove();
      // Bank ingestion does not rewrite reconciled expenses or wealth positions.
      // Keep their validated values while refreshing today's balances/forecast.
      const ui=window.__LTS_V168_STATE;
      if(ui)ui.updates.openFinance=state.status;
      await window.__LTS_V178_REVIEW.refresh();
      if (V==='Fluxo Diário' && typeof FLOWFROM!=='undefined' && FLOWFROM && FLOWTO) loadFlowRange(FLOWFROM,FLOWTO);
      else render();
    }
    async function poll() {
      if (!signedIn()) { clearTimeout(state.timer); state.syncing=false; return; }
      await readStatus();
      const rows=connections().filter(c=>names[c.institution_code]);
      const fresh=rows.length===3 && rows.every(c=>new Date(c.last_success_at).getTime()>=state.requestedAt);
      const failed=rows.some(c=>c.last_error_code && new Date(c.last_attempt_at).getTime()>=state.requestedAt && new Date(c.last_success_at).getTime()<state.requestedAt);
      if (fresh) {
        state.syncing=false; state.error=''; state.message='Bancos atualizados'; paint(); refreshScreens(); return;
      }
      if (failed || Date.now()-state.requestedAt>90000) {
        state.syncing=false;
        state.error=failed?'Um banco não atualizou. Consulte a última posição por banco.':'';
        state.message=failed?'':'Solicitação enviada; os bancos ainda estão processando.';
        paint(); return;
      }
      state.timer=setTimeout(poll,5000);
    }
    async function refresh(force) {
      if (!signedIn() || state.syncing) return;
      if (!force && Number(sessionStorage.getItem('lts_of_open_refresh_at')||0)>Date.now()-600000) { await readStatus(); return; }
      state.manualRefresh=!!force; state.syncing=true; state.error=''; state.message=''; paint();
      try {
        // Finish the initial read before asking all banks to reconcile sources.
        await window.__LTS_V178_REVIEW?.ready?.();
        if(!signedIn()){state.syncing=false;return;}
        const result=await rpc('lts_browser_open_finance_refresh_v1');
        if (result.ok!==true || !result.requested_at) throw Error('Solicitação não confirmada');
        state.requestedAt=new Date(result.requested_at).getTime();
        sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
        await poll();
      } catch(error) { state.syncing=false; state.error='Não foi possível solicitar a atualização. Tente novamente.'; paint(); }
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
      dialog.innerHTML='<header><h2>Compras aguardando confirmação</h2><button type="button" data-close>Fechar</button></header><p>Consumo provisório: '+esc(brl(data.net_expense))+' · '+data.transaction_count+' transações. '+(data.unclassified_count??0)+' precisam identificar a finalidade. Créditos reduzem o total. A posição é revista automaticamente quando o banco confirma, altera ou reverte o registro.</p><div class="v225-pending-table"><table><thead><tr><th>Data</th><th>Banco / cartão</th><th>Descrição</th><th>Categoria</th><th>Despesa provisória</th></tr></thead><tbody>'+data.rows.map(r=>'<tr><td>'+esc(r.date.split('-').reverse().join('/'))+'</td><td>'+esc(names[r.institution_code])+(r.last4?' · '+esc(r.last4):'')+'</td><td>'+esc(r.description)+'</td><td>'+esc((r.category||'A classificar').replace(/^Lucas\s*[-—]\s*/i,'').replace(/Vestuário/gi,'Imagem e cuidados pessoais'))+'</td><td>'+esc(brl(r.expense))+'</td></tr>').join('')+'</tbody></table></div><p>O pagamento continua representado por uma única fatura. Estes itens não criam outro débito bancário.</p>';
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
    function after() {
      if (!signedIn()) { state.started=false; state.syncing=false; state.pending={key:'',data:null,loading:false,error:''}; clearTimeout(state.timer); return; }
      paint(); paintPending();if(!statusTimer)watch();
      if (!state.started) { state.started=true; queueMicrotask(()=>refresh(false)); }
    }
    render=function(){const result=previousRender();after();return result;};
    state.refresh=()=>refresh(true);
    state.readStatus=readStatus;
    let statusTimer;function watch(){clearTimeout(statusTimer);if(!signedIn()||document.hidden)return;statusTimer=setTimeout(async()=>{await readStatus();watch();},60000);}
    document.addEventListener('visibilitychange',()=>{if(!document.hidden){readStatus();watch();}else clearTimeout(statusTimer);});
    if(typeof S!=='undefined')S.auth.onAuthStateChange?.(event=>{if(event==='SIGNED_OUT')clearTimeout(statusTimer);else watch();});
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
