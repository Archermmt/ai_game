# 风屿手记 / Breezely Isles

一个可以体验的治愈海岛建造版本：画出土地，摆小屋和花园，看居民走路、喝茶与看海，最后拍一张自己的岛屿照片。

## 开始体验

需要 **Godot 4.7 stable**。macOS 可双击本目录的 `play.command`，或在终端执行：

```sh
godot --headless --path . --editor --import  # 首次克隆时先生成导入缓存
godot --path .
```

按 F5 或打开 `play.command`，在欢迎页选择 **走进暖树湾**。红陶屋顶、毛地黄和树荫下的庭院都在可编辑地图上。家门前的小路连着码头，日落、摄影、居民活动、撤销和读档仍使用同一个世界。

1. 打开“建造”，选温室，沿小屋右侧空出的草地挪动画笔。预览显示“1 间邻屋会换外观”时落笔。留意小屋的粉色条纹篷、窗下的花箱和院边草色。
2. 撤销一次，屋檐和庭院会一起复原。也可以先用“整理 → 定形”点击小屋，再试着放温室。
3. 切换日落或按 P 拍照。Q/E 转动镜头，滚轮拉近查看窗框、碎石路和睡莲，拉远可继续画岛。

“新建海湾（无建筑）”可从头建岛，“其他海湾”中有月牙湾、花园池畔、灯塔岩岬和空白海面。“继续上次的岛”会读取已有存档。新版 Mac 体验包为本地 `builds/BreezelyIsles-Warmtree-macOS.zip`。[放置温室的实机演示](snapshots/healing_cove/placing_greenhouse.mp4)。新版截图和验证见 [开发进度](docs/STATUS.md)。此前的 0.3.0 安装包和性能记录对应上一个版本。

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
