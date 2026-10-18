# W07 美术与包装源

本周不新增资产族：优化既有 BLD-09 圆窗，制作 UI-04 十二张选择卡；
NAT-07 绿篱由 NAT-06 共享网格/图集重复生成，不另制绿篱源模型。

## 重建顺序

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_seven_assets.py -- --root "$PWD"
python3 tools/art/build_week_seven_ui.py
.tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
.tools/godot/Godot.app/Contents/MacOS/Godot --path . -s tests/palette_render_probe.gd
.tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/reports/week_07_source_audit.json"
python3 tools/quality/run_checks.py --week 7 --negative-control
```

Godot 导入/渲染/导出串行。`palette_render_probe.gd` 需要桌面图形设备，输出原生 96×96 PNG；
使用与运行场景相同的笔触贴图和色乘参数，固定中性光；源 SVG、色值与标签另保留可编辑文件。
完整字体/图标延续 W06，色板不新增材质族或变体计数。

## 圆窗

旧 W02 圆窗为 32 块倒角木块，4048 三角面，超过 PRD 的建议 1600。
W07 保存独立 `window_round.blend`，采用 48 段连续闭合倒角圆框，加横竖木构、静态暗衬和窗光遮罩，
共 **1360 三角面**；源名/UV/风颜色和墙挂点保留。旧资产留作历史回归，W07 `OpeningAssembly` 使用新件。
审计重新打开 46 模型源，新增圆框检查每条边均有两个相邻面，不能只查 GLB。

## 包装与预算

`features/assets/asset_wrapper.tscn` 是应用拥有的基场景，`wrappers/` 的 17 个继承场景绑定稳定资产 ID。
视觉由已有目录实例化，不在磁盘上改导入 GLB；拾取盒、地面/支撑/灯锚在包装层。
`assets/week_07/asset_ledger.json` 登记当前 24 个手工模型交付（含 3 LOD），来源/哈希/PRD 建议预算和包装路径可查。
源片作为原有生成器输入，不能和程序化结果重复统计。木构立柱/檐口采用 W06 GLB；
基座/围栏/短阶继续共用 `KitProfiles` 米制截面参数。
完整导入契约、共享图集/材质与包装交互在无导入缓存的检出中重验。
