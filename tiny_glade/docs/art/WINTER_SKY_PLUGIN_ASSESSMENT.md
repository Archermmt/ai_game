# 积雪质感与云层插件 · 本地接口与验收基线

日期：2026-10-27（Asia/Shanghai）。基线为Godot 4.7.2、Metal Forward+、Terrain3D 1.0.2和现有四层草。本记录区分上游能力、本地接入与仍开放的验收，不把材质小样或导入成功记为完整冬景交付。

用户本轮要求：冬景应有银装素裹的雪质与覆盖层，天空应有与现有手绘场景协调的云；优先采用现成插件，雪暂不自行修改shader实现新效果。批准PRD保持原文，常规草地已认可的外观保持为比较基线。

## 外部候选与采用结论

**云层采用SunshineClouds2做隔离体验；雪采用puchik原材质做质感对照。正式地形雪厚度、屋檐雪壳与树冠挂雪仍未解决。** 现有积雪插件没有在当前引擎、Metal和Terrain3D组合下满足这三类需求的直接接入方案，因此本轮不升级引擎、不替换地形系统，也不把表面变白或法线凹凸称为厚雪。

| 候选与固定版本 | 上游真实能力 | 当前工程的决定 |
| --- | --- | --- |
| Blanket，`7b1166a9f03135098c80fc0aba3a19e7e0909b9f`；发行标签`v1.0.0`为`3b591546e5206aa67a9e31769bb97f856bb8c8ae`；MIT | 从朝上三角面生成有体积的几何覆盖层，具备真正雪壳能力；要求Godot 4.8、Vulkan与计算着色器。输入是普通`MeshInstance3D`的`ArrayMesh`，不是任意渲染对象 | 不引入当前4.7.2/Metal工程。已核对的首版与标签也基于4.8，没有找到可推荐的4.7.2历史版本；其普通网格入口也不能直接覆盖Terrain3D或`MultiMeshInstance3D`植被 |
| TerraBrush，`9f08ac72fa9cd0aa13f19908548834da08556467`；发行`0.14.7Alpha`为`e7012f9cb9e8ceea8943b3aed26f49d4bc7bd8fa`；MIT | 自带地形上的厚雪、雪纹理/法线、压雪与恢复；当前为C++ GDExtension，要求Godot 4.5+，发布构建包含macOS universal | 不作为Terrain3D附加插件安装。雪依赖自己的clipmap、区域和高度/雪纹理协议，不能通过现成GDScript接口独立挂到当前Terrain3D；采用需要地形迁移或维护原生扩展分支，超出本轮薄适配 |
| puchik/godot-extras snow-shader，`515900a4aee952cdc4487bed98cc69758c899a32`；原README声明MIT，ambientCG纹理为CC0 | Godot 4.2样例的现成雪/岩石材质：朝上覆盖、粉雪纹理、法线与粗糙度混合；`basic_snow.gdshader`没有顶点位移 | 已固定原shader、四张纹理和README，仅用于独立平面、圆润石块、坡面的近景质感对照。原导入设置恢复后，小样已能正确显示；未自动套正式地形、屋顶或植被，不能验收雪厚度 |
| SunshineClouds2，`a73a80b08fb37b255f8f10d49debd71e5541bd70`，2.7加上游Godot 4.7相机修复；MIT | CompositorEffect计算着色器体积云，支持柔软/卡通样式、程序噪声、密度和颜色绘制、方向光跟踪；上游2.2起声明Metal支持 | 已固定源码并接入隔离体验适配器，沿用现有太阳、天气与显示时钟。本机Metal路径须关闭MSAA、保留TAA；完整美术接受、其他视口一致性及性能仍逐项验收 |

### 积雪的兼容性证据

Blanket的[固定版本要求](https://github.com/1hue/Blanket/blob/7b1166a9f03135098c80fc0aba3a19e7e0909b9f/README.md)明确列出4.8和Vulkan；[覆盖节点实现](https://github.com/1hue/Blanket/blob/7b1166a9f03135098c80fc0aba3a19e7e0909b9f/addons/blanket/instance.gd)检查父节点与网格类型。Godot新增网格buffer RID的[上游PR #118973](https://github.com/godotengine/godot/pull/118973)属于4.8功能；Vulkan限制来自Blanket自身要求，不能据此推断Godot整个网格接口仅支持Vulkan。即使后续升级引擎或更换图形API，Terrain3D与MultiMesh适配仍需另行解决。

TerraBrush的[固定版本仓库说明](https://github.com/spimort/TerraBrush/tree/9f08ac72fa9cd0aa13f19908548834da08556467)、[扩展入口](https://github.com/spimort/TerraBrush/blob/9f08ac72fa9cd0aa13f19908548834da08556467/demo/addons/terrabrush/terrabrush.gdextension)和[构建工作流](https://github.com/spimort/TerraBrush/blob/9f08ac72fa9cd0aa13f19908548834da08556467/.github/workflows/build.yml)证明当前C++实现及macOS universal构建，不能继续沿用旧资料中的“必须C#/.NET”结论。这里的Mac构建存在不等于已在本机Metal验收。更关键的是，[`Snow::_bind_methods()`为空](https://github.com/spimort/TerraBrush/blob/9f08ac72fa9cd0aa13f19908548834da08556467/src/nodes/snow.cpp)，其创建与数据绑定由[`TerraBrush::createSnow()`](https://github.com/spimort/TerraBrush/blob/9f08ac72fa9cd0aa13f19908548834da08556467/src/terra_brush.cpp)内部完成；[雪clipmap shader](https://github.com/spimort/TerraBrush/blob/9f08ac72fa9cd0aa13f19908548834da08556467/demo/addons/terrabrush/Resources/Shaders/snow_clipmap_shader_include.gdshaderinc)也依赖该地形的数据布局。它是有能力的另一套地形系统，当前没有独立、公开、可直接复用的Terrain3D雪层入口，也没有自动给普通屋顶和树冠生成雪壳的证据。

puchik的[固定版原README](https://github.com/puchik/godot-extras/blob/515900a4aee952cdc4487bed98cc69758c899a32/tutorials/snow-shader/README.md)保留授权原文“Everything is licensed under MIT.”；纹理另记录[ambientCG的CC0许可](https://docs.ambientcg.com/license/)。本地没有编造上游未提供的MIT作者行或完整版权声明。[原版basic_snow shader](https://github.com/puchik/godot-extras/blob/515900a4aee952cdc4487bed98cc69758c899a32/tutorials/snow-shader/snow-shader-complete/shaders/basic_snow.gdshader)在顶点阶段只调整UV，表面覆盖由片元阶段混合；其法线使近景受光有粉雪凹凸，但轮廓和物理高度不变。本地`puchik_snow.lock.json`记录原始路径、逐文件SHA-256和许可来源，shader保持上游原文。

另核对[Flynsarmy/gd-snow-project，`72af9dd9f8e7fdb6f8a8d1573261767b25e26ebd`](https://github.com/Flynsarmy/gd-snow-project/tree/72af9dd9f8e7fdb6f8a8d1573261767b25e26ebd)：其[雪材质](https://github.com/Flynsarmy/gd-snow-project/blob/72af9dd9f8e7fdb6f8a8d1573261767b25e26ebd/materials/M_Snow.gdshader)确有顶点位移，但依赖自有地形UV、顶点色与DrawableTexture绘制掩码，属于示例工程，不能直接替代Terrain3D的材质入口或完成全场物件挂雪。未将其作为另一个地形并行加入。

### 云层的兼容性证据与限制

SunshineClouds2的[官方说明与效果图](https://github.com/Bonkahe/SunshineClouds2#features)列出体积云、柔软/卡通样式和Metal支持；实际固定到[合并Godot 4.7相机修复的commit](https://github.com/Bonkahe/SunshineClouds2/commit/a73a80b08fb37b255f8f10d49debd71e5541bd70)。该修复通过公开相机变换/投影接口自行打包相机数据，替代缺少4.7布局的私有SceneData镜像；不能只固定较旧的“2.7”说明而漏掉这个相机修复。运行入口为[`SunshineCloudsDriverGD`](https://github.com/Bonkahe/SunshineClouds2/blob/a73a80b08fb37b255f8f10d49debd71e5541bd70/addons/SunshineClouds2/SunshineCloudsDriver.gd)与[`SunshineCloudsGD` CompositorEffect](https://github.com/Bonkahe/SunshineClouds2/blob/a73a80b08fb37b255f8f10d49debd71e5541bd70/addons/SunshineClouds2/SunshineClouds.gd)，不需要另一盏太阳或另一套天气日历。

上游说明包含MSAA支持，但**本机Godot 4.7.2/Metal的MSAA写入路径出现`image2DMS`写入错误**。当前隔离场景采用TAA、关闭MSAA；这是本地兼容限制，不是上游承诺所有Metal组合都失败，也没有通过切换全项目图形API规避。源码及导入归一化记录在`sunshine_clouds.lock.json`，原README和MIT许可保留，未启用无关编辑器Dock。Compute/Compositor方案需要真实RenderingDevice，headless测试只能验证适配和状态，不证明云正确绘制。

当前批准的是按用户要求研究并使用现成插件、制作可体验的隔离样板；**尚无用户对新云风格的最终接受，也没有厚积雪交付的通过结论**。主画面、摄影导出、池面反射、冻结/减少动态、正式编辑生命周期、Windows真实设备与性能须各自保留证据；本报告不代签这些门槛。付费资源购买、引擎升级、Terrain3D迁移或自写厚雪shader均未作为本轮默认动作。

## 现有效果为什么仍像染白

| 部位 | 当前工程实际做法 | 尚未具备的表现 |
| --- | --- | --- |
| Terrain3D地形 | `ProductionTerrainRenderer.CLIMATE_FRAGMENT`按`living_snow`和朝上法线混入固定雪白色，将粗糙度变为0.96 | 没有独立雪材质贴图/法线，没有新增雪层位移、厚度、堆积轮廓或接触边缘 |
| 屋顶 | `painted_roof.gdshader`给原有瓦片几何混白 | 瓦片自身起伏仍在，但没有覆盖瓦沟的柔软雪壳、厚檐口或檐边雪团 |
| 树和灌木 | `painted_foliage.gdshader`给部分朝上叶片混白，仍沿用原叶片裁切几何 | 没有树冠雪团/枝头覆雪的新增轮廓；薄叶片变白不能代替挂雪体积 |
| 四层草 | 依据积雪强度隐藏低草和大多数高草，剩余草枯黄、叶尖少量染白 | 已解决草遮住雪地的问题，但雪本体仍由上述地形着色承担 |
| 降雪 | 900个平面雪花实例，随天气显示/移动 | 下落雪花与落地后表面质感、厚度是不同问题 |
| 云层 | `painted_sky.gdshader`在天空方向上布置两排圆弧/SDF云团，并用简化颜色表现云底 | 没有三维云层密度、自遮挡或随太阳方向形成的体积明暗；换更复杂的轮廓仍不等于体积云 |

屋顶与植被的现有`living_up`来自局部`NORMAL.y`，不是变换后的世界向上法线。旋转/倾斜物体的积雪选择还需在候选插件实测中确认，不能仅根据平放物件判断覆盖正确。

**雪色、粗糙度、纹理和法线可以增强表面质感，但均不能单独证明几何雪厚度成立。** 视差、法线假凹凸也应按其真实能力命名。只有存在实际位移/雪壳/附加雪几何，并在屋檐或石头轮廓处看得到厚度，才可通过“厚积雪”视觉节点。

旧的`winter_cover_probe.gd`主要统计白色像素、绿色埋藏与草显隐；它能证明雪盖范围和春季恢复，不能证明雪材质、厚度或银装素裹的质量。其31项检查继续作为功能基线，新效果需补充近景和轮廓验收。

## 最小插件适配边界

1. 先做继承`ProductionLandscapePlayground`的隔离体验场景，使用正式房屋、四层草和Terrain3D，提供同一世界、同一机位的基线/候选切换。不要并排运行两个庭园代替A/B。
2. 在`_init`中设`qa_mode=true`，在任何继承的偏好加载/保存之前生效；试验偏好只保留在会话，预览作品和照片使用专用QA目录。不开正式存档槽，不通过插件改写WorldDocument。用`production_files()`核对前后真实作品/偏好哈希。
3. 现有`LivingAtmosphere`继续唯一拥有日历、太阳、环境光、天气过渡和时间。插件使用其输出，不再独立启动第二个昼夜循环或第二盏太阳。
4. 当前`SunshineCloudAdapter`独立挂到试验场景，在`WorldEnvironment.compositor`附加上游效果并管理释放；保留`LivingAtmosphere.sky`的`PaintedSky`类型与现有天空接口。启用插件云时只隐藏旧解析云，仍保留天空底色和太阳联动；不能把任意外部Node直接赋给有类型约束的字段。
5. 插件仅有通用网格积雪效果时，不能因此宣称Terrain3D也受支持。当前Terrain3D保留自己的原生材质和0.25m高度图；普通MeshInstance材质无法直接覆盖它。必须使用插件提供的Terrain3D兼容入口，或将该能力明确留为未解决。
6. 物件覆盖层属于派生显示。可在现有`Cottage/HandLaidTiles`等提交后的视图节点上注册插件效果，随视图替换、取消、撤销重做释放/重建；不逐帧遍历全场创建雪节点，不把雪壳写回源建筑或新增用户实例ID。
7. 当前任务先使用插件公开参数与接口做配置和必要适配。没有合适的雪插件覆盖所需能力时，保留基线并记录缺口，不借选型工作自行编写新的雪shader/雪堆生成器。

## 必须接好的状态接口

| 当前权威状态 | 给插件的含义 | 接入时的检查 |
| --- | --- | --- |
| `WeatherBlend.current["cover"]` | 已累积的雪盖；冬季晴天也有雪 | 与`current["snow"]`分开，停止下雪不能立即清空雪层 |
| `current["cloud"] / energy / fog / rain / snow / dust` | 18秒过渡中的天气显示值 | 用平滑后的值，避免阴晴切换时云层和光线跳变；不再对原始天气枚举另起一套过渡 |
| `LivingAtmosphere.elapsed` | 天空、云及动态效果的显示时钟 | 使用插件的显式时间/相位接口；固定使用内置`TIME`而无法停在当前相位的候选不能通过摄影冻结 |
| `atmosphere.frozen` / `_climate_frozen` | 摄影冻结当前画面和天气过渡 | 插件自带`_process`、噪声偏移和时间累积也须停住，不能只暂停现有脚本 |
| `atmosphere.reduced_motion` | 现有天空/降水时钟降至1/4速度，植被另有停止规则 | 沿用现有显示时钟，避免插件仍以全速云动/闪烁 |
| `host.sun`的变换、颜色和能量 | 当前太阳与天气照明 | 云底阴影、云边受光及雪阴影跟随同一太阳；不叠加插件默认环境光造成全场过曝 |
| 现有WorldDocument、版本和事务 | 地形、屋体和植被的唯一真源 | 气候与预览切换不改变源哈希、revision、历史；编辑后的效果只绑定最新发布的视图 |

雪若只在渲染层产生位移，需要单列视觉雪面与`TerrainField`物理高度的关系。当前刷坡、贴地、第一人称支撑都以TerrainField为准；不能为了雪厚度直接改变其高度图、池岸或用户建筑位置。

## 摄影和水面兼容性不能只看主画面

- `PhotoExport.capture()`新建共享World3D的SubViewport和Camera3D，复制相机的Environment、属性、裁剪层等，目前没有复制Compositor。依赖主相机CompositorEffect或屏幕空间节点的插件，即使主窗口有云，也不代表1080p/2K摄影会有云。
- `PondReflections`使用独立480×270反射相机，只同步Environment.sky和部分光雾参数。屏幕空间云与3D云节点还需确认反射路径；天空材质方案通过共享Environment.sky较容易覆盖两种相机。
- 反射系统默认排除地形、草和Atmosphere分支。雪壳若新增为物件子节点，需要按已有规则决定是否进入物件反射层，避免雪与被覆盖屋顶在反射中分离。
- 旧天空原生测试直接读取`atmosphere.sky.material`中的`sun_direction`和`sky_time`。插件采用不同接口时，需为候选增加真实的适配检查，不给虚假的兼容参数只为通过旧测试。

## 最小可验收节点

### 雪候选

- 固定晴冬和降雪两套光线，包含庭园全景、1.65m屋檐低视角、圆顶/坡顶侧视角、常青树冠、石头与地面近景；关闭景深，固定风相位。
- 与现有白色覆盖基线成对截图：能看到雪表面的低频起伏、法线/粗糙度变化、冷暖受光，并保留柔和的手绘大色块；高频闪点或纯白过曝不能算质感改善。
- “表面质感”和“厚度/挂雪”分别验收。厚度通过必须有真实雪层能力及屋檐/岩石轮廓证据；材质纹理变化的像素差不能替代轮廓证据。
- 覆盖朝上表面，屋檐底面和垂直墙体不过度挂雪；积雪与冬季稀疏枯草一致，春季消退后原外观恢复。编辑、取消、撤销重做后没有旧雪壳残留。

### 云候选

- 固定晴天积云、阴天/雪天、黄昏、夜间，至少包含地平线低视角、向上看云底、太阳附近云边和林间低机位。
- 云团有可读的大轮廓、柔软云底与层次；不靠强景深掩盖云边噪点，不出现重复贴纸排列。云边受光随现有太阳变化，雪天不仍是晴天高亮云色。
- 主窗口、池面反射、1080p/2K摄影中云均正确；摄影冻结前后在同机位TAA收敛后图像差维持现有门槛，解除冻结后动态恢复。

### 技术收据

- 锁定引擎、插件commit/版本、许可与资源哈希；保留原包源码及必要的可追溯兼容补丁说明，不复制下载缓存或导出包进Git。
- 有非零自动检查、真实Metal画面、实际插件资源/节点已接入的证明；导入成功不能替代Mac渲染通过。
- 前后源/偏好/作品哈希不变，无脚本错误或退出泄漏；天气重定向、冻结、减少动态、摄影和场景退出均有检查。
- 本机G4草地已有20ms门槛缺口。新插件的代价单独记录，不以风格化名称推定轻量，也不将本机Metal结果写成Windows或完整性能验收通过。

## 本地证据路径

- `features/weather_plugins/puchik_snow.lock.json`、`sunshine_clouds.lock.json`：固定上游commit、原始路径、许可和文件哈希。
- `features/weather_plugins/snow_material_reference.gd`：原版雪材质的独立近景对照；没有厚度或正式地形接入。
- `features/weather_plugins/sunshine_cloud_adapter.gd`、`weather_lab.gd`与`app/weather_plugin_lab.tscn`：插件云、现有天气时钟与隔离体验入口。
- `features/living_world/weather_blend.gd`：18秒过渡与雪盖/降雪分离。
- `features/living_world/living_atmosphere.gd`：太阳、环境光、显式时钟及天空同步。
- `features/living_world/painted_sky.gd` / `.gdshader`：当前天空提供者接口及两排解析云。
- `features/landscape/production_terrain.gd`：固定Terrain3D材质扩展与当前雪色覆盖。
- `features/art_direction/materials/painted_roof.gdshader`、`painted_foliage.gdshader`：物件当前覆雪方式。
- `features/photography/photo_export.gd`、`features/pond_water/pond_reflections.gd`：其他相机/视口路径。
- `tests/week_14/production_landscape/winter_cover_probe.gd`、`tests/week_13/sky_weather_native_probe.gd`：既有功能与冻结回归基线。
