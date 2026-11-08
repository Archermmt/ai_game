# I1：美术接入基础与渲染对照

2026-10-29。承接 `4d81d6b` 美术改良计划，原画面基线为 `0b65303`。本周目的是建立可靠的对照与材质管线；连续地形、真实草树、主屋表面和新水面由I2起制作，当前仍不作为Brushland参考级美术通过。

## 交付与门槛

| 任务 | 当前交付 | 仍需验证 |
| --- | --- | --- |
| VA01 | 固定世界JSON、六机位、冻结时间、1080p实际截图；9项首批资产/插件的来源、免费边界、潜在项目ID | 外部包尚未下载；免费子集、许可副本和文件哈希在VA05导入前核对，来源候选不等于实际依赖锁 |
| VA02 | 完整材质资源身份分组、8m分块及局部原点；不适合合批的表面整件保留；颜色/GLB往返与原生GPU合批对照 | 新的真实草树资产仍须逐件验证风、Alpha、LOD；结构与像素测试不等于艺术风格接受 |
| VA03 | 同一M4 Pro本机的Compatibility/OpenGL与Forward+/Metal原生截图、帧时、编辑和拍照回调对照 | M1/8GB、Windows、完整压力场景未测；画质档的水/光/反射尚未制作，正式渲染主线继续待样板决定 |

G0的本机材质与渲染路径部分可检查；实际依赖锁和目标设备部分保持待验收。G1港湾视觉、G2完整性能与功能门槛均未关闭。

## 固定观察条件

- 引擎：Godot `4.7.stable.official.5b4e0cb0f`；系统：macOS 15.1，Apple M4 Pro。不是PRD目标M1/8GB设备。
- 固定世界：[bay_baseline.json](../../game/art_lab/fixtures/bay_baseline.json)，349个记录格、21个物件、4名居民，保留旧演示岛作为背景。SHA-256：`fc74fe3b9d9f9ba86df093baea7e47fd1214b82ac566aa65372908b81706728c`。
- 港湾关注区为源格`x=[19,35), z=[24,40)`，约16×16m。六机位同时包含周围旧场景，用全景暴露边界；这不是已经完成重新构图的港湾美术样板。
- 六机位：港湾、水平转90°、主屋近景、岸边近景、全岛、日落。具体中心/尺寸/角度写在 [art_lab.gd](../../game/art_lab/art_lab.gd) 及每次JSON内。
- 每个视图1920×1080，正交投影，固定太阳/环境参数；海水运动、居民和动物时间冻结，隐藏UI，不触碰玩家存档。相同参数用于修改前后与两渲染器对照。
- 原生Forward+启动参数明确为`--rendering-method forward_plus --rendering-driver metal`；Compatibility日志中的“OpenGL … Metal”不作为Forward+证据。

## 颜色修复

原 `ArtKit.material()` 将sRGB色再手工转一次linear，之后StandardMaterial3D/GLB链路继续执行自身转换。原生无光照色卡实测，原草绿`#a4b98a`会成为约`#5f7c40`。两条渲染路径均能复现这项偏暗，因此删除这次手工转换，并重新导出15个自制GLB。

地形显式使用`vertex_color_is_srgb=true`，使原始sRGB顶点色在两路径中一致。shader颜色使用`source_color`；法线/粗糙度等数据输入不做颜色转换。

色卡包含18%灰附近的`#767676`、奶油`#efe4c9`、草绿`#a4b98a`和陶红`#c67c65`；横向依次为直接材质、故意重复转换、sRGB顶点色、手工linear顶点色、贴图、source_color uniform和GLB实际导出/导入。正确输入最大RGB误差阈值0.035，故意错误列必须至少偏差0.15，避免检查空跑。Compatibility与Forward+对手工linear顶点色的处理不同，因此项目统一使用明确的sRGB标记。

[Compatibility色卡](../../snapshots/art_i1/colors/gl_compatibility.png) · [Forward+色卡](../../snapshots/art_i1/colors/forward_plus.png) · [颜色数据](../reports/art_i1/colors_gl_compatibility.json)

## 合批保真

[StaticBatcher](../../game/art/static_batcher.gd)按完整材质资源身份、顶点格式、渲染属性与8m空间块分组，不按颜色近似合并。资源身份会保留贴图、法线、UV和发光等全部材质字段；相似但独立的材质宁可分别提交。分块以局部原点烘焙顶点，不改变世界位置。

ShaderMaterial、透明、overlay/next_pass、风动/自定义通道、动画、骨架、LOD、原点敏感材质和显式动态节点保留原件。混合表面的网格整体旁路；不能先跳过自定义表面再删除整个原网格。已合并节点的附属灯光和子节点继续保留。外部适配可在分支根设置`batch_exclude=true`元数据或`dynamic_visual`组。

原生GPU探针覆盖不同albedo/normal贴图、ShaderMaterial、混合表面、透明、overlay/next_pass和父变换，比较同相机合批前后像素。负控故意改坏输出材质，必须检测到差异并退出1；它另存报告，不能覆盖正向证据。

导入GLB的自动阴影网格也保留：相同surface映射分别烘焙主网格和shadow网格，保留fused vertex拓扑与全部可用通道。真实`bench.glb`的24→8顶点阴影作为结构正控，GPU场景另验证阴影确实落在接收面上。布局/数组缓存仅在一次合批内按Mesh复用，材质仍从每个节点获取，不能污染surface override。

固定引擎还有一个已核实边界：4.7压缩的position-only阴影网格读取可能返回空vertex数组，原因见 [Godot对应版本源码](https://github.com/godotengine/godot/blob/5b4e0cb0f/servers/rendering/rendering_server.cpp#L1455)。正常公开读取优先；只有已核实的3D vertex/index、压缩标记、stride=8、offset=0、准确字节长度与有限AABB时，才按公开描述恢复位置。未知布局或阴影LOD继续整件保留。升级引擎必须重跑这些真实GLB/GPU检查。

## 实际截图

修改前与校准后共用同一存档和机位。I1改变输入正确性与接入架构，大的造型差距仍可见；下一周先改海岸和资产。

| 机位 | 修改前Compatibility | 校准后Compatibility | 校准后Forward+/Metal |
| --- | --- | --- | --- |
| 港湾 | [图](../../snapshots/art_i1/baseline_compatibility/harbor.png) | [图](../../snapshots/art_i1/gl_compatibility/harbor.png) | [图](../../snapshots/art_i1/forward_plus/harbor.png) |
| 旋转90° | [图](../../snapshots/art_i1/baseline_compatibility/orbit.png) | [图](../../snapshots/art_i1/gl_compatibility/orbit.png) | [图](../../snapshots/art_i1/forward_plus/orbit.png) |
| 主屋 | [图](../../snapshots/art_i1/baseline_compatibility/house.png) | [图](../../snapshots/art_i1/gl_compatibility/house.png) | [图](../../snapshots/art_i1/forward_plus/house.png) |
| 岸边 | [图](../../snapshots/art_i1/baseline_compatibility/shore.png) | [图](../../snapshots/art_i1/gl_compatibility/shore.png) | [图](../../snapshots/art_i1/forward_plus/shore.png) |
| 全岛 | [图](../../snapshots/art_i1/baseline_compatibility/whole.png) | [图](../../snapshots/art_i1/gl_compatibility/whole.png) | [图](../../snapshots/art_i1/forward_plus/whole.png) |
| 日落 | [图](../../snapshots/art_i1/baseline_compatibility/sunset.png) | [图](../../snapshots/art_i1/gl_compatibility/sunset.png) | [图](../../snapshots/art_i1/forward_plus/sunset.png) |

## 验证与短采样

<!-- RESULTS_START -->
本轮两组suite合计20步通过：8步规则/资产与12步原生GPU/编辑/摄影（其中5步为预期失败负控）。静态合批正向52项检查；故意失败返回1。两条渲染路径的颜色、真实GLB往返、不同贴图/法线、Shader与透明表面、非均匀缩放法线、可见阴影均通过；原生材质比较中超过3/255容差的变化像素均为0。纹理破坏与旧法线变换负控均确实检测到差异并返回1。

[规则suite](../reports/art_i1/suite_rules.json) · [原生suite](../reports/art_i1/suite_native.json) · [Compatibility材质数据](../reports/art_i1/materials_gl_compatibility.json) · [Forward+材质数据](../reports/art_i1/materials_forward_plus.json)

| 同存档/1920×1080短采样 | 帧间隔p50 ms | 帧间隔p95 ms | 整笔重建p95 ms | 全岛可见draw calls |
| --- | ---: | ---: | ---: | ---: |
| 修改前Compatibility | 8.318 | 14.637 | 63.759 | 101 |
| 校准后Compatibility | 8.274 | 14.585 | 106.971 | 340 |
| 校准后Forward+/Metal | 8.330 | 9.808 | 759.074 | 290 |

这是保真修复，尚未达成性能目标。修改后795/981个来源合为81批，其中181个阴影来源合为35个阴影批；153个真实LOD和33个单例保留。完整资源身份、空间分块与LOD保留增加了绘制数；全量重建和GPU资源更新仍重，尤其Forward+。当前开发主线继续使用Compatibility，Forward+保留隔离样板，不能凭较低帧间隔p95切换默认。I2优先把VA04的脏块/局部更新落实，并为稳定建筑/材质缓存避免不相关编辑反复重建；真实LOD实例化在VA06继续处理。

[修改前数据](../reports/art_i1/baseline_compatibility.json) · [Compatibility数据](../reports/art_i1/gl_compatibility.json) · [Forward+数据](../reports/art_i1/forward_plus.json)
<!-- RESULTS_END -->

帧时使用同场景150个原生帧样本（另有30帧预热）；编辑是7次完整重建，p95相当于该短样本最大值。统计保留它的实际代价，不以draw calls下降作为单独目标。引擎静态内存不是进程峰值/显存；短样本不是五分钟压力测试或M1目标设备结论。

当前水仍是旧无受光shader，地形、球冠树和纯色建筑未重做。单切Forward+不能取得参考画面，因此不在I1修改默认渲染器。等VA04–VA08样板的实际水/光效果与设备证据齐备后再决定正式画质档。

颜色输入校准后，相同太阳/环境能量在Compatibility的受光物体上偏亮，Forward+则较收敛。无光照色卡通过只证明输入传输正确，不能证明受光画面已经一致或更接近参考。这里保留相同参数以暴露差异，VA08需分别校准各档的光照/曝光；不把本周较浅的树色和墙色当作最终调色。

## 复现

本周macOS原生验证入口（需要本机图形会话）：

```sh
python3 tools/run_art_i1.py
```

单独查看固定港湾并重拍校准后截图：

```sh
godot --path . --rendering-method gl_compatibility res://game/art_lab/art_lab.tscn -- --label=gl_compatibility
godot --path . --rendering-method forward_plus --rendering-driver metal res://game/art_lab/art_lab.tscn -- --label=forward_plus
```

规则测试可用`python3 tools/run_art_i1.py --only rules`，GPU/拍照测试用`--only native`。runner有90秒超时、引擎错误扫描和必须出现的通过标记；负控必须非零退出。日志与机器可读结果在 [reports/art_i1](../reports/art_i1/)。修改前`baseline_compatibility`截图只保留历史，不用新代码覆盖；从旧提交重新构建才可重建该基线。

若刚导出GLB或首次拉取源码，先用编辑器完成资源导入。之前曾观察到本机编辑器导入退出时的原生线程清理崩溃，需检查导入/脚本诊断并另跑真实场景，不用编辑器退出码替代GPU验证。

## I2交接

下一周程序主攻VA04：连续岸线、草坡/岩岸、统一表面采样，使地基、道路、居民和拾取同步。美术并行VA05首批下载核验与主屋、两树形、岩组、瓦/灰泥材质样板。先交第一组真实对照图；四层草依赖表面与资产样板，新水面依赖岸线数据与渲染路径。明确容量与验收见 [开发计划11.6](../DEVELOPMENT_PLAN.md#116-i1执行交接与i2承诺)。
