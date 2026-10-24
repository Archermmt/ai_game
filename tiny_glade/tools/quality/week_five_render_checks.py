"""W05 visible checks, sequential to avoid graphics/import contention."""
import json
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    engine=engine_binary();out=ROOT/'reports/week_05_visuals';out.mkdir(exist_ok=True)
    steps=[]
    captures=[('day',[]),('dusk',['--dusk']),('stairs',['--w05-stairs','--hide-ui']),
              ('invalid_bridge',['--w05-invalid-bridge','--hide-ui'])]
    captures += [('angle_'+str(a),['--hide-ui','--view-angle='+str(a)]) for a in [45,135,225,315]]
    captures += [('no_water',['--hide-ui','--view-angle=45','--no-water'])]
    captures += [('gallery_'+str(a),['--w05-gallery','--hide-ui','--view-angle='+str(a)]) for a in [45,135,225,315]]
    for name, flags in captures:
        steps.append(run_step('w05_render_'+name,[engine,'--path',str(ROOT),'--','--wind-time=0',
            '--capture='+str(out/(name+'.png')),*flags]))
    steps.append(run_step('w05_water_pixels',[engine,'--headless','--path',str(ROOT),'-s','tests/week_05/water_render_probe.gd',
        '--',str(out/'angle_45.png'),str(out/'no_water.png'),str(out/'water_pixels.json')]))
    # New cloth source: actual pixel motion plus two independent static settings.
    for mode,flags in [('on',[]),('zero',['--wind-strength=0']),('still',['--still'])]:
        for sample in [0,1]:
            steps.append(run_step('w05_wind_'+mode+str(sample),[engine,'--path',str(ROOT),'--','--w05-gallery','--hide-ui',
                '--wind-time='+str(sample),'--capture='+str(out/(mode+'_'+str(sample)+'.png')),*flags]))
    steps.append(run_step('w05_wind_pixels',[engine,'--headless','--path',str(ROOT),'-s','tests/week_01/wind_render_probe.gd',
        '--',str(out),str(out/'wind_pixels.json')]))
    metrics={}
    for mode,flags in [('day',[]),('dusk',['--dusk']),('editing',['--edit-benchmark'])]:
        report=out/(mode+'_metrics.json')
        steps.append(run_step('w05_metrics_'+mode,[engine,'--path',str(ROOT),'--resolution','1920x1080','--',
            '--hide-ui','--wind-time=0','--benchmark-seconds=10','--smoke-output='+str(report),*flags]))
        metrics[mode]=json.loads(report.read_text())
        assert metrics[mode]['frames']>100
        if mode=='editing':assert metrics[mode]['edit_metrics']['probe_edits']==20
        if mode=='dusk':assert metrics[mode]['edit_metrics']['local_lights']<=4
    result={'device':'Apple M4 Pro / 20-core GPU / 48GB RAM / macOS arm64',
        'renderer':'Forward+ / Metal 3.2','scope':'W05 bounded sample; 1080p VSync; not final stress/minimum-spec gate',
        'water':json.loads((out/'water_pixels.json').read_text()),'steps':steps,'wind':json.loads((out/'wind_pixels.json').read_text()),'benchmarks':metrics}
    (ROOT/'reports/week_05_render_checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print('W05 VISIBLE CHECKS PASS')


if __name__=='__main__':main()
