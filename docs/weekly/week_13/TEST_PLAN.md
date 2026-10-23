# W13 测试契约

用户六项扩展见[SCOPE.md](SCOPE.md)，不重写历史PRD。

- 保留W01–W12、ART、UX、PERF-01/02、失败注入及跨进程重载，全部断言/脚本错误/空或跳过套件令命令失败。W13至少19项。
- 历法：360日进位、大步长、暂停/倍速、四季映射、非法及上界状态、DTO兼容旧档和实际异步保存重载、旧黄昏档映射傍晚并可回到日间。手动时间/天气标记未保存，自动流逝不污染源/历史。
- 地形：确定性及换种子变化、可见高度差>2m、旧平地/坡地不变、源ID与支撑偏移保留、实例派生落地、池岸/建筑约束、地形缓存签名包含新profile。
- 所有快捷工具和资产按钮用图片且无文字按钮条，悬停与无障碍描述保留；实际输入点击建筑底栏和月份原生菜单。
- 原生1920×1080：春/夏同一正午对比强度、秋阴云、冬飘雪及落叶、雨丝/闪电、午夜、150%日历、云影相位A/B及地貌远景。云影冻结其它动态后，1232个场景样点RGB均差>0.003；不以UI变化代替云影。
- 摄影冻结日历、云、雨雪和闪电相位，退出恢复；减少动态禁止闪电。真实CoreAudio、Windows/低配设备及手动听感继续单列。
- 固定容量24屋/1000源，保留旧布局来量测新增气候开销；新起伏示范另测。晴/雨/雪/起伏示范各60秒、20次提交，首笔和全样本保留，不与导入/回归并行。功能与性能预算结果分开。
- 正式作品与偏好前后哈希不变；不覆盖旧作品或旧W12安装包。新源件未改Blender，不新增源审计声明。

```bash
python3 tools/quality/week_thirteen_checks.py
python3 tools/quality/clean_checkout.py --week 13
python3 tools/quality/week_thirteen_native_checks.py
python3 tools/quality/week_thirteen_performance.py
```

着色器坐标/矩阵/自定义POSITION及冻结TIME依据[Godot Spatial Shader官方参考](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)。天气用两个固定预算MultiMesh，无逐粒子CPU更新；云影为世界坐标程序投影，积雪为材质覆盖，非流体/体积雪模拟。
