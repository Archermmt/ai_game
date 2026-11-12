# demo 运行资产

所有游戏运行资源使用 res://assets/ 路径。音乐位于 audio/seasonal_music，八首文件的源摘要、处理与权限说明见该目录 manifest.json；环境与操作音效见 audio/manifest.json。字体许可随 fonts 一起保留。

woodland/clouds、materials/woodland_cabin、materials/woodland_ground 是温馨小屋画风的云、木石、草地和雪面输入，分别由 tools/art/build_woodland_clouds.py、build_woodland_timber.py、build_woodland_ground.py 重建。几何由 features 中的生成器创建。已有自制生活道具位于 week_04 至 week_06 等目录。

demo_inventory.json 记录本次整理时的资产摘要。painterly_grass/local 是旧实验本地缓存，不属于当前 demo 的供应依赖，也不进入导出包。可编辑来源保存在 art_source，插件实现和其许可保存在 addons。
