"""W06 native visible evidence. Run serially against one import cache."""
import json
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    engine = engine_binary()
    out = ROOT / 'reports/week_06_visuals'
    out.mkdir(exist_ok=True)
    steps = []
    captures = [('day', []), ('dusk', ['--dusk']), ('ui_150', ['--ui-scale=1.5']),
                ('foliage', ['--w06-foliage', '--hide-ui'])]
    captures += [('angle_' + str(a), ['--hide-ui', '--view-angle=' + str(a)]) for a in [45, 135, 225, 315]]
    captures += [('gallery_' + str(a), ['--w06-gallery', '--hide-ui', '--view-angle=' + str(a)]) for a in [45, 135, 225, 315]]
    captures += [('gallery_dusk', ['--w06-gallery', '--hide-ui', '--dusk']),
                 ('no_water', ['--hide-ui', '--view-angle=45', '--no-water'])]
    for name, flags in captures:
        steps.append(run_step('w06_render_' + name, [engine, '--path', str(ROOT), '--', '--wind-time=0',
            '--capture=' + str(out / (name + '.png')), *flags]))
    steps.append(run_step('w06_icons', [engine, '--path', str(ROOT), '-s', 'tests/week_06/icon_render_probe.gd',
        '--', str(out / 'icons.png')]))
    steps.append(run_step('w06_water_pixels', [engine, '--headless', '--path', str(ROOT), '-s',
        'tests/week_05/water_render_probe.gd', '--', str(out / 'angle_45.png'), str(out / 'no_water.png'), str(out / 'water_pixels.json')]))
    for mode, flags in [('on', []), ('zero', ['--wind-strength=0']), ('still', ['--still'])]:
        for sample in [0, 1]:
            steps.append(run_step('w06_wind_' + mode + str(sample), [engine, '--path', str(ROOT), '--', '--w06-foliage',
                '--hide-ui', '--wind-time=' + str(sample), '--capture=' + str(out / (mode + '_' + str(sample) + '.png')), *flags]))
    steps.append(run_step('w06_wind_pixels', [engine, '--headless', '--path', str(ROOT), '-s',
        'tests/week_01/wind_render_probe.gd', '--', str(out), str(out / 'wind_pixels.json')]))
    metrics = {}
    for mode, flags in [('day', []), ('dusk', ['--dusk']), ('editing', ['--edit-benchmark']), ('foliage', ['--w06-foliage'])]:
        report = out / (mode + '_metrics.json')
        steps.append(run_step('w06_metrics_' + mode, [engine, '--path', str(ROOT), '--resolution', '1920x1080', '--',
            '--hide-ui', '--wind-time=0', '--benchmark-seconds=10', '--smoke-output=' + str(report), *flags]))
        metrics[mode] = json.loads(report.read_text())
        assert metrics[mode]['frames'] > 100
        if mode == 'editing':
            assert metrics[mode]['edit_metrics']['probe_edits'] == 20
        assert metrics[mode]['edit_metrics']['local_lights'] <= 4
    result = {'device': 'Apple M4 Pro / 20-core GPU / 48GB RAM / macOS arm64', 'renderer': 'Forward+ / Metal 3.2',
        'scope': 'W06 bounded samples; 1080p VSync; not final capacity/minimum-spec/GPU timing approval',
        'steps': steps, 'water': json.loads((out / 'water_pixels.json').read_text()),
        'wind': json.loads((out / 'wind_pixels.json').read_text()), 'benchmarks': metrics}
    (ROOT / 'reports/week_06_render_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('W06 VISIBLE CHECKS PASS')


if __name__ == '__main__':
    main()
