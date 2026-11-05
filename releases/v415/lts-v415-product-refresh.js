/* V415: complete server snapshots, lightweight refresh status and bounded retries. */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.LTSV415ProductRefresh = api;
})(typeof window === 'undefined' ? globalThis : window, function () {
  'use strict';
  const STATUS_RPC = 'lts_browser_product_refresh_status_v415';
  const REQUEST_RPC = 'lts_browser_product_refresh_request_v415';
  const PRODUCT_RPC = 'lts_browser_product_v1';
  const delays = [10000, 20000, 30000];
  const MAX_STATUS_POLLS = 20;
  const phases = new Set(['ready', 'pending', 'running', 'failed']);
  const legacyEnvelope = Symbol('legacyEnvelope');
  function version(value) {
    if (typeof value === 'number' && Number.isSafeInteger(value) && value >= 0) return BigInt(value);
    if (typeof value === 'string' && /^\d+$/.test(value)) return BigInt(value);
    return null;
  }
  function normalize(value, cache = {}, available = false) {
    if (value != null && (typeof value !== 'object' || !phases.has(value.state)
      || typeof value.required !== 'boolean' || typeof value.cached_available !== 'boolean'
      || version(value.request_version) === null || version(value.completed_version) === null)) throw Error('Invalid refresh status');
    const required = value?.required === true || cache?.refresh_required === true || cache?.is_stale === true;
    const state = value?.state || (required ? 'pending' : 'ready');
    return { ...value, [legacyEnvelope]: value == null, state: state === 'ready' && required ? 'pending' : state, required,
      cached_available: value?.cached_available ?? available,
      cached_refreshed_at: value?.cached_refreshed_at || cache?.refreshed_at || null };
  }
  function ready(value) {
    const requested = version(value?.request_version), completed = version(value?.completed_version);
    return value?.state === 'ready' && value.required === false && value.cached_available === true
      && (value?.[legacyEnvelope] === true || requested !== null && completed !== null && completed >= requested);
  }
  function create(options) {
    const rpc = options.rpc, visible = options.visible || (() => true);
    const later = options.setTimeout || setTimeout, cancelLater = options.clearTimeout || clearTimeout;
    let active = false, disposed = false, generation = 0, timer = null, delayIndex = 0;
    let refresh = null, hasProduct = false, cachedAt = null, error = null, needsProduct = false;
    let statusFlight = null, requestFlight = null, productFlight = null, lastFetchedKey = null, pollAttempts = 0;
    const controls = new Set();
    const snapshot = () => ({ active, refresh, hasProduct, cachedAt, error,
      pending: active && (!!error || !ready(refresh) || needsProduct || !hasProduct), polling: timer !== null || !!statusFlight,
      productLoading: !!productFlight, requesting: !!requestFlight, pollAttempts });
    const emit = () => options.onState?.(snapshot());
    const key = value => [value?.request_version ?? '', value?.completed_version ?? '', value?.cached_refreshed_at ?? ''].join('|');
    function clearTimer() { if (timer !== null) cancelLater(timer); timer = null; }
    function interrupt() {
      generation++; clearTimer();
      for (const controller of controls) controller.abort();
      controls.clear(); statusFlight = requestFlight = productFlight = null;
    }
    function canRun() { return active && !disposed && visible(); }
    function schedule(reset = false) {
      clearTimer();
      if (!canRun() || error || ready(refresh) || refresh?.state === 'failed') return;
      if (pollAttempts >= MAX_STATUS_POLLS) { error = 'waiting'; emit(); return; }
      if (reset) delayIndex = 0;
      const delay = delays[Math.min(delayIndex++, delays.length - 1)];
      timer = later(() => { timer = null; poll(); }, delay);
    }
    async function invoke(name, token) {
      const controller = new AbortController(); controls.add(controller);
      let deadline;
      const cancelled = new Promise((resolve, reject) => {
        controller.signal.addEventListener('abort', () => reject(Error('Request cancelled')), { once: true });
        deadline = later(() => controller.abort(), name === PRODUCT_RPC ? 25000 : 10000);
      });
      try {
        const response = await Promise.race([Promise.resolve().then(() => rpc(name, {}, controller.signal)), cancelled]);
        if (token !== generation || !canRun()) return null;
        if (response?.error) {
          const issue = Error('Request unavailable'); issue.status = response.error.status; issue.code = response.error.code;
          throw issue;
        }
        if (!response?.data || response.data.ok === false) throw Error('Invalid response');
        return response.data;
      } finally { cancelLater(deadline); controls.delete(controller); }
    }
    function fail(kind, issue, token) {
      if (token !== generation || !active || disposed) return;
      clearTimer(); error = kind; emit();
      if (issue?.status === 401 || ['PGRST301', 'session_not_found', 'refresh_token_not_found'].includes(issue?.code))
        options.onAuthError?.(issue);
    }
    function setRefresh(value, cache, available) {
      const next = normalize(value, cache, available);
      const priorVersion = version(refresh?.request_version), nextVersion = version(next.request_version);
      if (priorVersion !== null && nextVersion !== null && nextVersion < priorVersion) return;
      if (priorVersion !== nextVersion) pollAttempts = 0;
      refresh = next; cachedAt = refresh.cached_refreshed_at || cachedAt;
      if (!ready(refresh)) needsProduct = true;
    }
    function acceptProduct(payload) {
      if (!payload || typeof payload !== 'object') throw Error('Invalid product envelope');
      const available = !!payload.mvp && typeof payload.mvp === 'object' && !Array.isArray(payload.mvp);
      if (!available && !payload.refresh) throw Error('Product unavailable');
      const incoming = normalize(payload.refresh, payload.cache, available);
      const priorVersion = version(refresh?.request_version), incomingVersion = version(incoming.request_version);
      if (priorVersion !== null && incomingVersion !== null && incomingVersion < priorVersion) throw Error('Obsolete product envelope');
      active = true; hasProduct = available; error = null;
      setRefresh(payload.refresh, payload.cache, available);
      if (!available && ready(refresh)) throw Error('Ready product unavailable');
      if (ready(refresh) && available) { needsProduct = false; lastFetchedKey = key(refresh); pollAttempts = 0; clearTimer(); }
      else schedule(true);
      emit(); return snapshot();
    }
    async function fetchReady(value, token) {
      if (!canRun() || productFlight || token !== generation) return productFlight;
      const requestedKey = key(value);
      if (lastFetchedKey === requestedKey) { fail('confirmation', null, token); return; }
      const job = Promise.resolve().then(async () => {
        try {
          options.beforeProduct?.();
          const payload = await invoke(PRODUCT_RPC, token);
          if (!payload || token !== generation) return;
          const next = normalize(payload.refresh, payload.cache, !!payload.mvp);
          const sameRequest = version(next.request_version) === version(value.request_version);
          if (!ready(next) && sameRequest) { fail('confirmation', null, token); return; }
          const state = acceptProduct(payload);
          if (token !== generation) return;
          if (payload.mvp) await options.onProduct?.(payload, { fresh: ready(state.refresh) });
          if (token !== generation) return;
          if (ready(state.refresh)) options.onReady?.(snapshot());
        } catch (issue) { fail('product', issue, token); }
        finally { if (productFlight === job) { productFlight = null; emit(); } }
      });
      productFlight = job; emit(); return job;
    }
    function poll() {
      clearTimer();
      if (!canRun()) return Promise.resolve();
      if (refresh?.[legacyEnvelope] === true && ready(refresh) && hasProduct && !needsProduct && !error) return Promise.resolve();
      if (statusFlight) return statusFlight;
      if (requestFlight || productFlight) return requestFlight || productFlight;
      if (pollAttempts >= MAX_STATUS_POLLS) { error = 'waiting'; emit(); return Promise.resolve(); }
      pollAttempts++;
      const token = generation;
      const job = Promise.resolve().then(async () => {
        try {
          const payload = await invoke(STATUS_RPC, token);
          if (!payload || token !== generation) return;
          if (!payload.refresh) throw Error('Refresh status unavailable');
          error = null; setRefresh(payload.refresh, {}, hasProduct); emit();
          if (ready(refresh)) {
            clearTimer();
            if (key(refresh) !== lastFetchedKey) needsProduct = true;
            if (needsProduct || !hasProduct) await fetchReady(refresh, token);
            else pollAttempts = 0;
          } else schedule();
        } catch (issue) { fail('status', issue, token); }
        finally { if (statusFlight === job) { statusFlight = null; emit(); } }
      });
      statusFlight = job; emit(); return job;
    }
    function observeRefresh(value) {
      if (disposed) return;
      active = true; error = null; needsProduct = true;
      setRefresh(value, {}, hasProduct); emit();
      if (ready(refresh)) { lastFetchedKey = null; return poll(); }
      schedule(true); return Promise.resolve();
    }
    function request() {
      if (!canRun()) return Promise.resolve();
      if (requestFlight) return requestFlight;
      if (productFlight) return productFlight;
      clearTimer(); const token = generation; error = null;
      const job = Promise.resolve().then(async () => {
        try {
          const payload = await invoke(REQUEST_RPC, token);
          if (!payload || token !== generation) return;
          if (!payload.refresh) throw Error('Refresh status unavailable');
          setRefresh(payload.refresh, {}, hasProduct); needsProduct = true; error = null;
          if (refresh.state !== 'failed') options.onRequested?.(snapshot());
          if (ready(refresh)) {
            lastFetchedKey = null;
            await fetchReady(refresh, token);
          } else schedule(true);
        } catch (issue) { fail('request', issue, token); }
        finally { if (requestFlight === job) { requestFlight = null; emit(); } }
      });
      requestFlight = job; emit(); return job;
    }
    function retry() {
      if (!canRun()) return Promise.resolve();
      lastFetchedKey = null; delayIndex = 0; pollAttempts = 0;
      if (refresh?.state === 'failed' && !error) return request();
      error = null; emit(); return poll();
    }
    function pause() { interrupt(); emit(); }
    function resume() { if (!canRun()) return; error = null; poll(); }
    function stop() {
      interrupt(); active = false; refresh = null; hasProduct = false; cachedAt = null;
      error = null; needsProduct = false; lastFetchedKey = null; delayIndex = 0; pollAttempts = 0; emit();
    }
    function dispose() { stop(); disposed = true; }
    return { acceptProduct, observeRefresh, poll, retry, request, pause, resume, stop, dispose, snapshot, repaint: emit };
  }
  function mount(options) {
    const doc = options.document || document, win = doc.defaultView || window;
    const app = options.app, banner = doc.createElement('section');
    banner.id = 'ltsRefreshStatusV415'; banner.className = 'v415-refresh-status'; banner.hidden = true;
    banner.setAttribute('aria-live', 'polite'); app.before(banner);
    const style = doc.createElement('style'); style.id = 'ltsRefreshStyleV415';
    style.textContent = '.v415-refresh-status{box-sizing:border-box;max-width:1444px;margin:12px auto 0;padding:11px 14px;border:1px solid #dfcfa9;border-radius:12px;background:#fff9ed;color:#5b4824;display:flex;align-items:center;justify-content:space-between;gap:12px;font:13px/1.4 system-ui}.v415-refresh-status[hidden]{display:none!important}.v415-refresh-status strong{display:block;font-size:13px}.v415-refresh-status p{font-size:12px;margin:3px 0 0}.v415-refresh-status button{min-height:40px;flex:none;white-space:nowrap}.v415-refresh-status time{white-space:nowrap}@media(max-width:1480px){.v415-refresh-status{margin-left:18px;margin-right:18px}}@media(max-width:500px){.v415-refresh-status{margin:10px 10px 0;padding:10px 12px;align-items:flex-start;flex-wrap:wrap;gap:7px}.v415-refresh-status p{font-size:11px}}';
    doc.head.append(style);
    function formattedTime(value) {
      const time = value && new Date(value);
      return time && Number.isFinite(time.getTime()) ? new Intl.DateTimeFormat('pt-BR', {
        timeZone: 'America/Sao_Paulo', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit'
      }).format(time) : null;
    }
    function describe(state) {
      const failed = !!state.error || state.refresh?.state === 'failed';
      const date = formattedTime(state.cachedAt);
      return { failed,
        title: state.error === 'waiting' ? 'A atualização está demorando mais que o esperado' : failed ? 'Não foi possível concluir a atualização' : 'Atualizando seus dados',
        detail: state.hasProduct ? (date ? 'Exibindo a atualização anterior. Última atualização: ' + date + '.' : 'Exibindo a última atualização disponível.')
          : failed ? 'Tente novamente para preparar seus dados.' : 'Esta tela será aberta assim que os dados estiverem prontos.',
        retry: failed, retryLabel: state.error === 'waiting' ? 'Verificar novamente' : 'Tentar novamente' };
    }
    const controller = create({ ...options, visible: () => doc.visibilityState !== 'hidden' && !options.isSignedOut?.(),
      onState(state) {
        const info = describe(state);
        const show = state.active && state.pending && state.hasProduct && options.isReadyView();
        banner.hidden = !show;
        if (show) {
          banner.setAttribute('role', info.failed ? 'alert' : 'status'); banner.replaceChildren();
          const block = doc.createElement('div'), title = doc.createElement('strong'), detail = doc.createElement('p');
          title.textContent = info.title; detail.textContent = info.detail; block.append(title, detail); banner.append(block);
          if (info.retry) {
            const button = doc.createElement('button'); button.type = 'button'; button.className = 'btn ghost';
            button.textContent = info.retryLabel; button.disabled = state.requesting || state.productLoading;
            button.onclick = () => controller.retry(); banner.append(button);
          }
        }
        if (state.active && !state.hasProduct && options.isPreparingView()) options.showPreparing(info, () => controller.retry());
        options.onState?.(state);
      }
    });
    const visibility = () => doc.visibilityState === 'hidden' ? controller.pause() : controller.resume();
    const invalidated = () => controller.poll();
    const hide = event => event.persisted ? controller.pause() : dispose();
    const show = event => { if (event.persisted) controller.resume(); };
    function dispose() {
      controller.dispose(); doc.removeEventListener('visibilitychange', visibility);
      win.removeEventListener('pagehide', hide); win.removeEventListener('pageshow', show);
      win.removeEventListener('lts:data-invalidated', invalidated); banner.remove(); style.remove();
    }
    doc.addEventListener('visibilitychange', visibility); win.addEventListener('pagehide', hide); win.addEventListener('pageshow', show);
    win.addEventListener('lts:data-invalidated', invalidated);
    return { ...controller, describe: () => describe(controller.snapshot()), paint: controller.repaint, dispose };
  }
  return { create, mount, normalize, ready, STATUS_RPC, REQUEST_RPC, PRODUCT_RPC, MAX_STATUS_POLLS };
});
