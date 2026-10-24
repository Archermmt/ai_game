"""W07 native desktop capture and bounded performance evidence; run serially."""
import json
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    engine=engine_binary();out=ROOT/'reports/week_07_visuals';out.mkdir(exist_ok=True)
    steps=[]
    captures=[('day',[]),('dusk',['--dusk']),('ui_150',['--ui-scale=1.5']),
              ('objects',['--w07-objects']),('palette',['--w07-palette']),('palette_150',['--w07-palette','--ui-scale=1.5']),
              ('hedges',['--w07-hedges','--hide-ui']),('hedges_dusk',['--w07-hedges','--hide-ui','--dusk']),('hedge_slope',['--w07-hedge-slope','--hide-ui']),
              ('contact',['--w07-contact','--hide-ui']),('round_close',['--w07-round-close','--hide-ui','--view-angle=135'])]
    captures += [('angle_'+str(a),['--hide-ui','--view-angle='+str(a)]) for a in [45,135,225,315]]
    captures += [('buildings_'+str(a),['--w07-buildings','--hide-ui','--view-angle='+str(a)]) for a in [45,135,225,315]]
    for name,flags in captures:
        steps.append(run_step('w07_render_'+name,[engine,'--path',str(ROOT),'--','--wind-time=0',
            '--capture='+str(out/(name+'.png')),'--smoke-output='+str(out/(name+'.json')),*flags]))
        if name=='hedge_slope':
            native=json.loads((out/(name+'.json')).read_text())['edit_metrics']
            assert native['hedge_native_height_range']>0.3 and native['hedge_native_instances']>10
    for mode,flags in [('on',[]),('zero',['--wind-strength=0']),('still',['--still'])]:
        for sample in [0,1]:
            steps.append(run_step('w07_wind_'+mode+str(sample),[engine,'--path',str(ROOT),'--','--hide-ui','--w07-hedges',
                '--wind-time='+str(sample),'--capture='+str(out/(mode+'_'+str(sample)+'.png')),*flags]))
    steps.append(run_step('w07_wind_pixels',[engine,'--headless','--path',str(ROOT),'-s','tests/week_01/wind_render_probe.gd',
        '--',str(out),str(out/'wind_pixels.json')]))
    metrics={}
    for mode,flags in [('day',[]),('dusk',['--dusk']),('editing',['--edit-benchmark'])]:
        report=out/(mode+'_metrics.json')
        steps.append(run_step('w07_metrics_'+mode,[engine,'--path',str(ROOT),'--resolution','1920x1080','--',
            '--hide-ui','--wind-time=0','--benchmark-seconds=10','--smoke-output='+str(report),*flags]))
        metrics[mode]=json.loads(report.read_text())
        assert metrics[mode]['frames']>100
        if mode=='editing': assert metrics[mode]['edit_metrics']['probe_edits']==20
        assert metrics[mode]['edit_metrics']['local_lights']<=4
    result={'device':'Apple M4 Pro / 20-core GPU / 48GB RAM / macOS arm64','renderer':'Forward+ / Metal 3.2',
        'scope':'W07 source template opening slice; 1080p VSync samples; not final stress/minimum-spec or artistic approval',
        'steps':steps,'wind':json.loads((out/'wind_pixels.json').read_text()),'benchmarks':metrics}
    (ROOT/'reports/week_07_render_checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print('W07 VISIBLE CHECKS PASS')


if __name__=='__main__':main()
