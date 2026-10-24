# W08 审核交付

本周不新增手工模型、贴图或资源族，`manifest.json` 保持空数组。
复用 `assets/week_07/asset_ledger.json` 的 24 个当前预算模型（含三树 LOD1）与累计源件。

- `tools/art/audit_sources.py` 重开 46 份 `.blend`、八份基础材质图与一份图集。
- `tools/art/audit_week_eight.py` 重开当前 24 份源件，检查法线、UV、正缩放、预算、导出哈希与透明 RGB 扩色。
- SCN-01 的正式源布局是 `levels/forest_slope/scn_01_filled.tres` 与 `scn_01_empty.tres`。
  `ForestLayout.source_json` 保存 ExactFloatJson 信封，避免 ResourceSaver 对 Dictionary double 值舍入。
  两者不保存任何派生网格；`tools/levels/freeze_forest.gd` 是显式重新冻结命令，运行前应审查源布局变更。
- 运行截图和自由相机录像在 `docs/weekly/week_08/`，不将程序化实例、用户缩略图重复计为手工资源。
  UI-06 的 512×288 模板缩略图按计划 W09 拍摄。
