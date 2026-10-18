# W06 美术源交付

茶具与提灯沿用 W05 初稿并完成近景内壁、壶嘴厚度、提灯四面发光遮罩和挂点。
茶盘/壶/两杯作为一个 PROP-07 组合；提灯作为 PROP-08 一个组合。
茶具 1908 / 2600 三角面，提灯 1028 / 2000；导出目录 `assets/week_06/`。

六份木石源片：立柱、横杆、角柱、基座拼片、木构收边、石踏步，各 108 三角面。
它们是 BLD-03/10/11/19 既有资产族的生成器组件，**不能统计成六个新增资产族**。
米制原点/轴/端点记录于 `assets/week_06/profiles.json` 与各 `asset.json`。
`KitProfiles` 已用于基础/围栏/短阶截面；正式 GLB 装配与边缘精修继续 T046。

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/build_week_six_assets.py -- --root "$PWD"
python3 tools/art/build_week_six_media.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/audit_sources.py -- --root "$PWD" --output "$PWD/reports/week_06_source_audit.json"
python3 tools/quality/run_checks.py --week 6 --negative-control
```

保留 `.blend`、共享图集链接、颜色权重与源 socket；不得手改导入后 GLB 内部节点。
生成器读入 W05 共用构件方法后独立导出 W06，不覆盖 W05 归档。

`ui/` 保留 16 工具 + 4 反馈 SVG，可编辑路径；运行副本位于 `assets/ui/`，128 像素导入，
64/128 尺寸实机预览见周报。工具为深绿轮廓、奶油底；悬停浅杏、选中琥珀，焦点描边；
四反馈用选框/十字/尺寸箭头/三角叹号区分，并伴随文字。

`audio/` 保留 17 段原创合成 PCM：林间底噪 1、风 2、浅水 1、木/石/草各 3、UI 3、音乐 1。
48kHz / mono / 16bit；循环 8 秒，音乐 24 秒。噪声滤波/周期合成与原创音符由脚本生成，
未使用第三方采样或录音。普通音频 RMS -30dBFS，音乐 -36dBFS，峰值低于 -6dBFS。
导入预设保留 PCM，循环文件开启前向循环、音效关闭循环；重建时保留 `.wav.import`。
波形/接缝/哈希审计见周报。此为 T043 资产交付；T063 完成播放器、混音、限频和听感签核。

中文字体不在本源目录重制；未修改的 Noto Sans SC 及 OFL 全文保留在 `assets/fonts/`，
来源、固定提交与 SHA256 见其 manifest 和仓库 `THIRD_PARTY.md`。
