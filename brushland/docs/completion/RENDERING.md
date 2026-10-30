# R2 渲染交付说明

项目保留Compatibility为默认渲染器；Forward+/Metal可运行并通过同一回归，当前没有将本机结果推断为M1或Windows兼容。

## 修改与保护范围

- 仍以1m源格和8m作者块保存/编辑，完整源节点、GLB、原始LOD和shadow_mesh不改。新`project_render_batches.gd`仅为已冻结的本项目静态资产生成LOD0显示代理。
- 不透明平色材质在完整存储属性签名相同时共享材质，色彩搬到顶点；带纹理/原有顶点色的完整输入保留。未知shader、蒙皮、动画分支、叠加材质、自定义顶点通道与非默认可见范围保留原显示。
- 非均匀缩放且有曲面插值法线的源网格保留原法线/网格，通过MultiMesh复用；避免烘焙法线造成近景明暗变化。原StaticBatcher不替换为弱化检查的通用实现。
- 地形代理32m分组，建筑/摆件代理32m分组，作者块仍是8m。缓存未变化的几何、材质和作者块记录；变更或移物只使相关区域失效。直接编辑不可变源的工具必须调用invalidate_geometry，普通游戏编辑会替换相关作者块。
- 代理根、网格节点、叶/曲面MultiMesh、草层与烟节点持久复用；只为变化的组替换网格/缓冲，删除消失组，避免每笔重新注册整个渲染对象集合。新增身份回归检查同一代理节点在未变化时保持不变。
- 不可变地表快照预建4096格高度数组和地基空间索引，替代每个法线采样遍历全部建筑；约1.35万个边界/半格/法线偏移点与原函数逐点相等。
- 三层草用全岛实例化；按各源块的本地rank交错，降低密度时全岛均匀保留，避免只剩半岛有草。批量上传MultiMesh.buffer。叶片保留自己的shader和动画时钟。
- 轻烟仅对本项目已知的无光照透明材质走独立8m分组，按相机深度排序、每帧更新原源透明度/变换；温室玻璃等其他透明物不混入该路径。
- 水域场按高度/陆地掩码缓存；道路与换色不重新做距离传播，改高度但不改海岸仅更新对应高度像素，改海岸时才重算两遍chamfer，ImageTexture复用。
- Compatibility的每物件灯光上限设为32，以覆盖标准样板的18个局部灯光；不通过删除灯光满足绘制预算。该配置会增加shader成本，外部目标硬件仍需复测。[引擎官方灯光说明](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)解释了该限制及拆分网格的权衡。任意大量灯塔密集重叠仍应单独测量，不由标准40建筑配比担保。

流畅档关闭太阳阴影、草卡密度乘0.6，中等档保持完整；视野较远时草卡再乘0.55。对象、居民、动物数量相同，字体与界面不降清晰度。照片相机剔除第20层笔刷预览与其阴影。

## 可复现证据

- `python3 tools/run_art_stage.py completion_r2`：13步资源/预算/三构图/骨架/保真代理/植被/地表/双渲染器编辑与摄影回归；验证日志在`docs/reports/completion_r2`。
- 六机位用同一存档、世界时钟、LOD0作对照。源路径运行art_lab并加`--project_batches=0 --force_lod0=1 --label=lod0_source`；代理路径`--label=proxy_on --force_lod0=1`；都加`--iteration=completion_r2`。`python3 tools/check_project_pixels.py`默认比较双方都指定force_lod0的proxy_on图；保留的曲面/实例也必须采用同一LOD设置，不与普通自动LOD的gl_compatibility直接混比；需Pillow/numpy，逐像素均值阈值0.001、超过3/255的像素比例阈值0.5%。六视图通过，最敏感近屋差异比例约0.289%。不将此等同于透明动态、全美术主观接受。
- 标准1200陆地/40建筑（12居所）/400装饰/12人/6动物的最终5分钟，直接运行macOS Release包：`python3 tools/run_completion_pressure.py`；每2秒升/降一笔、旋转相机，半程夜景。报告`pressure.json`及`pressure_process.json`；每分钟截图在`snapshots/completion_r2/pressure`。
- 早期失败的完整静止1600陆地样板：draw219、p9514.721ms，保留`pressure_before_smoke*`，不能用其旧峰值替换最终结果。加入连续编辑后初始约268ms，经缓存/分区降到约81.5ms的1600陆地10秒短测保留`pressure_smoke.json`。不同陆地/建筑配比，不能直接作为与I6同条件的比例比较。
- 标准场景的流畅档成品10秒短测在`completion_r4/low_smoke.json`，只为功能/数量检查，不作为完整5分钟性能签收。曾发现Release会省略assert内有副作用的构建调用，旧短测明确作废并保留`invalid_fixture_low_smoke.json`；当前使用显式调用、运行时数量校验与外部报告复核。

正式编辑延迟从paint开始，由RenderingServer.frame_post_draw回调被动记录完成时间；主循环仅等待process_frame，避免测量工具在绘制回调上停滞。帧时也来自实际绘制完成事件。截图在回调取像后后台压缩写盘。编辑延迟计时，包含CPU重建与绘制等待；仅CPU指标不替代它。旧不持久代理在此口径下五分钟p95 200.835ms、draw202失败，保留pressure_before_persistent；此前CPU口径与短测也分别保留，不作为最终通过证据。

原生MultiMesh测试需GPU，headless的dummy后端不保存实例变换；不能用dummy结果替代本机保真。压力测量时没有并行其他GPU验证/视频编码。RSS每2秒采样，可能漏瞬时尖峰；引擎MEMORY_STATIC在Release为0，不用于判断1.5GB进程内存门槛。
