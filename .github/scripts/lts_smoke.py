import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v120"
SUPABASE_URL = "https://tadhkamnwtsbdozwkyut.supabase.co"
ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "index.html"
RESULT = ROOT / "smoke-result.txt"
TMP = Path("/tmp/lts-shell.html")


def key():
    m = re.search(r"sb_publishable_[A-Za-z0-9_-]+", INDEX.read_text(encoding="utf-8"))
    if not m:
        raise RuntimeError("publishable_key=missing")
    return m.group(0)


def shell(k):
    url = f"{SUPABASE_URL}/rest/v1/lts_public_ui_shell?version=eq.{VERSION}&select=html"
    req = urllib.request.Request(url, headers={"apikey": k, "Authorization": "Bearer " + k})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    if not data or not data[0].get("html"):
        raise RuntimeError("shell=missing")
    return data[0]["html"]


def main():
    lines = [f"version={VERSION}"]
    fail = []
    try:
        h = shell(key())
        TMP.write_text(h, encoding="utf-8")
        lines.append(f"shell_bytes={len(h)}")
        scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", h, re.I | re.S)
        lines.append(f"inline_scripts={len(scripts)}")
        for i, s in enumerate(scripts):
            p = Path(f"/tmp/lts-script-{i}.js")
            p.write_text(s, encoding="utf-8")
            r = subprocess.run(["node", "--check", str(p)], capture_output=True, text=True)
            lines.append(f"node_check_{i}={r.returncode}")
            if r.returncode:
                fail.append(f"node_check_{i}")

        req = {
            "stamp": "WIP35-v120 · Conciliação explícita",
            "build": "const BUILD='WIP35-v120 · Browser RPC v1 · Explicit reconciliation choice'",
            "footer": "Versão WIP35-v120",
            "seven_main_tabs": "const main=['Dashboard','Atualizações','Fluxo Diário','Despesas','Cartões','Patrimônio','Planejamento']",
            "updates_title": "O que precisa de você, num único lugar.",
            "updates_actions": "Ações pendentes",
            "updates_info": "Informações e proteções do LTS",
            "updates_css": "updates-actionable-v116",
            "generic_context_clear": "INPUTCTX=null;V=b.dataset.v",
            "dashboard_actionable_count": "actionable_count??D.updates?.pending_count",
            "input_context_css": "updates-input-context-v115",
            "input_document_v2": "lts_browser_register_document_v2",
            "input_text_v2": "lts_browser_register_structured_text_v2",
            "flow": "lts_browser_flow_v3",
            "flow_last5": "data-p=\"Últimos 5 dias\"",
            "expenses": "Para onde foi o dinheiro?",
            "expense_rpc": "lts_browser_expense_dual_lens_v1",
            "expenses_four_tabs": "tabs=['Visão','Caixa','Consumo','Detalhes']",
            "expenses_insight_css": "expenses-v117-insight-layer",
            "expenses_concentration": "Concentração do consumo",
            "expenses_recurring": "Padrões recorrentes observados",
            "expenses_coverage_guard": "Comparação temporal protegida",
            "cards": "Cada cartão em um lugar.",
            "cards_action_css": "cards-v118-operational-actions",
            "cards_payment_helper": "function card118PaymentUpdate(m)",
            "cards_payment_action": "Confirmar pagamento",
            "cards_payment_binding": "document.querySelectorAll('.cardpayconfirm').forEach(b=>b.onclick=()=>confirmCardPayment(b))",
            "cards_cash_consumption_guard": "Caixa ≠ consumo",
            "wealth": "O que é seu hoje. Sem somar o que ainda não é.",
            "financing": "O que já está contratado. E o que ainda precisa ser confirmado.",
            "cipo_css": "cipo-document-v119",
            "cipo_task_fn": "function cipo119Task()",
            "cipo_open_fn": "function openUpdateContext(id)",
            "cipo_action": "Enviar posição Bradesco",
            "cipo_task_id": "document_cipo_current_debt_balance",
            "cipo_binding": "document.querySelectorAll('.cipo119doc').forEach(b=>b.onclick=()=>openUpdateContext(b.dataset.update))",
            "cipo_guard": "Saldo devedor atual",
            "reconciliation_css": "reconciliation-choice-v120",
            "reconciliation_fn": "function confirmReconciliationCandidate(b)",
            "reconciliation_rpc": "lts_browser_confirm_reconciliation_candidate_v1",
            "reconciliation_action": "Usar este crédito",
            "reconciliation_binding": "document.querySelectorAll('.recon120-use').forEach(b=>b.onclick=()=>confirmReconciliationCandidate(b))",
            "reconciliation_guard": "Nenhuma nova entrada é criada e nenhum valor realizado é alterado.",
            "planning_title": "Quanto tempo seu caixa aguenta?",
            "dashboard_title": "Sua vida financeira, em uma tela.",
            "new_category": "+ Nova categoria",
            "merchant": "Sugestão por estabelecimento identificado",
            "merchant_guard": "Nada vira regra sem sua confirmação.",
        }
        for n, t in req.items():
            ok = t in h
            lines.append(f"{n}={'ok' if ok else 'missing'}")
            if not ok:
                fail.append(n)

        exact = {
            "render_nav": "function renderNav()",
            "updates": "function atualizacoes()",
            "update_action": "function updateIsAction(x)",
            "update_info": "function renderUpdateInfo(x)",
            "reconciliation_confirm": "function confirmReconciliationCandidate(b)",
            "dashboard": "function dashboard()",
            "flow": "function fluxo()",
            "expenses": "function despesas()",
            "expense_analysis": "function exp117Analysis(rows,j)",
            "expense_recurring_rows": "function exp117RecurringRows(xs)",
            "expense_center_rows": "function exp117CenterRows(xs,total)",
            "expense_coverage_card": "function exp117CoverageCard(a)",
            "cards": "function cartoes()",
            "cards_payment_helper": "function card118PaymentUpdate(m)",
            "cards_model": "function card111Card(m)",
            "cipo_task": "function cipo119Task()",
            "cipo_open": "function openUpdateContext(id)",
            "wealth": "function patrimonio()",
            "financing": "function financiamentos()",
            "planning": "function planejamento()",
            "config": "function config()",
            "ledger": "function lancamentos()",
            "inputs": "function entradas()",
            "input_context": "function inputContextBanner()",
            "input_task_context": "function inputTaskContext()",
            "diagnostic": "function diagnostico()",
        }
        for n, t in exact.items():
            c = h.count(t)
            lines.append(f"single_{n}={c}")
            if c != 1:
                fail.append(f"single_{n}")

        for marker in [
            "expenses-v110-dual-lens",
            "cards-v111-by-card-cockpit",
            "wealth-financing-v112-trust-first",
            "navigation-updates-v113",
            "dashboard-planning-v114-cockpit",
            "updates-input-context-v115",
            "updates-actionable-v116",
            "expenses-v117-insight-layer",
            "cards-v118-operational-actions",
            "cipo-document-v119",
            "reconciliation-choice-v120",
        ]:
            c = h.count(marker)
            lines.append(f"css_{marker}={c}")
            if c != 1:
                fail.append(f"css_{marker}")

        cipo_actions = h.count("Enviar posição Bradesco")
        cipo_bindings = h.count("document.querySelectorAll('.cipo119doc').forEach(b=>b.onclick=()=>openUpdateContext(b.dataset.update))")
        recon_actions = h.count("Usar este crédito")
        recon_bindings = h.count("document.querySelectorAll('.recon120-use').forEach(b=>b.onclick=()=>confirmReconciliationCandidate(b))")
        lines.append(f"cipo_action_count={cipo_actions}")
        lines.append(f"cipo_binding_count={cipo_bindings}")
        lines.append(f"reconciliation_action_template_count={recon_actions}")
        lines.append(f"reconciliation_binding_count={recon_bindings}")
        if cipo_actions != 2:
            fail.append("cipo_action_count")
        if cipo_bindings != 2:
            fail.append("cipo_binding_count")
        if recon_actions != 1:
            fail.append("reconciliation_action_template_count")
        if recon_bindings != 1:
            fail.append("reconciliation_binding_count")

        forbidden = {
            "old_v119_footer": "Versão WIP35-v119",
            "literal_backslash_n_open": r"\nfunction openUpdateContext",
            "literal_backslash_n_reconciliation": r"\nfunction confirmReconciliationCandidate",
            "old_document_rpc": "lts_browser_register_document_v1",
            "old_structured_rpc": "lts_browser_register_structured_text_v1",
            "flow_rpc_v2": "lts_browser_flow_v2",
            "old_nav_map": "N.innerHTML=NAV.map((x,i)=>",
            "expense_since_2023": 'data-dper="2023"',
            "expense_since_2013": 'data-dper="2013"',
            "cards_null_detail": "cardSettlementInline(null)",
            "old_wealth_title": "O que está disponível. E o que ainda não está.",
            "old_financing_title": "Compromissos que já estão contratados.",
            "technical": "e.category||e.source",
            "cdn": "cdn.jsdelivr.net",
        }
        for n, t in forbidden.items():
            present = t in h
            lines.append(f"{n}={'present' if present else 'absent'}")
            if present:
                fail.append(n)

        if fail:
            lines += ["publish=blocked", "failures=" + ",".join(fail)]
            RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
            print(RESULT.read_text())
            return 1

        shutil.copyfile(TMP, INDEX)
        lines.append("publish=ready")
        RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(RESULT.read_text())
        return 0
    except Exception as e:
        lines += ["publish=blocked", f"exception={type(e).__name__}:{e}"]
        RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(RESULT.read_text())
        return 1


if __name__ == '__main__':
    sys.exit(main())
