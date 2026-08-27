import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v112"
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
            "stamp": "WIP35-v112 · Patrimônio e compromissos confiáveis",
            "build": "const BUILD='WIP35-v112 · Browser RPC v1 · Trust first wealth and financing'",
            "footer": "Versão WIP35-v112",
            "flow_rpc_v3": "lts_browser_flow_v3",
            "flow_last5": "data-p=\"Últimos 5 dias\"",
            "flow_edit": "function flowCanEdit(e)",
            "flow_semantic": "function flowSemanticTitle(e)",
            "expenses_title": "Para onde foi o dinheiro?",
            "expenses_rpc": "lts_browser_expense_dual_lens_v1",
            "expenses_css": "expenses-v110-dual-lens",
            "expenses_tabs": "tabs=['Visão','Caixa','Consumo','Detalhes']",
            "cards_title": "Cada cartão em um lugar.",
            "cards_css": "cards-v111-by-card-cockpit",
            "cards_models": "function card111Models(o)",
            "cards_overdue": "Vencida · confirmar pagamento",
            "cards_detail": "Última competência com compras detalhadas",
            "cards_future": "Calendário de parcelas futuras",
            "wealth_css": "wealth-financing-v112-trust-first",
            "wealth_title": "O que é seu hoje. Sem somar o que ainda não é.",
            "wealth_liquidity": "Liquidez realizável até D+3",
            "wealth_total_unknown": "Patrimônio líquido total",
            "wealth_not_calculated": "Não calculado",
            "wealth_cipo_current_value": "Valor atual do imóvel",
            "wealth_cipo_debt": "Saldo devedor atual",
            "wealth_cipo_rows": "desembolsos em revisão · sem somar como custo patrimonial",
            "wealth_cipo_guard": "não chama a soma deles de “valor investido”",
            "financing_title": "O que já está contratado. E o que ainda precisa ser confirmado.",
            "financing_coopharma": "Coopharma · próxima folha",
            "financing_volvo": "Volvo · próxima parcela",
            "financing_parents": "Pai e Mãe · início previsto",
            "financing_cipo_review": "CIPÓ 396",
            "financing_cipo_warning": "Cronograma CIPÓ está em revisão e não representa saldo devedor atual.",
            "financing_debt_guard": "Saldo devedor atual",
            "financing_payroll_guard": "não existe uma segunda saída bancária",
            "financing_parents_balloon": "Maior saída prevista:",
            "planning": "Três cenários. Uma única verdade de caixa.",
            "dashboard": "Seu dinheiro, sem ruído.",
            "updates_title": "Deixe o LTS em dia sem caçar pendências.",
            "new_category": "+ Nova categoria",
            "merchant_suggestion": "Sugestão por estabelecimento identificado",
            "suggestion_guard": "Nada vira regra sem sua confirmação.",
            "historical_card": "Resumo histórico da fatura",
        }
        for n, t in req.items():
            ok = t in h
            lines.append(f"{n}={'ok' if ok else 'missing'}")
            if not ok:
                fail.append(n)

        exact = {
            "dashboard": "function dashboard()",
            "expenses": "function despesas()",
            "cards": "function cartoes()",
            "wealth": "function patrimonio()",
            "financing": "function financiamentos()",
            "financing_detail": "function financingDetail()",
            "planning": "function planejamento()",
            "updates": "function atualizacoes()",
            "flow": "function fluxo()",
            "flow_can_edit": "function flowCanEdit(e)",
            "expense_loader": "async function loadExpenseDual(a,b)",
            "card_models": "function card111Models(o)",
            "new_category_fn": "async function addNewCategory(b)",
        }
        for n, t in exact.items():
            c = h.count(t)
            lines.append(f"single_{n}={c}")
            if c != 1:
                fail.append(f"single_{n}")

        structs = {
            "expenses_hero": '<div class="exp110-hero">',
            "cards_summary": '<div class="c111-summary">',
            "wealth_hero": '<div class="w112-hero">',
            "financing_hero": '<div class="f112-hero">',
            "planning_hero": '<div class="p104-hero">',
            "updates_hero": '<div class="u105-hero">',
            "flow_shell": '<div class="flow-shell">',
        }
        for n, t in structs.items():
            c = h.count(t)
            lines.append(f"{n}_open={c}")
            if c != 1:
                fail.append(n)

        forbidden = {
            "flow_rpc_v2": "lts_browser_flow_v2",
            "old_v111_footer": "Versão WIP35-v111",
            "old_wealth_title": "O que está disponível. E o que ainda não está.",
            "old_financing_title": "Compromissos que já estão contratados.",
            "old_cipo_historical_money_label": "Saídas históricas rastreadas",
            "old_cipo_future_money_label": "Cronograma futuro",
            "expense_since_2023_button": 'data-dper="2023"',
            "expense_since_2013_button": 'data-dper="2013"',
            "cards_null_detail_anchor": "cardSettlementInline(null)",
            "technical": "e.category||e.source",
            "cancel_projection": ">Cancelar projeção</button>",
            "cdn": "cdn.jsdelivr.net",
        }
        for n, t in forbidden.items():
            present = t in h
            lines.append(f"{n}={'present' if present else 'absent'}")
            if present:
                fail.append(n)

        for marker in ["expenses-v110-dual-lens", "cards-v111-by-card-cockpit", "wealth-financing-v112-trust-first"]:
            c = h.count(marker)
            lines.append(f"css_{marker}={c}")
            if c != 1:
                fail.append(f"css_{marker}")

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
