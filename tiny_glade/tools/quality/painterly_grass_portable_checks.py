"""Fresh local-project validation with explicitly supplied local derivatives, no vendor bundle."""
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
from common import ROOT, engine_binary
from clean_checkout import committed_project_archive, run_verified


def main():
    out = ROOT/'reports/week_14/g1'
    out.mkdir(parents=True,exist_ok=True)
    revision, prefix, archive = committed_project_archive(ROOT)
    with tempfile.TemporaryDirectory(prefix='windhaven-g1-portable-') as name:
        checkout = Path(name)
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(checkout,filter='data')
        assert not (checkout/'.godot').exists()
        for path in ['assets/painterly_grass/local','art_source/painterly_grass/local']:
            shutil.copytree(ROOT/path,checkout/path,ignore=shutil.ignore_patterns('*.blend1','*.blend2'))
        (checkout/'.venv').symlink_to(ROOT/'.venv',target_is_directory=True)
        environment=os.environ.copy()
        environment.update(GODOT_BIN=engine_binary(),WINDHAVEN_SOURCE_REVISION=revision)
        process=run_verified([sys.executable,'tools/quality/painterly_grass_checks.py','--stage','1','--local-only'],checkout,environment,180)
        (out/'portable.log').write_text(process.stdout+process.stderr)
        result=json.loads((checkout/'reports/week_14/g1/local_checks.json').read_text())
        assert result['g1_tests']>=8 and result['production_unchanged']
        shutil.copyfile(checkout/'reports/week_14/g1/tests.xml',out/'portable_tests.xml')
        report={'revision':revision,'project_subdirectory':prefix,'cache_reused':False,
                'local_derivatives_supplied':True,'vendor_bundle_copied':False,
                'vendor_original_path_needed_at_runtime':False,'passed':True,'checks':result,
                'git_only_asset_portability':'pending repository terms; not claimed'}
        (out/'portable_checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print('G1 FRESH LOCAL COPY PASS; Git-only asset portability remains pending')


if __name__=='__main__':
    main()
