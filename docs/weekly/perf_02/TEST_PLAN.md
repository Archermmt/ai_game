# PERF-02 测试契约

本轮仅修复 T065/T071 性能缺陷，继承 W12 与 PERF-01，玩法、美术、45% 默认草密度和既有验收目标保持。

- 所有历史门禁、故意失败负控、跨进程存档保留。新的套件必须非空、无脚本错误/失败/跳过，Python协议负控也必须运行。
- 高度查询索引按每次重建独立建立，不能改源、不能跳过校验。乱序输入、负坐标、闭边界、插值halo、spacing及池岸的签名与原全扫描逐字符一致；完整生成几何和姿态与冷缓存一致。
- 风材质按实际根节点身份复用，新增/删除/替换/种子/池岸/撤销失效；材质集合与递归遍历相同，无重复，无漏风、色板或摄影冻结。
- 草的未变块复用已发布节点；取消不能释放live节点。worker曾生成但未发布的版本不能当作live。分布变化、撤销、0/100%密度、空结果、后台源隔离保留回归。
- 批量MultiMesh缓冲必须保持旧变换、相位、顺序和密度，不改变草形状、数量、距离或材质。按Godot官方row-major Transform3D + custom Color布局验证。
- 原生串行：1920×1080、24屋/1000源、默认45%草、选中建筑、20笔局部/8笔大刷、60秒原协议保留，首笔、raw samples、max及旧upper均不删；与本轮优化前同机基线比较，不用历史环境波动冒充收益。
- 首绘前提交与首绘后direct terrain探针分别保留；前者是启动重叠压力，不能简单延后起点以关闭尖峰。记录提交绝对时间，避免“首绘时已完成”等同“首绘前未提交”。
- 另测示范/容量各3独立进程、首绘立即真实鼠标屋顶拖拽20笔、零预热。记录motion/press/release→publish→frame_post_draw→草稳定；原始时戳、全程帧间隔、第一笔和PNG保留。新协议不替换旧门槛，渲染完成不等同物理显示延迟。
- 退出时先释放场景并等待两次process_frame，让删除、worker join和deferred交付完成，再退出引擎；新增工作中退出与一次续调回归。生产入口和GUI/场景QA采用同一清理顺序，不改变性能计时区间。
- 音频释放单测同时覆盖播放中/静音暂停：验证真实mix时钟推进，并以WeakRef检查4组stream/playback全部释放，不能仅检查player.stop。短时通过不替代长时原生退出检查。
- 正式作品/设置哈希不变。显式Dummy只验证非音频；Windows、最低配置、真实音频/触摸板、全新机器冷启动及十位首次玩家保持待验，M4/M5不自动关闭。

```bash
python3 tools/quality/perf_followup_checks.py
# 提交实现后从Git archive空导入缓存复验
python3 tools/quality/clean_checkout.py --week 12 --perf-followup
# 两条串行运行，不与导入、回归或源码修改并行
python3 tools/quality/perf_native_checks.py --followup --silent-audio
python3 tools/quality/perf_visible_checks.py --silent-audio
```

MultiMesh缓冲布局依据：[Godot RenderingServer.multimesh_set_buffer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-multimesh-set-buffer)。
