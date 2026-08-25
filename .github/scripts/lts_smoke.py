import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v103"
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
            "stamp": "WIP35-v103 · Dashboard & Despesas",
            "build": "const BUILD='WIP35-v103 · Browser RPC v1 · Executive cockpit and expense intelligence'",
            "footer": "Versão WIP35-v103",
            "dashboard_operational_source": "function dashboardTodayFlow()",
            "dashboard_hero": "Seu dinheiro, sem ruído.",
            "dashboard_available": "Disponível até D+3 hoje",
            "dashboard_cash_breakdown": "Caixa bancário",
            "dashboard_d0_breakdown": "D0/D1 disponível",
            "dashboard_vested_breakdown": "RSU vested",
            "dashboard_restricted_guard": "FGTS restrito",
            "dashboard_trajectory": "Para onde o caixa está indo",
            "dashboard_agenda": "Agenda financeira",
            "dashboard_attention": "O que merece você",
            "dashboard_expenses_link": "Entenda para onde o dinheiro foi",
            "dashboard_nav_fix": "renderNav();render()});document.querySelectorAll('.dashGoExpenses')",
            "dashboard_css": "dashboard-expenses-v103-wow",
            "expense_header": "Análise de consumo",
            "expense_period_name": "function expensePeriodName()",
            "expense_rank_helper": "function expenseRankBars(items,type,limit=6)",
            "expense_rhythm": "Ritmo de gastos",
            "expense_categories": "Onde foi o dinheiro",
            "expense_centers": "Pessoas e contextos",
            "expense_recurring": "Compromissos invisíveis",
            "expense_counterparties": "Quem mais recebeu",
            "expense_quality_read": "Qualidade da leitura",
            "expense_custom_period": "Período personalizado",
            "expense_card_coverage": "Detalhe de cartão disponível desde",
            "expense_credit_tag": "crédito/estorno · reduz consumo",
            "expense_coverage_guard": "Cobertura insuficiente",
            "expense_month_guard": "expenseComparisonReliable([last.month_key,prev.month_key])",
            "expense_review_center": "Classificação de extrato",
            "safe_suggestion_action": "Confirmar sugestão",
            "card_hierarchy": "Fatura fechada → faturas abertas → parcelas futuras já contratadas",
            "card_floor": "Piso conhecido · não é previsão do valor final",
            "card_payment_rpc": "lts_browser_confirm_card_payment_v1",
            "flow_sticky_header": ".fx87-head{position:sticky!important;top:0!important",
            "flow_balance_highlight": ".fx87-balance{background:#f2f4f6",
            "flow_net_salary": "Salário líquido",
            "flow_coopharma": "consignado Coopharma",
            "flow_edit": "data-mode=\"edit\"",
            "flow_duplicate": "data-mode=\"duplicate\"",
            "flow_split": "Dividir / substituir",
            "flow_delete": "async function deleteFlowEvent(e,b)",
            "flow_delete_label": "Excluir lançamento",
            "historical_card_helper": "function historicalCardUnitForEvent(e)",
            "historical_card_summary": "Resumo histórico da fatura",
            "historical_card_no_fake_detail": "Detalhe de compras",
            "historical_card_unavailable": "Não disponível",
            "cipo_label": "Apartamento CIPÓ 396",
            "flow_shell": "class=\"flow-shell\"",
            "flow_fixed_controls": "class=\"flow-sticky-controls\"",
            "flow_single_vertical_scroll": "body.flow-view{height:100vh;overflow:hidden}",
            "updates_question": "O que falta fazer para o LTS estar atualizado?",
            "updates_ambiguous_guard": "Candidatos encontrados · nenhuma conciliação automática",
            "updates_evidence_guard": "A escolha exige vínculo documental; o LTS não decide entre candidatos equivalentes.",
            "updates_transfer_rpc": "lts_browser_confirm_overdue_transfer_v1",
            "updates_event_rpc": "lts_browser_confirm_overdue_event_v1",
            "wealth_d0": "Liquidez até D+0",
            "wealth_d3": "Liquidez realizável até D+3",
            "wealth_restricted": "Restrito · não é caixa",
            "wealth_future": "Awards futuros · indisponíveis hoje",
            "financing_future": "Saídas futuras programadas",
            "financing_debt_guard": "Não inferido pela soma das parcelas",
            "planning_d0": "Só caixa + D+0",
            "planning_d3": "Incluindo ativos já disponíveis D+3",
            "planning_vesting": "Se os vestings de novembro ocorrerem",
            "planning_fgts": "FGTS permanece patrimônio restrito e é intencionalmente excluído dos três cenários",
        }
        for name, text in required.items():
            if text in h:
                lines.append(f"{name}=ok")
            else:
                lines.append(f"{name}=missing")
                failures.append(f"{name}=missing")

        exact_once = {
            "dashboard": "function dashboard()",
            "dashboard_today_flow": "function dashboardTodayFlow()",
            "expenses": "function despesas()",
            "expense_period_name": "function expensePeriodName()",
            "expense_rank_bars": "function expenseRankBars(items,type,limit=6)",
            "cards": "function cartoes()",
            "flow": "function fluxo()",
            "flow_values": "function flowVals",
            "flow_editor": "async function openFlowEditor",
            "flow_delete": "async function deleteFlowEvent(e,b)",
            "historical_card_unit": "function historicalCardUnitForEvent(e)",
            "expense_tx": "function expenseTx",
            "expense_coverage": "function expenseCoverageStart()",
            "expense_compare": "function expense12mCompare(rows)",
            "updates": "function atualizacoes()",
            "updates_item": "function renderUpdateItem(x)",
            "wealth": "function patrimonio()",
            "financing": "function financiamentos()",
            "planning": "function planejamento()",
        }
        for name, text in exact_once.items():
            n = h.count(text)
            lines.append(f"single_{name}={n}")
            if n != 1:
                failures.append(f"single_{name}=failed")

        structure = {
            "flow_shell_open": '<div class="flow-shell">',
            "flow_controls_open": '<div class="flow-sticky-controls">',
            "dashboard_hero_open": '<div class="dash103-hero section">',
            "expense_hero_open": '<div class="exp103-hero">',
        }
        for name, text in structure.items():
            n = h.count(text)
            lines.append(f"{name}={n}")
            if n != 1:
                failures.append(f"{name}=failed")

        forbidden = {
            "old_dashboard_question": "Tenho dinheiro hoje?",
            "old_dashboard_next": "O que vence / precisa de mim?",
            "old_dashboard_trajectory": "Para onde estou indo?",
            "technical_flow_footer": "Conta corrente → D0/D1",
            "technical_main_footer": "FIX86 é piso",
            "technical_source_render": "e.category||e.source",
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
