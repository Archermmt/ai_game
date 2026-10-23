# 每周测试与验收约定

## 当前可执行门槛

```bash
python3 tools/quality/run_checks.py --week 9 --negative-control
```

按顺序执行锁定引擎导入、格式、lint、资源契约、GUT、各周两个独立进程的保存/重载，
最后注入一个必失败测试，验证退出码和失败报告确实生效。生成报告在忽略版本管理的
`reports/`，发布节点将摘要、XML 和必要截图复制到 `docs/weekly/week_XX/`。

命令必须在发现引擎脚本错误、崩溃、测试失败、空测试集或关键用例跳过时返回非零。
失败注入文件在 `finally` 中删除，不进入正常测试或 Git。不得修改断言来掩盖失败。
导入与导出共用 `.godot/` 缓存，**同一目录内串行执行，禁止并发启动编辑器批处理**。

## 每周最低测试范围

| 周次 | 必须保留的既有回归 | 本周新增验收 |
| --- | --- | --- |
| W01 | 首次建立 | 源数据/ID、存档校验、事务取消/失败/50步历史、真实洞口、GLB风权重与插槽、相机、UI输入隔离、实际鼠标拖建、导出与启动 |
| W02 | W01 全部 | 洞口极限/贴靠收边、池岸派生地形删除恢复、3m基座整笔拒绝、陈旧任务淘汰与脏区不丢失 |
| W03 | W01–02 | 连续改尺寸/屋顶、稳定种子、地形采样接缝、实例数据与显示索引映射 |
| W04 | 既有全部 | 路径生门/手窗避让/删路锁门、固定地坪、围栏端头与开口 |
| W05 | 既有全部 | 池桥失效与恢复、双向池屋安全带、短阶边界、灰模全流程、全部源字段保存往返 |
| W06 | 既有全部 | 分类刷植/擦除/密度、手工保护、后台纯数据、旧结果晚到、晾布零风与减少动态 |
| W07 | 既有全部 | 八道具支撑面、提灯、绿篱、材质与导入重建、属性卡操作 |
| W08 | 既有全部 | 完整容器格式/引用/迁移、五存档/自动保存/备份、可绕看视觉与资产集成 |
| W09 | 既有全部 | 压力场景帧时间/内存、摄影两尺寸、模板与空布局入口 |
| W10 | 既有全部 | AC-01~14 完整回归、坏档/中断注入、UI150%/重绑/减少动态、功能冻结 |
| W11 | 既有全部 | 冻结包十人体验、反馈缺陷回归；不以新增需求挤掉可靠性验证 |
| W12 | 既有全部 | 最终包全新解压、Windows实机、许可/哈希/操作说明、保存重启摄影退出 |

W01–W09 已注册：42 + 52 + 42 + 50 + 45 + 68 + 51 + 62 + 34 = **446 项**，执行累计回归。
W10–12 仍是计划，传入未注册周次会明确失败。新增周次必须注册 gate 并保留既有回归。

## 四类证据分开

- 自动化：GUT XML、进程退出码、导入日志、资源契约与重启报告。
- 视觉：从实际运行视口截取，记录版本、渲染器、镜头和状态；概念图不是运行证据。
- 性能：固定设备、画质和场景；W01 小样本不能代替完整 PRD 压力场景或最低配置。
- 平台：macOS 上导出 Windows EXE 只证明导出；Windows OS 上的 headless 测试只证明
  其自动化路径；3D 显示、输入、存档和退出仍须目标设备可见运行。

CI 工作流对 Ubuntu / Windows 配置同一组自动检查；本地没有远程仓库和 CI 运行记录时，
只报告“工作流已配置”，不能称云端 CI 已通过。

## W02 专项命令

```bash
python3 tools/quality/run_checks.py --week 3 --negative-control
python3 tools/quality/render_checks.py
python3 tools/quality/run_game.py -- --edit-benchmark --benchmark-seconds=10 --smoke-output=/absolute/path/edit_metrics.json
python3 tools/quality/export_smoke.py --week 2
```

W02 新增：带实际高度变化的 0.25/0.5m 分块接缝测试、单独池岸源/派生层、3m 限制、
双向安全带、手工保护、50 笔混合编辑、真实鼠标与 PendingCommit、已显示预览后的失败回滚，
以及由 Semaphore 控制的旧任务晚到。性能记录区分 worker 计算、headless 资源准备和可见主线程发布耗时。
发布阶段仍会整场重建；若超过 2–4ms 建议预算，必须记录风险，不把空闲帧率当成编辑过程达标。

模型/材质源变更还须运行 Blender 的 `tools/art/audit_sources.py`，实际重开源文件，
确认 UV/权重/插槽以及未链接模型的材质库节点仍被保存（Fake User）。本机报告为 W02 的
`source_audit.json`；CI 无 Blender 时的 GLB/纹理检查不能代替此源文件审计。

Mac 相机输入增加 6 项视口事件测试：Option+左键环绕不误编辑、Option/Shift 优先级、
双指捏合方向与边界、双指滚动与精确滚轮、UI 隔离及跨 UI 松键。W02 当前最低 52 项，
累计最低 94 项；实体触控板操作与事件注入测试区分记录。


## W03 专项命令

```bash
python3 tools/quality/run_checks.py --week 3 --negative-control
python3 tools/quality/week_three_render_checks.py
python3 tools/quality/export_smoke.py --week 3
```

W03 新增 42 项：参数极值 / 几何法线 / 米制 UV、连续尺寸预览 / 取消 / 失败回滚、批量删父对象与门窗恢复、
附着冲突、50 条历史与分支、源快照容量、树 LOD / 图集 / 根与果实风权重、稳定实例映射、石径贴坡 / 交汇去重 / 避水 / 建筑内隐藏，
以及 W03 的实际 UI 多选、鼠标石径和 Mac 手势。独立进程检查包含待附着门窗、树种和路径源数据。

可见验证检查四向 / LOD1 / 黄昏 / 建筑极值场景、风动与零风 / 减少动态像素对照、迎光水面不过曝像素检查，
并记录单池显示 / 隐藏的 1080p 帧时间。GPU 计时不可用时明确标记 unavailable，不能把 0 当成无开销。
Blender 审计需重开三周 22 份模型源、8 个基础材质图及 2K 共享图集节点。


## W04 专项命令

```bash
python3 tools/quality/run_checks.py --week 4 --negative-control
python3 tools/quality/week_four_render_checks.py
python3 tools/quality/export_smoke.py --week 4
python3 tools/quality/clean_checkout.py --week 4
```

W04 新增 50 项：曲线控制点 / 路宽 / 距离高差 / 复用门 / 最后一条供门路径删除 / 锁定保留 / 手窗优先，
手放五开口、跨 UI 松键、取消和准备失败回滚；地形平滑恢复 / 核心边界 / 池域与入口保护 / 3m 支撑；
64 块缓存、邻接采样 halo / 改池删池失效 / 全量结果一致；五自然资源及道具源件、根 / 挂点风权重、
坡面贴地、最近四灯与连续光照；围栏开工数据 / 路径开口；以及新工具下的 Option 环绕与捏合隔离。

源变更须重开三周原件及 W04 九件，当前共 31 份模型源。每次可见验收记录日暮 / 四向 / 资源近景、
路门与基座演示、零风 / 减少动态像素对照及 20 笔编辑。图形验证与 headless 回归分开执行。
缓存是精确源签名和原始数组；主线程缓存与单 worker 缓存分离，不能从两条线程并发写同一字典。
最终全场压力与 Windows 真机仍独立验收。


## W05 专项命令

```bash
python3 tools/quality/run_checks.py --week 5 --negative-control
python3 tools/quality/week_five_render_checks.py
python3 tools/quality/export_smoke.py --week 5
python3 tools/quality/clean_checkout.py --week 5
```

W05 新增 45 项：自由轮廓/自交/最窄与边界、池底与岸带、固定水位、删除恢复玩家数据、双向安全带、手放内容保护、精确局部缓存；
短桥范围/桥头高差/确认、失效保留与撤销同恢复、入口短阶/宽高边界；围栏转角共享与闭合封边/路径开口；
木箱支撑高度/循环与丢失引用、模型预算、实际鼠标松手预览、取消 PendingCommit、Mac Option 隔离和浮点存档精度。
50 笔混合样本串联建屋/手工门窗、路径以往回归、刷植、摆物、地形、池塘、桥、围栏、删父与重新附着、全部撤销重做。
独立进程保存包含非圆岸线、桥头采样、闭合围栏和堆叠引用。源审计重开五周共 37 模型及材质图。
可见验证和导出仍串行；Windows 真机、最低配置和全场压力不能由本地检查代替。

## W06 专项命令

```bash
python3 tools/quality/run_checks.py --week 6 --negative-control
python3 tools/quality/week_six_render_checks.py
python3 tools/quality/export_smoke.py --week 6
python3 tools/quality/clean_checkout.py --week 6
```

W06 新增 68 项，覆盖分类密度/稳定种子/擦除保护、自动植被避让与手放保护、64 分块局部重建与全量等价、
异步陈旧结果/取消/准备失败/原子发布、支撑移动/高度锁定、MultiMesh 个体映射与风相位、真实提灯开关与最近四灯、
中文字体/布局缩放/输入隔离、模型源属性、20 SVG 与 17 WAV 的格式/峰值/RMS/循环设置。
精确浮点存档还检查相邻 double、JSON 边界、非法路径/NaN、旧容器兼容和独立进程严格往返。
各周独立进程检查仍保留。新增资源审计重开 45 模型源、8 材质图与 1 图集 / 9 图像。

渲染检查实际批量植被风动及零风/减少动态、日暮、四向茶具与提灯、100/150% 布局和 64/128 图标。
性能分开记录 worker 计算、分帧资源准备、主线程发布、提交到显示的总延迟；原生调用不可抢占，
分帧预算是目标而非硬实时承诺。采样设备与场景、GPU 计时有效性必须随报告保留。
W06 只验收声音资产波形与导入；完整播放、混音、听感签核继续 T063，不能据此宣称声音系统完成。

## W07 专项命令

```bash
python3 tools/quality/run_checks.py --week 7 --negative-control
python3 tools/quality/week_seven_render_checks.py
python3 tools/quality/export_smoke.py --week 7
python3 tools/quality/clean_checkout.py --week 7
```

W07 新增 51 项：绿篱短段/端头/转角/缩放/整段擦除/手放保护/控制点/完整区域失效，
共享网格与 UV、坡面/锁高；17 包装/拾取/挂点、12 材质卡、五开口与极值、共享角柱；
物件属性提交/拒绝/取消、UI150%、真实鼠标 Dock/绿篱与 Option 隔离、提灯复制/四灯限制，
新格式 DTO/旧容器/校验/未知版本保护/int64/无效引用与独立进程重启。
24 个当前手工模型含 LOD 按 PRD 建议预算审计；圆窗优化源额外重开，模型源累计 46 份。
原生 96px 缩略图须实际渲染后导入；headless 格式检查不能代替图像签核。

Dummy 渲染后端不提供 MultiMesh 变换缓冲读回，自动化验证纯数据布局，
原生 Metal 单独确认坡面变换范围和可见结果。不得把 Dummy 零值当作 GPU/动画无成本。
存档格式 2 与源 schema 1 分开，未来格式不能覆盖原文件；完整迁移/多槽/自动保存仍为 W08。

当前 51 实例草案可见编辑存在超过目标的发布/准备尖峰，W08 T054 必须继续剖析；
功能回归通过不代表最终性能、最低配置或 Windows 可见交互通过。


## W08 专项命令

```bash
python3 tools/quality/run_checks.py --week 8 --negative-control
python3 tools/quality/export_smoke.py --week 8
# 支持 --executable /absolute/path/to/exported/app，复测发布包而非编辑器运行时
python3 tools/quality/week_eight_render_checks.py
python3 tools/quality/clean_checkout.py --week 8
```

W08 新增 62 项：五槽隔离/三代轮替/临时文件中断/坏校验与坏头恢复/未来版本保护、
旧容器迁移/完整元信息/精确冻结布局，设置持久化/默认与新键冲突/重置、
真实场景保存与分帧载入、载入前未存提示/退出取消/确认期间不自动决策、
60s 空闲边界/相机与输入重置计时/预览互斥/五槽已满保护、DOF 开关、
草木与晾布减少动态/新材质继承、150% 常驻反馈、缓存复用与八轮取消。
每次保存/载入的场景用例使用隔离 QA 目录；`qa_mode` 禁止读写用户偏好。
独立 write/read 进程验证五份作品的标题、PNG 缩略图、镜头、氛围、精确高度和重绑设置。

实机脚本串行采集 21 张核心截图、一张存档种子图、六张风效图、四组 10s / 1080p 采样和 180 帧环绕录像；
风效差分固定水面时间，分别比较全部 SCN-01 草木/晾布的正常、零风、本机减少动态。
FFmpeg 8.1 仅转码审核录像，不进入游戏运行依赖。GPU 计时若为 null/0 样本必须保留此事实。
本周测试不替代 W09 满容量 60s / 最低配置和 W10 长时间混合编辑；Windows 真机与远程 CI 独立记录。

Blender 源审计：`audit_sources.py` 重新打开累计源文件与九张材质图，
`audit_week_eight.py` 对当前 24 项预算模型（含三个 LOD1）额外检查法线、UV、正缩放、导出哈希和图集扩色。
审计不写回 `.blend`，本周模型生产数记为零；UI-06 模板缩略图仍在 W09。


## W09 专项结果与复现

[完整报告](weekly/week_09/README.md) · [测试契约/AC01–08映射](weekly/week_09/TEST_PLAN.md)。
新增34项，累计446项/10509断言；实际1201.536秒、50提交/50撤销/50重做通过。
摄影使用独立渲染视口、两尺寸PNG解码、失败重试与编辑状态恢复；100/150%入口/摄影原生截图复核。
性能目标单独报告：满容量局部205.478ms、半密度152.608ms，150ms目标仍未通过；不将“采集成功”当“目标全过”。
QA自动保存隔离，正式存档前后哈希不变；Windows真机、最低配置、物理手感与远程CI仍待对应验证。


## W10 声音与组合冻结候选

当前累计命令：`python3 tools/quality/run_checks.py --week 10 --negative-control`，包含 W01–10、ART-01、11组write/read跨进程探针和真实失败注入。
W10 新增30项/2755断言，累计521项/15512断言；每周套件最小数、跳过、引擎错误和泄漏均为门禁。
原生声音使用CoreAudio总线PCM捕获（无麦克风权限），照片使用真实渲染器和PNG解码；物理听感与Windows真机单列。
[W10测试契约](weekly/week_10/TEST_PLAN.md) · [W10交付](weekly/week_10/README.md)。
150ms局部提交与首次启动5秒目标未达标时，只交付冻结候选，不能因用例全绿宣布M4/M5完成。


## UI / Meadow 01

当前门禁 `python3 tools/quality/ui_meadow_checks.py` 包含W01–10、ART和新工具栏/草层/柔焦，共544项/15794断言；新增23项/282断言。原生 `ui_meadow_native_checks.py` 检查真实1080p截图、草动画/减少动态、柔焦差分、150%滑杆、摄影解码及0/45/100%与满容量的四组60秒预算。
保存与摄影沿用原路径/格式；草密度与柔焦为本机偏好，不进入源或历史。关草期间编辑后再启用、过期草任务丢弃和提交互斥均有回归。详情见 [本轮交付](weekly/ui_meadow_01/README.md)。

## W11 当前门禁（2026-10-22）

`python3 tools/quality/week_eleven_checks.py` 串行包含 W01–W10、ART、UI/Meadow、负控制及 W11 卡片反馈/鼠标取消/池岸缓存回归；六项 Python 试玩汇总器测试与真实0/10记录独立输出。原生：`python3 tools/quality/week_eleven_native_checks.py`；干净检出及导出均使用 `--week 11`。详见 [W11测试契约](weekly/week_11/TEST_PLAN.md)。真实试玩、性能和平台门槛独立于自动化通过状态。

## UX-02 当前门禁（2026-10-22）

默认场景 `app/simple_root.tscn`，累计入口 `python3 tools/quality/simple_checks.py`；追加直接编辑/复制/取消/桥阶/指向墙面与UI回归。原生 `python3 tools/quality/simple_native_checks.py` 走真实Godot输入分派、摄影PNG解码及有选中手柄的60秒满容量场景。提交后空缓存与导出使用 `--week 11 --simple`。旧周场景、553项历史测试、六项试玩数据校验和负控制保留，完整契约见 [UX-02测试计划](weekly/ux_02/TEST_PLAN.md)。


UX-03悬停编辑为当前默认版本：`python3 tools/quality/hover_checks.py`，原生 `python3 tools/quality/hover_native_checks.py`；空缓存/导出使用 `--week 11 --hover`。完整契约和证据在 `docs/weekly/ux_03/`；旧UX-02工具门禁保留历史场景。

## W12 内部交付

累计入口 `python3 tools/quality/week_twelve_checks.py`；干净源码测试与实际重导出 `python3 tools/quality/clean_checkout.py --week 12 --export`。随后串行执行原生、资产、打包、放行检查，详见 [W12测试契约](weekly/week_12/TEST_PLAN.md)。功能通过不代表正式 M5 放行；无真实 Windows、最低配置、首次玩家或 M4 证据时，`week_twelve_release.py --require-release` 必须退出2。

本机W12记录：CoreAudio混音时钟不推进的最小复现及失败日志保留；最终clean_checkout与native命令使用显式 `--silent-audio`。该参数只给测试进程选择Dummy，不修改包的默认驱动，native_audio_output保持未通过。不能以此替代真实音频验收。

## PERF-01 性能修复

累计命令 `python3 tools/quality/perf_checks.py`；空缓存复验 `python3 tools/quality/clean_checkout.py --week 12 --perf`；原生串行 `python3 tools/quality/perf_native_checks.py --silent-audio`。新增12项草缓存、空间索引、池岸边界和分位数回归。

提交p95修正为nearest-rank，保留原始20笔、最大值和旧upper统计；不能把统计定义修正当作性能收益。原先首绘前自动提交的60秒样本继续保留，另做首个可见画面后提交的独立诊断，不用后者替代旧样本。详见 [PERF-01测试契约](weekly/perf_01/TEST_PLAN.md)。Dummy不代替真实音频、Windows或最低配置验证。

## PERF-02 当前累计门禁

`python3 tools/quality/perf_followup_checks.py` 保留此前全部回归、负控及每周重启，新增33项Godot精确等价/发布/取消/密度/风材质/退出音频引用回归与5项Python测量协议负控。
提交后以 `python3 tools/quality/clean_checkout.py --week 12 --perf-followup` 从Git archive空缓存复验；Python报告也随空缓存证据复制。
原生串行运行 `python3 tools/quality/perf_native_checks.py --followup --silent-audio` 与 `python3 tools/quality/perf_visible_checks.py --silent-audio`，保留原先20笔/8笔60秒协议与首笔，新增首绘后真实鼠标屋顶拖拽。
输入→发布、渲染完成、草稳定分开记录；不能用渲染完成冒充物理显示时延，也不能用新协议替代旧门槛。当前CI指向本门禁，远端尚未运行。
完整规范与证据见 [PERF-02测试契约](weekly/perf_02/TEST_PLAN.md)。
