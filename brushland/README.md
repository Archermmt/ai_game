# 风屿手记 / Breezely Isles

一个可以体验的治愈海岛建造版本：画出土地，摆小屋和花园，看居民走路、喝茶与看海，最后拍一张自己的岛屿照片。

## 开始体验

需要 **Godot 4.7 stable**。macOS 可双击本目录的 `play.command`，或在终端执行：

```sh
godot --path .
```

也可在 Godot 项目管理器导入 `project.godot`，按 F5。默认欢迎页可选“走进海湾”“继续上次的岛”或“空白海面”。海湾已布置好四间小屋、茶屋、温室、灯塔、码头与短桥，方便直接观察生活。

建议先做这三件事：

1. 走进海湾，在“花草与摆件”选择花圃，在小屋外围画三格；观察花园外观，也可在“整理”中锁定或配色。
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

存档面板包含三个手动槽、自动存档恢复、声音和减少环境动画开关。自动存档每60秒写入一次，保存发生在完整编辑提交后，并滚动保留三份备份。照片与存档写到 Godot 的用户数据目录，不写进项目源代码。

## 参考与开发

- [当前进度与已知限制](docs/STATUS.md)
- [基础美术交付](docs/BASIC_ART.md)
- [PRD](docs/PRD.md) · [开发计划](docs/DEVELOPMENT_PLAN.md)
- [昼景](snapshots/playable_day.png) · [日落](snapshots/playable_sunset.png) · [纯场景](snapshots/playable_photo.png)

基础美术源代码在 `game/art/art_kit.gd`，可执行以下命令重新导出15个GLB：

```sh
godot --headless --path . --script game/art/export_models.gd
```

建筑与居民使用 `game/art/models/` 的GLB，地形、花草、基础设施与环境动物由程序生成。音频为原创合成试听素材，源程序在 `game/audio/make_audio.py`。没有引用第三方模型或音效。

规则与数据测试位于 `tests/test_*.gd`，例如：

```sh
godot --headless --path . --script tests/test_playable.gd
godot --path . --script tests/test_app.gd
```

这是基础美术体验版，不是已通过全部 PRD 生产与发行验收的版本；目标设备性能、Windows 检查、完整蒙皮动画和音频覆盖仍有后续工作。
