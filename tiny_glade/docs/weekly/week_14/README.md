# W14 · Painterly Grass 集成台账

2026-10-26：用户认可插件山谷样板并授权正式应用，F5默认入口现已采用Terrain3D和四层草。新增8项回归，累计789项Godot/37项Python、50项Metal原生检查通过；作品源、编辑和保存联动保留，性能后置。[正式庭园报告与实机](PRODUCTION_LANDSCAPE.md)。

2026-10-25：G0环境恢复与旧草基线已完成，见[G0报告](G0_BASELINE.md)。G1本地单体与材质展示已交付，见[G1报告](G1_GRASS_LAB.md)；源素材入库条款和用户视觉评价待验。G2本地对照已交付，见[G2报告](G2_GRASS_PATCH.md)；用户随后授权继续G3，可编辑本地副本见[G3报告](G3_EDITABLE_GRASS_GARDEN.md)；用户随后反馈片状感且不如原草，V2/V3改为需调整，G4/G5未开始。[诊断](../../art/PAINTERLY_GRASS_VISUAL_DIAGNOSIS.md)。

- [完整集成计划、场景体验与验收命令](../../DEV_PLAN_PAINTERLY_GRASS.md)
- [初步分析及只读统计](../../art/PAINTERLY_GRASS_ASSESSMENT.md)
- [项目当前状态](../../../STATUS.md)

2026-10-25追加：用户要求采用Terrain3D与ProtonScatter，先对齐demo美术、性能后置。已交付[山谷美术样板](LANDSCAPE_PLUGIN_LAB.md)，F6打开`app/landscape_lab.tscn`或从G1进入；新增8项回归，累计781项Godot/37项Python通过。本机Metal实拍通过，正式可编辑庭园迁移、用户视觉接受和性能门槛仍开放。

## 阶段台账

“技术通过”“用户视觉接受”“性能通过”分开填写。G0旧场景、G1统一预览入口与G2局部庭园已经存在，G3可编辑副本也已交付，G4/G5子场景仍为计划交付物。

| 节点 | 技术状态 | 用户视觉状态 | 新草性能状态 | 体验入口 | 执行证据/提交 |
| --- | --- | --- | --- | --- | --- |
| G0 环境/旧草基线 | 通过 | 旧草参考已采集，待用户体验 | 不适用；旧草两场预算通过 | 现有 `app/living_root.tscn`，F6 | [报告](G0_BASELINE.md)，实现`b710fb7` |
| G1 单体材质 | 本地技术通过；素材入库待验 | 待用户体验 | 未测容量 | `app/painterly_grass_preview.tscn`，F6 | [报告](G1_GRASS_LAB.md)，`304de9d` |
| G2 局部新旧对照 | 本地技术通过；素材入库待验 | 需调整：片状感，未接受 | 局部新旧各60秒；容量待G4 | `app/painterly_grass_patch.tscn`，F6 | [报告](G2_GRASS_PATCH.md)，`04ae506` |
| G3 可编辑庭园 | 本地技术通过；素材入库待验 | 需调整：不如原草、与参考差距大 | 未签核容量/编辑时延 | `app/painterly_grass_garden.tscn`，F6 | [报告](G3_EDITABLE_GRASS_GARDEN.md)，`d1a7911` / `06e5bf9` |
| G4 满容量预算 | 未开始 | 未评 | 未测 | 规划 `grass_capacity.tscn` | 待记录 |
| G5 候选版本 | 未开始 | 未评，最终节点V5 | 未测 | 规划 `grass_candidate.tscn` | 待记录 |

G1统一预览入口已交付为 `app/painterly_grass_preview.tscn`；已实现G1/G2进入G3与返回试验室的按钮；子场景位于 `features/painterly_grass/previews/`。完成的阶段可用F6直接体验，未完成阶段禁用入口；主游戏F5入口仍按项目当前配置运行。不得将打开旧场景写成已经体验新资产。

## 每阶段收据

阶段完成时填写以下信息，并关联 `evidence/painterly_grass/g0/` 至 `g5/` 的实际文件：

- 阶段、Git提交、工具版本、实际场景路径和F6体验步骤。
- 自动测试命令、非零测试数、失败/跳过数、负控与日志检查结果。
- 同机位新旧截图、参数/配方版本、源数据和正式文件哈希核对。
- 性能原始样本/统计/硬件条件，或明确标记本阶段未测。
- 用户视觉反馈原意、关联视角、已解决与待解决问题；无反馈填未评。
- 阶段决定：继续、留在本阶段调整或退回上一提交；旧缺口与外部门槛保持。

运行临时结果放忽略的 `reports/`；此目录只存必要证据，不存下载包、运行时、缓存、导出包或用户作品。改变Blender源/生成器后必须重开源件审计，不能只查GLB。

## 初始计划文档验证（历史）

仅验证文档链接、现有命令路径和阶段一致性，结果见[计划核对记录](evidence/painterly_grass/plan_verification.json)。该条只描述计划整理时的核对；后续G0实际游戏测试与旧草GPU记录见G0报告。新草GPU测试仍未执行。
