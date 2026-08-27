import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

VERSION = "wip35-v113"
SUPABASE_URL = "https://tadhkamnwtsbdozwkyut.supabase.co"
ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "index.html"
RESULT = ROOT / "smoke-result.txt"
TMP = Path("/tmp/lts-shell.html")

def key():
    m=re.search(r"sb_publishable_[A-Za-z0-9_-]+",INDEX.read_text(encoding="utf-8"))
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
          "stamp":"WIP35-v113 · Central de trabalho",
          "build":"const BUILD='WIP35-v113 · Browser RPC v1 · Work center navigation'",
          "footer":"Versão WIP35-v113",
          "seven_main_tabs":"const main=['Dashboard','Atualizações','Fluxo Diário','Despesas','Cartões','Patrimônio','Planejamento']",
          "work_center_title":"O que precisa de você, num único lugar.",
          "work_import":"Importar extrato ou documento",
          "work_manual":"Novo lançamento",
          "work_ledger":"Movimentos e histórico",
          "work_financing":"Volvo, Coopharma, Pai e Mãe e CIPÓ.",
          "work_backup":"Backup e configurações",
          "work_diagnostic":"Diagnóstico técnico",
          "work_binding":"document.querySelectorAll('.u113-go')",
          "nav_css":"navigation-updates-v113",
          "flow":"lts_browser_flow_v3",
          "flow_last5":"data-p=\"Últimos 5 dias\"",
          "expenses":"Para onde foi o dinheiro?",
          "expense_rpc":"lts_browser_expense_dual_lens_v1",
          "cards":"Cada cartão em um lugar.",
          "cards_css":"cards-v111-by-card-cockpit",
          "wealth":"O que é seu hoje. Sem somar o que ainda não é.",
          "wealth_css":"wealth-financing-v112-trust-first",
          "financing":"O que já está contratado. E o que ainda precisa ser confirmado.",
          "financing_parents":"Pai e Mãe · início previsto",
          "financing_cipo":"Cronograma CIPÓ está em revisão e não representa saldo devedor atual.",
          "planning":"Três cenários. Uma única verdade de caixa.",
          "new_category":"+ Nova categoria",
          "merchant":"Sugestão por estabelecimento identificado",
          "merchant_guard":"Nada vira regra sem sua confirmação.",
        }
        for n,t in req.items():
            ok=t in h; lines.append(f"{n}={'ok' if ok else 'missing'}")
            if not ok: fail.append(n)
        exact={
          "render_nav":"function renderNav()","updates":"function atualizacoes()","dashboard":"function dashboard()","flow":"function fluxo()",
          "expenses":"function despesas()","cards":"function cartoes()","wealth":"function patrimonio()","financing":"function financiamentos()",
          "planning":"function planejamento()","config":"function config()","ledger":"function lancamentos()","inputs":"function entradas()","diagnostic":"function diagnostico()"
        }
        for n,t in exact.items():
            c=h.count(t); lines.append(f"single_{n}={c}")
            if c!=1: fail.append(f"single_{n}")
        for marker in ["expenses-v110-dual-lens","cards-v111-by-card-cockpit","wealth-financing-v112-trust-first","navigation-updates-v113"]:
            c=h.count(marker); lines.append(f"css_{marker}={c}")
            if c!=1: fail.append(f"css_{marker}")
        forbidden={
          "old_v112_footer":"Versão WIP35-v112","flow_rpc_v2":"lts_browser_flow_v2",
          "old_nav_map":"N.innerHTML=NAV.map((x,i)=>","expense_since_2023":'data-dper="2023"',"expense_since_2013":'data-dper="2013"',
          "cards_null_detail":"cardSettlementInline(null)","old_wealth_title":"O que está disponível. E o que ainda não está.",
          "old_financing_title":"Compromissos que já estão contratados.","technical":"e.category||e.source","cdn":"cdn.jsdelivr.net"
        }
        for n,t in forbidden.items():
            present=t in h; lines.append(f"{n}={'present' if present else 'absent'}")
            if present: fail.append(n)
        if fail:
            lines += ["publish=blocked","failures="+",".join(fail)]; RESULT.write_text("\n".join(lines)+"\n",encoding="utf-8"); print(RESULT.read_text()); return 1
        shutil.copyfile(TMP,INDEX); lines.append("publish=ready"); RESULT.write_text("\n".join(lines)+"\n",encoding="utf-8"); print(RESULT.read_text()); return 0
    except Exception as e:
        lines += ["publish=blocked",f"exception={type(e).__name__}:{e}"]; RESULT.write_text("\n".join(lines)+"\n",encoding="utf-8"); print(RESULT.read_text()); return 1

if __name__=='__main__': sys.exit(main())
