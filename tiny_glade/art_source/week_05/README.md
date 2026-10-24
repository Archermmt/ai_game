# W05 模型源

Blender 5.1.2；米制、glTF Y-up。六份独立 `.blend` 与对应 GLB、UV、`wind_mask`、挂点及三角形预算保留。

- PROP-03 盆栽：厚盆沿与内壁、封闭土面、共享植物图集；替代 W04 初稿。
- PROP-04 晾衣架：木架/脚、下垂绳、两块带自然褶皱布、夹子；上沿顶点权重为零；替代 W04 初稿。
- PROP-05 木箱：六面木条、角条、0.8m 高支撑挂点；复用木材。
- PROP-06 浇水壶：低饱和粗糙金属、壶嘴、喷头、独立可读把手。
- PROP-07/08 茶具与提灯是 T038 的 W05D5 源初稿；不在本周工具菜单标成最终交付，W06 完成装配、近景内壁/亮灭验收。

重建：`Blender --background --python-exit-code 1 --python tools/art/build_week_five_assets.py -- --root /absolute/project`。
修改后再运行 `tools/art/audit_sources.py`，实际重开五周模型与材质库。源审计检查绳与两布存在、上沿零权重、下摆可动和预算。
无新材质族或新贴图家族；盆色、金属为既有建筑材质库的粗糙度/颜色实例。共享风控制，不采用实时布料物理。
