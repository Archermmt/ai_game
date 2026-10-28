"""Native pixel proof for the invisible winter grass optimization; no performance sign-off."""
import hashlib
import json
import shutil

from art_pass_render_checks import production_files
from common import ROOT, engine_binary
from painterly_grass_g0_checks import preflight
from run_checks import run_step
from weather_immersion_checks import LEAKS


def main():
    out = ROOT / 'reports/week_14/winter_grass_cull'
    out.mkdir(parents=True, exist_ok=True)
    receipt = out / 'checks.json'
    receipt.unlink(missing_ok=True)
    (out / 'result.json').unlink(missing_ok=True)
    before = production_files()
    environment = preflight()
    shader = ROOT / 'features/landscape/production_grass.gdshader'
    source_hash = hashlib.sha256(shader.read_bytes()).hexdigest()
    step = run_step('winter_grass_cull_native', [engine_binary(), '--audio-driver', 'Dummy',
        '--path', str(ROOT), '--script',
        'res://tests/week_14/production_landscape/winter_grass_cull_probe.gd'], timeout=300)
    log = ROOT / 'reports/winter_grass_cull_native.log'
    assert not LEAKS.search(log.read_text()), 'Native probe leaked resources'
    shutil.copy2(log, out / 'native.log')
    result = json.loads((out / 'result.json').read_text())
    assert result['passed'] and result['rendering_driver'] == 'metal'
    rows = result['comparisons']
    assert {(row['near'], row['cover']) for row in rows} == {
        (near, cover) for near in [False, True] for cover in [0.0, 0.4, 0.65, 0.98]}
    assert len(rows) == 8 and all(row['difference'] <= row['noise'] + 0.00001 for row in rows)
    assert result['source_unchanged'] and result['instance_count_unchanged']
    assert before == production_files(), 'Probe touched formal saves/preferences'
    assert hashlib.sha256(shader.read_bytes()).hexdigest() == source_hash
    receipt.write_text(json.dumps({'passed': True, 'environment': environment,
        'shader_sha256': source_hash, 'step': step, 'native': result,
        'production_unchanged': True, 'performance_gate_run': False}, indent=2) + '\n')
    print('WINTER GRASS CULL PASS: 8 native pixel comparisons; performance separate')


if __name__ == '__main__':
    main()
