"""Finish the local G5 handoff from a verified committed candidate; no release approval."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile

from art_pass_render_checks import production_files
from clean_checkout import committed_project_archive
from common import ROOT, engine_binary
from painterly_grass_g0_checks import preflight
from run_checks import ERRORS, run_step
from weather_immersion_checks import LEAKS

OUT = ROOT / 'reports/week_14/g5'
RUNTIME = {'app', 'core', 'features', 'ui', 'levels', 'assets', 'addons'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    portable = json.loads((OUT / 'portable_checks.json').read_text())
    assert portable['passed'] and not portable['cache_reused']
    assert portable['checks']['production_unchanged']
    candidate = Path(portable['candidate_directory'])
    revision, _, archive = committed_project_archive(ROOT, portable['revision'])
    runtime = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        for member in source:
            parts = Path(member.name).parts
            if not member.isfile() or not (parts[0] in RUNTIME or member.name == 'project.godot'):
                continue
            expected = hashlib.sha256(source.extractfile(member).read()).hexdigest()
            assert digest(candidate / member.name) == expected, 'Candidate changed: ' + member.name
            assert digest(ROOT / member.name) == expected, 'Runtime changed; commit and rerun portable check: ' + member.name
            runtime[member.name] = expected
    assert len(runtime) > 100
    subprocess.run([sys.executable, 'tools/quality/candidate_asset_supply_checks.py'], cwd=ROOT, check=True)
    supply = json.loads((OUT / 'asset_supply.json').read_text())
    for relative, entry in supply['files'].items():
        assert digest(candidate / relative) == entry['sha256'], 'Supplied candidate file changed: ' + relative
    # Engine-level override is applied before any scene or preference service starts.
    # The committed project.godot and all runtime sources stay byte-identical.
    scope = 'WindhavenDiorama_G5_' + candidate.name.removeprefix('candidate_')
    override = candidate / 'override.cfg'
    overlay = '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=' + json.dumps(scope) + '\n'
    if override.exists():
        assert override.read_text() == overlay, 'Candidate has a different user override; preserve it and rebuild a separate candidate'
    else:
        override.write_text(overlay)
    handoff = OUT / ('handoff_' + revision[:8])
    handoff.mkdir(exist_ok=True)
    launchers = {}
    scenes = {
        'play_winter.command': ('res://app/living_root.tscn', ['--season=winter', '--weather=clear', '--hour=12']),
        'play_summer.command': ('res://app/living_root.tscn', ['--season=summer', '--weather=clear', '--hour=12']),
        'compare_new_grass.command': ('res://app/grass_capacity.tscn', []),
        'compare_original_grass.command': ('res://app/grass_capacity.tscn', ['--g4-legacy']),
    }
    for name, (scene, flags) in scenes.items():
        launcher = handoff / name
        launcher.write_text('#!/bin/sh\nexec ' + shlex.join([engine_binary(), '--path', str(candidate),
            '--resolution', '1440x900']) + ' "$@" ' + shlex.join([scene, '--', '--qa-settings', *flags]) + '\n')
        launcher.chmod(0o755)
        subprocess.run(['sh', '-n', str(launcher)], check=True)
        launchers[name] = digest(launcher)
    (handoff / 'HANDOFF.md').write_text('''# 风栖小筑 · G5 本地候选

双击 play_winter.command / play_summer.command 体验正式庭园。
compare_new_grass.command / compare_original_grass.command 打开相同24屋/1000物件容量样例。
容量样例内可切新旧草、密度和天气；切换会重载该容量样例，先保存需要保留的预览编辑。
主场景继续支持建造、撤销、保存、摄影、WASD漫步；Esc返回俯视。

候选还通过项目级override.cfg拥有独立用户目录，早于场景/偏好初始化；正式作品和其他阶段QA不受影响。
所有这些启动脚本使用QA作品/偏好；可保存、关闭后重开，通过载入继续候选作品。
候选依赖本机固定Godot工具链，重建入口为 tools/quality/production_candidate_portable_checks.py。
生成目录不提交Git；原项目F5仍启动正式游戏。

已知问题：冬景帧p95 26.496ms，超过20ms，G4已授权后置。
素材分发条款、Git-only资产供应、独立导出包和Windows实机仍未放行。
物理音频/触控板、新设备、首次玩家验收及完整性能矩阵/长测保持开放。

草渲染对照仅切派生渲染路径，不迁移或改写正式作品；代码基线见仓库阶段台账。
需要重新生成候选或目录被移动时，请在原项目重跑构建命令。
''')
    manifest = {'source_revision': revision, 'candidate_directory': str(candidate),
                'runtime_files': runtime, 'supplied_files': supply['files'], 'launchers': launchers,
                'toolchain_engine_sha256': digest(Path(engine_binary())),
                'local_candidate_only': True, 'g4_frame_budget_passed': False,
                'qa_user_scope': scope, 'scope_override_sha256': digest(override),
                'distribution_approved': False, 'standalone_export_verified': False,
                'windows_verified': False}
    (handoff / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return portable, candidate, handoff, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-only', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    receipt = OUT / 'handoff_checks.json'
    receipt.unlink(missing_ok=True)
    before = production_files()
    environment = preflight()
    portable, candidate, handoff, manifest = build()
    steps = []
    native = None
    if not args.build_only:
        steps.append(run_step('g5_final_cumulative', [sys.executable,
            'tools/quality/run_checks.py', '--week', '9', '--negative-control'], timeout=900))
        checks = json.loads((ROOT / 'reports/week_09_checks.json').read_text())
        assert checks['tests'] == 446 and checks['negative_control'] and checks['failures'] == 0
        env = os.environ.copy()
        env.update(GODOT_BIN=engine_binary(), WINDHAVEN_SOURCE_REVISION=portable['revision'])
        command = [sys.executable, 'tools/quality/grass_capacity_checks.py', '--native-only']
        process = subprocess.run(command, cwd=candidate, env=env, capture_output=True, text=True, timeout=240)
        (OUT / 'handoff_capacity.log').write_text(process.stdout + process.stderr)
        assert process.returncode == 0 and not ERRORS.search(process.stdout + process.stderr), process.stdout + process.stderr
        native = json.loads((candidate / 'reports/week_14/g4/functional_checks.json').read_text())
        assert native['functional_passed'] and native['native_checks'] >= 11 and native['production_unchanged']
        log = candidate / 'reports/week_14/g4/ui/native.log'
        assert not LEAKS.search(log.read_text())
        shutil.copy2(log, OUT / 'handoff_capacity_native.log')
        scope_probe = handoff / 'user_scope_probe.gd'
        scope_probe.write_text('extends SceneTree\nfunc _initialize() -> void:\n\tassert(OS.get_user_data_dir().get_file() == ' + json.dumps(manifest['qa_user_scope']) + ')\n\tprint("G5_USER_SCOPE ", OS.get_user_data_dir())\n\tquit()\n')
        process = subprocess.run([engine_binary(), '--headless', '--path', str(candidate),
                                  '--script', str(scope_probe)], text=True, capture_output=True, timeout=30)
        scope_log = process.stdout + process.stderr
        (OUT / 'handoff_user_scope.log').write_text(scope_log)
        assert process.returncode == 0 and not ERRORS.search(scope_log) and 'G5_USER_SCOPE ' in scope_log, scope_log
        launcher = handoff / 'play_winter.command'
        process = subprocess.run(['sh', str(launcher), '--audio-driver', 'Dummy', '--quit-after', '420'],
                                 cwd=ROOT, text=True, capture_output=True, timeout=120)
        text = process.stdout + process.stderr
        (OUT / 'handoff_launcher.log').write_text(text)
        assert process.returncode == 0 and not ERRORS.search(text) and not LEAKS.search(text), text
        assert 'Metal' in text and 'W09_FIRST_DRAW' in text
    assert before == production_files(), 'Handoff validation modified formal saves/preferences'
    result = {'passed': not args.build_only, 'build_only': args.build_only, 'environment': environment,
              'source_revision': portable['revision'], 'handoff_directory': str(handoff),
              'candidate_directory': str(candidate), 'runtime_file_count': len(manifest['runtime_files']),
              'runtime_manifest_sha256': digest(handoff / 'manifest.json'),
              'qa_user_scope': manifest['qa_user_scope'],
              'scope_override_sha256': manifest['scope_override_sha256'],
              'steps': steps, 'capacity_native': native, 'production_unchanged': True,
              'reused_verified_candidate': True, 'new_cold_import_run': False,
              'local_g5_complete': not args.build_only, 'g4_frame_budget_passed': False,
              'distribution_approved': False, 'standalone_export_verified': False, 'windows_verified': False}
    receipt.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('G5 LOCAL HANDOFF PASS' if not args.build_only else 'G5 HANDOFF BUILT; final checks not run')
    print(handoff)


if __name__ == '__main__':
    main()
