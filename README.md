# 风栖小筑 · Godot MVP

第一周可运行工程样板：在林间空地拖出矩形 / 圆形小屋，检查真实门窗洞、风动导入和事务存档。
开发进度见 [STATUS.md](STATUS.md)，详细验收见 [W01 报告](docs/weekly/week_01/README.md)。
当前画面是尺度与技术样板，正式手绘材质、地形 / 池塘、完整建筑编辑按后续周次实现。

## 运行

固定 Godot **4.7.2 Standard**；版本与插件见 [toolchain.lock.json](toolchain.lock.json)。
首次检出（Python 3.12+、网络可用）：

```bash
python3 tools/quality/bootstrap.py
python3 tools/quality/run_checks.py --week 1 --negative-control
python3 tools/quality/run_game.py
```

本机已准备 `.tools/` 和 `.venv/`，可直接运行后两条命令。也可使用相同版本 Godot 打开
`project.godot` 后按 F6 / F5。系统的 Godot 4.7 不满足本项目补丁版本锁。
可通过 `GODOT_BIN` 指定同版本引擎；下载的引擎、缓存、试玩包和用户存档不进入 Git。

| 操作 | 输入 |
| --- | --- |
| 建房 | 选矩形 / 圆形，左键在草地拖动并释放 |
| 取消预览 | Esc 或“取消” |
| 环视 / 平移 / 缩放 | 右键拖动 / 中键或 Shift+左键 / 滚轮 |
| 恢复镜头 | F 或“复位视角” |
| 撤销 / 重做 | Ctrl（macOS 为 Cmd）+Z / Shift+Z；或按钮 |
| 存档 / 读档 | Ctrl/Cmd+S / Ctrl/Cmd+O；或按钮 |
| 日暮色 / 减少动态 | 左侧按钮 |

W01 建筑宽深 3–12m、高 2.4–7.2m；当前拖建高度固定，旋转仅支持 0°。
重叠放置被拒绝，相切 / 同朝向侧贴可通过数据检查；接触墙消隐与收边尚在 W02 风险任务中。
存档位置为 Godot `user://week_01/forest.wgs`，包含校验及一个备份，不是完整五存档产品界面。

## 测试与导出

```bash
# 自动化回归、格式、lint、资源契约、跨进程重启与失败注入
python3 tools/quality/run_checks.py --week 1 --negative-control
# 有桌面 GPU 的机器：真实风效图像比较、日暮色截图及两渲染器采样
python3 tools/quality/render_checks.py
# 本机 macOS：取匹配的桌面模板、注册、导出并实际启动 macOS 包
python3 tools/quality/fetch_desktop_runtime.py --templates-only
python3 tools/quality/install_desktop_templates.py
python3 tools/quality/export_smoke.py
```

导入、导出以及质量检查按顺序运行，避免两个编辑器进程同时修改同一 `.godot/`。
自动报告输出到 `reports/`；试玩包位于 `builds/windows/` 和 `builds/macos/`。
macOS 包是本地未公证开发包。Windows EXE 导出成功仍需 Windows 设备完成可见交互验证。
CI 已配置 Ubuntu / Windows 自动回归，尚未推送远程触发。
每周新增功能必须补测试并保留既有回归，见 [测试约定](docs/TESTING.md)。

## 模块与资源

- `app/`：试玩组合根；`core/`：源数据、放置约束和事务。
- `features/`：建筑网格、轨道相机、存档与风着色器；`ui/`：W01 操作面板。
- `tests/week_01/`：GUT 回归和独立进程探针；`tools/quality/`：可复现质量命令。
- `art_source/week_01/`：六份可编辑 Blender 源文件与清单；`assets/`：GLB 和导入配置。
- `docs/`：已批准 PRD、开发计划、每周证据与许可。

Blender 5.1.2 为唯一主模型源，三种门与树 / 布 / 长凳样板可用以下命令重建：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_one_assets.py -- --root "$PWD"
```

Windows / Linux 改用当地 Blender 路径。Three.js 暂未引入；GUT 9.7.1 已随源码保存。
更多工具选择、数据契约与未完成部分见 W01 报告；第三方许可见 [THIRD_PARTY.md](THIRD_PARTY.md)。
