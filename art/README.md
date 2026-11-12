# Godot 美术场景集

用 Godot 4.7 打开本目录的 `project.godot`，首次导入完成后按 F5，默认进入春日铁路道口。数字键 1–5 在五个实景间切换，左右键拖动环绕，滚轮缩放，R 或 Home 恢复参考机位。编辑器中可直接打开下表任意场景按 F6。

| 键 | 场景入口 | 美术手册 |
| --- | --- | --- |
| 1 | [三渲二街道](street/street.tscn) | [制作手册与复盘](docs/street/制作手册与复盘.md) |
| 2 | [治愈风格小岛](examples/island/island.tscn) | [制作手册与复盘](docs/examples/island/制作手册与复盘.md) |
| 3 | [温馨林中小屋](examples/cabin/cabin.tscn) | [制作手册与复盘](docs/examples/cabin/制作手册与复盘.md) |
| 4 | [低多边形沙漠营地](examples/desert/desert.tscn) | [制作手册与复盘](docs/examples/desert/制作手册与复盘.md) |
| 5 | [奇幻熔岩植物](examples/lava/lava.tscn) | [制作手册与复盘](docs/examples/lava/制作手册与复盘.md) |

所有主图均为 1704 × 960 的 Godot Forward+ 实机渲染。Blender 源或可重建的模型源代码随各案例保存。查看 [街景开发计划](docs/street.md)，其余案例的创作计划与美工手册在 `docs/examples/<案例>/`。

从终端运行某个场景可使用 `godot --path . examples/island/island.tscn`。生成证据图时在末尾附加 `-- --capture=res://captures/island/final.png`。可选 `--azimuth=15` 在右转 15° 后取图。指定 `--benchmark=res://captures/island/benchmark.json` 记录静机 30 秒的主循环间隔与真实绘帧，加入 `--bench-motion` 会小幅扫动相机。运行样例本身只需要 Godot；编辑或重建模型时再使用对应手册列出的工具。
