# 美术源库使用与许可

本轮覆盖原清单全部117条记录、170份交付源，其中MVP为111条/161份，POST为6条/9份。`source_available`表示源文件可加载和可复用；不等同于原PRD的每条视觉、拼接、动作、交互和平台验收均已通过。

## 文件与再生成

- `docs/art_i6/source_catalog.json`：逐ID、变体、路径、格式、SHA256及阶段索引。
- `game/art/catalog_sources/`：Godot原生PackedScene、Animation、Environment、Material以及场景JSON配方。
- `game/art/animations/motions.tres`：共享具名动作库。角色/动物运行时与源件使用同一库；`motion_library.gd`是可重生成的动作作者源。
- `game/art/models/`：15个GLB交换文件，包含居民和动物真实Skin；运行时由原生控制器驱动。GLB树叶保留静态Alpha Scissor材质，风动在原生shader中。
- `game/ui/vectors/`：24个工具/操作/心愿/状态SVG及3个透明拍照相框；`game/ui/icons/`是引擎模型渲染缩略图。
- `game/art/art_catalog.gd`、`art_extras.gd`、`art_post.gd`、`art_kit.gd`：地形、模块、道具、可选资源的可编辑作者源。

在项目根目录执行：

```sh
godot --headless --editor --path . --import
godot --headless --path . --script game/art/export_models.gd
godot --headless --editor --path . --import
godot --headless --path . --script game/art/export_catalog.gd
godot --headless --path . --script tests/test_catalog.gd
godot --headless --path . --script game/art/check_art_budgets.gd
```

原生场景与JSON配方是本库的主要交付格式，并非为每条记录另做一个GLB。场景配方通过`IslandData.restore(recipe.world)`与`IslandView.rebuild()`接入，保留源格的占地、保存与寻路权威。模块源件不会替换现有建筑规则；衣装源件绑定同名骨架后可重用。轻量原生源件没有伪造额外手工LOD；已导入GLB的自动LOD及shadow_mesh在实例化中保留。

衣装包含黄斗篷、绿背带裤、珊瑚围裙、蓝围巾、蓝毛衣；四套头饰另列PROP_011。挂点使用LeftHandSocket、RightHandSocket、SeatSocket，道具源件含Grip/Ground标记。9骨居民与10骨动物是简化风格骨架，不含足底IK。

## 动态资源

水、草、树叶、烟、灯塔扫光、绘制反馈由`IslandView.environment_clock`统一更新；摄影/暂停/减少动画冻结时钟。POST雨景和涟漪通过`island_clock_materials`接受同一clock。源包提供秋树、雨景、灯串、帆篷、相框、坐姿看海；游戏内天气切换、相框选择等完整产品功能尚未接入。提灯/抱盆动作可供AnimationPlayer使用，不代表新增居民职业或活动规则。

衣装/动作/模块源文件可独立打开，实际画面参见`snapshots/art_i6/catalog/`七张图鉴。图鉴是资源审阅场景，未用其绘制数代替游戏压力结果。

## 来源与许可

- 模型、程序网格、动画、shader、SVG、布局与场景配方为本项目制作，没有直接复制Brushland的模型、贴图、UI或场景。
- 九张外部材质输入来自Poly Haven，CC0。原始文件、许可副本在`game/art/materials/`，官方来源、尺寸、MD5与SHA256在`docs/art_i2/downloads.json`。粗糙度原图保留，当前风格材质以常量粗糙度为主。
- 两张透明植物位图使用内置imagegen生成；原图、模式、提示词见`docs/art_i3/IMAGEGEN.md`与`LEAF_IMAGEGEN.md`。未把生成图或原创模型标为CC0第三方下载包。
- Quaternius、Terrain3D、ProtonScatter等仍是研究候选，没有隐式vendor、下载未取得的免费包或新增插件依赖。工程实际采用自有派生表面和散布实现。
- 字体使用系统字体回退，未打包系统字体文件。

## 验收解释

86份具有显式三角面限制的模型逐件通过预算检查，衣装按各自400/350/250/100/350面限制分别核验。其余材质、UI、环境、动画与配方没有被误记为面数测试对象。所有170份资源均经过存在性、哈希与Godot加载检查；全清单的人工视觉、尺寸/拓扑拼接和复杂姿态接受仍以逐项复核为准。
