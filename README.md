# 风栖小筑 · Godot MVP

第四周可运行样板：可编辑曲线石径与路径生门，三门两窗手放 / 移动 / 锁定，坡地升降 / 平滑 / 恢复；
接入五种灌草岩石、长凳、信箱与统一风场，日暮光照 / 窗光平滑过渡。保留尺寸编辑、历史恢复与 Mac 手势。
进度见 [STATUS.md](STATUS.md)，验证见 [W04 报告](docs/weekly/week_04/README.md)。
围栏转角 / 闭合、盆栽 / 晾衣架成品和自由池岸继续 W05；当前仍非完整 MVP。

## 运行

固定 Godot **4.7.2 Standard**；版本与插件见 [toolchain.lock.json](toolchain.lock.json)。
首次检出（Python 3.12+、网络可用）：

```bash
python3 tools/quality/bootstrap.py
python3 tools/quality/run_checks.py --week 4 --negative-control
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
| 存档 / 读档 | Ctrl/Cmd+S / Ctrl/Cmd+O；或按钮 |
| 日暮色 / 减少动态 | 左侧按钮 |

建筑宽深 3–12m、高 2.4–7.2m；拖建时默认高 3m，右侧属性面板可连续改尺寸与檐高后提交；建筑旋转仅支持 0°。
重叠放置被拒绝，相切 / 同朝向侧贴可通过数据检查；接触墙消隐与端部封边已有风险实现；正式局部屋檐与木石收边继续后续任务。
存档位置为 Godot `user://week_04/forest.wgs`，包含校验及一个备份，不是完整五存档产品界面。

## 测试与导出

```bash
# 自动化回归、格式、lint、资源契约、跨进程重启与失败注入
python3 tools/quality/run_checks.py --week 4 --negative-control
# 有桌面 GPU 的机器：真实风效、日暮/资源四向与可见编辑采样
python3 tools/quality/week_four_render_checks.py
# 本机 macOS：取匹配的桌面模板、注册、导出并实际启动 macOS 包
python3 tools/quality/fetch_desktop_runtime.py --templates-only
python3 tools/quality/install_desktop_templates.py
python3 tools/quality/export_smoke.py --week 4
# 提交后，从无导入缓存的 Git 归档复测
python3 tools/quality/clean_checkout.py --week 4
```

导入、导出以及质量检查按顺序运行，避免两个编辑器进程同时修改同一 `.godot/`。
自动报告输出到 `reports/`；试玩包位于 `builds/week_04/windows/` 和 `builds/week_04/macos/`。
macOS 包是本地未公证开发包。Windows EXE 导出成功仍需 Windows 设备完成可见交互验证。
CI 已配置 Ubuntu / Windows 自动回归，尚未推送远程触发。
每周新增功能必须补测试并保留既有回归，见 [测试约定](docs/TESTING.md)。

## 模块与资源

- `app/`：试玩组合根；`core/`：源数据、放置约束和事务。
- `features/`：建筑网格、轨道相机、存档与风着色器；`ui/`：操作面板与建筑属性 / 恢复面板。
- `tests/week_01/`–`week_04/`：累计 GUT 回归和独立进程探针；`tools/quality/`：可复现质量命令。
- `art_source/week_01/`–`week_04/`：模型、纹理与材质库源文件；`assets/`：GLB、贴图和导入配置。
- `docs/`：已批准 PRD、开发计划、每周证据与许可。

Blender 5.1.2 为唯一主模型源，三种门与树 / 布 / 长凳样板，以及 W02 窗 / 树初稿 / 笔触纹理可分别重建：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_one_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_two_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_three_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_four_assets.py -- --root "$PWD"
```

Windows / Linux 改用当地 Blender 路径。Three.js 暂未引入；GUT 9.7.1 已随源码保存。
更多工具选择、数据契约与未完成部分见 W01 报告；第三方许可见 [THIRD_PARTY.md](THIRD_PARTY.md)。

修改源资产后还需在 Blender 中重新打开检查（报告目录先由质量命令建立）：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/reports/week_04_source_audit.json"
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

W02 圆池/灰模样板保留作回归；当前已接通 W04 曲线路径。自由池岸、全局依赖图与预算化提交继续后续排期。
仅用于验收的演示：`python3 tools/quality/run_game.py -- --contact-demo --low-angle`，
或 `--road-demo` 查看单笔路径→门的窄范围契约样板。该演示不代表完整路径编辑已开放。


## W03 操作

- 右侧列表选小屋，Cmd/Ctrl 多选；调整宽度、檐高、进深后点“提交尺寸”。圆屋进深始终等于直径。Esc 取消预览。
- “删除所选小屋”一次记录一条历史；手放门窗保留在“待重新附着”列表。选列表中的门窗与目标小屋，再点重新附着；冲突时保留原态。
- “恢复初始布局”可撤销，不清空历史；读取存档会开始新的历史会话。
- “画石径”在草地拖动，路宽 0.5–3m；坡面投影、交汇去重、建筑内隐藏和水域避让已接入。曲线控制点编辑与联动生门现已接通，见下文 W04 操作。
- 自然树实例可复用“选择灰模 / 移动”等入口编辑，复制保留树种；正式分类种树笔刷仍是 W06。
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
- 自然页可放五自然资源、长凳 / 信箱；盆栽和晾衣架标为初稿。正式分类刷植仍在 W06，保留原灰模刷植用于事务验证。
- 环境页拖动风量 / 风向滑杆，松手提交；日暮切换约 1.2 秒。最多四盏近景局部灯，其余仅发光；当前小光点为功能探针，正式提灯模型是后续任务。
- 围栏为 W04D5 直段开工版本，可拖绘和撤销；转角、闭合与最终端头细节继续 W05。

可见验收场景：在 `run_game.py --` 后添加 `--w04-links-demo`、`--w04-terrain-demo` 或 `--w04-asset-gallery --hide-ui`。
W04 存档有独立目录，读取兼容旧源数据；未自动覆盖旧周包 / 槽。
