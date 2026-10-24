# 日历精简

按用户要求将月份与日期合并为一行（例如`Jan.1st`），小时与分钟合并为一行（例如`7:00`）。采用英文月份缩写及序数后缀，11/12/13日使用th。月、日、小时、分钟仍可分别点击并用原生下拉选择，静止时隐藏多余箭头与边框。

天气只在顶部显示图标，点击图标打开原天气选项；悬停可读当前天气。删除独立Weather行。Year、Season与Speed保留，纸色面板高度由380缩短至270；原日期保存、速度、日照和天气系统继续使用。

## 验证

自动回归覆盖合并后的显示格式、控件处于同一行、天气处于标题栏且无常驻文字、天气选择、月末与23:59选择。复验命令：

```bash
python3 tools/quality/week_thirteen_checks.py
python3 tools/quality/week_thirteen_native_checks.py
```

结果及本次实拍见[evidence/calendar_compact/](evidence/calendar_compact/)。历史W13性能证据不改写，本次仅调整UI，未重新执行四组性能基准，也未更新旧安装包。

累计676项Godot + 28项Python通过，含历史负控。最终收紧间距后，局部20项/972断言与10项原生检查再次通过；150%面板边界正常，正式作品与偏好哈希不变。原生使用Dummy，不计真实音频/Windows验收。

[常规实拍](evidence/calendar_compact/summer.png) · [150%实拍](evidence/calendar_compact/calendar_150.png)
