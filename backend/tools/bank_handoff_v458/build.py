"""Build an immutable frontend with one handoff from bank collection to product."""
import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'releases/v454'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(path, old, new):
    text = path.read_text()
    assert text.count(old) == 1, (path.name, old[:80])
    path.write_text(text.replace(old, new))


BANK_BEFORE = """      const cashOnly=V==='Fluxo Diário',transport=window.__LTS_V227_TRANSPORT,revision=transport?.revision;
      if(window.__LTS_V172_STATE)"""
BANK_AFTER = """      const cashOnly=V==='Fluxo Diário',transport=window.__LTS_V227_TRANSPORT,revision=transport?.revision;
      const product=window.__LTS_V415_REFRESH;
      if(product?.snapshot?.().active&&typeof product.poll==='function'){
        // Collection completion is not complete-product readiness. Join the
        // existing status/job; its verified onProduct owns heavy invalidation.
        await product.poll();
        if(!activeSession(epoch,gen))return;
        if(product.snapshot().pending||(transport&&transport.revision!==revision)){
          const ui=window.__LTS_V168_STATE;if(ui)ui.updates.openFinance=state.status;
          await window.__LTS_V178_REVIEW?.refreshCashOnly?.(true);
          if(activeSession(epoch,gen))render();
          return;
        }
      }
      if(window.__LTS_V172_STATE)"""
RECOVERY_BEFORE = """      if (!canRun() || deferredRecoveries >= MAX_TRANSIENT_RETRIES) return Promise.resolve();
      if (deferredFlight) return deferredFlight;
      const token = generation;"""
RECOVERY_AFTER = """      if (!canRun()) return Promise.resolve();
      if (deferredFlight) return deferredFlight;
      // A deferred reader while a known job runs is not a failed full-product
      // retry. Keep the existing bounded timer and join any active read.
      if (!error && ['pending', 'running'].includes(refresh?.state)) {
        if (timer === null && !statusFlight && !productFlight && !requestFlight) schedule();
        return statusFlight || productFlight || requestFlight || Promise.resolve();
      }
      if (deferredRecoveries >= MAX_TRANSIENT_RETRIES) return Promise.resolve();
      const token = generation;"""
TRANSPORT_BEFORE = "const mutation=name!=='lts_browser_budget_save_v441'&&"
TRANSPORT_AFTER = "const mutation=name!=='lts_browser_budget_save_v441'&&name!=='lts_browser_open_finance_refresh_v1'&&"


def build(target):
    shutil.copytree(BASE, target)
    app = target / 'app.html'
    assert app.read_text().count('V454') == 5
    app.write_text(app.read_text().replace('V454', 'V458'))
    changed = ['lts-v225-open-finance.js', 'lts-v415-product-refresh.js',
               'lts-v227-read-transport.js']
    replace_once(target / changed[0], BANK_BEFORE, BANK_AFTER)
    replace_once(target / changed[1], RECOVERY_BEFORE, RECOVERY_AFTER)
    # This endpoint enqueues collection; it does not install a verified product.
    # It remains a native, uncached and unreplayed write. Its product handoff
    # above owns subsequent report invalidation, not enqueue acceptance.
    replace_once(target / changed[2], TRANSPORT_BEFORE, TRANSPORT_AFTER)
    # The controller loads directly; the bank module loads in exactly one bundle.
    for component in [changed[0], changed[2]]:
        original = (BASE / component).read_text()
        bundles = [target / name for name in ['lts-v384-startup-1.js', 'lts-v384-startup-2.js']
                   if original in (target / name).read_text()]
        assert len(bundles) == 1
        replace_once(bundles[0], original, (target / component).read_text())
    (target / 'provenance.json').write_text(json.dumps({
        'release': 'v458', 'base_release': 'v454',
        'scope': 'Coalesce bank collection with the existing complete-product refresh',
        'financial_math_changed': False, 'financial_writers_changed': False,
        'source_guards_changed': False, 'authentication_changed': False,
        'single_heavy_read_preserved': True, 'existing_job_only': True,
        'ready_product_recovery_limit_per_request_version': 2,
        'physical_mobile_validated': False}, indent=2) + '\n')
    (target / 'manifest.json').write_text(json.dumps({
        'release': 'v458', 'version': 'v458', 'base_release': 'v454',
        'entry': 'app.html',
        'protected_manifest': {'path': 'releases/v454/manifest.json',
                               'sha256': digest(BASE / 'manifest.json')},
        'files': {p.name: digest(p) for p in sorted(target.iterdir()) if p.name != 'manifest.json'}
    }, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        expected = Path(tmp) / 'v458'
        build(expected)
        actual = ROOT / 'releases/v458'
        if args.check:
            assert {p.name: p.read_bytes() for p in actual.iterdir()} == {
                p.name: p.read_bytes() for p in expected.iterdir()}
        else:
            assert not actual.exists(), 'Never overwrite a published release'
            shutil.copytree(expected, actual)
    print(json.dumps({'pass': True, 'release': 'v458', 'protected_base': 'v454'}))
