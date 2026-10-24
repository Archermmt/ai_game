# W11 首次试玩执行与记录

2026-10-22。此协议校正 W10 准备稿的计时任务，验收以 PRD 与 T067 为准。当前无真实玩家记录；未进行外部联系。自动测试和本机审查均不计作玩家反馈。

正式测试开始前，T066/M4 冻结通过，并将获准的完整 Git SHA 写入 `playtest_records.json`。目前 `m4_approved=false`；性能、Windows 真机等开放项不能由脚本自动批准。

每位未接触本作的玩家约20分钟。使用独立 QA 存档目录/系统账号；记录系统和输入设备。先取得观察记录及可选录屏许可，记录匿名编号，不保存姓名、联系方式。使用同一冻结版本；旧包或预冻结观察只能用于修复建议，不能补进正式十人验收。

| 时间 | 主持行为与观察 | PRD 指标 |
| --- | --- | --- |
| 0–3分 | 进入可编辑布局，开始计时。请玩家造一间带门、屋顶和相连路径的小屋。不解释按钮位置，记录独立完成时间和各组成部分。 | ≤180秒独立完成，至少8/10 |
| 3–15分 | 自由探索。观察保存、修改、草密度、环境与摄影入口。**不提示截图任务**，如玩家主动输出图片，记录从开场起的秒数。 | ≤900秒主动截图，至少7/10 |
| 15–17分 | 开放式询问“你认为这里有什么目标？接下来想做什么？”记录原话，由主持复核是否理解无需经营，不先告知答案。 | 无需经营理解至少8/10 |
| 17–20分 | 此时可以提示未发现的功能，检查保存重启、摄影返回、150%和减少动态。前面没有主动截图者不得因本阶段完成截图而追记成功。 | 补充问题与可用性记录 |

如果玩家求助，可以帮助，但受帮助的建屋记 `house_independent=false`；提示摄影后的截图记 `screenshot_unprompted=false`。未完成用 `null` 时间；恰好180/900秒允许，超时不算成功。另记录错误复现、严重度、崩溃/丢档、操作舒适度与原话，发现数据安全问题立即停止该轮。

每条真实记录的字段：

```json
{
  "participant_id": "P01",
  "revision": "替换为40位冻结Git SHA",
  "system": "实际系统与GPU",
  "input_device": "实际鼠标或触摸板",
  "first_time": true,
  "consent": true,
  "reviewed": true,
  "evidence": "observations/P01.md",
  "house_seconds": null,
  "house_independent": false,
  "door": false,
  "roof": false,
  "path": false,
  "screenshot_seconds": null,
  "screenshot_unprompted": false,
  "understood_no_management": false
}
```

此示例不是已完成记录。`observations/P01.md` 由主持保存实际任务时间、帮助、原话、问题及取得许可后的截图引用，再标记 reviewed。脚本检查文件和字段、去重、版本、首次资格和门槛；不能证明观察真实性，仍需要人工复核。同一批最多十人；不同批次分文件，避免事后择优拼接。

```bash
python3 tools/quality/playtest_report.py docs/weekly/week_11/playtest_records.json --output reports/week_11_playtest.json
```

当前输入为空，预期输出0/10、`awaiting_m4_freeze`、T067不通过。六项 Python 用例中的十人数据全部是临时合成测试，不写入真实记录。T068/T069 的真实反馈排期在收到记录后进行；未出现的问题不扩充为新美术/功能。
