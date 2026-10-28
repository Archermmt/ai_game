# 插件使用心得与维护手册

更新：2026-10-27。适用工程：风栖小筑；本地验证基线：Godot **4.7.2 Standard / Forward+ / macOS Metal / Apple M4 Pro**。

本文总结当前工程实际采用的插件、接入边界和踩坑，不是通用插件排行榜，也不代表最新上游版本的兼容结论。版本以项目lock文件为准；详细实机证据见[正式地形与草地](weekly/week_14/PRODUCTION_LANDSCAPE.md)、[正式云雪采用](weekly/week_14/WEATHER_ADOPTION.md)。

## 1. 当前插件清单

“目录中有代码”“编辑器已启用”“运行时实际调用”是三件事。目前[project.godot](../project.godot)的编辑器插件只启用了Terrain3D和ProtonScatter；其余按以下方式使用。

| 组件 | 固定版本 / commit | 当前用途与使用方式 | 本项目结论 |
| --- | --- | --- | --- |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | 1.0.2-stable / `0077405` | 编辑器插件与原生GDExtension；正式地形显示、材质和连续雪面 | 成熟的地形显示能力有价值；自然地貌仍来自设计和高度源 |
| [ProtonScatter](https://github.com/HungryProton/scatter) | 4.2.0 / `7198cc0` | 编辑器可用；运行时调用修改器生成四层草的稳定候选 | 负责分布，项目继续负责贴地、避让、分块与渲染 |
| [SunshineClouds2](https://github.com/Bonkahe/SunshineClouds2) | 2.7 + 上游4.7相机修复 / `a73a80b` | 正式相机的CompositorEffect；不启用编辑器Dock | 体积层次明显改善；Metal和多相机必须真实验证 |
| [Blanket](https://github.com/1hue/Blanket) | `7b1166a` | 原计算子集 + 本地4.7/Metal缓冲桥；不启用原编辑器插件/autoload | 有界物件雪壳有效；不能拿这条路径直接覆盖完整大地形 |
| [puchik snow material](https://github.com/puchik/godot-extras/tree/515900a4aee952cdc4487bed98cc69758c899a32/tutorials/snow-shader) | `515900a` | 材质参考与纹理输入复用；不是EditorPlugin | 能改善雪的表面质感，本身不生成厚度 |
| [GUT](https://github.com/bitwes/Gut) | 9.7.1 / `aeb5d4f` | CLI自动回归；当前未启用其编辑器面板 | 适合逻辑、源状态与异步流程；不能替代GPU及美术验收 |

版本与许可入口：[Terrain3D lock](../features/landscape_lab/terrain3d.lock.json)、[Scatter lock](../features/landscape_lab/proton_scatter.lock.json)、[Sunshine lock](../features/weather_plugins/sunshine_clouds.lock.json)、[Blanket lock](../features/weather_plugins/blanket.lock.json)、[puchik lock](../features/weather_plugins/puchik_snow.lock.json)、[GUT/toolchain lock](../toolchain.lock.json)。

PainterlyGrass是外部美术资产，不是Godot插件。它的模型、纹理、Blender源与分发条款必须单独管理，不能因为使用了MIT插件就认为素材也自动获得相同授权。

## 2. 最重要的架构经验

### 插件提供能力，作品源仍由项目管理

当前关系是：

```text
WorldDocument / TerrainField / 编辑事务
    ├─ 高度与材质数据 → Terrain3D派生显示
    ├─ 种子与区域 → Scatter候选 → 项目贴地/避让 → 草分块与MultiMesh
    ├─ 日历/天气/太阳/时钟 → 各相机独立的Sunshine云资源
    └─ 已发布物件网格 → Blanket雪壳缓存
```

不要让插件节点、生成网格或原生区域成为另一份作品数据库。保存的是源参数与稳定身份，显示结果允许丢弃重建；预览、取消、提交、撤销和读档沿用原事务链。这样才能使用插件而不丢掉编辑器已有的可靠性。

目前拨草使用项目的[四点接触状态](../features/landscape/grass_walker_contact.gd)与草shader，脚印使用[Godot内置Decal适配](../features/immersion/snow_footprints.gd)。它们没有再引入第三方交互插件，也不是Scatter或Blanket自动提供的能力。优先复用成熟能力，不等于每个小功能都需要新依赖。

### 先判断缺的是哪一层

| 看到的问题 | 优先检查 | 这次的实际经验 |
| --- | --- | --- |
| 草像纸片、缺少体积 | 模型、层次、透明图、法线与受光 | 换散布工具不能修复错误资产选择；恢复作者四层模型后才接近参考 |
| 地形不自然 | 高度源、坡度、尺度、地貌构图 | Terrain3D负责显示，并不会自动设计山谷 |
| 雪只是变白 | 材质、法线、真实几何分别检查 | puchik负责质感，Blanket负责物件厚度，地面走Terrain3D |
| 主画面正常、照片或倒影异常 | 相机、视口与历史缓冲的归属 | 共享世界不等于可以共享同一个云历史缓存 |

## 3. Terrain3D：保留自己的地形源，复用原生显示

**实际接入。** [ProductionTerrainRenderer](../features/landscape/production_terrain.gd)把当前TerrainField转换为高度与颜色数据，沿用[LandscapeTerrainAdapter](../features/landscape_lab/terrain_adapter.gd)的原生显示能力。正式场景使用0.25m对齐映射；样板的山谷高度图不会覆盖玩家已有地貌。原生新图准备好之前，保留事务准备的后备地形显示，只发布最新版本。

**踩坑与处理：**

- GDExtension必须实际加载。只看GDScript导入成功，无法证明二进制、驱动或地形显示正确。
- region size等接口有初始化时机要求；当前在节点进入World3D后设置，不能只照抄属性赋值顺序。
- 动态纹理没有可重载的资源路径，当前设置`free_editor_textures = false`，避免把仍需要的纹理释放掉。
- 控制图是存放在RF内存里的uint32位编码。不能用普通浮点颜色值代替控制位；适配器使用`encode_u32`写入。
- 固定版本的编辑器Dock退出曾泄漏，保留了[最小释放补丁](../features/landscape_lab/patches/terrain3d_1_0_2_editor_dock_cleanup.patch)，原始与修改后哈希都在lock中。
- 安装原生地形不代表拾取、建筑支撑、漫步碰撞都应改成插件数据。当前仍共享TerrainField，避免显示和编辑拥有不同的地面定义。

**雪面边界。** 当前地面接入puchik材质输入，并在Terrain3D顶点阶段按雪盖产生最多14cm显示位移。作者高度数据保持原值；相机视高和脚印投射补偿这个差值。以后改变雪厚度，必须同步检查这些消费者，不能只调画面。

上游平台说明与本机实测分开看：固定版的选型记录中，Metal并未获得上游明确支持；本项目有本机Metal运行证据，不能外推为所有Mac或Windows均通过。参见[选型记录](art/LANDSCAPE_PLUGIN_ASSESSMENT.md)。

## 4. ProtonScatter：只接需要的生成能力

**实际接入。** [LandscapeScatterAdapter](../features/landscape_lab/scatter_adapter.gd)调用原版Create Inside (Random)、Randomize Transforms修改器；[正式草渲染器](../features/landscape/production_grass_renderer.gd)按种子准备候选池，再通过项目worker处理当前高度、保护区、分块与版本发布。没有依赖插件在游戏中自动重建整场植被。

**使用心得：**

- 四种草层分别使用稳定种子、数量、尺度与埋根偏移，层间可以重叠；互斥填充无法还原原demo的连续草团。
- 候选生成、接受过滤、可见密度是不同的数量。调低密度不等于必须重新生成全部随机候选。
- 适配器输出世界坐标；挂到有变换的渲染父节点时，必须转换到对应局部空间。
- 原demo需要保留作者完整基向量和埋根信息，不能只复制位置、重新随机缩放后仍称为还原。
- 正式流程先在平面生成稳定候选，再由项目按最新源贴地；样板还支持通过表面回调采样高度、法线和允许区域。不要混淆这两条流程。
- 插件本身不负责草的笔触、透明采样、风、季节、拨草与LOD。这些仍由项目材质和渲染器承担。

从“草像贴图”到可接受草地，关键修正是恢复24 / 2,288 / 28 / 8三角的四层模型、4K连续透明遮罩和正确受光。Scatter让布局更好做，没有单独创造这套美术。详细接口见[集成说明](../features/landscape_lab/PROTON_SCATTER.md)。

## 5. SunshineClouds2：多视口和生命周期是主要成本

**版本不能只写“2.7”。** 当前固定commit包含上游Godot4.7相机修复，不能升级或回退时只按大版本名称选择。原插件源码保持，接入代码在[SunshineCloudAdapter](../features/weather_plugins/sunshine_cloud_adapter.gd)。

**遇到的问题：**

1. Metal的MSAA写入路径报错。当前正式场景采用样板已验证的TAA、关闭MSAA；上游写“支持Metal/MSAA”不代表我们的组合已经通过。
2. 最初用共享WorldEnvironment效果，主画面、摄影和反射会轮流使用同一份视口尺寸/历史数据。最终改为每个相机独立效果、独立缓存，只同步参数与相位。
3. 新摄影相机必须继承启用状态，并复制云相位；否则关闭插件的对照照片也可能出现插件云，或照片中的云与主画面不一致。
4. 新视口需要收敛。当前有Compositor的摄影等待32帧，再读取图像；导出后释放自己的资源，不能影响主相机。
5. 原版默认AO颜色是诊断红色，直接使用会把云染红。适配器通过公开颜色参数改为场景冷灰色，没有为此修改插件shader。
6. Compositor资源可能持有RenderingDevice资源及引擎借出的视口引用。退出时需要区分“我们拥有的RID”和“视口拥有的纹理”，正确释放前者、解除后者引用；只把节点移出场景不够。

**当前约定。** 原日历、太阳和天气是唯一权威，不再启动插件独立的昼夜循环。冻结/减少动态时云相位保持，恢复后继续；适配器在重新启用效果时刷新历史。编辑器Dock未启用，避免其自动处理头文件版本，破坏固定源码。摄影相关接入见[PhotoExport](../features/photography/photo_export.gd)。

真实倒影云与摄影已做像素验证，但体积云本身没有因此自动提供与云密度一致的地面投影。当前场景仍有原来的近似云影，不应把二者描述为严格一致。

## 6. Blanket：保留算法，限制兼容层的承诺

**原版要求与本地适配分开记录。** 上游固定版要求Godot4.8/Vulkan；我们没有升级引擎，而是使用其有界物件计算子集，制作4.7.2/Metal缓冲桥。原GLSL选面、圆边、边裙、挤出、平滑与法线算法保持逐字节不变。

[BlanketBaker](../features/weather_plugins/blanket_baker.gd)负责上传4.7网格数据到自有storage buffer，运行原流程，再读取为派生ArrayMesh；[BlanketSnowRenderer](../features/weather_plugins/blanket_snow_renderer.gd)负责选择已发布物件、缓存、季节显示及编辑更新。兼容改动见[补丁](../features/weather_plugins/compat/blanket_4_7.patch)。

**主要教训：**

- 同样是白色表面，材质和雪壳不是一回事。厚度必须检查实际三角形、轮廓和边裙。
- 不能为所有网格使用同一路径。完整64m地面曾出现大输出索引与异常尖片，最终移除了这条路线；地面交给Terrain3D，物件交给Blanket。
- 当前桥对生成顶点超过65,536的物件跳过处理。这是本地兼容范围，不是上游普遍限制，也不能宣称原插件已全面支持Metal。
- 原版CUSTOM0需要浮点数组，首轮误改字节数组导致失败，已恢复。处理底层接口前要核对引擎实际格式。
- 预分配、未被三角形引用的顶点可能污染包围盒。我们在读回时压缩有效引用，不能用一个异常AABB草率否定或通过厚度。
- 透明叶片喷片不能直接生成实心雪板；落叶树冬季消失的叶冠也不能留下悬空雪团。当前选择屋顶底层包络、岩石实体、松枝垫层、灌木实体和裸枝。
- 几何缓存与物件位姿分开，重复部件可复用；更新源后及时移除旧显示，避免撤销、取消或移动物件后留下旧雪壳。

2026-10-28补充：完全积雪时，适配器仅将无距离限制的自然物雪壳按共享网格与8m空间块合批；屋顶和有距离范围的部件保留各自的可见性原点。融雪/透明渐隐时恢复独立物件，完全不透明时采用不透明材质路径。源雪壳数量和实际绘制视图数必须分开记录；满容量本轮为1,412个源雪壳、1,137个视图。不要只按“相同网格”合并后改变每实例LOD，也不要把单个末帧的全场draw call数当作整段收益，倒影和材质通道会影响计数。[本轮保真与性能报告](weekly/week_14/WINTER_RENDER_OPTIMIZATION.md)。

目前属于朝向驱动的局部覆盖，不是全场遮挡感知、风吹雪堆或物理压雪模拟。参数深度也不等于处处相同的最终厚度：圆边/平滑会改变轮廓，植物实例缩放也会缩放雪壳。

## 7. puchik雪材质：导入设置是效果的一部分

它提供向上表面混合、雪贴图、法线和粗糙度参考，没有雪壳或地形体积能力。原shader保留在[addons/puchik_snow](../addons/puchik_snow/README.md)，正式地面复用其输入并适配到Terrain3D；并未直接替换整套地形shader。

最重要的一次失误是只带图片、漏带原导入参数。法线压缩方式改变后，材质对朝向的判断出了问题；恢复原VRAM压缩、法线标记和mipmap设置后才正确。**复制纹理文件，不等于复制了材质效果。**

另一次雪覆盖检查失败，其实是平面样板被丘陵从边缘穿出，采样读到了真实地形。应先排查机位、遮挡与测试布置，再改材质；最终抬高整个参考板，保留原验收阈值。

授权也要分层：上游README声明代码MIT，但没有单独提供完整MIT版权文件；纹理来源按上游声明记录为ambientCG、CC0。保留原声明及来源，不编造作者署名，也不把这份声明扩大到其他下载素材。

## 8. GUT与验收：自动测试要分工

| 验收层 | 负责证明 | 不能替代 |
| --- | --- | --- |
| GUT/headless | 稳定种子、源状态、事务、撤销、异步发布、生命周期 | 原生shader、GPU几何和Metal最终画面 |
| 原生图像/几何检查 | 实际插件调用、实例原点、雪厚度、冻结、照片与倒影像素 | 用户美术接受、所有机位都无时序伪影 |
| 人工视觉体验 | 草地体积、云色、雪的质感和场景协调 | 容量与帧时间预算 |
| 独立性能/平台门禁 | 指定硬件、驱动、场景和预算下的表现 | 其他设备/驱动或Windows真实设备 |

GUT运行必须非零、无遗漏/跳过；断言失败、脚本错误和退出泄漏都要使外层命令失败。故意失败负控用于证明门禁能拒绝错误。还要删除旧结果再运行，防止把历史JSON或截图当成本轮证据。

实测踩坑包括：headless无法反射native shader uniform；旧房屋节点表已为空，检查必须跟随正式发布节点；浮点AABB需要合理近似比较。这些都应修正测试布置或接口判断，不能降低真实渲染门槛来“凑通过”。

## 9. 接入、升级与排错的固定做法

1. **明确缺口。** 先判断需要的是地形、散布、材质还是几何，不把所有视觉问题交给同一插件。
2. **检查固定源码和许可。** 核对引擎、原生库、驱动、素材许可与依赖；先固定tag/commit与哈希，保留原许可。
3. **做隔离样板。** 使用真实资产和同一套场景状态，隔离存档/偏好，提供同机位开关和直达入口。
4. **接公共接口。** 源、事务、天气时钟仍属于项目；必要适配集中在feature层，vendor修改保留最小diff。
5. **验证完整链路。** 包括编辑、取消、撤销、读档、摄影、倒影、冻结、减少动态、退出释放和正式文件哈希。
6. **先确认美术方向，再优化。** 用户确认前不靠删草层、换低质材质强行达到预算；认可也不能代替性能通过。
7. **升级后重验接口和实际画面。** 尤其检查原生API、shader插入点、纹理导入归一化、相机缓存和RID所有权；不能只改版本号。

排错时先分清：安装/加载失败、数据或坐标错误、材质/导入错误、相机/历史错误、资源释放错误、性能超预算。每次修改对应一个可验证的原因，保留失败摘要和修复后的证据。

## 10. 当前验证入口与开放节点

从项目根目录执行；命令可能包含导入、累计回归或真实GPU过程，原生验证应串行运行。

| 目的 | 命令 |
| --- | --- |
| 合同要求的W01–W09与负控 | `python3 tools/quality/run_checks.py --week 9 --negative-control` |
| Terrain3D/Scatter样板 | `python3 tools/quality/landscape_lab_checks.py` |
| 正式地形/草的功能回归 | `python3 tools/quality/production_landscape_checks.py --skip-import` |
| 当前正式云雪、漫步及累计门禁 | `python3 tools/quality/weather_adoption_checks.py --cumulative` |
| 正式云雪原生专项 | `python3 tools/quality/weather_adoption_checks.py --native-only` |
| G4旧阶段性能入口 | `python3 tools/quality/painterly_grass_performance.py --pilot` |

正式入口是`app/living_root.tscn`；样板有`app/landscape_lab.tscn`、`app/weather_plugin_lab.tscn`，草地展示台可往返。性能命令不是默认应成功的演示命令，预算失败须保留非零退出。

最近云雪采用留存的通过记录是：446项累计及负控、36项定向/2,807断言、36项正式云雪与74项漫步Metal检查，另有有界雪壳兼容检查；详见[收据](weekly/week_14/evidence/weather_adoption/checks.json)。本轮优化已重跑446项累计、42项定向、36项正式云雪与74项漫步Metal检查，并新增36组保真对照，见后附优化报告。

**仍开放：** 当前组合的20ms冬景预算、完整容量矩阵/长测、Windows实机、下载美术素材的分发归档，以及物理雪变形等未实现能力。2026-10-28三组独立进程、每边60秒动态冬景，本轮保真优化后帧p95中位数26.496ms，原配置28.200ms，约改善6%；仍超过20ms。按用户授权将G4阶段后置，不记性能通过；旧MSAA基线保留为历史证据。[本轮报告](weekly/week_14/WINTER_RENDER_OPTIMIZATION.md)。

研究过而未采用的TerraBrush不代表不好用：其雪层依赖自己的地形数据，接入意味着迁移系统，而不是给Terrain3D加一个可即插即用的雪效果。保留现有成熟数据链、限定适配范围，有时比再安装一整套系统更合适。
