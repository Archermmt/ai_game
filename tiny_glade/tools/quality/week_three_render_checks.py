"""Serial W03 GPU evidence: four angles, LOD, water A/B, freeze regression."""
import json
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    engine = engine_binary()
    output = ROOT / 'reports/week_03_visuals'
    output.mkdir(exist_ok=True)
    steps = []
    def capture(name, flags=(), scene=None):
        command = [engine, '--path', str(ROOT)]
        if scene:
            command.append(scene)
        command += ['--', '--wind-time=0', '--capture=' + str(output / (name + '.png')), *flags]
        steps.append(run_step('w03_render_' + name, command))
    capture('day')
    capture('dusk', ['--dusk'])
    for angle in [45, 135, 225, 315]:
        capture('angle_' + str(angle), ['--hide-ui', '--view-angle=' + str(angle), '--tree-lod=0'])
    capture('lod1', ['--hide-ui', '--view-angle=45', '--tree-lod=1'])
    capture('parameters', ['--hide-ui'], 'res://app/building_parameter_gallery.tscn')
    steps.append(run_step('w03_water_highlights', [engine, '--headless', '--path', str(ROOT),
        '-s', 'tests/week_03/water_render_probe.gd', '--', str(output / 'angle_135.png'), str(output / 'water_highlights.json')]))
    for mode, flags in [('on', []), ('zero', ['--wind-strength=0']), ('still', ['--still'])]:
        for sample in [0, 1]:
            steps.append(run_step('w03_wind_' + mode + str(sample), [
                engine, '--path', str(ROOT), '--', '--hide-ui', '--wind-time=' + str(sample),
                '--capture=' + str(output / (mode + '_' + str(sample) + '.png')), *flags]))
    steps.append(run_step('w03_wind_pixels', [engine, '--headless', '--path', str(ROOT),
        '-s', 'tests/week_01/wind_render_probe.gd', '--', str(output), str(output / 'wind_pixels.json')]))
    benchmarks = []
    for index, mode in enumerate(['transparent', 'hidden', 'hidden', 'transparent']):
        report = output / f'water_{index}_{mode}.json'
        flags = ['--no-water'] if mode == 'hidden' else []
        steps.append(run_step('w03_water_' + str(index), [
            engine, '--path', str(ROOT), '--resolution', '1920x1080', '--', '--hide-ui',
            '--wind-time=0', '--benchmark-seconds=10', '--smoke-output=' + str(report), *flags]))
        data = json.loads(report.read_text())
        assert data['frames'] > 100
        data['gpu_timing_available'] = data['edit_metrics']['gpu_samples'] > 0
        benchmarks.append({'mode': mode, 'report': report.name, 'result': data})
    result = {'device': 'Apple M4 Pro, 20-core GPU, 48GB RAM, macOS arm64',
        'renderer': 'Forward+ / Metal 3.2', 'benchmark_resolution': [1920, 1080],
        'scope': 'W03 two houses, nine trees, single circular pond; not minimum-spec or MVP stress gate',
        'gpu_api_note': 'RenderingServer GPU queries returned no positive values on this Metal run; null is unavailable, not zero GPU cost. V-sync remains enabled; frame time is not isolated GPU timing.',
        'water_ab_limitation': 'Transparent water versus hidden water. GPU times include whole viewport and visibility changes, so this is incremental pond rendering cost, not isolated transparency-pass time.',
        'steps': steps, 'water_benchmarks': benchmarks,
        'water_highlights': json.loads((output / 'water_highlights.json').read_text()),
        'wind': json.loads((output / 'wind_pixels.json').read_text())}
    (ROOT / 'reports/week_03_render_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W03 VISIBLE RENDER CHECKS PASS')


if __name__ == '__main__':
    main()
