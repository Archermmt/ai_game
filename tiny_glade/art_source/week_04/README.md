# W04 源资源与导出契约

Blender 5.1.2 为主源工具，GLB 为 Godot 导入件；不覆盖 W03 初稿。

- NAT-04 林下蕨：七向弯曲叶轴和成对叶片，地面叶轴权重 0。
- NAT-05 野花：多高度茎与五瓣花，复用 MAT-03 花色区。
- NAT-06 矮灌木：多团簇体积轮廓，不使用大型十字卡。
- NAT-08 苔石 / NAT-09 扁石：封闭底面与不同高宽比，石材/苔色分离；风权重 0。
- PROP-01 木长凳：独立完整源件，保留 socket_tea_surface / socket_ground；共享木材。
- PROP-02 信箱：封闭箱体、投递口、独立屋盖与旗形标识，无品牌地址。
- PROP-03 盆栽 / PROP-04 晾衣架：W04D5 开工源件，继续 W05 精修，未将整项提前标完成。
  晾布挂点权重 0，底摆权重渐增，运行时通过统一风向/风量和独立对象相位驱动。

所有模型有米制、Y-up 导出、UV0、wind_mask 顶点色与地面挂点；叶草花复用现有 2K MAT-03，
木材与石材复用 MAT-02，未新增纹理族。source/export 一一对应见 manifest.json。

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/build_week_four_assets.py -- --root "$PWD"
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/reports/week_04_source_audit.json"
```

造型和色彩均由项目源脚本原创，可在 .blend 中继续编辑；最终手绘精修和全场美术审核仍随后续资产整合进行。
本周实机四向近景图和预算审计见 docs/weekly/week_04/，不以源文件存在代替成品检查。
