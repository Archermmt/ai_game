# W12 · MVP 内部候选交付

版本 `0.12.0-w12`；承接已完成的 UX-03 悬停编辑。遵循开发计划 T070–T073，不扩充 P1/P2。已生成内部 QA 包，正式 M5 放行需独立通过全部门槛。

| 任务 | 本机工作与验收边界 |
| --- | --- |
| T070 | 核对 47 族 / 79 基础单元、21 手工模型族，源件与运行资源哈希、既有 Blender 重开记录、许可证；逐族最终视觉签核仍待完成 |
| T071 | 累计自动化、AC01–14 映射、原生悬停/性能、正式文件隔离；150ms、全新设备冷启动、首次玩家和 M4 审核分别判定 |
| T072 | 从 Git archive 空缓存测试及重导出；Windows 内部离线 ZIP 包含版本、源码提交、逐文件 SHA256、操作说明、已知问题与许可证；不宣称正式候选放行 |
| T073 | 提供最终 ZIP 真机验收协议；本机 macOS 导出启动只作辅助，Windows 真机结果保持未执行 |

`asset_index.json` 保留与原资产清单的逐族/逐单元映射；原批准 PRD 和资产状态不覆盖。生成器、材质、图标以原清单单位计数，实例不充当独立模型。本周不更改 Blender 源件，复用已有重开审计，未冒充新审计。

[测试契约](TEST_PLAN.md) · [操作说明](HOW_TO_PLAY.zh-CN.md) · [已知问题](KNOWN_ISSUES.zh-CN.md) · [Windows 真机协议](WINDOWS_VALIDATION.md)。正式外部观察填写 `platform_observations.json`，必须对应包 SHA256 与精确源码提交，附已审核证据；空值不通过。

## 交付状态

内部包不包含用户作品、缓存或下载的运行时；实际结果如下。

## 本轮实际结果（2026-10-23）

源码 `0e184a7fc9e8ede61c1f57a0341a66fab8a8659d`，默认 `app/hover_root.tscn`，本地归档标签 `v0.12.0-w12`。

- Git archive 空导入缓存累计 **611 项 Godot + 23 项 Python**，0 失败/0 跳过；原有故意失败负控通过。本周新增 2 项音频退出生命周期回归与 17 项资产/打包/放行测试。
- AC01–14 自动证据逐条指向通过用例；原生 GUI 24 项全真，覆盖屋顶、门窗、桥端点、150%与摄影返回。正式存档和偏好哈希不变。
- 资产技术清单 **47族 / 79基础单元 / 21手工模型族** 通过，源件/运行引用/许可证哈希已记录。未更改 Blender 源件，既存重开报告仅作技术证据；最终逐族视觉签核仍待完成。
- 满容量帧p95 **23.218ms**，提交p95 **363.913ms**，主回调最大 **128.981ms**，RSS峰值 **947.12MiB**；各性能目标按下方放行记录逐项判定，未达项保持开放。显式静音 QA 结果，不与原有真实音频性能作严格A/B。
- 相同 Git archive 实际重导出 Windows EXE 与 Mac ZIP，Mac解包启动/保存/缩略图通过；本机首绘 **2.836秒**，不代表全新设备启动。Windows仅PE结构检查，真机未执行。
- Windows内部ZIP `builds/week_12/windows/Windhaven_0.12.0-w12_Windows_Internal.zip`，58155485字节，SHA256 `887bcb21e00324867ee028a4bdb7edc6ac95f0bc472de5d61a249fa15e39e64f`。严格十文件包清单、逐项哈希验证通过；包不进入Git。
- 正式放行命令实际退出2，保持 **internal_qa_only**；M4/M5不通过，十人首次试玩仍0/10。

### 音频环境与修复边界

初次包冒烟被10个音频对象退出泄漏正确拦截。补上显式声部清理、统一退出、释放音频节点后等待多个混音周期；2项生命周期单测通过。GUI探针原先直接退出，在移除场景前显式停止声部并等待排空后，Dummy模式退出无泄漏，24项GUI通过。后续单声部最小复现显示本机CoreAudio混音时钟不推进，等待后仍复现，不把实际音频问题标记已解决。最终GUI/导出/性能显式选择Dummy，游戏包仍用系统默认驱动，native_audio_output门槛保持失败。失败日志及最小复现源码保留在 evidence/audio_diagnostics 与相关日志中。

### 仍待完成的正式验收

Windows最终ZIP全新解压完整流程、最低配置PC、全新机器首帧、真实音频输出/听感、最终美术签核、十位首次玩家及M4审核待补；帧/回调与150ms局部编辑需继续优化。T070技术核对完成，T071本机功能通过但放行阻塞，T072内部QA包完成，正式T072/T073不标通过。物理触控板手感与远端CI未冒充完成。

[交付清单](delivery.json) · [放行决定](evidence/week_12_release.json) · [文件校验](checksums.json)。

本轮未通过的正式门槛：

- `asset_visual_signoff`
- `native_audio_output`
- `frame_p95_20ms`
- `local_edit_p95_150ms`
- `main_callback_100ms`
- `windows_real_device`
- `minimum_spec_pc`
- `fresh_machine_startup_5s`
- `t067_ten_first_players`
- `explicit_m4_approval`
