# Painterly Grass · 山谷参考与G3视觉差距诊断

2026-10-25。用户反馈：当前草不如原草，像一片片贴图，与提供的Valley效果图差距过大；进一步提供对应`.blend`，明确即使不用EEVEE，场景草地的感觉也不应有如此差距。**V2/V3记录为需调整，暂停向G4推进，先修复局部视觉样板。** G3功能正确性收据仍有效，不作为美术通过证明。

## 已核实的差别

只读打开用户提供的`Valley_of_the_North_Demo_3.3.blend`，关闭脚本执行、未保存源件，前后SHA256相同。地形`Plane_low_res`有四个启用渲染的散布层，全部使用`01_Natural_Scatter_Wind`：

| 原场景层 | 实际绑定对象 | 基础三角数，不含修改器结果 |
| --- | --- | --- |
| Blades Grass | Basic_Grass_13 | 24 |
| Detail Puffs | Detailed_Wave_Grass_06 | 572，另有Subdivision |
| Puffs2 | Basic_Grass_04 | 28 |
| Floor Grass | Basic_Grass_Floor_10 | 8 |

当前G3使用的是主库另选的`Basic_Grass_Card_01`、`Basic_Grass_Card_03`和`Basic_Grass_Floor_04`，每种8三角。没有采用上述四层对象组合，也没有复现原场景各层的缩放、密度、方向和覆盖遮罩；本轮未求值完整Geometry Nodes，不能把原场景修改器输入数值当作已验证的实际实例密度。

当前散布在同一候选网格上用`kind=int(phase*3)`互斥选择三类，再按默认45%设置取每组排序前缀；地被约占候选种类的三分之一，并因同一个phase驱动缩放而偏大。它不是原场景底层地被、竖向草叶、蓬松草团与细节的分层覆盖。成片草地因此变成可逐片数出的点状植被，裸地和卡片外轮廓显眼。具体观感影响是结合用户反馈与G3截图的诊断，不把未测试的参数调整宣称有效。

原`Eevee Grass C`材质含`CGM UV LIST`、`CGM Alpha Fade`、`CGM Eevee Grass Shader`，主草还含`CGC Paint Stroke`、环境遮蔽与全局雾。Alpha Fade明确使用Layer Weight/Facing参与透明混合；Grass Shader含Diffuse/Translucent混合、各向异性高光、渐变与随机色。原文件在当前Blender中转换为DITHERED，场景记录4096采样，不能与实时Godot截图视为同条件渲染。

当前Godot材质只重建遮罩、根梢色、有限随机色、云影和弱背光；采用固定0.18 Alpha Scissor，未实现视角相关的卡片边缘淡出，法线统一向上，也没有保留原Paint Stroke/AO/受光组合。连续灰度遮罩在裁切后成为明确的轮廓；与宽平卡、稀疏覆盖相叠加，会放大片状感。这个差别可从当前shader和原节点图直接核对，不应归因于“Godot不能使用EEVEE”后停止分析。

## 结论和下一步

主因是这次选型、分层散布和材质重建过度简化，尚无容量测试证明必须把所有模型压到8三角。原草虽更简单，其细叶几何和既有散布是一起调过的；换成宽卡后继续沿用网格候选、互斥草种与45%前缀，并不保证同等视觉覆盖。

应先回到8×8m视觉样板，按上述四层源对象提取实际形态，保留草团层次、方向、地被融合和边缘淡化；在相近机位下对照原demo，分别检验几何/分布和材质，再做俯视及1.65m近景。先达成连续草地、少露卡片和自然尺度，再优化面数、LOD和透明成本。是否需要昂贵细节全铺、Mac性能余量多少，均留给样板与后续测量，不提前承诺。

[原场景对象/材质节点只读记录](../weekly/week_14/evidence/painterly_grass/visual_review/valley.json) · [四层实际绑定记录](../weekly/week_14/evidence/painterly_grass/visual_review/valley_layers.json) · [源件哈希验证](../weekly/week_14/evidence/painterly_grass/visual_review/verification.json)。本轮只诊断和记录视觉反馈，未修改游戏渲染或Blender源件。
