# 开发进度

## 第 1 周 — 已交付可运行灰盒

- Godot 4.7 stable，Compatibility 渲染；64×64 数据地图，0–4 高度。
- 正交相机、平移/旋转/缩放，七类地形操作，三档笔刷，取消、一笔提交、50步撤销重做。
- 程序化地形、树木、水面样板；尚非 PRD 正式美术资产。
- 自动检查：地形、撤销重做、边界高度与历史容量。
- [实际运行截图](../snapshots/week_01.png)。
- 已知缺口：圆角岸缘、正式 GLB 素材、目标 M1/Windows 验证尚未完成；不将整个 M0 美术验收标为通过。

运行：`godot --path .`；测试：`godot --headless --path . --script tests/test_world.gd`。
