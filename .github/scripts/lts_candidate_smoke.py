import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = ROOT / "wip35-v140-candidate.html"
PARENT = ROOT / "wip35-v139-candidate.html"
PUBLIC_FALLBACK = ROOT / "index.html"
PUBLIC_FALLBACK_BLOB_SHA = "a130eafe5f7ee5b7f60a95b5ff988669d0c401d9"
RESULT = ROOT / "candidate-smoke-result.txt"

V140_REQUIRED = {
    "candidate_stamp": "CANDIDATA v140",
    "parent_candidate": "wip35-v139-candidate.html",
    "lexical_bridge_stamp": "__LTS_LEXICAL_BRIDGE='v140'",
    "bridge_s": "['S','D','brl','fmt','esc','num','today']",
    "bridge_v": "exposeLexical(w,'V',true)",
    "loading_recovery": "Carregando seu LTS",
}

V139_REQUIRED = {
    "fallback_guardrail": "v136 permanece fallback",
    "flow_v4": "lts_browser_flow_v4",
    "updates_action_filter": "original.filter(w.updateIsAction)",
    "updates_context_filter": "original.filter(x=>!w.updateIsAction(x))",
    "updates_context_label": "Contexto / monitoramento",
    "updates_compact_lifecycle": "Recebido</span><i>›</i><span>Interpretado",
    "document_change_summary": "u139DocumentChanges",
    "document_change_payload": "change_summary",
    "document_change_heading": "O que mudou",
    "card_cash_guardrail": "Compra documentada; efeito de caixa ocorre pela fatura.",
    "expense_documentary_rpc": "lts_browser_expense_merchant_drilldown_v1",
    "card_history_coverage_rpc": "lts_browser_card_history_coverage_v1",
    "analytics_stamp": "LTS_CANDIDATE_ANALYTICS",
    "merchant_documentary_guardrail": "Merchant só aparece quando existe compra individual estruturada",
    "card_history_no_fabrication_guardrail": "agregado nunca vira compra/merchant fictício",
}

FORBIDDEN = {
    "direct_insert": "insert into",
    "direct_delete": "delete from",
    "direct_update_sql": "update public.",
    "direct_upsert": ".upsert(",
}


def git_blob_sha(path: Path) -> str:
    run = subprocess.run(["git", "hash-object", str(path)], capture_output=True, text=True, cwd=ROOT)
    return "" if run.returncode else run.stdout.strip()


def check_inline_scripts(path: Path, lines: list[str], failures: list[str], prefix: str) -> str:
    html = path.read_text(encoding="utf-8")
    lines.append(f"{prefix}_bytes={len(html.encode('utf-8'))}")
    scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", html, re.I | re.S)
    lines.append(f"{prefix}_inline_scripts={len(scripts)}")
    if not scripts:
        failures.append(f"{prefix}_inline_scripts")
    for i, script in enumerate(scripts):
        js = Path(f"/tmp/lts-{prefix}-script-{i}.js")
        js.write_text(script, encoding="utf-8")
        run = subprocess.run(["node", "--check", str(js)], capture_output=True, text=True)
        lines.append(f"{prefix}_node_check_{i}={run.returncode}")
        if run.returncode:
            failures.append(f"{prefix}_node_check_{i}")
            if run.stderr:
                lines.append("node_error=" + run.stderr.strip().replace("\n", " | "))
    return html


def main() -> int:
    lines = ["candidate=wip35-v140-candidate.html"]
    failures = []

    if not PUBLIC_FALLBACK.exists():
        failures.append("public_fallback_missing")
    else:
        fallback_sha = git_blob_sha(PUBLIC_FALLBACK)
        fallback_ok = fallback_sha == PUBLIC_FALLBACK_BLOB_SHA
        lines.append(f"public_fallback_blob_sha={fallback_sha}")
        lines.append(f"public_fallback_expected_sha={PUBLIC_FALLBACK_BLOB_SHA}")
        lines.append(f"public_fallback_v136={'ok' if fallback_ok else 'changed'}")
        if not fallback_ok:
            failures.append("public_fallback_v136")

    if not CANDIDATE.exists():
        failures.append("candidate_missing")
        candidate_html = ""
    else:
        candidate_html = check_inline_scripts(CANDIDATE, lines, failures, "v140")
        for name, marker in V140_REQUIRED.items():
            ok = marker in candidate_html
            lines.append(f"required_v140_{name}={'ok' if ok else 'missing'}")
            if not ok:
                failures.append(f"v140_{name}")

    if not PARENT.exists():
        failures.append("v139_parent_missing")
        parent_html = ""
    else:
        parent_html = check_inline_scripts(PARENT, lines, failures, "v139")
        for name, marker in V139_REQUIRED.items():
            ok = marker in parent_html
            lines.append(f"required_v139_{name}={'ok' if ok else 'missing'}")
            if not ok:
                failures.append(f"v139_{name}")

    combined = (candidate_html + "\n" + parent_html).lower()
    for name, marker in FORBIDDEN.items():
        present = marker.lower() in combined
        lines.append(f"forbidden_{name}={'present' if present else 'absent'}")
        if present:
            failures.append(name)

    lines.append("result=" + ("PASS" if not failures else "FAIL"))
    if failures:
        lines.append("failures=" + ",".join(failures))
    RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(RESULT.read_text(encoding="utf-8"))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
