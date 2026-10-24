# 漫步方向、图标反馈与绘本天空

2026-10-24，按用户提出的五项修改扩展当前W13源码。原批准PRD、美术源件、资产导入和锁定工具版本保持；本轮没有下载天空材质、图片或插件，天空Shader及新增示意图为项目原创。

## 交付行为

| 修改 | 当前实现 |
| --- | --- |
| 漫步方向 | 反转第一人称环顾的水平、垂直方向，鼠标与Mac双指一致；行走方向及原俯瞰操作不改 |
| 当前模式反馈 | 主底栏选中卡片放大至112%；子类型图标也放大并清除上一项高亮，不改变布局槽位 |
| 摄影统一图标 | 底部纸色摄影卡片使用漫步、冻结、目录、设置、拍照、保存构图、应用构图、隐藏、返回示意图；悬停和无障碍名称保留。尺寸、目录输入和构图列表收进设置；支持原1920/2560导出 |
| 天气渐变 | 晴转雨雪先聚云、降日照，再增加降水；转晴先收降水，再散云。雾、暴风雨、暴风雪和沙尘也连续混合，水面雨纹及强风底声同步渐变 |
| 天空 | 白天柔和蓝天、流云与太阳；暮色渐变；夜间月亮、星星与淡紫银河，云层遮住天体。天体位置随游戏小时变化，日月交替与星光淡入淡出 |

摄影仍可隐藏界面进入漫步，直接拍当前第一人称构图。返回俯瞰恢复景深和原构图。导出过程中禁止移动和环顾，避免主相机、导出相机及水面反射错位。

## 连续天气模型

`WeatherBlend`是独立的表现状态，不修改日历概率、季节合法性、世界源或撤销记录。日历天气表示玩家/随机系统选择的目标；实际云量、日照系数、雾密度、雨、雪、沙尘和积雪在约18个现实秒内转向目标。

转向新目标时从当前表现值开始，重复切换不会跳回上一次端点。刚从晴天转雨时，前约4.5秒先积云；如果已经阴云密布，增加降水无需重新等待聚云。适用于快速流速下连续改换天气。时间流速控制日历与日月；云和雨雪维持自然运动节奏，暂停游戏日期时仍可观看天气变化。

粒子数量预算仍为雨1400、雪900、尘700。固定实例的稳定随机值控制渐显，雨滴/雪点尺寸、密度、透明度和风速逐渐变化；不是突然切换整组显示。雨雪可短暂同时存在以完成交接，全部预算始终有上限。降水运动相位采用积分，避免强度变化让粒子位置突然跳转。

摄影冻结同时停止云时间、粒子相位和天气插值；取消冻结继续变化。减少动态保留较慢运动并禁闪电。没有新增体积云、每粒子CPU更新或天气网格重建。

## 天空与性能取舍

使用Godot的[Sky Shader接口](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html)和[自定义天空说明](https://godotengine.org/article/custom-sky-shaders-godot-4-0/)核对方向、天空背景与辐射更新行为。Shader通过视线方向绘制三层二维噪声云、柔边日月、稳定星点及噪声银河；没有逐步射线行进或外部贴图。

真实GPU发现实时模式会强制256辐射尺寸，因此使用32尺寸的渐进更新模式。辐射立方图分支只画便宜的渐变，细节留给实际背景；环境照明继续使用解析色。云层与星光使用显式时间，冻结时不依赖引擎TIME。地表云影、水面雨纹和天空云量来自同一个表现状态；水面反射仍受480×270/8Hz预算约束。

## 复验

```bash
python3 tools/quality/week_thirteen_checks.py
# 以下桌面GPU检查串行执行
python3 tools/quality/sky_weather_native_checks.py
python3 tools/quality/walk_native_checks.py
python3 tools/quality/pond_water_native_checks.py
python3 tools/quality/week_thirteen_native_checks.py
python3 tools/quality/walk_performance_checks.py
python3 tools/quality/weather_budget_checks.py
python3 tools/quality/walk_performance_checks.py --transitions
```

W13最低77项：新增长短步一致、全部天气对的范围/端点/切换连续性、冻结恢复、连续重定向、已阴天快速转降水、图标/设置、主卡片与子类型选中反馈、天空预算/时间冻结和首帧不跳变；补充漫步方向断言。历史天气与水面测试仍检查原端点，显式推进表现插值到端点，新增测试单独检查中间过程。

原生探针实际点击模式、摄影、漫步和设置按钮；投递双指事件；真实等待天气转场并分阶段截图；测量云运动、昼夜像素差、日月亮度、星点及冻结。合成输入不替代物理触控板验收。

性能分别测满容量漫步30秒、三种恶劣天气各30秒及每6秒重新指定天气的连续转场漫步30秒，保留原始帧间隔。旧编辑尖峰/冷启动、Windows/低配、物理听感/触控板、远端CI与M4/M5继续保持原门槛；旧W12包未重导出。

## 实拍与最终结果

源码`03a41f7c1842fa5e6d9de8261788ea9a5f500024`。累计733项Godot/30,440断言 + 28项Python，0失败/0跳过、负控通过；本轮新增15项/8281断言。完整累计后补充强风底声渐变测试，最终W1377项/11196断言另行重跑，19份XML与原完整累计收据均保留。

原生天空/天气17项、漫步18项、水面9项及既有界面22项全部通过，正式作品/偏好前后哈希未变。晴到暴风雨实际等待分段捕获，早期雨量0、中期约0.281，冻结像素均差约0.00020；云运动均差约0.0076，夜空检出305个星点样本。

满容量漫步30秒帧p95为8.874ms；每6秒重定向天气、最多三种粒子同时显示的转场漫步p95为10.319ms。暴风雨/暴风雪/沙尘暴分别12.121/15.278/12.121ms，RSS峰值924.31MiB，20ms p95/2GiB目标通过。没有把最大帧或旧编辑尖峰计成已修复。

测试数、源码、性能及正式文件隔离结果见[交付收据](evidence/sky_weather/delivery.json)。初次端点浮点舍入、探针HUD类型、实时天空强制尺寸及旧水面端点前提的失败诊断保留在[evidence/sky_weather/diagnostics/](evidence/sky_weather/diagnostics/)。最终退出不得出现脚本错误或资源泄漏。

[摄影图标栏](evidence/sky_weather/native/photo_icon_bar.png) · [白天云层](evidence/sky_weather/native/day_clouds.png) · [月亮](evidence/sky_weather/native/moon.png) · [银河星空](evidence/sky_weather/native/night_stars.png) · [暮色林间](evidence/sky_weather/native/sunset.png)。

[晴天](evidence/sky_weather/native/rain_start.png) → [聚云](evidence/sky_weather/native/rain_clouding.png) → [雨量增加](evidence/sky_weather/native/rain_building.png) → [暴风雨](evidence/sky_weather/native/rain_full.png)。
