# W12 测试契约

使用固定 Godot 4.7.2 / GUT 9.7.1 和锁定 gdtoolkit。测试失败、引擎脚本错误、空套件、跳过均拒绝功能通过。

```bash
# 提交实现后：空导入缓存累计回归，并从同一 Git archive 重导出
python3 tools/quality/clean_checkout.py --week 12 --export
# 串行运行：真实桌面 GUI、60 秒满容量性能、摄影、正式文件隔离
python3 tools/quality/week_twelve_native_checks.py
python3 tools/quality/week_twelve_audit.py
python3 tools/quality/week_twelve_package.py
python3 tools/quality/week_twelve_release.py
# 正式放行命令；未满足外部与性能门槛时必须退出 2
python3 tools/quality/week_twelve_release.py --require-release
```

常规累计入口：`python3 tools/quality/week_twelve_checks.py`。保留 W01–W09 `run_checks.py --week 9 --negative-control`，通过 UX-03 基线累计运行，不省略历史周跨进程保存和故意失败负控。预期 611 项 Godot 加 23 项 Python；本周新增 2 项 Godot 音频退出回归及 17 项 Python 检查资产完整性、重复/路径逃逸、包篡改、固定包清单、无证据放行、错误版本/哈希及缺失平台结果。合成通过数据只在临时单测目录，不进入实际玩家或设备记录。

AC01–14 用 `ac_index.json` 指向 XML 的真实通过用例，自动通过和人工视觉/Windows 验收分开记录。包仅允许十个文档/可执行/清单文件，严格逐项哈希验证。Git archive 源码、导出和原生报告必须同一源码提交；归档文档提交可后置。

性能记录帧 p95、提交 p95、主线程回调最大、RSS；提交 p95 目标 150ms，未通过不能被帧率或回调代替。最小配置、全新机器首帧、Windows 完整流程、十位首次玩家、M4 审批、最终美术复核必须有独立证据。macOS 上导出 Windows EXE 不代表 Windows 运行通过。
