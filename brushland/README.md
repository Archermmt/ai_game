# 风屿手记 / Breezely Isles

一个可以体验的治愈海岛建造版本：画出土地，摆小屋和花园，看居民走路、喝茶与看海，最后拍一张自己的岛屿照片。

## 开始体验

需要 **Godot 4.7 stable**。macOS 可双击本目录的 `play.command`，或在终端执行：

```sh
godot --headless --path . --editor --import  # 首次克隆时先生成导入缓存
godot --path .
```

按 F5 或打开 `play.command`，在欢迎页选择 **走进暖树湾**。红陶屋顶、毛地黄和树荫下的庭院都在可编辑地图上。家门前的小路连着码头，日落、摄影、居民活动、撤销和读档仍使用同一个世界。

1. 选“建造 → 小屋”，在原屋右侧紧贴外墙的草地上移动。看到“与 1 栋邻屋合建”后点击，两户会连成一栋共用屋脊的长屋，各自保留门口和住户。
2. 保持小屋工具，再点任一户的屋顶或墙面，该户依次变为阁楼、望楼，再回到原式。茶屋、温室、灯塔也可以用各自的建造工具重塑。从“整理 → 定形”锁定的建筑需要先解锁。
3. 用草地笔把岸边往外画，再用小屋笔在同高陆地上拖出一排地基。松开鼠标同时建成，撤销一次收回整笔。三栋以上连成一组时，居中的住宅或茶屋可长出带三联窗的共用主厅。入口须留空，相隔一格或对角的建筑各自保留屋面。
4. 在场景上按住右键拖动，左右环绕，上下调俯角。触控板双指滑动也能转镜头，捏合可缩放。轻点右键仍是取消。摄影模式沿用这些操作。

“新建海湾（无建筑）”可从头建岛，“其他海湾”中有月牙湾、花园池畔、灯塔岩岬和空白海面。“继续上次的岛”会读取已有存档。新版体验包在本地 `builds/BreezelyIsles-Miniature-macOS.zip` 和 `builds/BreezelyIsles-Miniature-Windows.zip`。[新版微缩场景与建造实录](snapshots/miniature/build_and_grow.mp4) · [开发进度](docs/STATUS.md)

## 操作

| 操作 | 输入 |
| --- | --- |
| 绘制 / 放置 | 左键拖动 / 点击；抬手提交一笔 |
| 取消 | 右键 / Esc |
| 平移与缩放 | WASD / 滚轮 |
| 场景环绕与俯仰 | 右键拖动或触控板双指滑动；Q/E 分步转向 |
| 待放物件旋转 | R |
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
