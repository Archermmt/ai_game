"""Validate reviewed, anonymous T067 observations; never infer human results from CI."""
import argparse
import json
import math
from pathlib import Path
import re


def summarize(data, evidence_root):
    if data.get('schema') != 1 or type(data.get('m4_approved')) is not bool:
        raise ValueError('Invalid schema / explicit M4 approval required')
    revision = data.get('frozen_revision')
    if revision is not None and not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Frozen revision must be a full Git SHA')
    if data['m4_approved'] and revision is None:
        raise ValueError('M4 approval requires a frozen revision')
    records = data.get('records')
    if not isinstance(records, list) or len(records) > 10:
        raise ValueError('Declare one cohort of at most ten records')
    root = Path(evidence_root).resolve()
    seen, eligible = set(), []
    for row in records:
        pid = row.get('participant_id', '')
        if not re.fullmatch(r'P\d{2}', pid) or pid in seen:
            raise ValueError('Duplicate or invalid anonymous participant ID')
        seen.add(pid)
        for key in ['first_time', 'consent', 'reviewed', 'house_independent', 'door', 'roof', 'path',
                    'screenshot_unprompted', 'understood_no_management']:
            if type(row.get(key)) is not bool:
                raise ValueError('Missing boolean: ' + key)
        for key in ['house_seconds', 'screenshot_seconds']:
            value = row.get(key)
            if key not in row or (value is not None and
                    (type(value) not in (float, int) or not math.isfinite(value) or value < 0)):
                raise ValueError('Invalid observation time: ' + key)
        for key in ['revision', 'system', 'input_device', 'evidence']:
            if not isinstance(row.get(key), str) or not row[key].strip():
                raise ValueError('Missing observation: ' + key)
        if not re.fullmatch(r'[0-9a-f]{40}', row['revision']):
            raise ValueError('Observation must identify its exact Git revision')
        relative = Path(row['evidence'])
        target = (root / relative).resolve()
        if relative.is_absolute() or not target.is_relative_to(root) or not target.is_file():
            raise ValueError('Observation evidence missing or outside evidence root')
        if (data['m4_approved'] and row['revision'] == revision and row['first_time']
                and row['consent'] and row['reviewed']):
            eligible.append(row)
    house = sum(r['house_seconds'] is not None and r['house_seconds'] <= 180 and
                r['house_independent'] and all(r[k] for k in ['door', 'roof', 'path']) for r in eligible)
    photo = sum(r['screenshot_seconds'] is not None and r['screenshot_seconds'] <= 900 and
                r['screenshot_unprompted'] for r in eligible)
    understanding = sum(r['understood_no_management'] for r in eligible)
    complete = len(eligible) == 10
    return {'actual_records': len(records), 'eligible_first_players': len(eligible), 'required': 10,
            'house_3min': house, 'screenshot_15min': photo, 'no_management_understood': understanding,
            'targets': {'house_8_of_10': complete and house >= 8,
                        'photo_7_of_10': complete and photo >= 7,
                        'understanding_8_of_10': complete and understanding >= 8},
            't067_passed': complete and house >= 8 and photo >= 7 and understanding >= 8,
            'status': 'awaiting_m4_freeze' if not data['m4_approved'] else
                      ('cohort_complete' if complete else 'awaiting_first_players')}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input', type=Path)
    parser.add_argument('--evidence-root', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = summarize(json.loads(args.input.read_text()), args.evidence_root or args.input.parent)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
