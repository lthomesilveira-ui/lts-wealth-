import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = ROOT / "wip35-v142-candidate.html"
CANDIDATE_JS = ROOT / "wip35-v142-ux.js"
PLANNING_BRIDGE_JS = ROOT / "wip35-v142-planning-bridge.js"
PARENT = ROOT / "wip35-v141-candidate.html"
GRANDPARENT = ROOT / "wip35-v140-candidate.html"
GREATGRANDPARENT = ROOT / "wip35-v139-candidate.html"
PUBLIC_FALLBACK = ROOT / "index.html"
PUBLIC_FALLBACK_BLOB_SHA = "a130eafe5f7ee5b7f60a95b5ff988669d0c401d9"
RESULT = ROOT / "candidate-smoke-result.txt"

V142_HTML_REQUIRED = {
    "candidate_stamp": "CANDIDATA v142",
    "parent_candidate": "wip35-v141-candidate.html",
    "external_ux_layer": "wip35-v142-ux.js?v142-ux-v2",
    "planning_bridge_layer": "wip35-v142-planning-bridge.js?v142-planning-bridge-v1",
    "internal_validation_copy": "validação interna",
}

V142_JS_REQUIRED = {
    "ux_stamp": "LTS_CANDIDATE_UX='v142-quick-planning-wealth-density-recovery-v2'",
    "version_guard": "Object.defineProperty(w,'__LTS_TOP_CANDIDATE_VERSION'",
    "quick_input": "Lançamento rápido",
    "quick_interpreter": "u142QuickInterpret",
    "liquidity_guard": "nunca será tratado como renda ou gasto",
    "planning_renderer": "u142PlanningAuditRenderer",
    "planning_audit_copy": "ponte Excel → motor em auditoria",
    "wealth_renderer": "u142WealthExecutiveRenderer",
    "wealth_v2_rpc": "lts_browser_wealth_executive_v2",
    "updates_compaction": ".u132-classrow{display:grid!important",
    "v142_css": "wip35-v142-ux-css",
}

PLANNING_BRIDGE_REQUIRED = {
    "stamp": "LTS_V142_PLANNING_BRIDGE='fgts-d30-projected-conservative-v1'",
    "rpc": "lts_browser_planning_bridge_executive_v1",
    "renderer": "u142PlanningBridgeRenderer",
    "management_copy": "Primeiro ponto de gestão",
    "d30_copy": "FGTS continua restrito",
    "request_balance_copy": "não conta contribuições posteriores",
    "position_bridge": "Ponte documental de RSU e FGTS",
    "css": "wip35-v142-planning-bridge-css",
}

V141_REQUIRED = {
    "candidate_stamp": "CANDIDATA v141",
    "parent_candidate": "wip35-v140-candidate.html",
    "updates_focus": "O que realmente precisa de atualização",
    "future_collapse": "Cobertura futura distante",
    "healthy_collapse": "Checks já cobertos / acompanhados",
    "version_hygiene": "fallback público v136 preservado",
    "ui_stamp": "LTS_CANDIDATE_UI='wip35-v141-updates-cipo-backup-shared-flow-document-outcomes'",
    "cipo_documentary_coverage": "card_documentary_coverage",
    "cipo_non_promoting_copy": "Cobertura documental não significa conciliação concluída",
    "backup_status_rpc": "lts_browser_backup_status_v1",
    "backup_private_copy": "O snapshot completo fica privado no backend",
    "flow_ux_stamp": "LTS_V141_FLOW_UX='balance-emphasis-no-duplicate-today'",
    "flow_hide_duplicate_today": "#goToday{display:none!important}",
    "flow_balance_emphasis": ".fx87-row .fx87-balance{background:#f2f4f6!important}",
    "document_outcome_rpc": "lts_browser_document_outcome_state_v1",
    "document_outcome_stamp": "LTS_V141_DOCUMENT_OUTCOMES='evidence-derived-v1'",
    "document_outcome_copy": "“Sem alteração” não cria lançamento",
    "document_outcome_decision": "Precisa decisão",
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


def node_check(text: str, label: str, lines: list[str], failures: list[str]):
    js = Path(f"/tmp/lts-{label}.js")
    js.write_text(text, encoding="utf-8")
    run = subprocess.run(["node", "--check", str(js)], capture_output=True, text=True)
    lines.append(f"{label}_node_check={run.returncode}")
    if run.returncode:
        failures.append(f"{label}_node_check")
        if run.stderr:
            lines.append("node_error=" + run.stderr.strip().replace("\n", " | "))


def check_inline_scripts(path: Path, lines: list[str], failures: list[str], prefix: str, require_inline: bool = True) -> str:
    html = path.read_text(encoding="utf-8")
    lines.append(f"{prefix}_bytes={len(html.encode('utf-8'))}")
    scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", html, re.I | re.S)
    lines.append(f"{prefix}_inline_scripts={len(scripts)}")
    if require_inline and not scripts:
        failures.append(f"{prefix}_inline_scripts")
    for i, script in enumerate(scripts):
        node_check(script, f"{prefix}_script_{i}", lines, failures)
    return html


def require_markers(text: str, markers: dict, lines: list[str], failures: list[str], prefix: str):
    for name, marker in markers.items():
        ok = marker in text
        lines.append(f"required_{prefix}_{name}={'ok' if ok else 'missing'}")
        if not ok:
            failures.append(f"{prefix}_{name}")


def read_external(path: Path, prefix: str, markers: dict, lines: list[str], failures: list[str]) -> str:
    if not path.exists():
        failures.append(prefix + "_missing")
        return ''
    text=path.read_text(encoding='utf-8')
    lines.append(f"{prefix}_bytes={len(text.encode('utf-8'))}")
    node_check(text,prefix,lines,failures)
    require_markers(text,markers,lines,failures,prefix)
    return text


def main() -> int:
    lines = ["candidate=wip35-v142-candidate.html", "candidate_js=wip35-v142-ux.js", "planning_bridge_js=wip35-v142-planning-bridge.js"]
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
    if not CANDIDATE.exists():
        failures.append("v142_missing")
        v142_html=''
    else:
        v142_html=check_inline_scripts(CANDIDATE,lines,failures,'v142',require_inline=False)
        require_markers(v142_html,V142_HTML_REQUIRED,lines,failures,'v142_html')
    htmls.append(v142_html)

    v142_js=read_external(CANDIDATE_JS,'v142_external_js',V142_JS_REQUIRED,lines,failures)
    htmls.append(v142_js)
    plan_js=read_external(PLANNING_BRIDGE_JS,'v142_planning_bridge_js',PLANNING_BRIDGE_REQUIRED,lines,failures)
    htmls.append(plan_js)

    for path,prefix,markers in [
        (PARENT,'v141',V141_REQUIRED),
        (GRANDPARENT,'v140',V140_REQUIRED),
        (GREATGRANDPARENT,'v139',V139_REQUIRED),
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
