# 灰桥前哨

Godot 4.7 高差战棋原型。用 Godot 导入本目录的 `project.godot`，按 F6/F5 启动，或执行：

```sh
godot --path .
```

启动后由标题和规则说明进入固定3v3战斗。左键选择候选，Enter 或按钮确认；右键取消；Q/E 旋转，滚轮缩放，R 复位，Esc 暂停。移动和能力可以任意先后，每次激活各一次，最后点击结束行动。治疗仅医师可用，医师可以选择自己。

按功能组织代码：`features/battle/rules` 为规则，`features/battle/presentation` 为三维画面与原型交互。文档与概念图在 [docs](docs/README.md)。

检查：

```sh
godot --headless --path . --script tests/test_rules.gd
godot --headless --path . --script tests/test_planner.gd
godot --headless --path . --script tests/test_lifecycle.gd
godot --headless --path . --script tests/test_integration.gd
godot --path . --script tests/test_viewport.gd
```

当前是可运行灰盒，尚未完成 P0 正式交付。进度、实机截图和已知限制见 [开发进度](docs/development_status.md)。
