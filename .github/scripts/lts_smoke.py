import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v104"
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
            "stamp": "WIP35-v104 · Patrimônio + Planejamento",
            "build": "const BUILD='WIP35-v104 · Browser RPC v1 · Wealth financing planning experience'",
            "footer": "Versão WIP35-v104",
            # v103 wow experience retained
            "dashboard_source": "function dashboardTodayFlow()",
            "dashboard_hero": "Seu dinheiro, sem ruído.",
            "dashboard_available": "Disponível até D+3 hoje",
            "dashboard_trajectory": "Para onde o caixa está indo",
            "dashboard_agenda": "Agenda financeira",
            "dashboard_attention": "O que merece você",
            "dashboard_css": "dashboard-expenses-v103-wow",
            "expense_header": "Análise de consumo",
            "expense_rhythm": "Ritmo de gastos",
            "expense_categories": "Onde foi o dinheiro",
            "expense_centers": "Pessoas e contextos",
            "expense_recurring": "Compromissos invisíveis",
            "expense_counterparties": "Quem mais recebeu",
            "expense_quality": "Qualidade da leitura",
            "expense_coverage_guard": "Cobertura insuficiente",
            "expense_month_guard": "expenseComparisonReliable([last.month_key,prev.month_key])",
            # v104 wealth
            "wealth_title": "O que está disponível. E o que ainda não está.",
            "wealth_operational_liquidity": "Liquidez realizável até D+3",
            "wealth_cash": "Caixa",
            "wealth_d01": "D0/D1",
            "wealth_vested": "RSU vested",
            "wealth_restricted": "Patrimônio fora do caixa",
            "wealth_future_calendar": "Próxima liquidez futura",
            "wealth_no_fake_available": "não aumentam o “disponível hoje”",
            "wealth_cipo": "Apartamento CIPÓ 396",
            "wealth_cipo_no_networth": "patrimônio líquido não calculado",
            "wealth_cipo_debt_missing": "Saldo devedor atual",
            "wealth_cipo_value_missing": "Valor atual do imóvel",
            "wealth_cipo_guard": "nenhum valor será inventado",
            # v104 financing
            "financing_title": "Compromissos que já estão contratados.",
            "financing_future_flow": "Saídas futuras mapeadas",
            "financing_not_debt": "Não representa saldo devedor consolidado",
            "financing_next": "Próxima saída",
            "financing_progress": "eventos percorridos",
            "financing_debt": "Saldo devedor atual",
            "financing_debt_guard": "não inferido pelas parcelas",
            "financing_payroll": "reduz o salário líquido no Fluxo e não vira uma segunda saída bancária",
            "financing_rule": "Parcela mostra o desembolso periódico. Fluxo futuro mostra o que ainda está programado.",
            # v104 planning
            "planning_title": "Três cenários. Uma única verdade de caixa.",
            "planning_same_motor": "O mesmo motor do Fluxo e do Dashboard",
            "planning_d01": "Só caixa + D0/D1",
            "planning_d3": "Incluindo ativos já disponíveis D+3",
            "planning_vesting": "Se os vestings de novembro ocorrerem",
            "planning_realizable": "Realizável hoje",
            "planning_conditional": "Com vestings programados",
            "planning_fgts_zero": "FGTS no caixa",
            "planning_fgts_value": "R$ 0,00",
            "planning_vesting_guard": "continuam condicionados à ocorrência do vesting, liquidação, preço, câmbio e tributação",
            "planning_decision": "Ponto de decisão",
            "planning_flow_link": "Ver trajetória no Fluxo",
            "planning_bind": "if(V==='Planejamento'){document.querySelectorAll('.dashact')",
            "v104_css": "wealth-financing-planning-v104",
            # Core regressions
            "card_hierarchy": "Fatura fechada → faturas abertas → parcelas futuras já contratadas",
            "card_floor": "Piso conhecido · não é previsão do valor final",
            "card_payment_rpc": "lts_browser_confirm_card_payment_v1",
            "flow_sticky": ".fx87-head{position:sticky!important;top:0!important",
            "flow_balance": ".fx87-balance{background:#f2f4f6",
            "flow_salary": "Salário líquido",
            "flow_coopharma": "consignado Coopharma",
            "flow_edit": "data-mode=\"edit\"",
            "flow_duplicate": "data-mode=\"duplicate\"",
            "flow_split": "Dividir / substituir",
            "flow_delete": "async function deleteFlowEvent(e,b)",
            "historical_card": "Resumo histórico da fatura",
            "historical_card_unavailable": "Não disponível",
            "flow_single_vertical": "body.flow-view{height:100vh;overflow:hidden}",
            "updates_question": "O que falta fazer para o LTS estar atualizado?",
            "updates_ambiguous": "Candidatos encontrados · nenhuma conciliação automática",
            "updates_evidence": "A escolha exige vínculo documental; o LTS não decide entre candidatos equivalentes.",
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
            "expense_period": "function expensePeriodName()",
            "cards": "function cartoes()",
            "flow": "function fluxo()",
            "flow_values": "function flowVals",
            "flow_editor": "async function openFlowEditor",
            "flow_delete": "async function deleteFlowEvent(e,b)",
            "wealth": "function patrimonio()",
            "financing_detail": "function financingDetail()",
            "financing": "function financiamentos()",
            "planning": "function planejamento()",
            "updates": "function atualizacoes()",
        }
        for name, text in exact_once.items():
            n = h.count(text)
            lines.append(f"single_{name}={n}")
            if n != 1:
                failures.append(f"single_{name}=failed")

        structure = {
            "dashboard_hero": '<div class="dash103-hero section">',
            "expense_hero": '<div class="exp103-hero">',
            "wealth_hero": '<div class="w104-hero">',
            "financing_hero": '<div class="f104-hero">',
            "planning_hero": '<div class="p104-hero">',
            "flow_shell": '<div class="flow-shell">',
            "flow_controls": '<div class="flow-sticky-controls">',
        }
        for name, text in structure.items():
            n = h.count(text)
            lines.append(f"{name}_open={n}")
            if n != 1:
                failures.append(f"{name}=failed")

        forbidden = {
            "old_dashboard_question": "Tenho dinheiro hoje?",
            "old_dashboard_next": "O que vence / precisa de mim?",
            "old_dashboard_trajectory": "Para onde estou indo?",
            "old_wealth_headline": "O que está disponível hoje fica separado do que é restrito",
            "old_financing_headline": "Acompanhe o que sai do caixa e o que ainda falta no cronograma.",
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
