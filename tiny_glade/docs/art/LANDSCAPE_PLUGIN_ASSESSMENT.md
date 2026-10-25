# Terrain3D 与 ProtonScatter · 地形草地接入评估

日期：2026-10-25（Asia/Shanghai）。状态：已接入独立样板，本机Metal原生与功能回归通过，用户美术验收待体验。

**建议采用这两个插件承担地形显示与植被分布，继续保留项目的数据、编辑事务和存档层。** 用户本轮明确要求合适就使用插件，并要求先对齐美术、随后再测性能；这构成对原MVP“暂不采用Terrain3D/Scatter”技术决策的范围补充。批准PRD不作覆盖，正式庭园尚未宣告迁移完成。

## 两个插件分别解决什么

| 当前问题 | 使用方案 | 仍需项目完成的部分 |
| --- | --- | --- |
| 地面起伏、材质变化与坡面过于单调 | Terrain3D显示真实高度场，使用其地表纹理与坡度混合 | 好看的山坡来自设计和源数据；安装插件不会自动生成自然地貌 |
| 草簇难以成片、多层分布缺少可调整工具 | ProtonScatter使用形状和修改器堆栈生成稳定分布，分别控制四层植物 | 草模型、笔触透明、受光和地面配色仍决定最终观感 |
| 当前草呈重复纸片、覆盖与原demo差距大 | 恢复作者实际四个模型、原始布局和全分辨率遮罩，再与Scatter布局比较 | 分布插件无法单独修复错误资产选择、法线或透明材质 |

Terrain3D是可在运行时通过API访问的分区高度场系统，包含地表绘制和材质混合；本轮使用其现成渲染能力。[官方介绍](https://terrain3d.readthedocs.io/en/stable/docs/introduction.html)。ProtonScatter通过ScatterShape定义区域、修改器生成及调整实例，适合用来制作可反复调整的群落分布。[固定版本说明](https://github.com/HungryProton/scatter/blob/7198cc00078ebde61307578137c3f35223c6e438/README.md)。

## 固定版本与Mac边界

| 组件 | 本轮固定版本 / 来源 | 验证边界 |
| --- | --- | --- |
| Godot | 工程既有4.7.2 Standard，不升级引擎 | 继续使用锁定本地运行时 |
| Terrain3D | 1.0.2，tag `v1.0.2-stable`；commit `0077405b52e353c5e5dc3a094e7ede49833ba6fe`；MIT | 原生GDExtension必须实际加载，不能以GDScript导入成功代替 |
| ProtonScatter | 4.2.0；commit `7198cc00078ebde61307578137c3f35223c6e438`；MIT | 固定源码和逐文件哈希见`features/landscape_lab/proton_scatter.lock.json` |
| Blender | 工程既有5.1.2及内置glTF导出器 | 派生源已重开审计 |

Terrain3D发布页列出Godot4.4–4.7支持范围，但安装文档仍写4.4–4.6及可能的后续版本；因此本项目4.7.2仍以实测为准。[1.0.2发布页](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.2-stable)、[安装说明](https://terrain3d.readthedocs.io/en/stable/docs/installation.html)。

官方平台文档支持macOS，同时仍将Metal标为未支持、未测试，Forward+ Vulkan则明确支持。Mac平台支持不能直接等同于当前Metal路径已经通过；本轮必须保存实际驱动、插件加载和画面结果。若Metal出现实际兼容问题，可验证文档支持的Vulkan路径，不能凭印象声明相容。[平台与渲染器文档](https://terrain3d.readthedocs.io/en/stable/docs/platforms.html)。本轮不以帧率、内存或容量目标裁减草层，性能验收依用户要求后置。

## 已落实的美术样板

独立入口为`app/landscape_lab.tscn`，可打开后F6运行。场景提供Demo原始布局 / ProtonScatter布局切换、Demo机位 / 山谷俯瞰 / 草丛近景、四层单独开关、暂停风、官方参考图与返回草地展示。

| 层 | 作者对象 | 导出三角 | 原demo实例数 |
| --- | --- | --- | --- |
| 细草叶 | `Basic_Grass_13` | 24 | 366 |
| 细节草团 | `Detailed_Wave_Grass_06` | 2,288，含原细分 | 305 |
| 蓬松草团 | `Basic_Grass_04` | 28 | 161 |
| 地被 | `Basic_Grass_Floor_10` | 8 | 2,445 |

合计3,277个原始Geometry Nodes实例。保留原UV、角法线、实例基向量及草根相对地面的偏移；不再用三种8三角资产互斥填充代替四层。覆盖图由原demo的`CGM_Flora_Atlas_C.jpg`灰度RGB提取为4096²连续透明遮罩。地形采自`Plane_low_res`真实表面，为256² RF高度图、64×64m范围，高度约-5.015–4.985m；原地面范围外11,728个采样延续最近边界，外围不是新增作者地貌。地面材质采用工程已有绘制纹理，未宣称原Blender程序材质已完整烘焙移植。

作者布局用作结构参照；Scatter布局使用插件的Create Inside (Random) / Randomize Transforms，再由项目表面适配器贴合Terrain3D的高度与法线。各草层独立种子、尺寸和埋根偏移，允许层间重叠。原始源数据与生成的MultiMesh保持分离。

## 接回正式庭园前的验收

先验收样板中山坡轮廓、草地体积、层次覆盖、笔触边缘和地面融合，再测性能。本机4.7.2/Metal已完成实际地形与植被渲染、三机位对照和功能回归；新增8项测试，累计781项Godot与37项Python通过，正式文件未变。该结果只确认本机路径，不能外推所有Mac或Windows。实拍中草团体积与层次已恢复；透明抖动、地面笔触衔接与局部裸地仍需美术复核，树、岩壁与天空没有复刻原demo。结果和场景往返证据见本周报告；截图和测试数不替代用户接受。

正式迁移须继续使用WorldDocument为权威状态，地形升降/平滑、池岸保护、路径、建筑支撑、拾取、漫步高度和草根必须读同一份表面。编辑通过现有事务准备与发布；撤销重做、旧档读取、保存重建、稳定种子、过期异步结果拒绝和局部刷新均须保留。Terrain3D区域与Scatter输出是可重建视图，不能成为另一套隐式作品数据库。Windows原生库和真实Windows设备仍需独立验收。

## 源件与复现

原下载文件只读，SHA256：`487631daaefc27eec0b02a2457c7eb4d93a78f48c14c0bf891ba1b50d99b3be3`。用户授权本机试用；插件MIT许可与下载素材的分发许可分别记录。派生`.blend`位于忽略目录`art_source/painterly_grass/local/valley/`，GLB、纹理、高度图、布局与参考图位于`assets/painterly_grass/local/valley/`。保留源和导入设置；素材入库/独立分发条款仍待归档，不把本地可用称为Git单独检出可用。

在工程根目录执行：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/art/extract_valley_grass.py -- --root "$PWD" --library '/Users/tongmeng/Desktop/assets/3d/PainterlyGrass/预置场景文件/山谷场景演示/Valleys_of_the_North_Free_Demo/Valley_of_the_North_Demo_3.3.blend'
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/docs/weekly/week_14/evidence/painterly_grass/valley_sources/audit.json" --extra-manifest art_source/art_pass_01/nature/manifest.json --extra-manifest art_source/painterly_grass/manifest.json --extra-manifest art_source/painterly_grass/valley_manifest.json
python3 tools/quality/landscape_lab_checks.py
```

源审计已重开46份旧源、11份植物源、3份G1源和4份Valley派生源，结果见`docs/weekly/week_14/evidence/painterly_grass/valley_sources/audit.json`及`verification.json`。Terrain3D发布ZIP SHA256为`a071850250ec5e596aa54da61c01d75768774eb379ee997584d426a45f4884a2`，Scatter源码归档SHA256为`485295fa4a97cb54bcd20d1b1304ed8a2fc0b28fe3215a07be62d26df9208d5f`。完整运行证据在本周[样板验收记录](../weekly/week_14/LANDSCAPE_PLUGIN_LAB.md)补齐。
