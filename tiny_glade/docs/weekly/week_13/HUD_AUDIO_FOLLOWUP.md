# 修改入口、时间滑块与音乐可辨识度

按用户截图反馈完成三项调整：当前主场景各工具栏移除“更多参数”修改按钮，对象操作栏的旧精确参数入口也隐藏，继续直接悬停对象并拖白色手柄；Speed改为1–60倍整数滑块，右侧实时显示倍速，旁边图示按钮单独暂停/继续；修正音乐被环境底声压盖的问题。旧周场景的历史参数入口保留给回归。

滑块支持任意中间整数倍速，如17×或37×，无需跳固定档；存档接受0（暂停）或1–60范围，旧0/1/5/20/60档兼容。暂停后继续恢复当前面板上次倍速，拖动滑块也可继续时间。日期推进仍只影响表现，不写建造源或撤销历史。

## 音频根因与修复

读取当前正式偏好，仅核对音乐音量50%、环境70%、操作65%及初始化标记，未改偏好文件。使用Godot AudioEffectCapture分别采集音乐与环境的内部混音，不使用麦克风。当前CoreAudio能正常产生采样，音乐播放进度也推进；问题是旧混音过低。相同《四季环》、晴天正午及默认音量下，音乐RMS约0.002277，环境约0.017425，相差**-17.68dB**，很容易被起伏的风/水底声掩盖。

音乐最大增益由0.12调为0.32，新主场景的环境底声系数设为0.5（约低6dB）。环境和音乐滑块数值不改，操作音量不变；雨雪/夜间仍压低音乐。淡入淡出、随机选曲与停止释放继续保留。调整后相同曲目采样音乐约0.00614、环境约0.00871，音乐比环境低约**3dB**，保持背景层次且可分辨；当前PCM均未削波。对应精确数值见最终收据。

此前Dummy检查只验证播放器状态与控制接线，没有验证实际可听混音。本轮新增采样数量、非零音乐RMS、播放进度及相对环境声比例门禁；旧混音采样会被该门禁拒绝。当前CoreAudio内部输出通过不等于物理扬声器/耳机主观听感签核，也不替历史W12关闭全平台音频放行门槛。

## 复验

```bash
python3 tools/quality/week_thirteen_checks.py
python3 tools/quality/week_thirteen_native_checks.py
python3 tools/quality/seasonal_music_native_checks.py
# macOS系统音频驱动，采集内部PCM；不访问麦克风
python3 tools/quality/seasonal_music_mix_checks.py --driver CoreAudio
```

累计回归包括新增任意速度保存/推进、滑块端点/中间值、暂停恢复、无修改入口与源隔离；原生UI增加实际拖动滑块和按钮缺席检查，并复查150%布局。原生音乐控制仍显式Dummy，实际PCM另外使用CoreAudio，二者结果独立。证据在[evidence/hud_audio_followup/](evidence/hud_audio_followup/)。不更新旧包、不重跑四组气候性能，其他外部放行门槛保留。

初次局部测试在暂停状态下把已经为1的滑块再次赋1，Godot不会发value_changed，导致两条显示断言失败；测试改为先到2再拖到1，并等待菜单queue_free完成后才形成最终收据。首份失败日志保留，运行时断言未删减。

采样API依据[Godot AudioEffectCapture官方参考](https://docs.godotengine.org/en/stable/classes/class_audioeffectcapture.html)。只采集应用自身音频总线。

## 结果

源码`a072da76dd784be933fba147b4e57d66655b3cca`。累计685项Godot/20,591断言 + 28项Python，0失败/0跳过、负控通过；新增3项/47断言，W13共29项/1347断言。原生UI12项、音乐控制10项通过；CoreAudio分别产生199,680帧有效音乐/环境采样，播放位置推进至10.232秒，默认混音差-3.045dB。正式作品/偏好哈希未变。旧混音收据经新校验确实被拒绝。

[收据](evidence/hud_audio_followup/delivery.json) · [建造栏实拍](evidence/hud_audio_followup/illustrated_build.png) · [150%日历实拍](evidence/hud_audio_followup/calendar_150.png)
