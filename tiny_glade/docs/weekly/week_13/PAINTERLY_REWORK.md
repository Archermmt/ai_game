# 手绘自然庭园：参考研究与实时美术重制

2026-10-24，用户授权对现有草地、树林、房屋、天空、光照与镜头作整体美术优化。范围保持现有P0资产族及可编辑庭园，不覆盖批准PRD，不新增室内、藤蔓、烟囱、生物或建造规则。

## 参考与执行要求

[完整参考研究](../../art/PAINTERLY_REFERENCE_STUDY.md)收录12张实际查看的吉卜力官方电影场面图，按草地、树林、房屋、天空分组，并保留官方作品页、原图与出版方资料链接。网络图片只作远端视觉研究，不进入游戏资产；可见画面的分析为项目归纳，不冒充画师原话。

| 层面 | 从参考提取的要求 | 游戏中的改造 |
| --- | --- | --- |
| 模型 | 先读出连贯体量，近景才读细节；厚度、分枝、屋檐和接地可信 | 树冠实体体量与较小叶簇结合；草叶不等高、弯曲；瓦片尺度调整、厚檐与真实封闭檐底 |
| 色彩 | 限制主色组，亮部暖、暗部有冷绿/蓝灰；细节围绕大色块组织 | 连续短草底色和疏密草簇；树冠内部较深，边缘亮叶克制；米灰泥、蜂蜜木、赤陶屋顶与青绿玻璃 |
| 材质 | 有使用痕迹但没有等距条纹或满屏高频噪点 | 木纹沿梁、柱和斜撑展开；瓦面使用跨瓦连续笔触；灰泥宽幅斑驳、石基不等距缝与柔和窗帘色层 |
| 光照 | 受光暖、树荫冷；阴影有大块关系，表面细节不被泛白光吞没 | 调整日照、冷色环境光、接触阴影、曝光与辉光，修正太阳阴影自遮挡条纹 |
| 天空 | 云体有清楚主轮廓、明亮上缘、蓝灰暗底；留出蓝天空隙 | 原创程序积云分两层、不对称云顶与柔边；加入随季节调色的低远山层，保留日月星河与天气渐变 |
| 镜头 | 主体和中景清楚，靠构图、色温与空气透视组织纵深 | 默认远焦强度0.12→0.045，开始位置从焦点外4m改为6m，过渡区更宽；保留开关与漫步无景深 |

## 具体改动与预算

草仍使用共享9三角网格，原种子、分布、密度排序、空间分块与默认45%密度不变。只调整派生叶形、根梢色、低频高度组、风弯曲与薄叶照明，避免发白尖叶海与黑色背面短茬。

阔叶冠从碎叶填充改为相互连接的主要体量，较小叶卡只补外缘和笔触；阔叶树三角数3630→3306、LOD1676→1640；果树3154→2902、LOD1500→1472。针叶保留3412/1576。植物原ID、支撑偏移、风、季节和LOD接口保持。

建筑保持真实门窗洞口、贴靠裁檐和4个绘制表面；最大默认12m房屋的屋面三角数不超过29000。木质檐底为真实7cm厚封闭几何，只在外伸檐环补顶/底/侧面，保留门窗和内部空间净空，没有通过关闭背面剔除掩盖白缝。

天空不使用体积云或逐步射线行进；两层角度云带以有限邻域计算轮廓与阴影。沿用32尺寸渐进辐射、480×270/8Hz平面反射和固定降水上限，继续支持四季、天气过渡、减少动态与摄影冻结。入口缩略图更新为本轮真实游戏捕获。

## 源件与审计

Blender版本保持5.1.2，Godot保持4.7.2，GUT保持9.7.1，无新插件。保留并更新11份植物`.blend`、材质库、源贴图、GLB、导入设置和生成清单。

植物生成器自带11件重开/GLB审计；独立执行`tools/art/audit_sources.py --root ROOT --output OUTPUT --extra-manifest art_source/art_pass_01/nature/manifest.json`，重开原46源模型与本轮11植物源。材质库另重开9个材质图及9张源图，哈希与运行贴图一致。地表原4张源图字节保持，仅调整游戏中融合配色。

`python3 tools/art/audit_foliage_evidence.py --root "$PWD"`重新测量当前PNG覆盖与GLB尺寸并绑定SHA：LOD最大尺寸差4.147%，通过原12%门槛；旧辅助报告明确归档为`historical_*`。本轮未做两次独立完整生成，当前确定性报告明确为`not_retested`，不复用旧版“双次一致”作为本轮证据。

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/build_art_foliage.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/build_art_materials.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/audit_sources.py -- --root "$PWD" --output reports/painterly_sources.json --extra-manifest art_source/art_pass_01/nature/manifest.json
```

## 测试与可重复验证

```bash
python3 tools/quality/week_thirteen_checks.py
# 以下桌面GPU检查全部串行，不与Blender渲染或其他Godot进程同时测性能
python3 tools/quality/painterly_views_checks.py --diagnostic
python3 tools/quality/sky_weather_native_checks.py
python3 tools/quality/walk_native_checks.py
python3 tools/quality/pond_water_native_checks.py
python3 tools/quality/week_thirteen_native_checks.py
python3 tools/quality/walk_performance_checks.py --transitions
python3 tools/quality/weather_budget_checks.py
```

W13门槛至少89项，新增12项回归覆盖顺纹UV、材质坐标、屋顶成本/4draw、封板闭合、低机位正面可见性、贴靠与门窗净空、草根固定/无退化三角、树冠覆盖与预算、光照/天空及中景清晰度。旧镜头测试的精确焦点偏移同步新6m设计，仍验证跟随缩放、关闭开关与源隔离。

原生11组固定镜头与修改前相同的世界、种子、位置和时间，含默认景深/无景深、建筑近景、池岸/树林/草近景、夏日天空、秋阴、冬雪、暮色与夜间。用游戏真实捕获检查源/历史不变及1920×1080帧缓冲；图像展示不代替编辑/导出回归。

阴影诊断分别隔离TAA、AO和太阳阴影。低bias控制能重现规则条纹；提高太阳bias后条纹减弱，同时保留与“无太阳阴影”画面的明显差异。这是针对渲染瑕疵的像素检查，不是用数值给艺术风格打分。

原生复核还修正了容器排序会清除图标缩放的问题，选中反馈在布局完成后持续保留。合成按钮按下/松开按单个输入批次投递，防止原生鼠标移动在两帧之间打断点击；仍走实际GUI事件与信号。雷光使用庭园上方的广域Omni闪光，保留蓝白闪光与减少动态禁闪；避免增减第二盏平行光。桌面检查显式保持窗口可见，冻结像素比较等待已固定状态渲染和TAA收敛后开始。

## 证据与视觉复核

源码`5876c0607e2dc9c60668a7f2ce6bdf51abd00980`。累计745项Godot/30,967断言 + 28项Python，0失败/0跳过、负控通过；新增12项/527断言。完整累计后最终W1389项/11723断言另行重跑，覆盖最后的局部雷光和持续图标反馈。

11固定机位、阴影隔离及天空天气18/漫步摄影18/水面9/既有界面22项原生检查通过。墙面高频残差由约0.0200降至0.0131，仍保留与无太阳阴影画面约0.0311的差异；不将这些诊断数当作风格分数。

24屋/1000源、1920×1080、默认45%草，三种粒子交叠的30秒漫步帧p95为8.961ms、max22.585ms；暴风雨/暴风雪/沙尘暴各30秒分别12.121/13.333/11.673ms，RSS峰值916.47MiB。20ms帧p95/2GiB目标通过，冷启动和旧编辑尖峰仍开放。正式文件哈希未变，未替换旧包。

[交付收据](evidence/painterly/delivery.json)记录最终源码、测试数、源件审计和性能。

| 主题 | 修改前 | 修改后 |
| --- | --- | --- |
| 默认构图 | [前](evidence/painterly/before/overview_default_focus.png) | [后](evidence/painterly/after/overview_default_focus.png) |
| 无景深诊断 | [前](evidence/painterly/before/overview_sharp.png) | [后](evidence/painterly/after/overview_sharp.png) |
| 屋檐与材料 | [前](evidence/painterly/before/cottage_detail.png) | [后](evidence/painterly/after/cottage_detail.png) |
| 池岸漫步 | [前](evidence/painterly/before/pond_walk.png) | [后](evidence/painterly/after/pond_walk.png) |
| 树林 | [前](evidence/painterly/before/forest_walk.png) | [后](evidence/painterly/after/forest_walk.png) |
| 草地 | [前](evidence/painterly/before/grass_detail.png) | [后](evidence/painterly/after/grass_detail.png) |
| 夏日天空 | [前](evidence/painterly/before/summer_sky.png) | [后](evidence/painterly/after/summer_sky.png) |
| 秋天 / 冬天 | [秋前](evidence/painterly/before/autumn_overview.png) · [冬前](evidence/painterly/before/winter_overview.png) | [秋后](evidence/painterly/after/autumn_overview.png) · [冬后](evidence/painterly/after/winter_overview.png) |
| 暮色 / 星空 | [暮前](evidence/painterly/before/sunset_walk.png) · [夜前](evidence/painterly/before/night_walk.png) | [暮后](evidence/painterly/after/sunset_walk.png) · [夜后](evidence/painterly/after/night_walk.png) |

技术测试不代表玩家已经接受最终画风。旧Windows/低配/物理触控板与听感、冷启动、编辑尖峰、首次玩家和M4/M5门槛继续开放；旧安装包未覆盖。
