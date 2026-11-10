# 风屿手记 · 制作与许可

游戏代码、动画、SVG 与声音作者源在本项目中制作。两张植物透明贴图由内置imagegen生成，提示词与生成记录保留在源码docs/art_i3。未复制Brushland的资产。

Godot Engine采用MIT许可；发行包licenses/GODOT_LICENSE.txt提供引擎许可，ENGINE_THIRD_PARTY.json提供引擎内置组件的版权和许可全文映射。

Noto Sans CJK SC Regular来自notofonts/noto-cjk官方仓库，采用SIL Open Font License 1.1，字体未经修改；完整许可在game/ui/fonts/OFL.txt及发行包licenses/NOTO_OFL.txt。来源：https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/SimplifiedChinese

九张材质输入来自Poly Haven，采用CC0；保留许可副本game/art/materials/LICENSE-CC0.txt及发行包licenses/POLYHAVEN_CC0.txt。来源、原始哈希在源码docs/art_i2/downloads.json。来源：https://polyhaven.com/license

音频为本项目的确定性合成作品，不含第三方采样；作者源game/audio/make_completion_audio.py。中文字体随包提供，没有复制macOS或Windows系统字体。

Godot模板来源及本地SHA256在源码docs/completion/export_template_sources.json，字体来源及SHA256在font_sources.json。

码头使用 Grab3D 的 Rowboat，原模型与贴图为 CC0 1.0。项目保留木船船身和两支船桨，收拢船桨，调整水线与中座，简化为 4,415 个三角面和一张 512 像素的船体色图。原 GLB 的 SHA-256 为 `1c67afedc7b443d30f00f94610e338e3709c93c5066f102432855f71ffea442e`，可用 `tools/prepare_rowboat.py` 从该版本重建。作者说明模型由 Blender 脚本生成，编写脚本时使用了 AI 辅助。[作品](https://grab3d.com/models/vehicles/rowboat/) · [原模型](https://grab3d.com/dl/rowboat/rowboat.glb) · [作者许可声明](https://grab3d.com/dl/rowboat/LICENSE.txt) · [文件清单](https://grab3d.com/dl/rowboat/manifest.json)


暖树湾的木筋小屋、橡树和毛地黄衍生自用户提供的《治愈风格小岛》附件工程。使用的是工程内生成的 `examples/island/island_model.glb`，来源记录在 `docs/healing_model_sources.json`。原工程没有附开放许可证。几何拆件保留了木筋、错排瓦、枝干和独立的花穗。游戏端增加可换色屋面、花箱、布棚和随风摆动的树冠。用 Python 3 与 NumPy 运行 `python3 tools/build_healing_models.py <参考工程.zip>` 即可重建四件 GLB。
