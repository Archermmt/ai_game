"""Local G1 gate. Explicitly requires local derivatives; Git asset portability remains separate."""
import argparse
import json
import shutil
import struct
import sys
import xml.etree.ElementTree as ET
from common import ROOT, engine_binary
from run_checks import run_step
from art_pass_render_checks import production_files
from painterly_grass_g0_checks import preflight
from validate_painterly_grass import validate

OUT = ROOT/'reports/week_14/g1'


def ensure_import_settings():
    command = [engine_binary(), '--headless', '--path', str(ROOT), '--editor', '--import']
    path = ROOT/'assets/painterly_grass/local/grass_coverage.png.import'
    if not path.is_file():
        run_step('g1_initial_import', command)
    text = path.read_text()
    updated = text.replace('mipmaps/generate=false', 'mipmaps/generate=true')
    assert 'mipmaps/generate=true' in updated
    if updated != text:
        path.write_text(updated)
    run_step('g1_import', command)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', type=int, choices=[1], default=1)
    parser.add_argument('--native-only', action='store_true')
    parser.add_argument('--local-only', action='store_true', help='Run G1-specific regressions; no cumulative claim')
    args = parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    environment = preflight()
    before = production_files()
    ensure_import_settings()
    assets = validate()
    (OUT/'asset_validation.json').write_text(json.dumps(assets,indent=2)+'\n')
    if args.native_only:
        step = run_step('g1_native', [engine_binary(),'--always-on-top','--audio-driver','Dummy',
            '--path',str(ROOT),'--resolution','1920x1080','-s','tests/week_14/grass_lab_native_probe.gd',
            '--','--g1-fhd',str(OUT/'native')],timeout=120)
        report = json.loads((OUT/'native/report.json').read_text())
        assert report['passed'] and len(report['checks']) >= 12 and all(report['checks'].values())
        for path in (OUT/'native').glob('*.png'):
            assert struct.unpack_from('>II',path.read_bytes(),16)==(1920,1080)
        assert before==production_files()
        report.update(environment=environment, step=step, production_before=before,
                      production_after=production_files(),production_unchanged=True,
                      physical_touchpad_verified=False,new_asset_capacity_benchmark=False)
        (OUT/'native_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
        shutil.copyfile(ROOT/'reports/g1_native.log',OUT/'native.log')
        print('G1 NATIVE PASS',len(report['checks']))
        return
    steps=[]
    if not args.local_only:
        steps.append(run_step('g1_cumulative',[sys.executable,'tools/quality/painterly_grass_g0_checks.py'],timeout=1000))
    steps.append(run_step('g1_tests',[engine_binary(),'--headless','--path',str(ROOT),'-s',
        'addons/gut/gut_cmdln.gd','-gdir=res://tests/week_14','-gexit',
        '-gjunit_xml_file=reports/week_14/g1/tests.xml']))
    suite=ET.parse(OUT/'tests.xml').getroot()
    count=int(suite.get('tests',0))
    assert count>=8 and int(suite.get('failures',0))==0
    assert not any(int(s.get('skipped',0)) for s in suite.findall('testsuite'))
    assert before==production_files()
    previous=json.loads((ROOT/'reports/week_14/g0/checks.json').read_text()) if not args.local_only else None
    result={'environment':environment,'stage':1,'g1_tests':count,
            'g1_assertions':sum(int(t.get('assertions',0)) for t in suite.iter('testcase')),
            'godot_tests':previous['godot_tests']+count if previous else None,
            'python_tests':previous['python_tests'] if previous else None,
            'cumulative_run':previous is not None,'negative_control':previous['negative_control'] if previous else None,
            'failures':0,'skipped':0,'production_unchanged':True,'assets':assets,'steps':steps,
            'asset_repository_terms':'pending; local-only derivatives'}
    (OUT/('local_checks.json' if args.local_only else 'checks.json')).write_text(json.dumps(result,indent=2)+'\n')
    print('G1 PASS:',count,'new Godot tests; cumulative:',previous is not None)


if __name__=='__main__':
    main()
