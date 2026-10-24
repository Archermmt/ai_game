# 池塘水面：搜索、选择与实现

用户反馈原池塘缺少倒影/波纹。本轮在现有池塘轮廓、编辑和保存模型上增加水面表现，原批准PRD不覆盖。

## 搜索结论

参考了作者发布的[Absorption Based Stylized Water](https://godotshaders.com/shader/absorption-based-stylized-water/)与[Stylized Water Godot Port](https://github.com/Jtfinlay/stylized-water-shader)，以及[Godot官方水面示例](https://docs.godotengine.org/en/stable/tutorials/shaders/your_first_shader/your_second_3d_shader.html)。共同可用思路是波纹法线、低粗糙度、深度吸收和岸边接触细节；没有直接复制候选代码、纹理或安装插件。本轮Shader为项目原创实现。

[官方反射说明](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/reflection_probes.html)列出天空、探针和SSR的取舍：SSR受屏幕内容限制；局部探针能补充屏外信息，但更新会重绘周围物体。首先试做UPDATE_ONCE局部探针，发现倒影在此视角仍模糊，并在退出出现7个Texture RID泄漏。最小Camera3D+ReflectionProbe场景复现，符合[引擎问题#122498](https://github.com/godotengine/godot/issues/122498)。未升级或修改锁定引擎，也未忽略警告计通过。

最终改用独立低分辨率平面反射SubViewport，避开上述探针图集路径；最终场景无ReflectionProbe。失败方案只保留诊断日志，不作为产品路径。

## 当前效果

- 镜像相机渲染实际附近树木、桥和建筑，水面采样该图像，随视角形成倒影；不是把原屏幕随意上下翻转，也不是画一块固定假倒影。
- 三组不同方向的解析波纹改变水面法线并扭曲倒影，细环扩散帮助读出水面运动；雨/暴风雨增强波纹。
- 使用实际场景深度区分浅水和深水、柔化接触边缘；保留青绿庭园色，不使用海面巨浪或写实高对比镜面。
- 夜间和天气沿用当前环境光/天空；减少动态令波纹稳定，摄影冻结沿用原水面freeze_time/sample_time接口。

## 预算和边界

反射纹理480×270，上限8次/秒；静止相机只在几何、天气或游戏时间10分钟窗口变化时更新。不逐帧重绘全部场景，不重建池塘网格；原源与事务不变。反射相机关闭SSAO/辉光，避免捕获水面自身、地形、基础、地表草和编辑辅助。保留近处桥、树和建筑作为倒影内容；这是受预算约束的场景反射，不含水下物理模拟或完整镜面裁切。

捕获层只用于派生显示节点，退出恢复原层；删除池塘后关闭捕获，新建复用原SubViewport。池岸原形状和水位不变，旧周场景仍保留历史水材质用于回归。未改Blender源或资产导入版本。

## 复验

```bash
python3 tools/quality/week_thirteen_checks.py
python3 tools/quality/pond_water_native_checks.py
python3 tools/quality/week_thirteen_native_checks.py
python3 tools/quality/pond_water_performance_checks.py
```

原生全部串行、明确Dummy。水面像素门禁先生成实际可见水面遮罩，避免把岸上物体直接变化当作倒影：只在水面内比较反射开启/关闭、波纹不同相位、减少动态稳定性，以及测试物体红→蓝导致的倒影变化。真实池塘网格/编辑源保持一致；退出日志中有RID泄漏即失败。

性能分别测24屋/1000源60秒20笔提交，以及同容量持续旋转相机30秒；保留全部帧间隔、初始构造尖峰和每个反射捕获计数，帧p95、内存和既有首笔编辑max门槛独立报告。

[证据目录](evidence/pond_water/)。

## 最终结果

源码`06257691ff3108044a1a8ff770bae06db7322a9c`。累计700项Godot/21,800断言 + 28项Python，0失败/0跳过，历史负控通过；新增4项/23断言，W13共44项/2556断言。水面9项原生检查及既有UI22项通过，正式作品/偏好前后哈希未变；最终退出无脚本错误或RID泄漏警告。

在12,861个水面样点上，反射开关RGB均差0.05513，红/蓝测试物体倒影均差0.02427，波纹相位均差0.00487；减少动态差为0。前后整体画面对比只作视觉参考，不把不同TAA设置造成的差异计作提升量。

满容量60秒20笔：帧p95为12.500ms，提交p95为88.430ms，提交max为233.671ms，RSS峰值1083.88MiB。持续绕转30秒保留2303帧，帧p95为14.166ms，反射实际捕获211次；整体最大帧间隔2233.014ms包含初次构造，没有剔除。帧p95/内存/提交p95通过，**首次提交max150ms仍未通过**；不关闭冷启动与外部验收门槛。

[交付收据](evidence/pond_water/delivery.json) · [改前](evidence/pond_water/before/pond_near.png) · [改后](evidence/pond_water/after/pond_near.png) · [整体场景](evidence/pond_water/after/pond_full.png) · [雨天水面](evidence/pond_water/after/rain_water.png) · [夜间水面](evidence/pond_water/after/night_water.png)。
