# W10 验证契约

保持批准 PRD 的 AC-09–14 和 ART-01 美术基线；新增声音不进入世界源，不改变存档 schema/generator。所有 QA 文件与正式 `user://week_08/saves`、`preferences.cfg` 隔离。

| 层 | 命令 / 内容 | 失败判定 |
| --- | --- | --- |
| 累计门禁 | `python3 tools/quality/run_checks.py --week 10 --negative-control` | W01–10 和 ART 空套件、跳过、断言失败、SCRIPT ERROR、引擎 ERROR、资源泄漏均失败；负控制必须确实失败 |
| 音频资源 | `python3 tools/quality/validate_week_ten_audio.py` | 双声道真实差异、首尾无缝、源/导出 SHA、四效果重叠+全部环境+音乐最大音量的保守峰值 < 1 |
| 原生混音 | Godot 原生 `-s tests/week_10/audio_native_probe.gd` | CoreAudio 实际 PCM > 1 秒、非静音、峰值 < 1；全部静音后输出为零；恢复音量不依赖重启 |
| 原生场景 | `python3 tools/quality/week_ten_native_checks.py` | 真 1920×1080、3 栋/170 源对象；容量 24/1000；摄影 1080p/1440p 可解码且无 UI，相机/源/选择恢复；QA 不触碰正式作品 |
| 发布 | `python3 tools/quality/export_smoke.py --week 10` | Mac 解压独立运行，保存与缩略图完成，包内不含 GUT/测试源；Windows 只验证 PE，不算真机运行 |
| 无缓存 | `python3 tools/quality/clean_checkout.py --week 10` | 已提交 Git archive，空 `.godot` 跑同一累计门禁，保留提交号 |

新增回归覆盖：场景声音/池水生命周期、三变体、0.12 秒全局效果限频、四语音有界复用、音乐开关、静音停止效果并暂停循环、旧偏好迁移和非法音量拒绝、连续十次艺术场景读写、中断后主文件损坏恢复最新有效备份、设置 150%/重绑/减少动态并用、预览取消与拒绝事务不发摆放声、提交/撤销/读档联动、坡岸保护与双向冲突、锁窗整体拒绝。

性能优化回归采用逐点精确等价对照，而非用固定耗时断言限制 CI 机器。原生 60 秒探针另外记录 p95、提交、主回调、RSS 和源数量，150 ms 未达标必须如实保留。GPU 计时不可用不填 0，Mac 高配结果不替代最低配置 PC。

原生混音捕获位于输出总线，属于软件音频证据；扬声器/耳机的听感、系统外部音量与物理触摸板仍由人工确认。
