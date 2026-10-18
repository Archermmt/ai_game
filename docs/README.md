# 风栖小筑 · 项目文档

阅读入口：[产品需求文档 PRD](PRD_风栖小筑.md)。核心玩法、分期范围、建造规则、美术方向、场景方案、完整资源清单、技术验收和切片排期均汇总在这一份文档中。

开发入口：[Godot MVP 开发计划](DEV_PLAN_MVP_Godot.md)，只覆盖“林间坡地”一个试玩场景；包含模块接口、Godot 标准、Blender / Three.js 工具链、插件选型、任务排期和验收追踪。

| 交付物 | 内容 |
| --- | --- |
| [开发状态](../STATUS.md) | 每周任务状态、测试结果与未通过门槛 |
| [运行说明](../README.md) | 启动、操作、测试和导出命令 |
| [每周测试约定](TESTING.md) | W01–W12 测试范围与证据要求 |
| [W04 验收报告](weekly/week_04/README.md) | 曲线路径生门、地形生产后端、自然/道具与环境联动 |
| [W03 验收报告](weekly/week_03/README.md) | 建筑参数、门窗恢复、三树 LOD / 共享图集及石径开工 |
| [W02 验收报告](weekly/week_02/README.md) | 地形/池岸、异步事务、编辑工具与基础材质实测 |
| [W01 验收报告](weekly/week_01/README.md) | 工程、数据、资产与风险样板的实测记录 |
| [Godot MVP 开发计划](DEV_PLAN_MVP_Godot.md) | 12 周 / 4 人全职等效的实施方案；含 47 个 P0 资产的任务映射 |
| [MVP 开发任务表](planning/mvp_backlog.csv) | 任务、主责、人天、依赖、资产 ID、验收与完成定义；初始状态为待开始 |
| [PRD](PRD_风栖小筑.md) | 中文完整方案；含四张概念图和逐项资源附录 |
| [资源清单 CSV](art/asset_manifest.csv) | 87 个资产族；MVP 47、P1 27、P2 13；UTF-8 BOM |
| [概念图生成记录](art/prompts/concept_prompts.md) | 四组完整提示词与工具说明 |
| [C01 主视觉](art/concepts/01_key_visual.png) | 林间坡地小屋与庭园 |
| [C02 场景方向板](art/concepts/02_scene_board.png) | 林间坡地 / 风铃茶庭 / 溪谷水车 |
| [C03 建筑套件](art/concepts/03_architecture_kit.png) | 墙体、屋顶、门窗与连接模块方向 |
| [C04 道具与自然](art/concepts/04_props_nature.png) | 八类生活道具、树木、灌草与岩石 |

开发进度以 [STATUS.md](../STATUS.md) 为准；前四周已建立 Godot 地形/池岸/编辑风险样板、三种门与两种窗源模型，以及笔触化基础材质；W03 接入尺寸预览、门窗恢复、三树 LOD；W04 接通曲线石径与门窗、正式地形刷和自然/道具源件。正式模型集、材质与后续功能按周验收，不将概念图或技术样板计为全部资产完成。图示中的藤蔓、炊烟、复杂廊檐等后续内容，在 PRD 第 8 节标明范围。资源数量按资产族与基础交付单元统计，不能当作模型数量。

![风栖小筑主视觉](art/concepts/01_key_visual.png)

- [W05 庭园、浅池、短桥/短阶与回退闭环](weekly/week_05/README.md)
