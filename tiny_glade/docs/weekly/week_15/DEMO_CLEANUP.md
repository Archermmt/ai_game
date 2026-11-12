# demo 整理记录

2026-11-10。正式入口继续为 app/living_root.tscn，固定 Godot 4.7.2。

本轮删除旧草地预览、容量对照及其一次性测试、交付探针，共 39 份文件。清单见 [删除记录](evidence/demo_cleanup_removed.json)。历史实现可从 Git 6ce46c4 及之前的提交恢复。共享算法和正式场景依赖的周次继承链继续使用，功能回归仍能重复执行。

清除 reports 中的历史候选副本、临时输出与 Python 缓存，约 1.5GB。当前验证会重新产生约 7MB 报告，持久验收证据保留在 docs/weekly。Blender 编辑源、导入设置、插件锁定版及其许可继续保存。

足印贴图、界面橡皮图标迁入 assets。正式运行的音乐、音效、字体、图像和生活模型都在 assets，树草、房屋及浮叶网格按源码生成。assets/demo_inventory.json 登记运行资产校验值，八首音乐逐文件核验源 manifest。旧下载素材仍是本机历史实验缓存，导出已排除 assets/painterly_grass/local。音乐的现有使用与分发说明仍在原 manifest 中。

两份复盘分别覆盖产品定位、规则、范围、交互、美术、里程碑，以及数据、事务、建筑洞口、地形池岸、道路结构、植被、异步重建、保存、摄影和漫步。版本化副本见 [策划指南](../../guides/治愈系微缩建造游戏策划指南.md) 和 [核心玩法开发指南](../../guides/治愈系微缩建造游戏核心玩法开发指南.md)。同内容文件已写入用户指定的策划、开发目录。

复验命令可在项目根目录执行。

```sh
python3 tools/quality/demo_assets_checks.py
python3 tools/quality/run_checks.py --week 9 --negative-control
python3 tools/quality/woodland_checks.py --native
```

结果为 240 份资产与八首音乐校验通过，446 项累计回归及负控通过，74 项专项、3,283 个断言和 24 项 Metal 实拍检查通过。当前文件迁移后的原始结果保存在 [本轮证据](evidence/demo_cleanup/)。本轮未进行新性能预算测量或 Windows 真机验证。
