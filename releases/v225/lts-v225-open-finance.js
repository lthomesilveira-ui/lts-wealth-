/* Additive integration: existing screen owners and financial writers are preserved. */
(function () {
  'use strict';
  const frame = document.getElementById('shell');
  function runtime() {
    if (window.__LTS_V225?.installed) return;
    const state = { installed: true, version: 'v225', status: null, loading: false,
      syncing: false, error: '', message: '', started: false, requestedAt: null, timer: null };
    window.__LTS_V225 = state;
    const previousRender = render;
    const names = { '341': 'Itaú', '237': 'Bradesco', '336': 'C6' };
    const esc = text => String(text ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
    const stamp = value => value ? new Intl.DateTimeFormat('pt-BR', {timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}).format(new Date(value)) : 'Sem atualização confirmada';
    const signedIn = () => typeof D !== 'undefined' && !!D && !N.classList.contains('hidden');
    async function rpc(name) {
      const result = await S.rpc(name);
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
      try { state.status = await rpc('lts_browser_open_finance_status_v1'); }
      catch (error) { state.error = 'Não foi possível consultar a atualização dos bancos.'; }
      finally { state.loading = false; paint(); }
    }
    function refreshScreens() {
      const exp=window.__LTS_V175_STATE, ui=window.__LTS_V168_STATE;
      if (exp) for (const key of ['expense','monthly','cards']) {
        const item=exp[key]; if (!item) continue;
        item.token=(item.token||0)+1; item.key=''; item.data=null; item.loading=false;
      }
      if (ui) {
        ui.invoices.rows=null; ui.invoices.loading=false;
        ui.updates.openFinance=state.status;
        ui.transactions.rows=null; ui.transactions.loading=false;
      }
      window.__LTS_V178_REVIEW.refresh();
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
      state.syncing=true; state.error=''; state.message=''; paint();
      try {
        const result=await rpc('lts_browser_open_finance_refresh_v1');
        if (result.ok!==true || !result.requested_at) throw Error('Solicitação não confirmada');
        state.requestedAt=new Date(result.requested_at).getTime();
        sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
        await poll();
      } catch(error) { state.syncing=false; state.error='Não foi possível solicitar a atualização. Tente novamente.'; paint(); }
    }
    function after() {
      if (!signedIn()) { state.started=false; clearTimeout(state.timer); return; }
      paint();
      if (!state.started) { state.started=true; queueMicrotask(()=>refresh(false)); }
    }
    render=function(){const result=previousRender();after();return result;};
    state.refresh=()=>refresh(true);
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
