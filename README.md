# 风栖小筑 · Godot MVP

当前源码包含PERF-01性能修复与UX-03悬停表面编辑，沿用W12版本，使用已接受的 ART-01 美术：暖灰泥、厚叠瓦、蜂蜜木构、分层叶簇与手绘林间庭院，
继承 W09 摄影/布局/全部建造工具及五槽保存。默认入口 `app/hover_root.tscn`，版本 `0.12.0-w12`。
进度见 [STATUS.md](STATUS.md)，性能排查见 [PERF-01报告](docs/weekly/perf_01/README.md)，历史交付与门槛见 [W12报告](docs/weekly/week_12/README.md)，[UX-03交互报告](docs/weekly/ux_03/README.md)保留。
F5 运行当前主场景；若用F6，请打开 `app/hover_root.tscn`，旧周场景保留历史画面。
已接环境、操作、音乐三路音量；局部编辑延迟目标仍开放，完整冻结另看门槛。

## 运行

固定 Godot **4.7.2 Standard**；版本与插件见 [toolchain.lock.json](toolchain.lock.json)。
首次检出（Python 3.12+、网络可用）：

```bash
python3 tools/quality/bootstrap.py
python3 tools/quality/perf_checks.py
python3 tools/quality/run_game.py
```

本机已准备 `.tools/` 和 `.venv/`，可直接运行后两条命令。也可使用相同版本 Godot 打开
`project.godot` 后按 F5；单场景测试请打开 `app/hover_root.tscn` 后按 F6。系统的 Godot 4.7 不满足本项目补丁版本锁。
可通过 `GODOT_BIN` 指定同版本引擎；下载的引擎、缓存、试玩包和用户存档不进入 Git。

| 操作 | 输入 |
| --- | --- |
| 就地修改 | 悬停对象直接显示引导；拖“宽/深/高/移”，松手完成；右键点选仍可用 |
| 屋顶 / 门窗 / 桥 | 拖△调整屋顶，下拉为平顶；门窗移/宽/高，桥两端◆可拖 |
| 复制与删除 | 选中后下方操作条；复制预览左键放下、右键取消；橡皮可点删 |
| 精确参数 | 按需打开“更多参数”或选中后的“精确参数” |
| 建房 | 选矩形 / 圆形，左键在草地拖动并释放 |
| 取消预览 | Esc 或卡片内“取消本笔” |
| 环视 / 平移 / 缩放 | 右键或双指上下左右移动 / Option（⌥）+左键、中键或 Shift+左键拖动 / 滚轮或双指捏合 |
| 恢复镜头 | F 或“复位视角” |
| 撤销 / 重做 | Ctrl（macOS 为 Cmd）+Z / Shift+Z；或按钮 |
| 分类植被 | 选择树木 / 植物 / 岩石；调半径和各类密度后选择刷植或擦除；Ctrl/Cmd+滚轮调半径 |
| 属性 | 手放内容可锁定高度；提灯选择开启 / 关闭 / 自动；顶部「设置」可改 UI 比例、重绑快捷键与关闭景深 |
| 存档 / 读档 | Ctrl/Cmd+S / Ctrl/Cmd+O；或按钮 |
| 日暮色 / 减少动态 | 底部「光线」/ 顶部「设置」|

建筑宽深 3–12m、高 2.4–7.2m；拖建时默认高 3m，选中后拖动就地手柄调整，精确尺寸与檐高仍可从“精确参数”设置；建筑旋转仅支持 0°。
重叠放置被拒绝，相切 / 同朝向侧贴可通过数据检查；接触墙消隐与端部封边已有风险实现；当前美术层已接厚屋檐、木石收边与局部贴靠裁剪。
顶部「我的作品」选择五个命名槽之一保存/载入，预览来自当前实机画面；快捷键操作当前作品。
空闲 60 秒自动保存当前作品，`.bak1`–`.bak3` 保留前三代。启动新示范只选择空槽；五槽已满时
暂停自动保存，需主动载入或选择保存目标。未保存的载入/退出可选保存、放弃或取消。
损坏主档按最新有效备份恢复到内存，保留原文件；请另存到空槽。未来版本不会被覆盖。

当前路径为 `user://week_08/saves/slot_01.wgs`–`slot_05.wgs`，本机设置为
`user://week_08/preferences.cfg`。W08 起使用固定用户目录 `WindhavenDiorama`，避免后续版本名称
改变导致找不到作品。macOS 对应 `~/Library/Application Support/WindhavenDiorama/`。
旧周次目录保留；关闭游戏后可将旧 `.wgs` **复制到空槽文件名**，兼容 WGLADE01 / W07 WGLADE02，
旧容器重存时进入新格式并保留原代备份。不要删除原件，也不要替换已有作品来迁移。


## 测试与导出

```bash
# 自动化回归、格式、lint、资源契约、跨进程重启与失败注入
python3 tools/quality/perf_checks.py
# 有桌面 GPU 的机器：24项悬停GUI与60秒满容量性能
python3 tools/quality/perf_native_checks.py
# ART 多角度与环绕录像保留历史入口：art_pass_render_checks.py / art_pass_orbit.py
# 提交实现后，从空导入缓存的Git archive复验本轮
python3 tools/quality/clean_checkout.py --week 12 --perf
# 历史W12导出/打包请切到 v0.12.0-w12，参见该周报告
```

当前本机CoreAudio混音时钟停滞；可在W12导出与perf_native_checks显式添加 `--silent-audio` 验证非音频功能。报告会标记Dummy，真实音频不计通过，游戏包默认音频驱动不变。

导入、导出以及质量检查按顺序运行，避免两个编辑器进程同时修改同一 `.godot/`。
自动报告输出到 `reports/`；历史试玩包位于 `builds/week_12/windows/` 和 `builds/week_12/macos/`；这些ZIP保持W12原提交，本轮性能修复请运行当前源码。
macOS 包是本地未公证开发包。Windows EXE 导出成功仍需 Windows 设备完成可见交互验证。
CI 已配置 Ubuntu / Windows 自动回归，尚未推送远程触发。
每周新增功能必须补测试并保留既有回归，见 [测试约定](docs/TESTING.md)。

## 模块与资源

- `app/`：试玩组合根；`core/`：源数据、放置约束和事务。
- `features/`：建筑网格、轨道相机、存档与风着色器；`ui/`：操作面板与建筑属性 / 恢复面板。
- `tests/week_01/`–`week_12/`、`tests/art_pass_01/`、`tests/ux_02/`、`tests/ux_03/` 与 `tests/perf_01/`：累计 GUT 回归和独立进程探针；`tools/quality/`：可复现质量命令。
- `art_source/week_01/`–`week_10/` 和 `art_source/art_pass_01/`：模型、纹理与材质库源文件；`assets/`：GLB、贴图和导入配置。
- `docs/`：已批准 PRD、开发计划、每周证据与许可。

Blender 5.1.2 为唯一主模型源，三种门与树 / 布 / 长凳样板，以及 W02 窗 / 树初稿 / 笔触纹理可分别重建：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_one_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_two_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_three_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_four_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_five_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_six_assets.py -- --root "$PWD"
python3 tools/art/build_week_six_media.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_seven_assets.py -- --root "$PWD"
python3 tools/art/build_week_seven_ui.py
```

Windows / Linux 改用当地 Blender 路径。Three.js 暂未引入；GUT 9.7.1 已随源码保存。
更多工具选择、数据契约与未完成部分见 W01 报告；第三方许可见 [THIRD_PARTY.md](THIRD_PARTY.md)。

修改源资产后还需在 Blender 中重新打开检查（报告目录先由质量命令建立）：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/reports/week_07_source_audit.json"
```

## 工程维护与历史记录

2026-10-23 已清除旧周导出、解包测试目录、重复运行报告、下载缓存和 Blender 自动备份。
仅保留 `builds/week_12/` 的 W12 内部安装包与许可文件；它们对应旧冻结提交，当前性能修复请运行源码。
`reports/` 是可再生成的工作目录，正式证据保存在 `docs/weekly/`。清理后如需重新打包，先重跑对应回归与导出命令。
清理记录、保留文件哈希及剩余验收见 [CLEANUP-01](docs/weekly/cleanup_01/README.md)。

`app/hover_root.tscn` 通过场景继承复用早期周次根节点；这些场景及旧周回归仍是当前工程依赖。
建筑参数画廊 `app/building_parameter_gallery.tscn` 用于渲染检查；旧素材的源件、清单及导入配置保留用于重建和兼容验证。
旧界面与周次操作说明统一查阅 [每周报告](docs/README.md)，当前操作以上方表格及 [W12操作说明](docs/weekly/week_12/HOW_TO_PLAY.zh-CN.md) 为准。
源历史最多50笔，每份源快照最多1MiB JSON；生成网格不进入历史或存档。

ART-01 原创自然模型和材质的可重建命令：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_art_foliage.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_art_materials.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --extra-manifest art_source/art_pass_01/nature/manifest.json --output "$PWD/reports/art_source_audit.json"
```

W10 默认继承已接受的美术样板，加入环境/操作/音乐三路音量（设置面板；0 为静音，音乐默认关闭）。累计验证：`python3 tools/quality/perf_checks.py`。进度和未关闭门槛见 `STATUS.md`，当周证据见 `docs/weekly/week_10/`。

底部「花草」卡片内可拖动地表动态草密度，0关闭、默认45%、100%最高，手工种植不受影响。设置可关闭远景柔焦；摄影保留景深并冻结草。修订报告见 `docs/weekly/ui_meadow_01/README.md`。
