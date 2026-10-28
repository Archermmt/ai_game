# G5 · 本地技术候选收口

2026-10-28。G4限定保真尝试已完成，性能风险按用户授权后置，20ms未通过；本阶段推进当前正式主场景的本地技术候选，**本地G5已完成，不代表发行放行**。

## 最终本地交付入口

交付目录：`reports/week_14/g5/handoff_9ebe3bf8/`，含`HANDOFF.md`、完整校验清单与四个启动脚本。Finder双击`play_winter.command`/`play_summer.command`体验实际庭园；`compare_new_grass.command`/`compare_original_grass.command`打开相同容量样例，样例内也可切换新旧草、密度和天气。

候选额外有显式的`override.cfg`，在引擎启动、场景与偏好读取之前分配独立用户目录`WindhavenDiorama_G5_9ebe3bf8_1x72b2ch`。源码与`project.godot`未改；覆盖文件哈希已记录。即使直接打开候选工程也不共用正式或其他QA存档；主项目F5仍使用正常目录。

最终检查核对1,720份运行文件、31份本地供应文件与启动脚本，重跑446项累计及失败负控，通过11项实际容量UI检查和真实启动/退出、目录隔离验证；无错误/泄漏，正式作品/偏好哈希保持。[最终收据](evidence/g5/closure/checks.json) · [G0–G5台账](G_STAGE_ACCEPTANCE.md)。这次复用已验证的空缓存副本，不把它记作新一次冷导入，也不重复计算此前42项/原生回归。

```sh
python3 tools/quality/g5_handoff_checks.py
```

如果候选不在本机或运行源码已变化，先提交源码、重跑`production_candidate_portable_checks.py`，再生成交付目录。交付脚本与目录是忽略产物，本机工具链仍显式复用，未上传下载包。

## 当前已核对

`python3 tools/quality/candidate_asset_supply_checks.py`核对四层Valley模型、四份可编辑源和4K透明笔触的9份manifest绑定文件；同时盘点用于本地供应的其他导入设置、散布记录及预览派生文件。[供应收据](evidence/g5/asset_supply.json)。作者源哈希保持，未改源/生成器，未新增Blender重开审计声明。

这些素材仍是本地供应，不在Git资产树中。可进行用户本机技术验证；下载素材的仓库/分发条款仍待归档，插件MIT不能替代美术资产许可。没有上传原下载包，也没有声明Git-only检出可运行。

## 空缓存候选副本

状态：**本地空缓存候选验证通过**，源码提交`9ebe3bf8`。从已提交源码创建的候选副本，完成446项累计及负控、42项定向/2,847断言、36项正式云雪与74项漫步原生检查、36组保真对照；无脚本错误/退出泄漏，正式作品/偏好哈希不变。[候选总收据](evidence/g5/portable_checks.json)、[执行日志](evidence/g5/portable.log)、[副本W09收据](evidence/g5/candidate_week_09_checks.json)。

本机候选目录：`reports/week_14/g5/candidate_9ebe3bf8_1x72b2ch/`。Finder双击[隔离启动脚本](../../../reports/week_14/g5/open_candidate.command)，或运行`sh reports/week_14/g5/open_candidate.command`；打开的是实际`app/living_root.tscn`冬景，使用QA作品/偏好。目录和启动脚本为本机忽略产物，不上传Git；原项目F5也已采用本轮优化。

只保证候选工程的`.godot`导入缓存为空，不宣称系统GPU缓存或新设备冷启动已验证。候选显式复用锁定的外部工具链；未制作独立`.app`/`.exe`发行包。

具体流程：从已提交版本导出项目源码，在独立候选目录显式供应本地派生素材/导入设置，复用固定外部引擎与Python工具链，不复用`.godot`缓存，不复制桌面原下载包。对当前正式场景执行累计、云雪/漫步/摄影和本轮保真回归；成功后保留候选目录及QA隔离启动器，便于继续体验。

```sh
python3 tools/quality/candidate_asset_supply_checks.py
python3 tools/quality/production_candidate_portable_checks.py
```

后者必须在源码提交后执行，收据记录测试的提交号与候选目录。真实作品/偏好不应变化；副本运行仍用QA隔离。不是独立导出包、Windows实机或商业分发验收。

## 保持开放

- G4性能风险：冬景20ms、完整天气/密度矩阵、编辑时延、20分钟长测、2K峰值与LOD人工复核。
- 素材条款、Git-only供应、正式候选导出包、干净新设备与Windows真实设备。
- 最新冬景体验、物理触控板/音频及首次玩家外部验收；自动截图和本机测试不能代签。
