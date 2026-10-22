"""Generate a release decision from current reports and explicitly reviewed device evidence."""
import argparse
import json
from common import ROOT
from week_twelve_audit import ac_evidence, decision, digest
from week_twelve_package import verify_package
from playtest_report import summarize


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-release', action='store_true')
    args = parser.parse_args()
    package = json.loads((ROOT / 'reports/week_12_candidate.json').read_text())
    manifest = verify_package(ROOT / package['path'])
    if digest(ROOT / package['path']) != package['sha256'] or manifest['revision'] != package['revision']:
        raise ValueError('Candidate changed since packaging')
    clean = json.loads((ROOT / 'reports/week_12_clean_checkout.json').read_text())
    if clean['revision'] != package['revision'] or not clean['passed'] or not clean.get('exported_from_clean_archive'):
        raise ValueError('Clean checkout and package revisions disagree')
    metrics = json.loads((ROOT / 'reports/week_12_native_checks.json').read_text())
    if metrics['revision'] != package['revision'] or not metrics['functional_passed']:
        raise ValueError('Native probe and package revisions disagree')
    assets = json.loads((ROOT / 'reports/week_12_assets.json').read_text())
    for name, record in assets['files'].items():
        if digest(ROOT / name) != record['sha256']:
            raise ValueError('Asset changed since technical audit: ' + name)
    ac = ac_evidence(ROOT, ROOT / 'reports/week_12_clean_evidence')
    records = json.loads((ROOT / 'docs/weekly/week_11/playtest_records.json').read_text())
    players = summarize(records, ROOT / 'docs/weekly/week_11')
    if records.get('frozen_revision') != package['revision']:
        players['t067_passed'] = False
    capacity = metrics['capacity']; m = capacity['metrics']
    facts = {'revision': package['revision'], 'zip_sha256': package['sha256'],
             'assets_passed': assets['technical_passed'], 'regression_passed': clean['gate']['functional_gate_passed'],
             'ac': {key: row['automated_passed'] for key, row in ac.items()},
             'performance': {'frame_p95_ms': capacity['p95_frame_ms'], 'commit_p95_ms': m['commit_latency_p95_ms'],
                             'main_callback_ms': m['main_callback_max_ms'], 'rss_bytes': capacity['rss_peak_bytes']},
             'playtest_passed': players['t067_passed'], 'actual_first_players': players['eligible_first_players']}
    observations = json.loads((ROOT / 'docs/weekly/week_12/platform_observations.json').read_text())
    result = {**decision(ROOT, facts, observations), 'facts': facts, 'ac': ac, 'playtest': players}
    (ROOT / 'reports/week_12_release.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('W12 release status:', result['status'], '; blockers:', ', '.join(result['blockers']))
    if args.require_release and not result['m5_approved']:
        raise SystemExit(2)


if __name__ == '__main__': main()
