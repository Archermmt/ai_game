# I1 / VA01 首批资产与插件候选来源

更新：2026-10-29。依据 [美术改良计划第8–11节](../ART_IMPROVEMENT_PLAN.md) 已完成的原作者与官方页面调研整理；机器可读记录见 [asset_candidates.json](asset_candidates.json)。当前工程基线为 Godot 4.7 / Compatibility，Forward+仍待VA03对照决定。

本清单记录上游声明、免费范围和潜在用途。9项均为 `not_downloaded`，没有下载、安装或导入；未核验包内文件、实际许可副本、纹理通道、GPU画面和本机兼容。`resolved_commit`、`sha256`均为 `null`，`actual_files`均为空数组。未提供版本号的资产网页保留 `candidate_version: null`，不编造版本、文件名或哈希。

## 首批候选

| ID | 来源与候选 | 免费/许可边界（上游声明） | 首轮作用与取舍 |
| --- | --- | --- | --- |
| AS-01 | [Quaternius Medieval Village MegaKit — Standard](https://quaternius.com/packs/medievalvillagemegakit.html) | 资产CC0；免费Standard约占整包60–70%，不能按全包304件计数。完整Godot工程、自定义shader、全部Blend源属于Source档。Standard宣称OBJ/FBX/glTF。 | 优先比较墙、门窗、屋顶及附着件；按1m角色与2×2足印重组，验证门高和瓦片尺度。对应KIT_001–004、008、009、011、012，BLD_001–003和MAT_002。 |
| AS-02 | [Quaternius Stylized Nature MegaKit — Standard](https://quaternius.com/packs/stylizednaturemegakit.html) | 资产CC0；免费Standard约60–70%，不是整包116件。完整Godot实现、风与风格shader、全部Blend源属于Source档。Standard宣称OBJ/FBX/glTF。 | 优先选主树、灌木、草、花、岩样本；本项目自校准风、Alpha、受光与LOD。对应NAT_001–004、007、008、010和MAT_004；不能预认免费子集包含全部所需变体。 |
| AS-03 | [Quaternius Ultimate Stylized Nature Pack](https://quaternius.com/packs/ultimatestylizednature.html) | 页面列63件并提供免费包，CC0；宣称FBX/OBJ/glTF/Blend，具体目录待下载核对。 | AS-02免费子集不足或风格不合时的自然物备选；最终选一致的家族，不整包混搭。潜在ID与AS-02相同。 |
| AS-05 | [Poly Haven Grey Roof Tiles 02](https://polyhaven.com/a/grey_roof_tiles_02) | 单项资产CC0；是贴图，不是屋顶模型。宣称Diffuse/Normal/Roughness/AO等通道及PNG/JPG/EXR。 | 先取1K–2K必要通道，选GL法线，校正UV尺度、噪声与苔藓强度。对应KIT_004、005及MAT_002。 |
| AS-06 | [Poly Haven White Plaster 02](https://polyhaven.com/a/white_plaster_02) | 单项资产CC0；宣称Diffuse/Normal/Roughness等通道及PNG/JPG/EXR。 | 低强度法线和低频墙面色差样板，木梁单独材质。对应KIT_001、002及MAT_002。 |
| AS-07 | [Poly Haven Rocky Terrain 02](https://polyhaven.com/a/rocky_terrain_02) | 单项资产CC0；宣称Diffuse/Normal/Roughness/Mask/Displacement等通道及PNG/JPG/EXR，现实覆盖约90m。 | 隔离测试岩土输入，裁选、重定尺度和调色；照片感过强则自制。不能直接铺满1m格海岛或替代崖面网格。对应TER_001–004及MAT_001。 |
| PL-01 | [ProtonScatter作者源](https://codeberg.org/hungryproton/proton_scatter) / [GitHub镜像](https://github.com/HungryProton/scatter)，候选4.2.0 | 插件代码MIT；README另列demo模型MIT，多数demo纹理来自Textures.com，不能整体按MIT迁入。4.2.0来自版本文件，不等于已解析固定commit。 | VA06分布与变换生成样板。项目保留源高度、稳定种子、道路/入口避让、脏块和MultiMesh发布；不复制整个demo。 |
| PL-02 | [Terrain3D](https://github.com/TokisanGames/Terrain3D)，候选[v1.0.2-stable](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.0.2-stable) | MIT原生扩展；release列Godot4.4–4.7，[stable平台文档](https://terrain3d.readthedocs.io/en/stable/docs/platforms.html)仍称Metal未支持/未测试。支持64m地图不等于本机兼容。 | VA04隔离备选；先验证自有连续Surface路线。只有迁移收益足以覆盖编辑、拾取、撤销和支撑适配时再接入。对应TER_001–010及MAT_001。 |
| PL-03 | [GUT](https://github.com/bitwes/Gut)，候选v9.7.1 / godot_4_7 | addon MIT；上游版本表将9.7.1映射4.7.x。尚未解析commit或加载addon。 | 测试治理候选，无视觉产出。可保留现有测试；采用时验证非零用例、无跳过、故意失败负控和外层非零退出。无美术资产ID，关联验收ID单列在JSON。 |

上述ID都是潜在映射，不表示原制作清单已完成。BLD_004温室、BLD_005茶屋、BLD_006灯塔的齐套扩展属于VA09；本批先验证主屋家族，不能由AS-01网页推定三类特殊建筑的免费件已齐备。

## 本周先解决什么

I1先固定港湾存档和六个机位，修复VA02的材质保真与合批，再用VA03确定渲染主线。模型、贴图和shader在合批时丢失、法线/色彩导入不一致，会让任何资产包继续呈现平板效果；先安装插件无法证明这个问题已经解决。

ProtonScatter只减少布局工作，四层草的层次、根部、Alpha、风和受光仍需VA05/06样板。Terrain3D涉及已有源数据的适配及本机原生扩展验证，不能只凭官网截图替换。GUT不改善画面，现有回归可用时无需在I1迁移。`IslandData`、稳定ID和编辑事务继续作为作品权威源，插件只负责派生显示。

## 下次实际下载时如何锁定

| 下载对象 | 锁定时机与内容 | 未满足时的处理 |
| --- | --- | --- |
| AS-01/02 Standard | VA05样板导入前锁实际下载来源/日期、包与所选文件的SHA-256、许可声明副本、实际免费模块列表、模型格式；保存源文件到项目适配文件及ID的映射。核对门窗屋顶和主树/草是否确在免费子集。 | 缺件用自制补齐；自然物可改AS-03。不把Source档shader或完整包当免费交付。 |
| AS-03 | AS-02不足时再下载并锁包/文件哈希、许可及实际目录；与AS-02同镜头比较后选自然物家族。 | 保留候选记录，不并行导入两整套。 |
| AS-05/06 | VA05表面材质对照前锁1K–2K所需通道、分辨率、GL法线约定、许可与每个文件哈希；归档导入/mipmap/压缩及材质参数。 | VA02保真未通过时先修管线，不据失败样板否定资产。 |
| AS-07 | VA04岩土样板确需时再锁具体通道、裁选范围、尺度与调色记录。 | 低频风格化效果不足则弃用，保留对照理由。 |
| ProtonScatter | VA06隔离样板前，从实际采用的作者源或镜像解析完整commit，核对4.2.0版本及许可，锁addon文件哈希和本地补丁；另记任何演示资产来源。 | 先用项目自有确定性散布，演示纹理不随插件整包迁入。 |
| Terrain3D | VA04对照证明需要时才锁v1.0.2-stable完整commit、平台二进制及哈希，验证类型注册、真实渲染、初始化/退出和导出。 | Metal或其他路径未通过则保持自有Surface显示，不影响源数据。 |
| GUT | 实际采用前锁v9.7.1完整commit、addon哈希与许可，并跑测试发现/负控/退出验证。 | 保留现有可验证的测试入口。 |

以上是下一阶段的下载锁要求，不是当前已取得的证据。实际采用时新增逐文件记录；本清单的空哈希不得被视为锁定。可逐项推进 `not_downloaded → downloaded_verified → sample_imported → visual_accepted → adopted`，每一步附对应证据，当前9项均停留在第一步。

## I1门槛与后续交接

- 来源子项门槛：9项均具来源、角色、上游许可、免费边界、候选版本/未版本化说明、潜在ID和未导入范围；不伪造下载件或本机验证。JSON内所有潜在美术ID须在现有清单中可解析。
- I1整周门槛：VA01固定场景/机位与差距记录、VA02材质保真和合批对照、VA03两渲染路径真实画面/帧时/编辑/摄影记录均要由对应工作验证。本来源清单不能单独关闭VA01或I1，也不代表已达到港湾视觉门槛。
- VA05接收本清单后，把候选缩为实际主屋、两树形、岩组及材质家族，补全下载锁、尺寸、UV、导入参数和源到适配文件映射。免费件真实包含情况在首次下载时核验。
- VA06仅接收VA05已经通过的自然物样板；在VA04统一表面采样上验证四层草、稳定候选/接受过滤、贴地避让、四向读形、风/LOD和分块发布。候选插件或草模型存在均不能直接抵扣这些验收。

AS-04 Kenney仅保留次选；AS-08动画等VA09；AS-09 Painterly Grass许可与可分发原件未核实，不复制tiny_glade资产。Boujie、Waterways及Sunshine等水/云插件不在本次9项清单，也没有因此安装或采用。
