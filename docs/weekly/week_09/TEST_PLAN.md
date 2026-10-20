# W09 测试契约

1. `python3 tools/quality/run_checks.py --week 9 --negative-control`：锁定引擎、导入、格式、lint、累计资产、W01–W09 GUT、每周独立进程写/读及故意失败负控。跳过、空套件、引擎错误或断言失败使 gate 失败。
2. `python3 tools/quality/export_smoke.py --week 9`：依次导出 Windows/macOS、验证 Windows PE、Mac 全新目录可见运行及实际保存探针。不是 Windows 真机验收。
3. `python3 tools/quality/week_nine_render_checks.py --executable '<W09 Mac app executable>'`：串行、1920×1080、每轮先 2 秒预热再 60 秒，固定满容量静态/20 笔局部/8 笔 9m 大刷；记录未排序帧序列、CPU 阶段、主线程回调、进程 RSS、首帧。任何目标不达即保留失败并自动跑半密度局部复测。校验正式存档前后哈希一致。
4. `python3 tools/quality/week_nine_photo_checks.py --executable <W09 Mac app executable>` 自动验证下面的图片与入口路径。也可原生运行 `-- --qa-settings --w09-photo-probe --photo-output=<可写绝对目录> --smoke-output=<报告路径>`：不存在目录先失败，随后输出两尺寸及 512×288 图，检查源/相机/选择恢复。PNG 头尺寸、图片解码及可见画面复核；独立视口不包含 Control，工具节点在进入摄影时隐藏。
5. `Godot --headless --path . -s tests/week_09/soak_probe.gd -- 1200 res://reports/week_09_soak.json`：实际等待至少 1200 秒、50 笔混合事务、20 手工道具与外围树源数据、完整 50 撤销/50 重做、最终源一致。小于 1200 参数只用于诊断，不能作为 20 分钟验收。
6. `python3 tools/quality/clean_checkout.py --week 9`：提交后，从 Git archive 临时目录、无 `.godot` 缓存重跑完整 gate；共享锁定工具而不共享导入缓存。

## AC-01–08 证据映射

| 验收 | W09 组合与累计覆盖 |
| --- | --- |
| AC-01 | W09 边界非法尺寸原子拒绝；W03 全部矩形/圆形尺寸与几何/UV，当前生产场景截图。 |
| AC-02 | W09 完整 SCN-01 接路锁门、删路保留、撤销；W04 路径多次接/删与顺序稳定。 |
| AC-03 | W09 完整模板手窗冲突不吞窗；W04 合法候选、拒绝冲突、开口间距。 |
| AC-04 | W09 3m 合法准备网格，3.01m 整笔拒绝且 live view 引用不变；W02/W04 地形刷与基座。 |
| AC-05 | W09 场景岸线使桥失效但视图保留，撤销同时恢复；W05 高差/跨岸与问题可视。 |
| AC-06 | W09 实际场景 50 笔混合事务中 20 手工道具 ID/位置/角度保留；W06 刷草避让入口。 |
| AC-07 | W09 场景每笔提交比较远处原实例的全部源字段；W06 局部缓存/稳定随机，20 分钟探针保护外围树。 |
| AC-08 | W09 场景 50 笔含删父建筑/待附着手窗，50 撤销和50 重做精确复现；另有实际20分钟探针与跨进程重启。 |

## 测量范围

帧间隔包括垂直同步及空闲样本，不等于 GPU 执行时间；独立报告编辑提交最大延迟。
主线程回调/准备切片/最终发布最大值用于发现输入阻塞，不能替代物理设备端到端输入延迟。
RSS 是进程驻留集，不宣称测到全部统一 GPU 显存。GPU 计时不可用保留 null。
首次渲染从进程启动计至首个原生 `frame_post_draw` 标记，250 ms 轮询存在采样误差；源准备耗时另外记录。
