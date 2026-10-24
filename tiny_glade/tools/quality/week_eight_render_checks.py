"""Serial W08 native/release captures, phase timings and a real camera orbit movie."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from common import ROOT, engine_binary
from run_checks import run_step


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--executable',type=Path)
    args=parser.parse_args()
    out=ROOT/'reports/week_08_visuals';out.mkdir(exist_ok=True)
    program=[str(args.executable.resolve())] if args.executable else [engine_binary(),'--path',str(ROOT)]
    steps=[]
    steps.append(run_step('w08_library_seed', [*program, '--', '--qa-settings', '--qa-slots',
        '--w08-save-probe', '--capture='+str(out/'library_seed.png'),
        '--smoke-output='+str(out/'library_seed.json'), '--wind-time=0', '--water-time=0']))
    seed=json.loads((out/'library_seed.json').read_text())
    assert seed['edit_metrics']['thumbnail_png_bytes']>0 and seed['edit_metrics']['save_worker_ms']>0
    captures=[('day',['--w08-day','--hide-ui']),('dusk',['--w08-day','--hide-ui','--dusk']),
              ('garden_day',['--w08-near','--hide-ui']),('garden_dusk',['--w08-near','--hide-ui','--dusk']),
              ('gameplay',[]),('settings',['--w08-settings']),('settings_150',['--ui-scale=1.5','--w08-settings']),
              ('library',['--qa-slots','--w08-library']),('library_150',['--qa-slots','--w08-library','--ui-scale=1.5']),('ui_150',['--ui-scale=1.5']),
              ('aged',['--w08-aged','--hide-ui']),('lantern',['--w08-near','--dusk','--hide-ui']),
              ('dof_on',['--w08-dof','--w08-day','--hide-ui'])]
    captures += [(f'{distance}_{angle}',['--hide-ui',f'--w08-{distance}',f'--view-angle={angle}'])
                 for distance in ['near','far'] for angle in [45,135,225,315]]
    for name,flags in captures:
        steps.append(run_step('w08_render_'+name,[*program,'--','--qa-settings','--water-time=0','--wind-time=0',
            '--capture='+str(out/(name+'.png')),'--smoke-output='+str(out/(name+'.json')),*flags]))
        report=json.loads((out/(name+'.json')).read_text())
        assert report['buildings']==2 and report['instances']==51
        assert report['edit_metrics']['local_lights']<=4
    # The same entire SCN-01 includes the clothesline and all plant species.
    for mode,flags in [('on',[]),('zero',['--wind-strength=0']),('still',['--w08-reduced'])]:
        for sample in [0,1]:
            steps.append(run_step('w08_wind_'+mode+str(sample),[*program,'--','--qa-settings','--water-time=0','--hide-ui',
                '--wind-time='+str(sample),'--capture='+str(out/(mode+'_'+str(sample)+'.png')),*flags]))
    # Pixel comparison is a data-only utility, even when captures came from the release executable.
    steps.append(run_step('w08_wind_pixels',[engine_binary(),'--headless','--path',str(ROOT),'-s',
        'tests/week_01/wind_render_probe.gd','--',str(out),str(out/'wind_pixels.json')]))
    benchmarks={}
    for name,flags in [('day',[]),('dusk',['--dusk']),('editing',['--edit-benchmark']),
                       ('large',['--edit-benchmark','--large-brush-benchmark'])]:
        report=out/(name+'_metrics.json')
        steps.append(run_step('w08_metrics_'+name,[*program,'--resolution','1920x1080','--','--qa-settings',
            '--hide-ui','--wind-time=0','--benchmark-seconds=10','--smoke-output='+str(report),*flags]))
        benchmarks[name]=json.loads(report.read_text())
        assert benchmarks[name]['frames']>100
        if name in ['editing','large']:
            assert benchmarks[name]['edit_metrics']['probe_edits']==(20 if name=='editing' else 8)
            assert benchmarks[name]['edit_metrics']['last_worker_terrain_chunks']<64
    movie=out/'orbit.avi'
    steps.append(run_step('w08_orbit_record',[*program,'--resolution','1280x720','--fixed-fps','30',
        '--write-movie',str(movie),'--quit-after','180','--','--qa-settings','--w08-orbit','--hide-ui']))
    video=out/'orbit.mp4'
    subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(movie),'-c:v','libx264','-crf','22',
        '-pix_fmt','yuv420p','-an',str(video)],check=True)
    probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries',
        'stream=codec_name,width,height,nb_frames:format=duration','-of','json',str(video)],text=True))
    assert int(probe['streams'][0]['nb_frames'])>=180
    result={'device':'Apple M4 Pro / 20-core GPU / 48GB / macOS arm64',
        'build':'exported release' if args.executable else 'editor runtime',
        'renderer':'Forward+ / Metal 3.2','scope':'51 source instances, 20 local edits, 8 radius-9m terrain brushes; W09 full stress remains separate',
        'steps':steps,'benchmarks':benchmarks,'wind':json.loads((out/'wind_pixels.json').read_text()),
        'movie':{'probe':probe,'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'bytes':video.stat().st_size}}
    (ROOT/'reports/week_08_render_checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print('W08 VISIBLE CHECKS PASS')


if __name__=='__main__':main()
