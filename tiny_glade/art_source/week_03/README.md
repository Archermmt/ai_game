# W03 原创自然资源源件

Godot 4.7.2 / Blender 5.1.2；无新增插件。原始源文件留在本目录，Godot 仅导入 assets 中的 GLB/PNG。

- MAT-03：2048² RGBA 图集。叶/树皮/草/花各占一象限；UV 区见 atlas_manifest.json。
- 分层：atlas_layers/base.png、brush.png、alpha.png 可独立绘制；layers.npz 保存合成前的浮点数组。
  合成公式及 Blender 自下而上的像素坐标约定见清单；brush.png 的中性色为 0.5，合成 RGB 时先减 0.5。最终 PNG 和带图像节点的 vegetation_atlas.blend 同步保留。
- NAT-01/02/03：阔叶、针叶、果树各一份 LOD0 与一份简化 LOD1 的独立 .blend/GLB。
  根/树干风权重为 0，叶和果实 COLOR.R 为主风权重、G 为次风权重，B 标识果实；材质覆盖由 Godot 包装完成。
  树冠主体使用不透明叶色区域，透明只用于共享叶/草/花裁切区；透明边缘 RGB 已保留扩色。
- NAT-04/05/06/08/09 是 T023 跨周初稿：蕨、野花、矮灌木、苔石、扁石。
  需在 W04 完成轮廓精修、对应 UV 区和岩石材质接入，当前不在试玩场景冒充正式成品。

Blender 生成命令：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_three_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/reports/week_03_source_audit.json"
```

生成器是可重建的原创形体与色彩来源，非外部模型或照片贴图。手绘笔触精修和最终整景仍按后续美术排期；
不要将程序化初版等同于最终人工美术签核。树身与树冠保持同一图集，LOD 以 34m 可见范围切换，
相位取稳定对象 ID；后续 T048 再考虑大批量实例包装，不在 W03 宣称 MultiMesh 压力放行。
