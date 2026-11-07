#!/usr/bin/env python3
"""Reuse the native queue interleavings after the V418 summary is calculated.

Only disposable PostgreSQL17 fixtures are accepted. No production connection or
identity is used. The existing V415 assertions remain unchanged; whole-product
hashes include a previously prepared summary, so rollback covers that field too.
"""
import argparse
import importlib.util
import json
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / 'durable_refresh_v415/concurrency_test.py'
spec = importlib.util.spec_from_file_location('v415_interleavings', SOURCE)
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)
original_setup = qa.setup


def setup():
    original_setup()
    qa.sql("UPDATE qa_v415.config SET value='\"summary_build\"' WHERE key='pause_stage'; "
           "UPDATE public.lts_product_read_cache SET payload=jsonb_set(payload,"
           "'{projection_summary_v418}','{\"previous_summary\":true}') "
           f"WHERE user_id='{qa.OWNER}';")


qa.setup = setup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', required=True)
    parser.add_argument('--output', type=Path, required=True)
    options = parser.parse_args()
    if not options.database.startswith('v418_') or not options.database.replace('_', '').isalnum():
        raise SystemExit('Only explicitly named v418_ disposable databases are supported')
    qa.DATABASE = options.database
    report = {'pass': False, 'scope': 'Native PostgreSQL interleavings after V418 summary capture', 'results': qa.RESULTS}
    try:
        report['runtime'] = qa.query('SELECT to_jsonb(version());')
        if 'PostgreSQL 17.' not in report['runtime']:
            raise AssertionError('Native PostgreSQL17 is required')
        sources = qa.query('SELECT to_jsonb(qa_v415.source_hash());')
        qa.invalidation_race()
        # The successful successor must publish the requested summary, not the
        # old prepared branch or a claim calculated against the prior epoch.
        memo = qa.query(f"SELECT payload->'projection_summary_v418' FROM public.lts_product_read_cache WHERE user_id='{qa.OWNER}';")
        state = qa.queue_state()
        qa.check('successor publishes matching summary version and current epoch',
                 memo['summary']['enabled'] is True
                 and memo['guard']['request_version'] == str(state['completed_version'])
                 and memo['guard']['source_epoch'] == str(qa.cache_state()['epoch']))
        qa.coalescing_and_advisory_race()
        qa.epoch_race()
        qa.receipt_only_race()
        qa.crash_durability()
        qa.check('all V418 interleavings preserve financial source rows',
                 sources == qa.query('SELECT to_jsonb(qa_v415.source_hash());'))
        report['pass'] = True
    except Exception as error:
        report['error'] = str(error)
    report['checks'] = len(qa.RESULTS)
    options.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['pass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
