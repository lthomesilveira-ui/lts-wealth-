"""Preserve V448 and recover a failed deferred read from a verified snapshot."""
import argparse, hashlib, json, shutil, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'releases/v448'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(path, old, new):
    value = path.read_text()
    assert value.count(old) == 1, (path.name, old[:100])
    path.write_text(value.replace(old, new))

def build(target):
    shutil.copytree(BASE, target)
    path = target / 'app.html'
    path.write_text(path.read_text().replace('V448', 'V449'))
    path = target / 'lts-v227-read-transport.js'
    replace_once(path,
        "document.documentElement.setAttribute('data-lts-v227-reads',JSON.stringify(events));};",
        """document.documentElement.setAttribute('data-lts-v227-reads',JSON.stringify(events));
   // A late source change can withdraw the audit snapshot after initial boot.
   // Observe the existing job; never request a job or replay a financial write.
   if(entry.name==='lts_browser_recurring_future_gap_audit_v5'&&entry.status>=500&&entry.status<=504)
    window.dispatchEvent(new Event('lts:deferred-read-failed'));
  };""")
    path = target / 'lts-v415-product-refresh.js'
    replace_once(path, 'let transientFailures = 0;',
        'let transientFailures = 0, deferredRecoveries = 0, deferredFlight = null;')
    replace_once(path, 'productLoading: !!productFlight, requesting: !!requestFlight, pollAttempts });',
        'productLoading: !!productFlight, requesting: !!requestFlight, pollAttempts, deferredRecoveries });')
    replace_once(path, 'if (priorVersion !== nextVersion) pollAttempts = 0;',
        'if (priorVersion !== nextVersion) { pollAttempts = 0; deferredRecoveries = 0; }')
    replace_once(path, '    function retry() {', """    function recoverDeferred() {
      if (!canRun() || deferredRecoveries >= MAX_TRANSIENT_RETRIES) return Promise.resolve();
      if (deferredFlight) return deferredFlight;
      const token = generation;
      const job = Promise.resolve().then(async () => {
        // A failure may arrive while status/product is already being installed.
        // Join it first, then recheck; do not lose this wakeup or overlap reads.
        if (statusFlight || productFlight || requestFlight) await (statusFlight || productFlight || requestFlight);
        if (token !== generation || !canRun() || deferredRecoveries >= MAX_TRANSIENT_RETRIES) return;
        deferredRecoveries++;
        lastFetchedKey = null; needsProduct = true; error = null;
        return poll();
      }).finally(() => { if (deferredFlight === job) deferredFlight = null; });
      deferredFlight = job;
      return job;
    }
    function retry() {""")
    replace_once(path, '\n      lastFetchedKey = null; delayIndex = 0; pollAttempts = 0; transientFailures = 0;',
        '\n      lastFetchedKey = null; delayIndex = 0; pollAttempts = 0; transientFailures = 0; deferredRecoveries = 0;')
    replace_once(path, 'error = null; needsProduct = false; lastFetchedKey = null; delayIndex = 0; pollAttempts = 0; transientFailures = 0; emit();',
        'error = null; needsProduct = false; lastFetchedKey = null; delayIndex = 0; pollAttempts = 0; transientFailures = 0; deferredRecoveries = 0; deferredFlight = null; emit();')
    replace_once(path, 'return { acceptProduct, observeRefresh, poll, retry, request, pause, resume, stop, dispose, snapshot, repaint: emit };',
        'return { acceptProduct, observeRefresh, poll, recoverDeferred, retry, request, pause, resume, stop, dispose, snapshot, repaint: emit };')
    replace_once(path, 'const invalidated = () => controller.poll();',
        'const invalidated = () => controller.poll();\n    const deferredFailed = () => controller.recoverDeferred();')
    replace_once(path, "win.removeEventListener('lts:data-invalidated', invalidated);",
        "win.removeEventListener('lts:data-invalidated', invalidated); win.removeEventListener('lts:deferred-read-failed', deferredFailed);")
    replace_once(path, "win.addEventListener('lts:data-invalidated', invalidated);",
        "win.addEventListener('lts:data-invalidated', invalidated); win.addEventListener('lts:deferred-read-failed', deferredFailed);")
    (target / 'provenance.json').write_text(json.dumps({
        'release': 'v449', 'base_release': 'v448',
        'scope': 'Bounded recovery of a failed deferred audit after verifying the existing server snapshot',
        'v448_chart_css_unchanged': True, 'financial_readers_changed': False,
        'financial_writers_changed': False, 'source_guards_changed': False,
        'authentication_changed': False, 'query_deadlines_changed': False,
        'physical_mobile_validated': False
    }, indent=2) + '\n')
    manifest = {'release': 'v449', 'version': 'v449', 'base_release': 'v448', 'entry': 'app.html',
        'protected_manifest': {'path': 'releases/v448/manifest.json', 'sha256': digest(BASE / 'manifest.json')},
        'files': {p.name: digest(p) for p in sorted(target.iterdir()) if p.name != 'manifest.json'}}
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as directory:
        expected = Path(directory) / 'v449'
        build(expected)
        actual = ROOT / 'releases/v449'
        if args.check:
            assert {p.name: p.read_bytes() for p in actual.iterdir()} == {p.name: p.read_bytes() for p in expected.iterdir()}
        else:
            assert not actual.exists(), 'Never overwrite an existing release'
            shutil.copytree(expected, actual)
    print(json.dumps({'pass': True, 'release': 'v449', 'protected_base': 'v448'}))
