> 当前为0.3.0本机验证候选：设置/摄影/音频、渲染优化、保存恢复与双平台测试包已整理。见[最终交付与边界](docs/completion/FINAL_REPORT.md)、[可转交测试步骤](docs/completion/TEST_HANDOFF.md)。M1/8GB、Windows实机及真人试玩尚未执行。

# 风屿手记 / Breezely Isles

一个可以体验的治愈海岛建造版本：画出土地，摆小屋和花园，看居民走路、喝茶与看海，最后拍一张自己的岛屿照片。

## 开始体验

需要 **Godot 4.7 stable**。macOS 可双击本目录的 `play.command`，或在终端执行：

```sh
godot --headless --path . --editor --import  # 首次克隆时先生成导入缓存
godot --path .
```

也可在 Godot 项目管理器导入 `project.godot`，按 F5。欢迎页的“新建海湾（无建筑）”用于从头建岛；“空白海面”可以从零画地。也可参观月牙湾、花园池畔和灯塔岩岬，或继续存档。参观月牙湾带四间小屋与公共设施，方便观察生活。无需编辑器的macOS/Windows测试ZIP在本地builds目录，使用说明见docs/completion/TEST_HANDOFF.md。

建议先做这三件事：

1. 参观月牙湾，在“花草与摆件”选择花圃，在小屋外围画三格；观察花园外观，也可在“整理”中锁定或配色。
2. 沿小路摆新屋、茶屋、温室或长椅；门前接上小路后，居民会到达并活动。木桥跨 2–6 格水，码头须通向外海。
3. 点击“日落”观察灯塔，再点击“拍照”。F12 保存新照片，Esc 返回建造；“存档”可打开照片文件夹。

## 操作

| 操作 | 输入 |
| --- | --- |
| 绘制 / 放置 | 左键拖动 / 点击；抬手提交一笔 |
| 取消 | 右键 / Esc |
| 平移与缩放 | WASD / 滚轮 |
| 相机旋转 / 物件旋转 | Q、E / R |
| 笔刷半径 / 桥码头长度 | [、] / −、+ |
| 撤销 / 重做 | Ctrl 或 Cmd + Z / 加 Shift |
| 暂停 / 手记面板 | Space / Tab |
| 拍照模式 / 保存照片 | P / F12 |
| 移动物件 | 整理 → 移动；先点物件，再点新位置 |

工具全部可用，没有货币或维护压力。已有物件的基础、入口、桥下水域和码头泊位受保护；先移动或移除物件再修改。

存档面板包含三个命名手动槽和三份自动备份；设置面板可调四类音量、声音/动画、75–150%界面缩放、全键盘重绑、画质与照片分辨率。自动存档每60秒写入一次，保存发生在完整编辑提交后，并滚动保留三份备份。照片与存档写到 Godot 的用户数据目录，不写进项目源代码。

## 参考与开发

- [当前进度与已知限制](docs/STATUS.md)
- [基础美术交付](docs/BASIC_ART.md)
- [I1美术基础与渲染对照](docs/art_i1/I1_REPORT.md) · [最新交付与外部验证](docs/DEVELOPMENT_PLAN.md#118-剩余任务r1r4与可转交交付2026-10-30)
- [PRD](docs/PRD.md) · [开发计划](docs/DEVELOPMENT_PLAN.md)
- [昼景](snapshots/playable_day.png) · [日落](snapshots/playable_sunset.png) · [纯场景](snapshots/playable_photo.png)

基础美术源代码在 `game/art/art_kit.gd`，可执行以下命令重新导出15个GLB：

```sh
godot --headless --path . --script game/art/export_models.gd
```

建筑与居民使用 `game/art/models/` 的GLB，地形、花草、基础设施与环境动物由程序生成。音频为原创合成资源，补全源程序在 `game/audio/make_completion_audio.py`。Noto中文字体随包提供，Poly Haven材质与生成贴图的来源、许可和哈希见 `THIRD_PARTY_NOTICES.md` 及docs/completion；没有引用第三方模型或音效。

规则与数据测试位于 `tests/test_*.gd`，例如：

```sh
godot --headless --path . --script tests/test_playable.gd
godot --path . --script tests/test_app.gd
```

这是可转交验证的候选版本。目标硬件、Windows实际运行、5–8人试玩和G1人工视觉接受仍须测试者执行；逐项证据与边界见docs/completion/AC_TRACEABILITY.md。POST天气、相框等只提供源件，完整功能属后续范围。
