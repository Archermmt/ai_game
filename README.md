# 风栖小筑 · Godot MVP

第三周可运行样板：矩形 / 圆形小屋可选中并预览修改尺寸、檐高；支持批量删除、门窗待附着恢复、可撤销的恢复初始布局。
场景接入三树及 LOD、2K 共享植被图集、浅岸静水与石径笔刷初版，保留地形 / 圆池 / 灰模编辑及 Mac 手势。
开发进度见 [STATUS.md](STATUS.md)，验收见 [W03 报告](docs/weekly/week_03/README.md)。
跨 W04 的曲线石径、灌草岩石精修、支撑收边与风场整合继续按计划；当前仍非完整 MVP。

## 运行

固定 Godot **4.7.2 Standard**；版本与插件见 [toolchain.lock.json](toolchain.lock.json)。
首次检出（Python 3.12+、网络可用）：

```bash
python3 tools/quality/bootstrap.py
python3 tools/quality/run_checks.py --week 3 --negative-control
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
存档位置为 Godot `user://week_03/forest.wgs`，包含校验及一个备份，不是完整五存档产品界面。

## 测试与导出

```bash
# 自动化回归、格式、lint、资源契约、跨进程重启与失败注入
python3 tools/quality/run_checks.py --week 3 --negative-control
# 有桌面 GPU 的机器：真实风效图像比较、日暮色截图及两渲染器采样
python3 tools/quality/week_three_render_checks.py
# 本机 macOS：取匹配的桌面模板、注册、导出并实际启动 macOS 包
python3 tools/quality/fetch_desktop_runtime.py --templates-only
python3 tools/quality/install_desktop_templates.py
python3 tools/quality/export_smoke.py --week 3
# 提交后，从无导入缓存的 Git 归档复测
python3 tools/quality/clean_checkout.py --week 3
```

导入、导出以及质量检查按顺序运行，避免两个编辑器进程同时修改同一 `.godot/`。
自动报告输出到 `reports/`；试玩包位于 `builds/week_03/windows/` 和 `builds/week_03/macos/`。
macOS 包是本地未公证开发包。Windows EXE 导出成功仍需 Windows 设备完成可见交互验证。
CI 已配置 Ubuntu / Windows 自动回归，尚未推送远程触发。
每周新增功能必须补测试并保留既有回归，见 [测试约定](docs/TESTING.md)。

## 模块与资源

- `app/`：试玩组合根；`core/`：源数据、放置约束和事务。
- `features/`：建筑网格、轨道相机、存档与风着色器；`ui/`：操作面板与建筑属性 / 恢复面板。
- `tests/week_01/`–`week_03/`：累计 GUT 回归和独立进程探针；`tools/quality/`：可复现质量命令。
- `art_source/week_01/`–`week_03/`：模型、纹理与材质库源文件；`assets/`：GLB、贴图和导入配置。
- `docs/`：已批准 PRD、开发计划、每周证据与许可。

Blender 5.1.2 为唯一主模型源，三种门与树 / 布 / 长凳样板，以及 W02 窗 / 树初稿 / 笔触纹理可分别重建：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_one_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_two_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_three_assets.py -- --root "$PWD"
```

Windows / Linux 改用当地 Blender 路径。Three.js 暂未引入；GUT 9.7.1 已随源码保存。
更多工具选择、数据契约与未完成部分见 W01 报告；第三方许可见 [THIRD_PARTY.md](THIRD_PARTY.md)。

修改源资产后还需在 Blender 中重新打开检查（报告目录先由质量命令建立）：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/reports/week_03_source_audit.json"
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

圆池、灰模物件和全场重建是 W02 风险样板；完整曲线池岸/路径工具、局部依赖图和预算化提交不是本周完成项。
仅用于验收的演示：`python3 tools/quality/run_game.py -- --contact-demo --low-angle`，
或 `--road-demo` 查看单笔路径→门的窄范围契约样板。该演示不代表完整路径编辑已开放。


## W03 操作

- 右侧列表选小屋，Cmd/Ctrl 多选；调整宽度、檐高、进深后点“提交尺寸”。圆屋进深始终等于直径。Esc 取消预览。
- “删除所选小屋”一次记录一条历史；手放门窗保留在“待重新附着”列表。选列表中的门窗与目标小屋，再点重新附着；冲突时保留原态。
- “恢复初始布局”可撤销，不清空历史；读取存档会开始新的历史会话。
- “画石径”在草地拖动，路宽 0.5–3m；坡面投影、交汇去重、建筑内隐藏和水域避让已接入。曲线控制点编辑、联动生门继续 W04。
- 自然树实例可复用“选择灰模 / 移动”等入口编辑，复制保留树种；正式分类种树笔刷仍是 W06。
- 右上角可收起小屋面板。参数极值检查场景可用 Godot 打开 `app/building_parameter_gallery.tscn`，或运行：

```bash
.tools/godot/Godot.app/Contents/MacOS/Godot --path . res://app/building_parameter_gallery.tscn
```

每周包分目录保存，旧存档未自动迁移到 W03 槽；数据结构仍兼容 W01/W02 源数据。当前 50 条历史、每份源快照最多 1MiB JSON，
超限整笔拒绝。历史仅保存源参数，生成网格不进入历史或存档。详细内存策略与性能限制见 W03 报告。
