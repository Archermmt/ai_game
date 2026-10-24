"""Serial real-1080p ribbon/focus/meadow images, freeze comparisons and density budgets."""
import json
import os
import struct
import subprocess
import time
from common import ROOT, engine_binary
from run_checks import ERRORS, run_step
from art_pass_render_checks import production_files

OUT = ROOT / 'reports/ui_meadow_01/native'


def probe(name, flags, duration=0):
    report = OUT / (name + '.json')
    command = [engine_binary(), '--path', str(ROOT), '--resolution', '1920x1080', '--', '--qa-settings', '--art-fhd',
               '--smoke-output=' + str(report), '--capture=' + str(OUT / (name + '.png')), *flags]
    if duration:
        command.append('--benchmark-seconds=' + str(duration))
    start = time.monotonic()
    rss = []
    with (OUT / (name + '.log')).open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=log)
        while process.poll() is None:
            if time.monotonic() - start > 180:
                process.kill(); process.wait()
                raise RuntimeError('Native timeout: ' + name)
            if os.name != 'nt':
                reading = subprocess.run(['ps', '-o', 'rss=', '-p', str(process.pid)], text=True, capture_output=True).stdout.strip()
                if reading.isdigit(): rss.append(int(reading) * 1024)
            time.sleep(.25)
    assert process.returncode == 0 and not ERRORS.search((OUT / (name + '.log')).read_text()), name
    data = json.loads(report.read_text())
    capacity = '--w09-stress' in flags
    assert data['viewport_size'] == [1920,1080] and data['buildings'] == (24 if capacity else 3) and data['instances'] == (1000 if capacity else 170)
    assert struct.unpack_from('>II',(OUT/(name+'.png')).read_bytes(),16) == (1920,1080)
    metrics = data['edit_metrics']
    assert metrics['meadow_visible'] == 0 if '--grass-density=0' in flags else metrics['meadow_visible'] > 10000
    result = {'report':str(report.relative_to(ROOT)), 'p95_frame_ms':data['p95_frame_ms'],
              'rss_peak_bytes':max(rss) if rss else None, 'seconds':time.monotonic()-start, 'metrics':metrics}
    print(name, 'p95',data['p95_frame_ms'],'grass', metrics['meadow_visible'], flush=True)
    return result


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    before = production_files()
    results = {}
    fixed = ['--wind-time=0','--water-time=0']
    for name,flags in [('ribbon',[]),('plants',['--garden-tool=plants']),('build',['--garden-tool=build']),
                       ('plants_150',['--garden-tool=plants','--ui-scale=1.5']),
                       ('focus_off',['--garden-no-focus']),('wind_t0',[]),('wind_t2',['--wind-time=2']),
                       ('reduced_t0',['--w08-reduced']),('reduced_t2',['--w08-reduced','--wind-time=2'])]:
        results[name] = probe(name,[*fixed,*flags])
    run_step('garden_photography',[engine_binary(),'--path',str(ROOT),'--','--qa-settings','--art-fhd',
        '--w09-photo-probe','--photo-output='+str(OUT),'--smoke-output='+str(OUT/'photo_smoke.json')])
    photo=json.loads((OUT/'photo_report.json').read_text())
    assert all(r['ok'] for r in photo['results']) and photo['failure_retry']
    assert all(photo[k] for k in ['source_unchanged','camera_restored','selection_restored','outline_restored'])
    run_step('garden_png_decode',[engine_binary(),'--headless','--path',str(ROOT),'-s','tests/week_09/image_probe.gd','--',str(OUT)])
    run_step("garden_image_checks",[engine_binary(),"--headless","--path",str(ROOT),"-s","tests/garden_presentation/image_probe.gd","--",str(OUT),str(ROOT/"reports/ui_meadow_01_image_checks.json")])
    metrics={}
    for name,density in [('grass_off',0),('grass_default',.45),('grass_full',1)]:
        metrics[name]=probe(name,['--grass-density='+str(density)],60)
    metrics['capacity_default']=probe('capacity_default',['--w09-stress','--grass-density=0.45'],60)
    assert production_files()==before,'QA changed formal saves/preferences'
    result={'views':results,'metrics':metrics,'photography':photo,'production_unchanged':True,
            'targets':{'p95_20ms':all(r['p95_frame_ms']<=20 for r in metrics.values()),
                       'rss_2gib':all(r['rss_peak_bytes']<2*1024**3 for r in metrics.values()),
                       'main_grass_slice_10ms':all(r['metrics']['meadow_apply_max_ms']<10 for r in metrics.values())},
            'device':'Apple M4 Pro / macOS / Metal','gpu_timer':None,'minimum_spec_pc':'not_run'}
    (ROOT/'reports/ui_meadow_01_native_checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('GARDEN NATIVE functional PASS; targets',result['targets'])


if __name__=='__main__': main()
