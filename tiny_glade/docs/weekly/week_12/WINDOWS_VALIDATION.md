# 最终ZIP实机验证协议（待执行）

不得从macOS导出成功推断本协议通过。当前没有Windows实机记录；测试者填写实际结果，不能把模板中的字段当作证据。

1. 从 `delivery.json` / `reports/week_12_candidate.json` 读取ZIP SHA256，用PowerShell `Get-FileHash -Algorithm SHA256`核对。PACKAGE.json内的40位revision必须一致；另一版本的结果不得复用。
2. 在真实Windows设备上全新解压到普通可写目录，使用独立测试账号或运行START_QA.cmd。记录系统/GPU/输入方式，去除用户名和硬件序列号。
3. 逐项实测：fresh_unzip、demo、empty_layout、build_and_hover_edit、door_window_bridge、undo_redo、save_restart_load、photo_1080p、photo_1440p、settings_150、clean_exit。读档必须退出并重启进程，两尺寸图片须实际打开；不能只观察文件存在。
4. 保存观察说明与截图，用相对路径、SHA256登记证据；由观察者实际复核后设置reviewed。最低配置另测frame_target和memory_target；全新设备冷启动另记fresh_machine/first_frame_under_5_seconds，不用暖缓存成绩替代。
5. 将记录填入platform_observations.json的windows/minimum_spec/cold_start条目。每条需要revision、zip_sha256、os="Windows"、匿名tester_id、reviewed=true、steps全部实测结果、evidence.path和evidence.sha256。空条目保持null；失败填false并记录缺陷。

示意结构（未填写，不是通过记录）：

```json
{
  "revision": "从PACKAGE.json复制完整40位SHA",
  "zip_sha256": "复制实测ZIP的64位SHA256",
  "os": "Windows",
  "tester_id": "匿名编号",
  "reviewed": false,
  "steps": {"fresh_unzip": false},
  "evidence": {"path": "docs/weekly/week_12/observations/实际文件.md", "sha256": "实际证据文件哈希"}
}
```

正式首次玩家继续执行W11 PLAYTEST_PROTOCOL：M4冻结后同一版本十人、3分钟独立建有门屋顶路径小屋、15分钟主动截图、无需经营理解；禁止把自动脚本或受提示后的截图记为成功。最终包、资产逐项视觉签字、性能和真人记录全部符合后才可审核M4/M5；本工具不代签人工批准。
