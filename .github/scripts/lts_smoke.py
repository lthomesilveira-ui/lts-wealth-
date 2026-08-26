import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v107"
SUPABASE_URL = "https://tadhkamnwtsbdozwkyut.supabase.co"
ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "index.html"
RESULT = ROOT / "smoke-result.txt"
TMP = Path("/tmp/lts-shell.html")


def key():
    m = re.search(r"sb_publishable_[A-Za-z0-9_-]+", INDEX.read_text(encoding="utf-8"))
    if not m: raise RuntimeError("publishable_key=missing")
    return m.group(0)


def shell(k):
    url=f"{SUPABASE_URL}/rest/v1/lts_public_ui_shell?version=eq.{VERSION}&select=html"
    req=urllib.request.Request(url,headers={"apikey":k,"Authorization":"Bearer "+k})
    with urllib.request.urlopen(req,timeout=30) as r: data=json.load(r)
    if not data or not data[0].get("html"): raise RuntimeError("shell=missing")
    return data[0]["html"]


def main():
    lines=[f"version={VERSION}"]; fail=[]
    try:
        h=shell(key()); TMP.write_text(h,encoding="utf-8"); lines.append(f"shell_bytes={len(h)}")
        scripts=re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>",h,re.I|re.S); lines.append(f"inline_scripts={len(scripts)}")
        for i,s in enumerate(scripts):
            p=Path(f"/tmp/lts-script-{i}.js"); p.write_text(s,encoding="utf-8")
            r=subprocess.run(["node","--check",str(p)],capture_output=True,text=True); lines.append(f"node_check_{i}={r.returncode}")
            if r.returncode: fail.append(f"node_check_{i}")
        req={
          "stamp":"WIP35-v107 · Fluxo semântico",
          "build":"const BUILD='WIP35-v107 · Browser RPC v1 · Semantic classified cash history'",
          "footer":"Versão WIP35-v107",
          "flow_rpc_v3":"lts_browser_flow_v3",
          "flow_semantic_title":"function flowSemanticTitle(e)",
          "flow_semantic_meta":"function flowSemanticMeta(e)",
          "flow_semantic_use":"desc=flowSemanticTitle(e)",
          "flow_raw_secondary":"Extrato: ",
          "card_semantic_title":"function cardSemanticTitle(p)",
          "dashboard":"Seu dinheiro, sem ruído.","expenses":"Análise de consumo",
          "wealth":"O que está disponível. E o que ainda não está.",
          "financing":"Compromissos que já estão contratados.",
          "planning":"Três cenários. Uma única verdade de caixa.",
          "planning_motor":"O mesmo motor do Fluxo e do Dashboard",
          "planning_d3":"Incluindo ativos já disponíveis D+3",
          "planning_vesting":"Se os vestings de novembro ocorrerem",
          "planning_fgts":"FGTS no caixa",
          "cards_title":"O que já fechou. O que ainda cresce.",
          "cards_closed":"Fechadas / a pagar",
          "cards_open":"Faturas abertas",
          "cards_floor":"Piso futuro contratado",
          "cards_not_paid":"Fechada não significa paga",
          "cards_future":"Parcelas que vêm pela frente",
          "cards_quality":"Quanto do cartão o LTS entende",
          "cards_review":"Revisar classificações",
          "cards_history":"Pagamentos por competência",
          "cards_cash_guard":"Pagamento de fatura é liquidação de caixa. O consumo econômico continua sendo cada compra, sem contagem dupla.",
          "cards_detail_action":"class=\"chip cardopdetail\"",
          "cards_month_action":"class=\"c105-month cardmonth\"",
          "updates_title":"Deixe o LTS em dia sem caçar pendências.",
          "updates_now":"Precisa de você agora",
          "updates_class":"Classificações",
          "updates_evidence_bucket":"Evidências / documentos",
          "updates_confirmable":"Confirmações possíveis",
          "updates_suggestion_guard":"Sugestão nunca é confirmação.",
          "updates_resolved":"Resolvido não volta.",
          "updates_learning":"Classificações que ainda fazem diferença",
          "updates_ambiguous":"Candidatos encontrados · nenhuma conciliação automática",
          "updates_evidence_guard":"A escolha exige vínculo documental; o LTS não decide entre candidatos equivalentes.",
          "updates_transfer_rpc":"lts_browser_confirm_overdue_transfer_v1",
          "updates_event_rpc":"lts_browser_confirm_overdue_event_v1",
          "updates_card_rpc":"lts_browser_confirm_card_payment_v1",
          "updates_input":"class=\"chip updinput\"",
          "updates_cardclass":"cardClassificationUpdates()",
          "updates_expclass":"expenseClassificationUpdates()",
          "v105_css":"cards-updates-v105-operational",
          "v104_css":"wealth-financing-planning-v104",
          "v103_css":"dashboard-expenses-v103-wow",
          "flow_edit":"data-mode=\"edit\"","flow_duplicate":"data-mode=\"duplicate\"","flow_split":"Dividir / substituir",
          "flow_delete":"async function deleteFlowEvent(e,b)","flow_scroll":"body.flow-view{height:100vh;overflow:hidden}",
          "historical_card":"Resumo histórico da fatura","cipo":"Apartamento CIPÓ 396"
        }
        for n,t in req.items():
            ok=t in h; lines.append(f"{n}={'ok' if ok else 'missing'}")
            if not ok: fail.append(n)
        exact={"dashboard":"function dashboard()","expenses":"function despesas()","cards":"function cartoes()","wealth":"function patrimonio()","financing":"function financiamentos()","planning":"function planejamento()","updates":"function atualizacoes()","update_item":"function renderUpdateItem(x)","flow":"function fluxo()","flow_delete":"async function deleteFlowEvent(e,b)","flow_semantic_title":"function flowSemanticTitle(e)","card_semantic_title":"function cardSemanticTitle(p)"}
        for n,t in exact.items():
            c=h.count(t); lines.append(f"single_{n}={c}")
            if c!=1: fail.append(f"single_{n}")
        structs={"cards_hero":'<div class="c105-hero">',"updates_hero":'<div class="u105-hero">',"wealth_hero":'<div class="w104-hero">',"planning_hero":'<div class="p104-hero">',"flow_shell":'<div class="flow-shell">'}
        for n,t in structs.items():
            c=h.count(t); lines.append(f"{n}_open={c}")
            if c!=1: fail.append(n)
        forbidden={"flow_rpc_v2":"lts_browser_flow_v2","old_cards_head":"Fatura fechada → faturas abertas → parcelas futuras já contratadas","old_updates_head":"O que falta fazer para o LTS estar atualizado?","old_dashboard":"Tenho dinheiro hoje?","technical":"e.category||e.source","cancel_projection":">Cancelar projeção</button>","cdn":"cdn.jsdelivr.net"}
        for n,t in forbidden.items():
            present=t in h; lines.append(f"{n}={'present' if present else 'absent'}")
            if present: fail.append(n)
        if fail:
            lines += ["publish=blocked","failures="+",".join(fail)]; RESULT.write_text("\n".join(lines)+"\n",encoding="utf-8"); print(RESULT.read_text()); return 1
        shutil.copyfile(TMP,INDEX); lines.append("publish=ready"); RESULT.write_text("\n".join(lines)+"\n",encoding="utf-8"); print(RESULT.read_text()); return 0
    except Exception as e:
        lines += ["publish=blocked",f"exception={type(e).__name__}:{e}"]; RESULT.write_text("\n".join(lines)+"\n",encoding="utf-8"); print(RESULT.read_text()); return 1

if __name__=='__main__': sys.exit(main())
