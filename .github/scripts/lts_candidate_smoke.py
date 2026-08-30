import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = ROOT / "wip35-v141-candidate.html"
PARENT = ROOT / "wip35-v140-candidate.html"
GRANDPARENT = ROOT / "wip35-v139-candidate.html"
PUBLIC_FALLBACK = ROOT / "index.html"
PUBLIC_FALLBACK_BLOB_SHA = "a130eafe5f7ee5b7f60a95b5ff988669d0c401d9"
RESULT = ROOT / "candidate-smoke-result.txt"

V141_REQUIRED = {
    "candidate_stamp": "CANDIDATA v141",
    "parent_candidate": "wip35-v140-candidate.html",
    "updates_focus": "O que realmente precisa de atualização",
    "future_collapse": "Cobertura futura distante",
    "healthy_collapse": "Checks já cobertos / acompanhados",
    "version_hygiene": "fallback público v136 preservado",
    "ui_stamp": "LTS_CANDIDATE_UI='wip35-v141-updates-cipo-backup-shared-flow'",
    "cipo_documentary_coverage": "card_documentary_coverage",
    "cipo_non_promoting_copy": "Cobertura documental não significa conciliação concluída",
    "backup_status_rpc": "lts_browser_backup_status_v1",
    "backup_private_copy": "O snapshot completo fica privado no backend",
    "flow_ux_stamp": "LTS_V141_FLOW_UX='balance-emphasis-no-duplicate-today'",
    "flow_hide_duplicate_today": "#goToday{display:none!important}",
    "flow_balance_emphasis": ".fx87-row .fx87-balance{background:#f2f4f6!important}",
}

V140_REQUIRED = {
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
    "document_change_summary": "u139DocumentChanges",
    "expense_documentary_rpc": "lts_browser_expense_merchant_drilldown_v1",
    "card_history_coverage_rpc": "lts_browser_card_history_coverage_v1",
    "analytics_stamp": "LTS_CANDIDATE_ANALYTICS",
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


def require_markers(html: str, markers: dict, lines: list[str], failures: list[str], prefix: str):
    for name, marker in markers.items():
        ok = marker in html
        lines.append(f"required_{prefix}_{name}={'ok' if ok else 'missing'}")
        if not ok:
            failures.append(f"{prefix}_{name}")


def main() -> int:
    lines = ["candidate=wip35-v141-candidate.html"]
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

    htmls=[]
    for path,prefix,markers in [
        (CANDIDATE,'v141',V141_REQUIRED),
        (PARENT,'v140',V140_REQUIRED),
        (GRANDPARENT,'v139',V139_REQUIRED),
    ]:
        if not path.exists():
            failures.append(f"{prefix}_missing")
            html=''
        else:
            html=check_inline_scripts(path,lines,failures,prefix)
            require_markers(html,markers,lines,failures,prefix)
        htmls.append(html)

    combined='\n'.join(htmls).lower()
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
