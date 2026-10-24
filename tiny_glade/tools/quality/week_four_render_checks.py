"""Serial W04 desktop evidence; keep graphics work separate from importer/exporter."""
import json
from common import ROOT,engine_binary
from run_checks import run_step


def main():
    engine=engine_binary();out=ROOT/'reports/week_04_visuals';out.mkdir(exist_ok=True)
    steps=[]
    for name,flags in [('day',[]),('dusk',['--dusk']),('angle_45',['--hide-ui','--view-angle=45']),
                       ('angle_135',['--hide-ui','--view-angle=135']),('angle_225',['--hide-ui','--view-angle=225']),
                       ('angle_315',['--hide-ui','--view-angle=315']),('links',['--w04-links-demo','--hide-ui']),
                       ('terrain',['--w04-terrain-demo','--hide-ui'])]:
        steps.append(run_step('w04_render_'+name,[engine,'--path',str(ROOT),'--','--wind-time=0','--capture='+str(out/(name+'.png')),*flags]))
    for angle in [45,135,225,315]:
        steps.append(run_step('w04_gallery_'+str(angle),[engine,'--path',str(ROOT),'--','--hide-ui','--w04-asset-gallery',
            '--wind-time=0','--view-angle='+str(angle),'--capture='+str(out/('gallery_'+str(angle)+'.png'))]))
    for mode,flags in [('on',[]),('zero',['--wind-strength=0']),('still',['--still'])]:
        for sample in [0,1]:
            steps.append(run_step('w04_wind_'+mode+str(sample),[engine,'--path',str(ROOT),'--','--hide-ui','--wind-time='+str(sample),
                '--capture='+str(out/(mode+'_'+str(sample)+'.png')),*flags]))
    steps.append(run_step('w04_wind_pixels',[engine,'--headless','--path',str(ROOT),'-s','tests/week_01/wind_render_probe.gd',
        '--',str(out),str(out/'wind_pixels.json')]))
    for mode,flags in [('day',[]),('dusk',['--dusk']),('editing',['--edit-benchmark'])]:
        report=out/(mode+'_metrics.json')
        steps.append(run_step('w04_metrics_'+mode,[engine,'--path',str(ROOT),'--resolution','1920x1080','--',
            '--hide-ui','--wind-time=0','--benchmark-seconds=10','--smoke-output='+str(report),*flags]))
        data=json.loads(report.read_text())
        assert data['frames']>100
        if mode=='editing':assert data['edit_metrics']['probe_edits']==20
        if mode=='dusk':assert data['edit_metrics']['local_lights']<=4
    result={'device':'Apple M4 Pro / 20-core GPU / 48GB RAM / macOS arm64','renderer':'Forward+ / Metal 3.2',
        'scope':'W04 sample, 1920x1080, VSync enabled; not minimum-spec or final MVP stress gate',
        'steps':steps,'wind':json.loads((out/'wind_pixels.json').read_text()),
        'benchmarks':{name:json.loads((out/(name+'_metrics.json')).read_text()) for name in ['day','dusk','editing']}}
    (ROOT/'reports/week_04_render_checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print('W04 VISIBLE RENDER CHECKS PASS')


if __name__=='__main__':main()
