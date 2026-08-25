import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v102"
SUPABASE_URL = "https://tadhkamnwtsbdozwkyut.supabase.co"
ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "index.html"
RESULT = ROOT / "smoke-result.txt"
TMP = Path("/tmp/lts-shell.html")


def find_public_key() -> str:
    current = INDEX.read_text(encoding="utf-8")
    m = re.search(r"sb_publishable_[A-Za-z0-9_-]+", current)
    if not m:
        raise RuntimeError("publishable_key=missing")
    return m.group(0)


def fetch_shell(key: str) -> str:
    url = f"{SUPABASE_URL}/rest/v1/lts_public_ui_shell?version=eq.{VERSION}&select=html"
    req = urllib.request.Request(url, headers={"apikey": key, "Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=30) as response:
        data = json.load(response)
    if not data or not data[0].get("html"):
        raise RuntimeError("shell=missing")
    return data[0]["html"]


def main() -> int:
    lines = [f"version={VERSION}"]
    failures = []
    try:
        key = find_public_key()
        h = fetch_shell(key)
        TMP.write_text(h, encoding="utf-8")
        lines.append(f"shell_bytes={len(h)}")

        scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", h, re.I | re.S)
        lines.append(f"inline_scripts={len(scripts)}")
        if not scripts:
            failures.append("inline_scripts=missing")
        for i, script in enumerate(scripts):
            path = Path(f"/tmp/lts-script-{i}.js")
            path.write_text(script, encoding="utf-8")
            p = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
            lines.append(f"node_check_{i}={p.returncode}")
            if p.returncode:
                failures.append(f"node_check_{i}=failed")
                if p.stderr:
                    lines.append(p.stderr.strip())

        required = {
            "stamp": "WIP35-v102 · Fluxo consistente e editável",
            "build": "const BUILD='WIP35-v102 · Browser RPC v1 · Flow continuity and editable forecasts'",
            "footer_version": "Versão WIP35-v102",
            "dashboard_today_question": "Tenho dinheiro hoje?",
            "dashboard_next_question": "O que vence / precisa de mim?",
            "dashboard_trajectory_question": "Para onde estou indo?",
            "dashboard_cash_guard": "sem FGTS e sem awards futuros",
            "dashboard_fgts_guard": "FGTS projetado permanece patrimônio restrito",
            "card_hierarchy": "Fatura fechada → faturas abertas → parcelas futuras já contratadas",
            "card_future_floor": "Piso conhecido · não é previsão do valor final",
            "card_paid_recent": "Pagas recentemente",
            "card_payment_rpc": "lts_browser_confirm_card_payment_v1",
            "sticky_table_header": ".fx87-head{position:sticky!important;top:0!important",
            "balance_highlight": ".fx87-balance{background:#f2f4f6",
            "net_salary_label": "Salário líquido",
            "coopharma_note": "consignado Coopharma",
            "flow_edit_action": "data-mode=\"edit\"",
            "flow_duplicate_action": "data-mode=\"duplicate\"",
            "flow_split_action": "Dividir / substituir",
            "flow_delete_button": "class=\"chip flowdeletebtn\"",
            "flow_delete_fn": "async function deleteFlowEvent(e,b)",
            "flow_delete_bind": "document.querySelectorAll('.flowdeletebtn')",
            "flow_delete_guard": "registro original será preservado para auditoria",
            "flow_delete_label": "Excluir lançamento",
            "flow_future_editor": "async function openFlowEditor",
            "historical_card_helper": "function historicalCardUnitForEvent(e)",
            "historical_card_display": "function flowDisplayDescription(e)",
            "historical_card_summary": "Resumo histórico da fatura",
            "historical_card_no_fake_detail": "Detalhe de compras",
            "historical_card_unavailable": "Não disponível",
            "historical_card_open": "Abrir fatura</button>",
            "cipo_human_label": "Apartamento CIPÓ 396",
            "flow_shell": "class=\"flow-shell\"",
            "flow_fixed_controls": "class=\"flow-sticky-controls\"",
            "flow_view_toggle": "classList.toggle('flow-view',V==='Fluxo Diário')",
            "flow_single_vertical_scroll": "body.flow-view{height:100vh;overflow:hidden}",
            "flow_table_scroll": ".flow-shell .fx87-scroll{height:100%;max-height:none!important;overflow:auto!important",
            "flow_footer_hidden": "body.flow-view .footer{display:none}",
            "expense_default_12m": "DSPPER='12m'",
            "expense_card_coverage": "Detalhe de cartão disponível a partir de",
            "expense_credit_tag": "crédito/estorno · reduz consumo",
            "expense_coverage_guard": "Cobertura insuficiente",
            "expense_month_guard": "expenseComparisonReliable([last.month_key,prev.month_key])",
            "expense_mixed_guard": "Comparações temporais que atravessam a mudança de cobertura de cartão são limitadas",
            "expense_review_center": "Classificação de extrato",
            "safe_suggestion_action": "Confirmar sugestão",
            "updates_question": "O que falta fazer para o LTS estar atualizado?",
            "updates_ambiguous_guard": "Candidatos encontrados · nenhuma conciliação automática",
            "updates_evidence_guard": "A escolha exige vínculo documental; o LTS não decide entre candidatos equivalentes.",
            "updates_transfer_rpc": "lts_browser_confirm_overdue_transfer_v1",
            "updates_event_rpc": "lts_browser_confirm_overdue_event_v1",
            "updates_evidence_action": "Enviar evidência",
            "updates_document_action": "Enviar documento",
            "updates_input_route": "V='Entradas';renderNav();render()",
            "wealth_d0": "Liquidez até D+0",
            "wealth_d3": "Liquidez realizável até D+3",
            "wealth_restricted": "Restrito · não é caixa",
            "wealth_future": "Awards futuros · indisponíveis hoje",
            "cipo_debt_missing": "Saldo devedor contratual atual",
            "financing_future": "Saídas futuras programadas",
            "financing_debt_guard": "Não inferido pela soma das parcelas",
            "planning_d0": "Só caixa + D+0",
            "planning_d3": "Incluindo ativos já disponíveis D+3",
            "planning_vesting": "Se os vestings de novembro ocorrerem",
            "planning_fgts_guard": "FGTS permanece patrimônio restrito e é intencionalmente excluído dos três cenários",
        }
        for name, text in required.items():
            if text in h:
                lines.append(f"{name}=ok")
            else:
                lines.append(f"{name}=missing")
                failures.append(f"{name}=missing")

        exact_once = {
            "dashboard": "function dashboard()",
            "cards": "function cartoes()",
            "flow": "function fluxo()",
            "flow_values": "function flowVals",
            "flow_editor": "async function openFlowEditor",
            "flow_delete": "async function deleteFlowEvent(e,b)",
            "historical_card_unit": "function historicalCardUnitForEvent(e)",
            "flow_display_description": "function flowDisplayDescription(e)",
            "expense_tx": "function expenseTx",
            "expense_coverage": "function expenseCoverageStart()",
            "expense_compare": "function expense12mCompare(rows)",
            "expense_review": "function expenseClassificationUpdates",
            "updates": "function atualizacoes()",
            "updates_item": "function renderUpdateItem(x)",
            "updates_group": "function groupUpdateItems(raw)",
            "updates_transfer_confirm": "async function confirmOverdueTransfer(b)",
            "updates_event_confirm": "async function confirmOverdueEvent(b)",
            "card_payment_confirm": "async function confirmCardPayment(b)",
            "wealth": "function patrimonio()",
            "financing": "function financiamentos()",
            "planning": "function planejamento()",
        }
        for name, text in exact_once.items():
            n = h.count(text)
            lines.append(f"single_{name}={n}")
            if n != 1:
                failures.append(f"single_{name}=failed")

        # Structure sanity for the desktop flow viewport.
        for name, op, cl in [
            ("flow_shell_open", '<div class="flow-shell">', '</div>'),
            ("flow_controls_open", '<div class="flow-sticky-controls">', '</div>'),
        ]:
            n = h.count(op)
            lines.append(f"{name}={n}")
            if n != 1:
                failures.append(f"{name}=failed")

        p = h.find("function cartoes()")
        card_snip = h[p:p + 13000] if p >= 0 else ""
        for text in ["source_status", "source_winner", "Unidades FIX86"]:
            key_name = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
            if text in card_snip:
                lines.append(f"card_forbidden_{key_name}=present")
                failures.append(f"card_forbidden_{key_name}=present")
            else:
                lines.append(f"card_forbidden_{key_name}=absent")

        forbidden = {
            "technical_flow_footer": "Conta corrente → D0/D1",
            "technical_main_footer": "FIX86 é piso",
            "technical_source_render": "e.category||e.source",
            "split_historical": "Histórico bancário",
            "split_future": "Hoje e projeção de caixa",
            "old_updates_copy": "Central de review & approve",
            "old_cancel_projection": ">Cancelar projeção</button>",
            "cdn": "cdn.jsdelivr.net",
        }
        for name, text in forbidden.items():
            if text in h:
                lines.append(f"{name}=present")
                failures.append(f"{name}=present")
            else:
                lines.append(f"{name}=absent")

        if failures:
            lines.extend(["publish=blocked", "failures=" + ",".join(failures)])
            RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
            print(RESULT.read_text(encoding="utf-8"))
            return 1

        shutil.copyfile(TMP, INDEX)
        lines.append("publish=ready")
        RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(RESULT.read_text(encoding="utf-8"))
        return 0
    except Exception as exc:
        lines.extend(["publish=blocked", f"exception={type(exc).__name__}:{exc}"])
        RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(RESULT.read_text(encoding="utf-8"))
        return 1


if __name__ == "__main__":
    sys.exit(main())
