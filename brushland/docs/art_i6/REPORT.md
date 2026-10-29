# I6：全量美术源库、资源接入与复核

2026-10-30（本轮开始于2026-10-29）。本次结束I2–I6连续制作，按迭代分别提交源码、文档与截图。I2为连续岛面/材质，I3为分层植被/浅湾水，I4为建筑/蒙皮/图标，I5为三套构图/动态表现，I6补全源库、衣装/动作、道具、资源映射与压力复核。

## 已交付

原清单**117条记录/170份资源**全部有可加载源文件；其中MVP为111条/161份，POST为6条/9份。逐项路径、格式、阶段与SHA256在[source_catalog.json](source_catalog.json)，CSV保留原规格、数量和验收条件，状态改为`source_available`，视觉接受单列为待审。原交付排期保留历史目标周，并附实际I6交付位置，不改写成历史阶段已验收。

- 六类建筑外观及12种独立模块；主屋和茶亭屋顶高度、温室框架、墙窗/入口、门廊/阳台、地基与烟囱尺寸进一步校正。
- 完整自然物与16类摆件源件；补草、灌木、芦苇、藤蔓、岩石变体、灯笼、信箱旗帜、伞、行李、壶、围栏等，附可复用握持/连接标记。
- 四套居民外观，共享9骨蒙皮；五件可切换衣装与四套独立头饰。海鸥/猫各10骨，具有实际权重和独立动作。
- 具名Animation资源覆盖原ANI清单；走/挥手/坐下-坐姿-起身/浇花/饮茶/拖箱/提灯抱盆、海鸥飞站起降、猫走睡伸展；另有坐姿看海和船体轻摇源。动作可在AnimationPlayer中编辑，运行时共用动作库。
- 24个原创SVG与模型缩略图接入工具栏/心愿/操作；三套可进入构图、午后/日落环境、窗灯与灯塔扫光，场景保持可编辑和可存档。
- 秋树、雨景/涟漪、灯串、帆篷、相框与坐姿看海作为可选美术源交付。未把后续天气/相框玩法误写成已完成。

[使用、许可与格式说明](SOURCES.md) · [模型预算](budgets.json)

## 实际画面

[港湾六机位](../../snapshots/art_i6/gl_compatibility/harbor.png) · [花园](../../snapshots/art_i6/garden/harbor.png) · [灯塔岬](../../snapshots/art_i6/lighthouse/whole.png) · [实际UI](../../snapshots/art_i6/interface.png) · [本周截图](../../snapshots/week_11.png) · [最终30秒动态](../../snapshots/art_i6/motion.mp4)

[建筑图鉴](../../snapshots/art_i6/catalog/buildings.png) · [模块](../../snapshots/art_i6/catalog/modules.png) · [自然](../../snapshots/art_i6/catalog/nature.png) · [摆件](../../snapshots/art_i6/catalog/props.png) · [角色与衣装](../../snapshots/art_i6/catalog/actors.png) · [地形设施](../../snapshots/art_i6/catalog/terrain.png) · [可选资源](../../snapshots/art_i6/catalog/optional.png)

截图来自原生Godot视口。视频由引擎MovieWriter录制后保留末30秒，固定30fps；它展示动作，不作性能依据。原始录制尺寸和帧数另列在`docs/reports/art_i6/motion_recording.json`。

## 验证与性能

资源存在/哈希/加载、86份显式面数预算、具名动作/衣装预算、三构图重载与入住、蒙皮、草层、连续表面、两渲染器UI/编辑/摄影回归均有独立记录。既有世界/建筑/居民存档/生活事件/过桥/GLB及合批规则继续通过。完整结果见[validation.json](../reports/art_i6/validation.json)、[补充原生检查](../reports/art_i6/finish_validation.json)及[suite_rules.json](../reports/art_i6/suite_rules.json)。

静态资源复用比较完整材质存储属性和几何，不再只比颜色；修复节点级材质覆盖挡住表面级去重的问题。实例化保留LOD和shadow_mesh，隐藏、动态、蒙皮、自定义可见边界与未知shader继续分流。原生结构检查覆盖这些边界；六机位优化前后像素均通过既定容差，近景最大平均RGB误差约0.000159、显著差异像素比例低于0.5%，并不宣称逐像素完全一致。两渲染器材质/法线/阴影正控及破坏负控均有证据。

最终五分钟压力数据在本节末尾自动归档；不得以短测或视频代替。测试机为Apple M4 Pro/macOS15.1/Godot4.7，默认Compatibility/OpenGL，另有Forward+/Metal固定岛对照。原PRD的M1/8GB与Windows实机未测。

## 未关闭的接受项

1. **绘制调用≤200目标未通过**：小港湾Compatibility主机位仍约345次；Forward+同场景约183次，但本次不据此自动切换全项目渲染器。高密度整岛需继续做跨块实例组织、材质/透明pass收敛与目标硬件画质档。
2. **G1视觉接受待用户审阅**：没有把参考画面相似度或六项评分自动判为通过。水采用高度/岸距与天空反射，无SSR/平面倒影；叶片为透明簇，复杂逆光、俯视和远景仍需人工观察。
3. **逐规格人工复核未代签**：源文件齐套与面数通过，不等于每条拼接、LOD、尺寸、动作穿模和UI缩放验收都通过。简化骨架无足底IK，复杂坡面、起坐与手杯/提灯/抱盆对位需进一步实机审阅。
4. **原生源格式及功能边界**：大部分新增件交付Godot场景/资源，非逐件独立GLB；设置/存档/拍照组件和相框源可复用，已有三手动槽与滚动备份；本轮未补做它们的完整故障注入。完整天气与所有平台UI适配也未因美术齐套自动通过。

进入后续功能开发前，优先使用三构图和动态预览做一次人工视觉审阅，再关闭G1；其后处理绘制数与目标设备G2。音效、按键重绑、存档故障注入及无讲解试玩继续原功能计划，不能算作本轮美术通过。

## 复现

```sh
python3 tools/run_art_stage.py art_i6
python3 tools/run_art_finish.py
python3 tools/run_art_pressure.py
godot --path .
```

后两个原生检查需显示/GPU环境。`run_art_pressure.py`真实运行约五分钟并每两秒采样进程RSS；短测只能通过手动`--duration=10`生成`pressure_smoke.json`。图鉴入口为`res://game/art_lab/catalog_gallery.tscn`。历史I1–I5证据保留在对应目录，本轮不以当前重拍覆盖历史。

## 最终五分钟压力结果

真实运行300.009秒，1920×1080，正交相机42m绕岛，前半午后/后半日落；40建筑（25居所、各5座茶屋/温室/灯塔）、400装饰、12居民、6动物。陆地1600格，较原PRD示例1200格更大，建筑组合也不同；这是完整数量压力样板，不等于原目标硬件/AC已验收。远景草层保留55%实例，物件数量不删减。

| 指标 | I6优化前 | 最终 | 结论 |
| --- | ---: | ---: | --- |
| 帧间隔p95 | 11.723ms | 9.328ms | 仅本机帧间隔，非独立GPU耗时 |
| 可见三角面峰值 | 357,870 | 169,148 | 通过≤350k |
| 绘制调用峰值 | 1,989 | 1,784 | 未通过≤200 |
| 场景构建 | 1961.9ms | 1835.9ms | 仅场景构建，非冷启动加载 |
| 进程RSS采样峰值 | — | 552.5MiB | 152次采样；不含独立VRAM统计 |

午后p95 8.700ms，日落p95 9.512ms。结果见[pressure.json](../reports/art_i6/pressure.json)、[进程采样](../reports/art_i6/pressure_process.json)、[范围说明](../reports/art_i6/pressure_scope.json)和[分项门槛](../reports/art_i6/quality_gates.json)。G2保持未通过，M1/8GB与Windows未测；未将过程执行成功写成所有预算通过。
