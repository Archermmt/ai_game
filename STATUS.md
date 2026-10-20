# 风栖小筑 · 开发状态

更新日期：2026-10-20（Asia/Shanghai）

## 当前阶段

**W09 本周实现、累计回归、原生摄影/发布包、20分钟探针及无缓存验证完成归档。局部编辑性能目标仍未通过，保留W10缺陷。**
默认入口 `app/week_nine_root.tscn`，Godot 4.7.2 Standard，版本 `0.9.0-w09`。
批准 PRD、开发计划和 backlog 保留基线；完整 MVP 仍按 M4/M5 门槛推进。

## 当前可试玩

继承 W01–W08 全部核心工具、五槽备份与本机偏好。当前 Mac 映射：
双指上下左右移动旋转，拉开/收拢缩放，Option+左键平移；右键旋转、中键/Shift+左键平移、滚轮缩放继续可用。
新增摄影、可保存构图、本地目录 PNG 输出、原生模板图、示范/同场景空布局双入口及可跳过提示。
摄影退出恢复编辑相机、选中状态和动态材质；仅明确保存构图时产生源事务。

## W09 任务

| 任务 | 实际进度 |
| --- | --- |
| T058 | 固定 24 体块/80树/800灌草岩石/120道具/1池/2桥源与压力存档；总实例预算修正为1000，植被分预算；60秒帧/编辑/首帧/RSS实测脚本，失败自动半密度复测，原始数据已归档；满容量局部205.478ms、半密度152.608ms均未达150ms，交T065 |
| T059 | 独立共享 World3D 渲染视口，1920×1080/2560×1440 PNG、本地目录选择/文件名清洗/失败重试；编辑 UI/轮廓隐藏、动态冻结可逆、构图存档；原生两尺寸图已验证 |
| T060 | 推荐镜头实拍512×288 UI-06，接入布局入口和存档空缩略图回退；有效用户缩略图优先，来源与哈希在 art_source/week_09 |
| T061 | AC01–08组合、生产场景50笔含删父建筑/待附着、20手工道具和远处源保护、50撤销/重做；实际1201.536秒探针通过，50提交/50撤销/50重做 |
| T062 | 示范/空布局入口复用地形和外围树幕；提示可跳过；已有槽覆盖确认、未存切布局三选；新增摄影/入口150%适配与15分钟体验脚本 |

## 测试与证据

累计 **446项 / 10509次断言**，0失败、0跳过。W01–W09分别42/52/42/50/45/68/51/62/34项。
`e10095e` 从Git archive、无导入缓存重跑全部通过，逐周跨进程保存重载和负控通过。
保持逐周跨进程重启及故意失败负控；引擎错误、失败、跳过、空套件均令 gate 失败。
原生摄影两尺寸及512×288图均可解码，失败后重试、返回源/相机/选择通过；100/150%界面看图复核。
满容量60秒p95最高18.056ms、大刷462.335ms、RSS峰值744.25MiB；首帧三轮1.395/1.427/1.421秒。
局部目标未过；主线程回调测量不替代物理输入延迟，GPU计时不可用。

```bash
python3 tools/quality/run_checks.py --week 9 --negative-control
python3 tools/quality/export_smoke.py --week 9
python3 tools/quality/week_nine_render_checks.py
python3 tools/quality/clean_checkout.py --week 9
```

[W09验收与原始证据](docs/weekly/week_09/README.md) · [W09测试契约](docs/weekly/week_09/TEST_PLAN.md) · [15分钟体验脚本](docs/weekly/week_09/PLAYTEST_15_MIN.md)。

## 存档与设置

正式作品沿用 `user://week_08/saves/slot_01.wgs`–`slot_05.wgs`，设置沿用 `user://week_08/preferences.cfg`，
固定用户目录 `WindhavenDiorama`，不迁移、不覆盖旧目录。
W09 QA原生自动保存使用 `user://qa_w09_native`，单测使用 `user://qa_w09_scene`；W08 QA也补上独立目录默认值。
长时首测发现的QA路径问题已修复，本轮生成的空探针和压力探针移入QA目录；后续原生脚本核对正式目录哈希不变。
用户作品、偏好、导出包和缓存不入Git。构图书签随作品保存，摄影PNG保存到所选目录。

## Git 里程碑

| 周次 | 已归档里程碑 |
| --- | --- |
| W01 | `db4451f` 实现 / `67be9cb` 归档；[工程与建造](docs/weekly/week_01/README.md) |
| W02 | `b0b556d`；`v0.2.0-w02`；[地形/事务](docs/weekly/week_02/README.md) |
| W02 Mac | `5a5a8b3`；[输入补充](docs/weekly/week_02/mac_input/README.md) |
| W03 | `2f02d62` 实现 / `90d408e` 归档；`v0.3.0-w03`；[建筑/恢复/自然](docs/weekly/week_03/README.md) |
| W04 | `fb3771b` 实现 / `13af20c` 归档；`v0.4.0-w04`；[路径/门/环境](docs/weekly/week_04/README.md) |
| W05 | `fea93d2` 实现；`v0.5.0-w05`；[庭园/池桥/回退](docs/weekly/week_05/README.md)，干净检出通过 |
| W06 | `7dacd8e` 实现；`v0.6.0-w06`；[分类植被/局部重建/中文主题](docs/weekly/week_06/README.md)，干净检出通过 |
| W07 | `06e91f9` 实现；`v0.7.0-w07`；[绿篱/材质卡/属性/包装](docs/weekly/week_07/README.md)，干净检出通过 |
| W09 | `34d9cdc` 实现 / `e10095e` 摄影修复；`v0.9.0-w09`；[摄影/入口/压力](docs/weekly/week_09/README.md)，无缓存446项通过；局部性能缺陷开放 |
| W08 | `e879782` 实现 / `e8abdba` 输入完善；`v0.8.0-w08`；[存档/设置/M3 切片](docs/weekly/week_08/README.md)，无缓存干净检出 412 项通过 |

本地 `main`，未配置远程、未推送。源件、导入设置、UID 与必要证据入库，缓存/运行时/导出包忽略。
W09 包：`builds/week_09/macos/windhaven_week_09.zip`、`builds/week_09/windows/windhaven_week_09.exe`。

## 下一周与剩余门槛

W10：T063声音播放/三类音量，T064 AC09–14持久化/摄影/设置/池岸组合，T065–066已复现缺陷与功能冻结。
Windows真机、最低配置性能、远程CI、物理触控板手感独立待验；Mac导出不替代Windows输入验收。
摄影与入口的15分钟人工计时体验未冒充已完成，按周目录脚本复核。
