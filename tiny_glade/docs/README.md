# 风栖小筑 · 项目文档

阅读入口：[产品需求文档 PRD](PRD_风栖小筑.md)。核心玩法、分期范围、建造规则、美术方向、场景方案、完整资源清单、技术验收和切片排期均汇总在这一份文档中。

开发入口：[Godot MVP 开发计划](DEV_PLAN_MVP_Godot.md)，只覆盖“林间坡地”一个试玩场景；包含模块接口、Godot 标准、Blender / Three.js 工具链、插件选型、任务排期和验收追踪。

| 交付物 | 内容 |
| --- | --- |
| [开发状态](../STATUS.md) | 每周任务状态、测试结果与未通过门槛 |
| [运行说明](../README.md) | 启动、操作、测试和导出命令 |
| [每周测试约定](TESTING.md) | W01–W13 测试范围与证据要求 |
| [Painterly Grass 集成计划](DEV_PLAN_PAINTERLY_GRASS.md) | G0–G5技术/视觉/性能验收与可运行场景交付；当前为计划 |
| [W14 集成台账](weekly/week_14/README.md) | 阶段状态、体验入口与证据；实现尚未开始 |
| [W13 自然庭园扩展](weekly/week_13/README.md) | 自然起伏、图标工具、虚构日历、昼夜四季与天气 |
| [CLEANUP-01 清理记录](weekly/cleanup_01/README.md) | 缓存与旧产物清理、依赖保护及验证 |
| [PERF-02 性能优化](weekly/perf_02/README.md) | 高度查询索引、草块/风材质复用及真实鼠标响应验证 |
| [PERF-01 性能报告](weekly/perf_01/README.md) | 上一轮原始性能样本与剩余尖峰 |
| [W12 内部交付](weekly/week_12/README.md) | 包哈希、操作说明、资产/验收索引与待验门槛 |
| [UX-03 悬停修改](weekly/ux_03/README.md) | 房屋、屋顶、门窗与桥阶就地拖动 |
| [UX-02 交互修订](weekly/ux_02/README.md) | 底栏与直接操作 |
| [W11 缺陷收尾](weekly/week_11/README.md) | 本机修复与首次玩家测试协议 |
| [W10 体验收尾](weekly/week_10/README.md) | 音频、输入、回归与试玩材料 |
| [ART-01 美术返工](weekly/art_pass_01/README.md) | 建筑、手绘材质、植物与美术源件 |
| [底栏、远景柔焦与草](weekly/ui_meadow_01/README.md) | 展示与性能设置 |
| [W09 验收报告](weekly/week_09/README.md) | Mac手势、摄影/模板/入口、满容量60秒与20分钟组合回归；局部性能缺陷仍开放 |
| [W08 验收报告](weekly/week_08/README.md) | 五槽/备份/自动保存、设置与重绑、SCN-01、局部性能与实机环绕录像 |
| [W07 验收报告](weekly/week_07/README.md) | 工具 Dock / 属性卡、十二色板、拉伸绿篱、资源包装与存档/示范草案开工 |
| [W06 验收报告](weekly/week_06/README.md) | 分类植被、局部重建与分帧发布、中文主题、茶具提灯及声音/图标资源 |
| [W05 验收报告](weekly/week_05/README.md) | 池岸、桥阶与灰模回退闭环 |
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

开发进度以 [STATUS.md](../STATUS.md) 为准：已完成 W01–W12 本机开发、ART-01 美术、UX-02/03 交互、PERF-01/02 性能修复与用户授权的W13自然庭园扩展。Windows 真机、最低配置、真实音频与触摸板、首次玩家及最终放行仍待验；不自动开启 P1/P2。

![风栖小筑主视觉](art/concepts/01_key_visual.png)
