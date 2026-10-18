# 风栖小筑 · Godot MVP

第七周试玩切片：底部工具 Dock、八道具属性卡、十二张原生材质选择卡、可拉伸/转角绿篱，
接入正式开口与木构套件、资源包装与拾取挂点。进度见 [STATUS.md](STATUS.md)，
验证见 [W07 报告](docs/weekly/week_07/README.md)。
默认进入可编辑的林间坡地示范草案；完整场景签核与存档可靠性继续 W08，摄影与混音维持后续排期。

## 运行

固定 Godot **4.7.2 Standard**；版本与插件见 [toolchain.lock.json](toolchain.lock.json)。
首次检出（Python 3.12+、网络可用）：

```bash
python3 tools/quality/bootstrap.py
python3 tools/quality/run_checks.py --week 7 --negative-control
python3 tools/quality/run_game.py
```

本机已准备 `.tools/` 和 `.venv/`，可直接运行后两条命令。也可使用相同版本 Godot 打开
`project.godot` 后按 F6 / F5。系统的 Godot 4.7 不满足本项目补丁版本锁。
可通过 `GODOT_BIN` 指定同版本引擎；下载的引擎、缓存、试玩包和用户存档不进入 Git。

| 操作 | 输入 |
| --- | --- |
| 建房 | 选矩形 / 圆形，左键在草地拖动并释放 |
| 取消预览 | Esc 或“取消” |
| 环视 / 平移 / 缩放 | 右键或 Option（⌥）+左键拖动 / 中键或 Shift+左键 / 滚轮、双指捏合或双指上下滑动 |
| 恢复镜头 | F 或“复位视角” |
| 撤销 / 重做 | Ctrl（macOS 为 Cmd）+Z / Shift+Z；或按钮 |
| 分类植被 | 选择树木 / 植物 / 岩石；调半径和各类密度后选择刷植或擦除；Ctrl/Cmd+滚轮调半径 |
| 属性 | 手放内容可锁定高度；提灯选择开启 / 关闭 / 自动；左侧环境面板可改 UI 比例 |
| 存档 / 读档 | Ctrl/Cmd+S / Ctrl/Cmd+O；或按钮 |
| 日暮色 / 减少动态 | 左侧按钮 |

建筑宽深 3–12m、高 2.4–7.2m；拖建时默认高 3m，右侧属性面板可连续改尺寸与檐高后提交；建筑旋转仅支持 0°。
重叠放置被拒绝，相切 / 同朝向侧贴可通过数据检查；接触墙消隐与端部封边已有风险实现；正式局部屋檐与木石收边继续后续任务。
当前存档位置为 Godot `user://week_07/forest.wgs`，WGLADE02 单容器包含元信息、压缩源数据及一个备份；保持浮点位值与整数类型，兼容旧 WGLADE01。完整五存档界面在后续排期。

## 测试与导出

```bash
# 自动化回归、格式、lint、资源契约、跨进程重启与失败注入
python3 tools/quality/run_checks.py --week 7 --negative-control
# 有桌面 GPU 的机器：真实风效、日暮/资源四向与可见编辑采样
python3 tools/quality/week_seven_render_checks.py
# 本机 macOS：取匹配的桌面模板、注册、导出并实际启动 macOS 包
python3 tools/quality/fetch_desktop_runtime.py --templates-only
python3 tools/quality/install_desktop_templates.py
python3 tools/quality/export_smoke.py --week 7
# 提交后，从无导入缓存的 Git 归档复测
python3 tools/quality/clean_checkout.py --week 7
```

导入、导出以及质量检查按顺序运行，避免两个编辑器进程同时修改同一 `.godot/`。
自动报告输出到 `reports/`；试玩包位于 `builds/week_07/windows/` 和 `builds/week_07/macos/`。
macOS 包是本地未公证开发包。Windows EXE 导出成功仍需 Windows 设备完成可见交互验证。
CI 已配置 Ubuntu / Windows 自动回归，尚未推送远程触发。
每周新增功能必须补测试并保留既有回归，见 [测试约定](docs/TESTING.md)。

## 模块与资源

- `app/`：试玩组合根；`core/`：源数据、放置约束和事务。
- `features/`：建筑网格、轨道相机、存档与风着色器；`ui/`：操作面板与建筑属性 / 恢复面板。
- `tests/week_01/`–`week_07/`：累计 GUT 回归和独立进程探针；`tools/quality/`：可复现质量命令。
- `art_source/week_01/`–`week_07/`：模型、纹理与材质库源文件；`assets/`：GLB、贴图和导入配置。
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

## W02 新操作与边界

- “抬高 / 降低地形”左键涂刷；一笔内多个采样只记一条历史。池底与 0.75m 岸带受保护。
- “画圆池”左键落笔确定中心，拖动半径后释放；再次绘制修改唯一池塘，保留首次水位。“删除池塘”可撤销。
- “放灰模”放立方体；“选择灰模”点击，Ctrl/Cmd+点击多选，再用移动、旋转、有限缩放、复制、删除。
- 选中物件显示红 X / 蓝 Z 手柄；移动模式从手柄拖动可锁轴，从主体拖动在地面平移。
- “灰模刷植 / 擦除刷植”用于验证批量实例事务；擦除保护手放及手动调整的物件。不是正式植被笔刷。
- “新居 / 岁月”切换基础材质。黄昏窗光跟随光线切换。
- 松手后显示“正在完成上一笔”，完成前不接收下一笔编辑，相机仍可操作；Esc 明确取消。
- 超过 3m 基座、池区原坡差 >0.6m、池岸与建筑 / 手放物件冲突都会拒绝整笔。

W02 圆池/灰模样板保留作回归；当前已接通曲线路径与 W05 自由池岸；W06 已接通局部依赖图与分帧准备。
仅用于验收的演示：`python3 tools/quality/run_game.py -- --contact-demo --low-angle`，
或 `--road-demo` 查看单笔路径→门的窄范围契约样板。该演示不代表完整路径编辑已开放。


## W03 操作

- 右侧列表选小屋，Cmd/Ctrl 多选；调整宽度、檐高、进深后点“提交尺寸”。圆屋进深始终等于直径。Esc 取消预览。
- “删除所选小屋”一次记录一条历史；手放门窗保留在“待重新附着”列表。选列表中的门窗与目标小屋，再点重新附着；冲突时保留原态。
- “恢复初始布局”可撤销，不清空历史；读取存档会开始新的历史会话。
- “画石径”在草地拖动，路宽 0.5–3m；坡面投影、交汇去重、建筑内隐藏和水域避让已接入。曲线控制点编辑与联动生门现已接通，见下文 W04 操作。
- 自然树实例可复用“选择灰模 / 移动”等入口编辑，复制保留树种；W06 已接通分类刷植。
- 右上角可收起小屋面板。参数极值检查场景可用 Godot 打开 `app/building_parameter_gallery.tscn`，或运行：

```bash
.tools/godot/Godot.app/Contents/MacOS/Godot --path . res://app/building_parameter_gallery.tscn
```

每周包分目录保存，旧存档未自动迁移到 W03 槽；数据结构仍兼容 W01/W02 源数据。当前 50 条历史、每份源快照最多 1MiB JSON，
超限整笔拒绝。历史仅保存源参数，生成网格不进入历史或存档。详细内存策略与性能限制见 W03 报告。


## W04 操作与边界

- 左侧“编辑 / 自然 / 环境”切页；右侧“小屋 / 石径 / 门窗”切页。各页可滚动。
- 画石径：左键拖绘后松手；在石径列表选择路径，再用“拖控制点”拖动黄色点。路宽 / 平滑曲线设置点“提交”才写入。
- 路端距墙≤0.6m、地面与入口高差≤0.45m 时生成门；相近请求复用一扇门。删最后供门路径时移除未锁自动门。
- 手放门窗：先选小屋，再选三门 / 两窗中的种类，到墙边拖动。门窗列表可选中移动、锁定或删除手工开口；锁定 / 手动移动使自动门转为手工。
  自动门由路径维护；删除自动门应删除供门路径。开口冲突会整笔拒绝，自动门不会挤掉手放窗。
- “平滑 / 恢复地形”保留源坡地与池岸；入口净空带保护。石基贴地、地坪固定，超过 3m 支撑仍整笔拒绝。
- 自然页可放五自然资源、长凳 / 信箱；W04 曾将盆栽和晾衣架标为初稿，W05 已收尾。W06 已接通正式分类刷植，旧灰模工具保留回归。
- 环境页拖动风量 / 风向滑杆，松手提交；日暮切换约 1.2 秒。最多四盏近景局部灯，其余仅发光；W06 已用正式提灯模型代替功能探针。
- W04D5 的直段围栏在 W05 已补齐转角、闭合与端头封边，见下文。

可见验收场景：在 `run_game.py --` 后添加 `--w04-links-demo`、`--w04-terrain-demo` 或 `--w04-asset-gallery --hide-ui`。
W04 存档有独立目录，读取兼容旧源数据；未自动覆盖旧周包 / 槽。


## W05 操作与边界

- 右侧“庭园”：选“绘制 / 重画池岸”，按住左键围绕水域绘一圈，松手闭合；转折点间距约 2m，最窄水域 2m。水位首次确定后固定；不支持自交轮廓。旧圆池和自由轮廓共用单池槽。
- 短桥 / 短阶：拖动两端，松手只保留预览，点击“确认桥 / 阶”才提交；Esc 取消。桥长 1.5–6m、桥头高差≤0.5m；短阶高差 0.15–0.9m、宽 0.8–2m。短阶上端可吸附外墙手工门的水平地坪。
- 改池岸或删池使桥失效时，桥以暖红色保留，列表提示调整桥头；撤销同时恢复岸线与有效状态。选列表项后点“拖动所选结构”，黄色点对应可拖端点/围栏点；支持删除并撤销。
- 左侧“连续围栏”：左键连续拖绘，转折自动留点；回到起点附近闭合。角柱共享、杆端封闭、穿路留开口。
- “自然”可放四种生活道具。将木箱/盆栽/浇水壶拖到已有木箱中心附近可吸附支撑面；移动上层物件会解除支撑引用。删除或移动仍被依赖的底箱会拒绝并保留原态，先移开上层物件。
- 茶具/提灯保留 T038 跨周源初稿，W06 收尾。灰模刷植仍用于数据闭环；正式分类植被笔刷为 W06。
- 演示：`--w05-gallery`、`--w05-stairs`、`--w05-invalid-bridge`，可与 `--hide-ui` / `--view-angle=45` 合用。

W05 历史包存档使用独立 `user://week_05/forest.wgs`；完整精度 JSON 保留采样桥头高度，不覆盖旧周槽。


## W06 操作与边界

“自然”页选择树/植物/岩石类别，各类密度互不影响；半径 0.5–6m，Ctrl/Cmd+滚轮可调整。
选择分类刷植/擦除后拖动，一整笔为一个历史事务；擦除只影响该类自动植被。
自动植被避开入口约 0.5m、路径、水域及桥阶端点；手放内容保留，冲突时整笔拒绝。
单放目录含三树/四灌草/两岩石与八道具；紧凑绿篱当前是灌木复用段，拉伸/转角继续 W07。

选中物件后切“锁高 / 跟随地面”；将茶盘放在长凳或木箱中心可吸附支撑面。
选提灯后点“亮 / 灭 / 随日暮”，发光面独立于最近四盏实时光；“环境”页可调 UI 比例。
演示参数 `--w06-gallery` 和 `--w06-foliage` 可结合 `--hide-ui` / `--view-angle=45`。
正式源片装配、属性卡、色板、拉伸绿篱继续 W07；音频目前交付资源，完整混音按 W10。


## W07 操作

- 底部 16 工具直接进入小屋、路、门窗、地形、池桥阶、围栏、树木、刷植和道具；窄窗口可横向滚动。
- “物件”页从列表或场景选择，改 X/Z、朝向和比例后点“提交属性”；多选按首项计算差量，整笔撤销。
  移动、复制、删除和锁高均有鼠标入口；依赖中的支撑需要先移开上层。提灯可选自动 / 开 / 关。
- “色板”页选择 12 张材质卡，改变整园对应材料；✓ 表示当前选中，修改随作品和历史保存。
- “自然”页选择“拖绘绿篱 / 转角”，拖动后松手提交；选绿篱后可拖控制点或改宽。
  复用灌木而不拉伸叶片 UV；分类擦除能命中自动绿篱任意一段，手动调整后受保护。
- 物件选中显示 X/Z 字母/箭头和选环；错误提示会说明可调整的原因。150% 界面用滚动访问下方内容。
- 当前“记住当前构图”保存源书签；完整摄影、载入构图体验与命名多槽在后续任务完成。

演示：`--w07-hedges`、`--w07-hedge-slope`、`--w07-buildings`、`--w07-contact`、
`--w07-round-close`、`--w07-palette`、`--w07-objects`；可组合 `--hide-ui` / `--view-angle=135`。
[W07 美术重建说明](art_source/week_07/README.md) 包含原生 96px 缩略图生成步骤。
当前 51 实例样例的 20 笔编辑仍有发布/资源创建尖峰，详见周报；W08 T054 继续性能优化。
