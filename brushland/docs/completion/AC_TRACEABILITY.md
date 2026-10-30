# AC证据矩阵 · 0.3.0候选

2026-10-30。自动化通过表示列出的确定性规则/本机行为通过。视觉质量、真实手势操作和目标设备接受保留人工栏，未将资源齐套或源码测试等同于全部MVP签收。

| AC | 已执行证据 | 本机结论与人工补测 |
| --- | --- | --- |
| 01 | test_world、test_acceptance_rules、test_surface：同笔去重、边界、高度、50历史、完整撤销、连续表面/重载 | 规则通过；岸线六机位已输出，连续拖画手感待外测 |
| 02 | test_building、test_acceptance_rules；实际提交保护支撑/入口且提示跳过 | 数据通过；手工确认提示与预览是否容易理解 |
| 03 | test_building、test_acceptance_rules：2→3花、garden及undo；原床位由object ID保持 | 规则通过；缩远可辨性待人工 |
| 04 | test_acceptance_rules：garden优先、锁定/解锁当前邻接重算；test_save_faults保存锁定 | 规则通过；各角度外观人工复核 |
| 05 | test_residents、test_acceptance_core：首人8.1秒、无入口路/码头/码头路/互通原因；test_playable四屋到人 | 通过；修复后可给已放码头岸端/桥头画路；内湖外海由BFS验证，待外部操作复核 |
| 06 | test_acceptance_rules、test_bridge_activity：合法桥可跨，7格/异高/堵门拒绝 | 规则通过；已补受阻斜纹与文字、可放置时的屋型预览；提示易懂性待人工 |
| 07 | test_playable/test_acceptance_rules释放被移除设施预约；test_app补居民桥中央拆桥→安全岸边→undo恢复 | 本机自动通过；长期自然活动中的动态改路仍列外测观察 |
| 08 | test_acceptance_core、test_save_faults、test_playable：愿望完成/收起、手记、身份、锁定与暂停/设置回存 | 数据通过；手记面板/收起按钮需人工理解验证 |
| 09 | test_acceptance_core：50次混合画地/移物/旋转/换色/锁定逐帧快照undo/redo，无足印重叠；完成记录不回滚 | 通过 |
| 10 | test_product_ui：独立1920×1080、相机/世界不变、重绑、1280×720/150%控件边界、预览独立层；test_app双路径摄影完成后还原暂停 | 本机通过；默认1440×900与独立1080p输出已实拍；两分辨率全部工具的实际鼠标操作待外测 |
| 11 | test_save_faults：部分写入/备份复制/原子替换故障，旧主档字节不变且能读，重试成功；3备份、16类坏输入不改内存 | 注入通过；实际OS权限恢复与异常退出人工转交，未破坏用户主档 |
| 12 | 实际macOS候选包、PRD精确1200陆地/40建筑/400装饰/12人/6动物、五分钟墙钟及每2秒编辑；报告completion_r2/pressure*.json | M4 Pro本机结果见FINAL_REPORT；M1/8GB、Windows未测 |
| 13 | test_acceptance_core：arriving期间拆屋、保存重载、原ID/人数保留、无双床位、补可达屋优先安置 | 通过；已补单船末段靠泊与坐船乘客、暂停和在途拆屋/回岸重载；不实现整条航路航运或交通避碰 |

执行记录在`docs/reports/completion_r3/core_tests.json`、`native_tests.json`（含靠泊乘客/稳定偏好）和各测试日志；完整美术13步在`completion_r2/validation.json`，同LOD0六机位保真在`lod0_pixels.json`。独立包检查在`completion_r4/package_checks.json`。人工步骤和记录表见TEST_HANDOFF。

六愿望从同一演示岛自然模拟完成的集成覆盖由test_playable执行，桥跨越并到达岸边活动由test_bridge_activity执行。它们使用模拟时间加速，不代替30分钟真人试玩。

## 外部执行边界

用户明确本轮先准备测试包，不安排M1/Windows设备和真人。因此T39/T40的外部运行、G1人工六项评分与T42最终发行签收保留“未执行”，不以准备了步骤改成通过。POST天气/相框等为后续范围，仅源件可用；不计入MVP闭环。
