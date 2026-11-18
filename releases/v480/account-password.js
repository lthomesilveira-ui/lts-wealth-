(() => {
  'use strict';
  const byId = id => document.getElementById(id);
  const openButton = byId('accountPasswordOpen');
  const dialog = byId('accountPasswordDialog');
  const form = byId('accountPasswordForm');
  const fields = byId('accountPasswordFields');
  const current = byId('accountCurrentPassword');
  const next = byId('accountNewPassword');
  const repeat = byId('accountRepeatPassword');
  const status = byId('accountPasswordStatus');
  const save = byId('accountPasswordSave');
  const close = byId('accountPasswordClose');
  let accountId;
  let operation;

  function clearFields() {
    form.reset();
    repeat.setCustomValidity('');
    next.setCustomValidity('');
  }

  function closeDialog() {
    if (operation) operation.abort();
    operation = undefined;
    accountId = undefined;
    clearFields();
    if (dialog.open) dialog.close();
  }

  async function openDialog() {
    // The account action also works while a new member's financial data is loading.
    if (dialog.open) return;
    const { data } = await S.auth.getSession();
    if (!data?.session?.user?.id || byId('logout').classList.contains('hidden')) return;
    clearFields();
    accountId = data.session.user.id;
    fields.hidden = false;
    save.hidden = false;
    save.disabled = false;
    close.textContent = 'Cancelar';
    status.textContent = '';
    dialog.showModal();
    current.focus();
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
    if (operation || !accountId || !dialog.open || fields.hidden) return;
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
      if (operation !== request) return;
      if (!session?.access_token || session.user?.id !== accountId) {
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
  openButton.addEventListener('click', openDialog);
  close.addEventListener('click', closeDialog);
  dialog.addEventListener('cancel', event => { event.preventDefault(); closeDialog(); });
  byId('logout').addEventListener('click', closeDialog);
  window.addEventListener('pagehide', closeDialog);
  window.addEventListener('storage', event => {
    if (dialog.open && (event.key === null || event.key === 'lts_supabase_session_v1')) closeDialog();
  });
})();
