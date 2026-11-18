(() => {
  'use strict';
  const byId = id => document.getElementById(id);
  const dialog = byId('accountPasswordDialog');
  const form = byId('accountPasswordForm');
  const fields = byId('accountPasswordFields');
  const current = byId('accountCurrentPassword');
  const next = byId('accountNewPassword');
  const repeat = byId('accountRepeatPassword');
  const status = byId('accountPasswordStatus');
  const save = byId('accountPasswordSave');
  const close = byId('accountPasswordClose');
  let openedIdentity;
  let operation;

  function clearFields() {
    form.reset();
    repeat.setCustomValidity('');
    next.setCustomValidity('');
  }

  function closeDialog() {
    if (operation) operation.abort();
    operation = undefined;
    openedIdentity = undefined;
    clearFields();
    if (dialog.open) dialog.close();
  }

  async function ownUserId(session, signal) {
    if (!session?.access_token) return null;
    if (session.user?.id) return session.user.id;
    const result = await fetch(U + '/auth/v1/user', {
      method: 'GET', cache: 'no-store', credentials: 'omit', redirect: 'error',
      headers: { apikey: K, Authorization: 'Bearer ' + session.access_token },
      signal
    });
    if (!result.ok) return null;
    const user = await result.json();
    return user?.id || null;
  }

  function openDialog() {
    if (dialog.open || byId('logout').classList.contains('hidden')) return;
    clearFields();
    fields.hidden = false;
    save.hidden = false;
    save.disabled = false;
    close.textContent = 'Cancelar';
    status.textContent = '';
    dialog.showModal();
    current.focus();
    // A legacy session can carry a valid access token without a stored user.
    openedIdentity = Promise.resolve().then(() => S.auth.getSession())
      .then(({data}) => ownUserId(data?.session)).catch(() => null);
  }

  function showProviderError(code, httpStatus) {
    if (code === 'weak_password') return 'Escolha uma senha mais forte e tente novamente.';
    if (code === 'same_password') return 'Escolha uma senha diferente da atual.';
    if (code === 'reauthentication_needed' || code === 'session_not_found' || httpStatus === 401)
      return 'Entre novamente no Wealth para alterar a senha.';
    if (code === 'invalid_credentials' || code === 'current_password_invalid' || code === 'incorrect_password')
      return 'Confira a senha atual e tente novamente.';
    if (httpStatus === 429) return 'Aguarde um momento antes de tentar novamente.';
    return 'A alteração não foi confirmada. Confira a senha atual e a nova senha.';
  }

  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (operation || !openedIdentity || !dialog.open || fields.hidden) return;
    repeat.setCustomValidity(repeat.value === next.value ? '' : 'As duas senhas precisam coincidir.');
    next.setCustomValidity(next.value === current.value ? 'Escolha uma senha diferente da atual.' : '');
    if (!form.reportValidity()) return;
    const request = new AbortController();
    operation = request;
    save.disabled = true;
    close.textContent = 'Fechar';
    status.textContent = 'Alterando a senha…';
    const timeout = setTimeout(() => request.abort(), 18000);
    try {
      const { data } = await S.auth.getSession();
      const session = data?.session;
      const [accountId, activeId] = await Promise.all([openedIdentity, ownUserId(session, request.signal)]);
      if (operation !== request) return;
      if (!accountId || !activeId || activeId !== accountId) {
        clearFields();
        status.textContent = 'Entre novamente no Wealth para alterar a senha.';
        return;
      }
      const response = await fetch(U + '/auth/v1/user', {
        method: 'PUT', cache: 'no-store', credentials: 'omit', redirect: 'error',
        headers: { apikey: K, Authorization: 'Bearer ' + session.access_token, 'Content-Type': 'application/json' },
        body: JSON.stringify({ current_password: current.value, password: next.value }),
        signal: request.signal
      });
      const result = await response.json().catch(() => null);
      if (operation !== request) return;
      if (!response.ok) {
        status.textContent = showProviderError(result?.error_code || result?.code, response.status);
        return;
      }
      if (!result || result.id !== accountId) {
        status.textContent = 'Não foi possível confirmar a alteração. Confira no próximo acesso.';
        return;
      }
      clearFields();
      fields.hidden = true;
      save.hidden = true;
      status.textContent = 'Senha alterada. Use a nova senha no próximo acesso.';
      close.focus();
    } catch {
      if (operation === request)
        status.textContent = 'A conexão foi interrompida. Confira a senha no próximo acesso antes de tentar de novo.';
    } finally {
      clearTimeout(timeout);
      if (operation === request) {
        operation = undefined;
        save.disabled = false;
      }
    }
  });
  for (const input of [current, next, repeat]) input.addEventListener('input', () => {
    next.setCustomValidity('');
    repeat.setCustomValidity('');
  });
  document.addEventListener('click', event => {
    if (event.target.closest?.('#accountPasswordOpen')) openDialog();
  });
  close.addEventListener('click', closeDialog);
  dialog.addEventListener('cancel', event => { event.preventDefault(); closeDialog(); });
  byId('logout').addEventListener('click', closeDialog);
  window.addEventListener('pagehide', closeDialog);
  window.addEventListener('storage', event => {
    if (dialog.open && (event.key === null || event.key === 'lts_supabase_session_v1')) closeDialog();
  });
})();
