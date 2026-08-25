import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v96"
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


def has(h: str, text: str) -> bool:
    return text in h


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
            "stamp": "WIP35-v96 · Cartões operacionais",
            "build": "const BUILD='WIP35-v96 · Browser RPC v1 · Card human states'",
            "footer_version": "Versão WIP35-v96",
            "dashboard_today_question": "Tenho dinheiro hoje?",
            "dashboard_next_question": "O que vence / precisa de mim?",
            "dashboard_trajectory_question": "Para onde estou indo?",
            "dashboard_no_new_vesting": "Sem novos vestings",
            "dashboard_scheduled_vesting": "Com vestings programados",
            "dashboard_cash_guard": "sem FGTS e sem awards futuros",
            "dashboard_fgts_guard": "FGTS projetado permanece patrimônio restrito",
            "dashboard_cockpit_css": "dashboard-v95-cockpit",
            "card_human_hierarchy": "Fatura fechada → faturas abertas → parcelas futuras já contratadas",
            "card_future_floor_semantics": "Piso conhecido · não é previsão do valor final",
            "card_detail_action": "Ver resumo da fatura",
            "card_review_action": "Revisar classificações",
            "card_history_semantics": "Histórico de pagamentos de fatura",
            "card_operating_css": "cards-v96-operational",
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
            "expense_card_coverage": "Detalhe de cartão disponível de",
            "expense_card_competence": "competência ${comp",
            "expense_credit_tag": "crédito/estorno",
            "expense_coverage_guard": "Cobertura insuficiente",
            "expense_review_center": "Classificação de extrato",
            "expense_review_policy": "Histórico já categorizado não aparece só por faltar contraparte/centro.",
            "safe_suggestion_label": "Sugestão do histórico:",
            "safe_suggestion_action": "Confirmar sugestão",
            "compact_invoice_default": "if(!CARDDETAILFULL)",
            "full_invoice_action": "Acessar fatura completa",
        }
        for name, text in required.items():
            if has(h, text):
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
            "expense_review": "function expenseClassificationUpdates",
            "updates": "function atualizacoes()",
        }
        for name, text in exact_once.items():
            n = h.count(text)
            lines.append(f"single_{name}={n}")
            if n != 1:
                failures.append(f"single_{name}=failed")

        p = h.find("function cartoes()")
        card_snip = h[p:p + 10000] if p >= 0 else ""
        forbidden_card = ["source_status", "source_winner", "Unidades FIX86"]
        for text in forbidden_card:
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
