import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v100"
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
            "stamp": "WIP35-v100 · Pagamentos e confirmações",
            "build": "const BUILD='WIP35-v100 · Browser RPC v1 · Operational payment confirmation'",
            "footer_version": "Versão WIP35-v100",
            "dashboard_today_question": "Tenho dinheiro hoje?",
            "dashboard_next_question": "O que vence / precisa de mim?",
            "dashboard_trajectory_question": "Para onde estou indo?",
            "dashboard_cash_guard": "sem FGTS e sem awards futuros",
            "dashboard_fgts_guard": "FGTS projetado permanece patrimônio restrito",
            "dashboard_cockpit_css": "dashboard-v95-cockpit",
            "card_human_hierarchy": "Fatura fechada → faturas abertas → parcelas futuras já contratadas",
            "card_future_floor_semantics": "Piso conhecido · não é previsão do valor final",
            "card_detail_action": "Ver resumo da fatura",
            "card_review_action": "Revisar classificações",
            "card_history_semantics": "Histórico de pagamentos de fatura",
            "card_operating_css": "cards-v96-operational",
            "card_paid_recent": "Pagas recentemente",
            "card_paid_data": "paid=o.paid_recent||[]",
            "sticky_header": ".fx87-head{position:sticky!important;top:0!important",
            "detail_entry_alignment": ".fx89-detail-entry{grid-column:3",
            "detail_exit_alignment": ".fx89-detail-exit{grid-column:4",
            "net_operational_entries": "entradas_operacionais",
            "net_salary_label": "Salário líquido",
            "coopharma_note": "consignado Coopharma",
            "financing_loans_nav": "Financiamentos e Empréstimos",
            "flow_edit_action": "data-mode=\"edit\"",
            "flow_duplicate_action": "data-mode=\"duplicate\"",
            "flow_split_action": "Dividir / substituir",
            "flow_divided_badge": "Dividido</i>",
            "flow_adjusted_badge": "Ajustado</i>",
            "expense_default_12m": "DSPPER='12m'",
            "expense_card_coverage": "Detalhe de cartão disponível a partir de",
            "expense_card_competence": "competência ${comp",
            "expense_purchase_date": "Compra ${fmt(tx)}",
            "expense_credit_tag": "crédito/estorno · reduz consumo",
            "expense_coverage_guard": "Cobertura insuficiente",
            "expense_month_guard": "expenseComparisonReliable([last.month_key,prev.month_key])",
            "expense_insight_guard": "pctReliable=!!(last&&prev.length&&expenseComparisonReliable",
            "expense_mixed_guard": "Comparações temporais que atravessam a mudança de cobertura de cartão são limitadas",
            "expense_12m_guard": "Comparação de 12 meses limitada pela mudança de cobertura de cartão",
            "expense_review_center": "Classificação de extrato",
            "expense_review_policy": "Histórico já categorizado não aparece só por faltar contraparte/centro.",
            "expense_review_link": "A classificar · revisar",
            "expense_review_action": "Revisar classificação",
            "safe_suggestion_label": "Sugestão do histórico:",
            "safe_suggestion_action": "Confirmar sugestão",
            "updates_question": "O que falta fazer para o LTS estar atualizado?",
            "updates_priority": "Math.abs(num(b.impact_amount))-Math.abs(num(a.impact_amount))",
            "updates_ambiguous_guard": "Candidatos encontrados · nenhuma conciliação automática",
            "updates_evidence_guard": "A escolha exige vínculo documental; o LTS não decide entre candidatos equivalentes.",
            "updates_transfer_group": "function groupUpdateItems(raw)",
            "updates_confirm_rpc": "lts_browser_confirm_overdue_transfer_v1",
            "updates_confirm_action": "Confirmar realizado</button>",
            "updates_confirm_pair_guard": "registra as duas pernas da transferência como fato",
            "updates_confirm_bind": "document.querySelectorAll('.updconfirm')",
            "updates_confirm_neutral_guard": "manterá o Consolidado neutro",
            "card_payment_rpc": "lts_browser_confirm_card_payment_v1",
            "card_payment_action": "Confirmar pagamento</button>",
            "card_payment_bind": "document.querySelectorAll('.cardpayconfirm')",
            "card_payment_cash_once": "pagamento vira fato de caixa uma única vez",
            "card_payment_consumption_guard": "compras da fatura continuam sendo o consumo econômico em Despesas",
            "compact_invoice_default": "if(!CARDDETAILFULL)",
            "full_invoice_action": "Acessar fatura completa",
            "wealth_d0_layer": "Liquidez até D+0",
            "wealth_d3_layer": "Liquidez realizável até D+3",
            "wealth_restricted": "Restrito · não é caixa",
            "wealth_future": "Awards futuros · indisponíveis hoje",
            "wealth_future_snapshot_guard": "snapshot documental de awards futuros",
            "cipo_debt_missing": "Saldo devedor contratual atual",
            "financing_future_label": "Saídas futuras programadas",
            "financing_debt_guard": "Não inferido pela soma das parcelas",
            "financing_coopharma_payroll": "Consignado em folha: R$ 4.451,02 reduz o salário líquido no Fluxo",
            "planning_d0_human": "Só caixa + D+0",
            "planning_d3_human": "Incluindo ativos já disponíveis D+3",
            "planning_vesting_human": "Se os vestings de novembro ocorrerem",
            "planning_fgts_zero": "FGTS nos cenários de caixa",
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
            "expense_tx": "function expenseTx",
            "expense_coverage": "function expenseCoverageStart()",
            "expense_compare": "function expense12mCompare(rows)",
            "expense_review": "function expenseClassificationUpdates",
            "updates": "function atualizacoes()",
            "updates_item": "function renderUpdateItem(x)",
            "updates_group": "function groupUpdateItems(raw)",
            "updates_confirm": "async function confirmOverdueTransfer(b)",
            "card_payment_confirm": "async function confirmCardPayment(b)",
            "wealth": "function patrimonio()",
            "financing_detail": "function financingDetail()",
            "financing": "function financiamentos()",
            "planning": "function planejamento()",
        }
        for name, text in exact_once.items():
            n = h.count(text)
            lines.append(f"single_{name}={n}")
            if n != 1:
                failures.append(f"single_{name}=failed")

        p = h.find("function cartoes()")
        card_snip = h[p:p + 12000] if p >= 0 else ""
        for text in ["source_status", "source_winner", "Unidades FIX86"]:
            key_name = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")
            if text in card_snip:
                lines.append(f"card_forbidden_{key_name}=present")
                failures.append(f"card_forbidden_{key_name}=present")
            else:
                lines.append(f"card_forbidden_{key_name}=absent")

        forbidden_global = {
            "technical_flow_footer": "Conta corrente → D0/D1",
            "technical_main_footer": "FIX86 é piso",
            "technical_source_render": "e.category||e.source",
            "split_historical": "Histórico bancário",
            "split_future": "Hoje e projeção de caixa",
            "old_d30": "Liquidez D+30</div>",
            "old_updates_copy": "Central de review & approve",
            "cdn": "cdn.jsdelivr.net",
        }
        for name, text in forbidden_global.items():
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
