#!/usr/bin/env python3
"""Render the handoff report only from a completed, identified native package run."""
from pathlib import Path
import hashlib,json,plistlib
root=Path(__file__).resolve().parents[1];reports=root/'docs/reports';completion=root/'docs/completion'
load=lambda p:json.loads(p.read_text())
pressure=load(reports/'completion_r2/pressure.json');process=load(reports/'completion_r2/pressure_process.json');packages=load(reports/'completion_r4/packages.json')
assert process['executed'] and pressure['duration_wall_seconds']>=300 and pressure['edit_samples']>=140
assert 'frame_post_draw' in pressure['edit_measurement']
app=next((root/'builds/macos').glob('*.app'));info=plistlib.loads((app/'Contents/Info.plist').read_bytes());binary=app/'Contents/MacOS'/info['CFBundleExecutable'];pck=next((app/'Contents/Resources').glob('*.pck'))
assert process['binary_sha256']==hashlib.sha256(binary.read_bytes()).hexdigest() and process['pck_sha256']==hashlib.sha256(pck.read_bytes()).hexdigest()
assert all(process[key] for key in ['draw_budget_passed','triangle_budget_passed','edit_budget_passed','frame_60fps_p95_passed','memory_sample_budget_passed'])
for package in packages['packages']:assert hashlib.sha256((root/'builds'/package['file']).read_bytes()).hexdigest()==package['sha256']
art=load(reports/'completion_r2/validation.json');core=load(reports/'completion_r3/core_tests.json');native=load(reports/'completion_r3/native_tests.json');checks=load(reports/'completion_r4/package_checks.json');pixels=load(reports/'completion_r2/lod0_pixels.json');low=load(reports/'completion_r4/low_smoke.json')
assert art['passed'] and pixels['passed'] and all(item['passed'] for item in core+native+checks)
files={}
for path in sorted(root.glob('game/**/*')):
 if path.is_file() and path.suffix in ['.gd','.tscn','.tres','.gdshader','.glb','.otf','.svg','.wav','.png','.jpg']:files[str(path.relative_to(root))]=hashlib.sha256(path.read_bytes()).hexdigest()
for name in ['project.godot','export_presets.cfg']:files[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
(reports/'completion_r4/source_hashes.json').write_text(json.dumps(dict(scope='Working source and export inputs; project.godot includes preserved user formatting/features',files=files),indent=2)+'\n')
rows='\n'.join(f"| {item['file']} | {item['bytes']:,} | `{item['sha256']}` |" for item in packages['packages'])
boots=[item['launcher_ready_ms'] for item in checks if item['name'].startswith('macos_release_')]
text=f'''# 0.3.0本机验证候选 · 最终交付

2026-10-30。R1–R4的本机开发、回归和转交准备已交付；用户确认暂不安排M1/8GB、Windows设备与5–8人试玩，因此外部执行、G1人工视觉与最终MVP签收保留未执行。不是已发行版本，也没有宣称画质与Brushland官方参考等效。

## 可以体验的内容

画地/改岸/升降、道路/桥/码头、六建筑外观与锁定/配色/移动、四居民形象与稳定偏好、单船末段靠泊及入住、茶/花/看海/灯塔活动、六愿望/手记、动物、昼夜、保存恢复、摄影都可操作。新建无建筑海湾、空白海面与三个参观构图区分，参观不用于首次建造门槛。

本轮补齐：持久设置/重绑与冲突处理、75–150%界面、真1920×1080摄影和预览剔除、22个48kHz原创音源、画质档、渲染代理/区域缓存、原子保存故障恢复/3备份与命名槽、收起愿望、精确入住原因、桥中央拆除安全迁移、在途拆屋重载与优先安置、受阻文字/斜纹和屋型预览。美术源库沿用I6的117条/170份，MVP111条/161份；没有用资源存在性替代人工接受。

## 最终成品五分钟实测

直接运行本次macOS Release二进制，Apple M4 Pro/macOS 15.1，Godot4.7 Compatibility/OpenGL3，固定1920×1080渲染、中等画质；桌面仅显示640×360角落预览，不抢键盘焦点，截图尺寸在运行时校验。64×64世界/1200陆地/40建筑（12居所、10茶屋、9温室、9灯塔）/400装饰/12居民/6动物；旋转一圈，半程白天/半程夜景，每2秒尝试升降同一合法边界格（按实际高度交替，避免时钟跳过后误删陆地），实际{pressure['edit_samples']}笔。未并行GPU测试或视频编码。

| 指标 | 本机结果 | 对应门槛 |
| --- | --- | --- |
| 实测持续时间 | {pressure['duration_wall_seconds']:.3f}秒，{pressure['frame_count']:,}帧 | ≥300秒 |
| 墙钟帧时p50 / p95 | {pressure['frame_ms_p50']:.3f} / {pressure['frame_ms_p95']:.3f}ms | p95目标≤16.67ms |
| 白天 / 夜间帧时p95 | {pressure['day_frame_ms_p95']:.3f} / {pressure['night_frame_ms_p95']:.3f}ms | 分段记录 |
| 一笔至帧绘制完成p95 | {pressure['edit_ms_p95']:.3f}ms | <100ms |
| 可见绘制调用峰值 | {pressure['draw_calls_peak']} | ≤200 |
| 可见三角面峰值 | {pressure['visible_primitives_peak']:,} | ≤350,000 |
| 进程RSS 2秒采样最大值 | {process['rss_peak_bytes']:,}字节 / {process['rss_peak_bytes']/1048576:.1f}MiB，{process['rss_samples']}次采样 | <1.5GB |
| 标准场景生成/发布 | {pressure['build_ms']:.3f}ms | 单列，不等于文件读取全链路 |

编辑从paint前计到RenderingServer.frame_post_draw的被动观察回调，包含本轮重建与下一次实际绘制；帧时也取真实绘制事件间隔。主循环不等待该信号，每分钟截图后台压缩写盘，减少记录工具干扰；不测OS合成器/显示器延迟。样板为固定单格提交，不能推断任意大笔刷、任意密集灯塔布局的最坏情况。RSS可能漏过瞬时峰值，非VRAM；Release的引擎静态内存计数为0，不拿它判内存门槛。绘制预算余量较小，应保留流畅档并在目标硬件/实际作品复测。

报告：`docs/reports/completion_r2/pressure.json`、`pressure_process.json`、`pressure.log`；每分钟实拍：`snapshots/completion_r2/pressure/minute_0..4.png`。过程文件记录实际二进制与PCK SHA256，和当前交付文件已核对。

流畅档成品10秒：仍为40/400/12/6、1200陆地，draw{low['draw_calls_peak']}、帧时p95 {low['frame_ms_p95']:.3f}ms；该短测用于档位/数量验证，编辑p95 {low['edit_ms_p95']:.3f}ms（4笔），不作为完整5分钟验收。M1/8GB和Windows必须分别测两档；本机结果不替代它们。

三次macOS成品启动器内部就绪耗时：{', '.join(str(value) for value in boots)}ms。该计时不包含全部进程/系统启动，也不代表从磁盘读大存档已在目标设备<5秒；外部步骤另测。

## 验证与失败记录

- {len(art['steps'])}步美术/双渲染器回归通过，{len(core)}项规则/恢复与{len(native)}项原生交互通过，同LOD0六机位像素容差通过。范围和人工补测逐项见[AC矩阵](AC_TRACEABILITY.md)、[渲染说明](RENDERING.md)、[保存/生活闭环](RECOVERY.md)。
- 部分写入、备份复制、原子替换失败保持旧主档可读；16类坏输入不改实时世界；50次混合undo/redo、六愿望自然模拟、内湖开口、桥中央移除、在途来客回存/补房优先恢复均有源码测试。
- 最初1600陆地静止五分钟draw219失败、连续编辑约268ms等过程结果保留before_smoke；不同陆地/配比不能与最终样板直接作倍率比较。正常自动LOD与固定LOD偏置混比的旧pixels/proxy_off保留，正式保真使用双方全部保留实例统一LOD偏置后的proxy_on对照lod0_pixels。
- 曾发现Release省略assert内构建副作用，旧短测实际缺建筑/居民，已明确作废为invalid_fixture_low_smoke.json；当前显式创建、运行时检查数量并在外部脚本复核。此前仅CPU重建的五分钟结果保留before_frame_draw；不持久代理在完整绘制口径下p95 200.835ms/draw202失败，保留before_persistent。随后改为持久节点/缓冲和高度/地基索引；正式结论使用当前含帧绘制完成口径的数据。
- 没有把签名、包格式检查、空白记录表或源码加速模拟当作Windows实机、真人30分钟试玩或G1主观视觉签收。

## 可转交构建

本地文件在项目builds下（因体积与可再生性不进Git），源代码/预设/工具和测试证据已归档。macOS为universal模板、ad-hoc签名未公证；Windows为未签名x86_64，未在Windows执行。两个包均在项目外独立目录查资源、场景、字体与许可，Windows PE/内嵌PCK检查通过，macOS签名验证/三次启动通过。

| 文件 | 字节数 | SHA256 |
| --- | --- | --- |
{rows}

每包包含游戏、TEST_HANDOFF、两平台基准脚本、RESULTS_TEMPLATE和licenses。Mac测试者运行对应.command，Windows使用对应.ps1或手动命令，默认300秒；脚本采集日志与进程内存，游戏输出report及每分钟截图。不要求安装Godot或关闭系统保护。字体与模板来源哈希在docs/completion，Godot/Noto/Poly Haven许可随包。

复现顺序：Godot4.7→首次导入→`python3 tools/run_completion_tests.py`→`python3 tools/run_art_stage.py completion_r2`→备齐官方模板（fetch_export_templates.py）→`python3 tools/build_release.py`→`python3 tools/check_release.py`→停其他GPU工作后`python3 tools/run_completion_pressure.py`。像素比较工具需Pillow/numpy。所有构建写builds，游戏写user://，不写安装目录。

## 留给测试者的执行项

按[转交步骤](TEST_HANDOFF.md)执行M1/8GB、Windows各5分钟双画质及保存/摄影/UI检查；按G1审阅三构图/近景/动作与听感；5–8人无讲解试玩30分钟，先取得记录/录屏同意，按80%小样本门槛填表。作品丢失/流程阻断先修，反馈修复后复测受影响项，再决定原MVP最终签收。POST天气、相框等完整玩法仍在后续范围，不算本轮遗漏任务。
'''
(completion/'FINAL_REPORT.md').write_text(text)
print('Final report and source hashes written')
