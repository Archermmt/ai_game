# 风栖小筑 · Godot MVP

工程版本标识仍为 **0.13.0-w13**，当前源码已完成W14的Terrain3D、四层Painterly Grass、体积云、厚雪、拨草与渐隐脚印接入。默认入口 `app/living_root.tscn`，F5运行正式主场景。

**G0–G5本地集成已收口：G4性能按授权后置，G5本地技术候选完成。** 冬景20ms、素材分发、独立导出包与Windows实机等仍开放；旧W12安装包未替换。进度见[STATUS](STATUS.md)、[G阶段台账](docs/weekly/week_14/G_STAGE_ACCEPTANCE.md)、[本地候选说明](docs/weekly/week_14/G5_CANDIDATE.md)。

## 本地候选与新旧草对照

已验证候选可从 `reports/week_14/g5/handoff_9ebe3bf8/` 启动：

- `play_winter.command` / `play_summer.command`：实际主场景冬景/夏景。
- `compare_new_grass.command` / `compare_original_grass.command`：同源容量样例的新/旧草；可在界面继续切换密度和天气。

Finder双击脚本即可体验。候选拥有独立用户目录，直接打开候选工程也不会使用正式作品或其他QA阶段的数据。容量对照切换会重载样例，不是当前未保存作品的热切开关。

首次准备和复建（派生美术素材须先按来源记录在本地供应，不会自动从Git获得）：

```sh
python3 tools/quality/candidate_asset_supply_checks.py
# 源码提交后，从空导入缓存创建并验证候选
python3 tools/quality/production_candidate_portable_checks.py
# 校验候选与源码/素材、生成交付脚本并执行最终检查
python3 tools/quality/g5_handoff_checks.py
```

候选目录、导入缓存、工具链和下载素材不提交Git。原项目F5继续沿用正常作品目录；本地交付不等于独立发行包。

## 历史G1–G3美术试验入口

打开 `app/painterly_grass_patch.tscn` 按F6，可在屋前8×8m区域切换新旧草，使用五个固定机位、日间/黄昏、暂停和第一人称漫步，Esc返回俯视。统一入口 `app/painterly_grass_preview.tscn` 提供G1单体展示与G2庭园对照的双向按钮；F5仍为正常游戏。

预览只读，直接F6也隔离正式存档和偏好。派生素材目前本地供应，Git单独检出需按[G1提取说明](art_source/painterly_grass/README.md)准备；[G2报告与五组对照](docs/weekly/week_14/G2_GRASS_PATCH.md)记录技术结果。这些早期预览保留用于历史对照；当前正式实现和验收状态以G阶段台账为准。

打开 `app/painterly_grass_garden.tscn` 按F6，可直接用新草建造、刷坡、撤销重做，切换四季雨雪、漫步和导出照片；存档与偏好使用独立预览目录。统一入口和G2中都可点击“编辑庭园 G3”。详见[G3报告](docs/weekly/week_14/G3_EDITABLE_GRASS_GARDEN.md)。

## 运行

固定 Godot **4.7.2 Standard**；版本与插件见 [toolchain.lock.json](toolchain.lock.json)。
首次检出（Python 3.12+、网络可用）：

```bash
python3 tools/quality/bootstrap.py
python3 tools/quality/candidate_asset_supply_checks.py
python3 tools/quality/winter_render_optimization_checks.py
python3 tools/quality/run_game.py
```

本机已准备 `.tools/` 和 `.venv/`，素材在本地齐备时可直接运行验证与启动命令。也可使用相同版本 Godot 打开
`project.godot` 后按 F5；单场景测试请打开 `app/living_root.tscn` 后按 F6。系统的 Godot 4.7 不满足本项目补丁版本锁。
可通过 `GODOT_BIN` 指定同版本引擎；下载的引擎、缓存、试玩包和用户存档不进入 Git。

| 操作 | 输入 |
| --- | --- |
| 就地修改 | 悬停对象直接显示引导；拖白色方向示意图标，松手完成；右键点选仍可用 |
| 屋顶 / 门窗 / 桥 | 拖屋顶示意图上下调整，下拉为平顶；门窗和桥两端按方向图标拖动 |
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
| 日期 / 天气 / 流速 | 右侧林间历：Month/Day/Hour/Min下拉；Weather选晴/阴/雨/雪；Speed暂停或1/5/20/60倍 |
| 四季 / 减少动态 | 月份决定季节；顶部「设置」减少动态会禁止闪电 |
| 第一人称漫步 | 相机卡片 → 林间漫步；WASD/方向键行走，Shift稍快；右键拖动或Mac双指环顾；Esc返回编辑 |
| 摄影设置 | 相机卡片打开底部示意图按钮；设置图标展开照片尺寸、目录与构图列表 |

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

当前W14正式场景与G5本地交付：

```sh
python3 tools/quality/winter_render_optimization_checks.py
python3 tools/quality/g5_handoff_checks.py
# 冬景20ms仍未通过；严格性能命令保留非零结果
python3 tools/quality/winter_render_performance.py
```

以下W13入口作为历史分层验证保留：

```bash
# 自动化回归、格式、lint、资源契约、跨进程重启与失败注入
python3 tools/quality/week_thirteen_checks.py
# 有桌面GPU：图标/日期真实输入、四季天气与150%界面实拍
python3 tools/quality/week_thirteen_native_checks.py
# 第一人称输入、无界面PNG与相机恢复；24屋/1000源漫步30秒
python3 tools/quality/walk_native_checks.py
python3 tools/quality/walk_performance_checks.py
# 起伏示范与晴/雨/雪满容量，各60秒及20笔编辑
python3 tools/quality/week_thirteen_performance.py
# ART 多角度与环绕录像保留历史入口：art_pass_render_checks.py / art_pass_orbit.py
# 提交实现后，从空导入缓存的Git archive复验本轮
python3 tools/quality/clean_checkout.py --week 13
# 历史W12导出/打包请切到 v0.12.0-w12，参见该周报告
```

历史本机CoreAudio混音时钟问题仍单列；W13原生/性能脚本明确使用Dummy验证非音频功能，报告不会把真实音频计为通过，游戏默认音频驱动不变。

导入、导出以及质量检查按顺序运行，避免两个编辑器进程同时修改同一 `.godot/`。
自动报告输出到 `reports/`；历史试玩包位于 `builds/week_12/windows/` 和 `builds/week_12/macos/`；这些ZIP保持W12原提交，本轮自然庭园扩展请运行当前源码。
macOS 包是本地未公证开发包。Windows EXE 导出成功仍需 Windows 设备完成可见交互验证。
CI 已配置 Ubuntu / Windows 自动回归，尚未推送远程触发。
每周新增功能必须补测试并保留既有回归，见 [测试约定](docs/TESTING.md)。

## 模块与资源

- `app/`：试玩组合根；`core/`：源数据、放置约束和事务。
- `features/`：建筑网格、轨道相机、存档与风着色器；`ui/`：操作面板与建筑属性 / 恢复面板。
- `tests/week_01/`–`week_12/`、`tests/art_pass_01/`、`tests/ux_02/`、`tests/ux_03/`、`tests/perf_01/` 与 `tests/perf_02/`、`tests/week_13/`：累计 GUT 回归和独立进程探针；`tools/quality/`：可复现质量命令。
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

W10 加入环境/操作/音乐三路音量（设置面板；0 为关闭）。当前主场景使用用户提供的8首音乐，按季节/时段从3首候选中随机播放，柔和混音与6秒交叉淡化；首次启用默认50%，后续记住音量和关闭选择。最新混音可辨识度与1–60倍时间滑块见[界面与音频修复](docs/weekly/week_13/HUD_AUDIO_FOLLOWUP.md)。见[季节音乐说明](docs/weekly/week_13/SEASONAL_MUSIC.md)。累计验证：`python3 tools/quality/week_thirteen_checks.py`。进度和未关闭门槛见 `STATUS.md`，当周证据见 `docs/weekly/week_10/`。

底部「花草」卡片内可拖动地表动态草密度，0关闭、默认45%、100%最高，手工种植不受影响。设置可关闭远景柔焦；摄影保留景深并冻结草。修订报告见 `docs/weekly/ui_meadow_01/README.md`。

日历“明早6:00”可跳过今天；底部太阳图标设置四季天气比例。自动天气每3游戏小时抽取，春夏秋禁雪、冬季禁雨，支持暴风雨/暴风雪/沙尘暴与雾。详见[天气说明](docs/weekly/week_13/WEATHER_CYCLE.md)。

池塘新增实际场景倒影、流动波纹、深浅水色和岸边细纹，沿用减少动态/摄影冻结。前后效果与开销见[水面说明](docs/weekly/week_13/POND_WATER.md)。

摄影加入[林间漫步](docs/weekly/week_13/FIRST_PERSON_WALK.md)：贴地行走、通过桥梯、避开屋体和池水，可隐藏面板并导出第一人称照片。返回俯瞰恢复原构图/景深；暂不提供房屋内部或游泳。

最新[交互与天空调整](docs/weekly/week_13/SKY_WEATHER_UI.md)：漫步环顾方向反转，选中图标局部放大，摄影统一为图标操作。天气约18秒渐变，天空加入流云、日月、星星和银河；摄影冻结同时定格天气过渡。

最新[整体美术重制与同机位对比](docs/weekly/week_13/PAINTERLY_REWORK.md)：短草疏密与连贯树冠、木纹和灰泥笔触、厚檐封底、积云与远山、暖光冷影及较轻景深。依据[12张官方场面图研究](docs/art/PAINTERLY_REFERENCE_STUDY.md)，请停止旧运行后F5查看当前源码。
