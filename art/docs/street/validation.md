# 道口场景验收记录

主相机输出 1704 × 960，缩回 852 × 480。对比 SHA、排除水印的区域、逐像素 ΔE00 与树冠遮罩轮廓均保留在[对照数据](../../captures/street/final/comparison/comparison.json)。

19 个位置采用原图预标注的同一地标，从最终渲染图人工判读。原图和成片的位置都有约 2–4 px 的判读误差。地台后边是推断角点。误差表按屏幕像素欧氏距离记录。19 点的中位偏差为 2.24 px，最大为 7.81 px（站棚亮顶脊左端）。[目标锚点](reference_anchors.csv) · [实拍锚点](render_anchors.csv)

建筑檐角、停止线、站台边沿与原图的遮挡次序相符。大樱花局部的可见粉色轮廓 IoU 约 0.79。小樱花、后排树和部分花团的内部形状仍有差异；从局部参考无法唯一确定遮住的结构。道路上的斜影方向一致，暗线端点部分被遮住，未把未经确定的阴影全长当作实测值。色区独立验收有 12/13 个达标，保留路面局部的超标项。整体颜色评估不替代这些局部结论。

M1 白模比较了相机投影，M2 对照了轻描边，M3 初版保留在 captures 目录。M4 调整屋檐、花团、坡岸和站房，M5 已保存左右侧视、重新导入房屋并验证远近遮挡。[白模](../../captures/street/m1_blockout/main.png) · [首版](../../captures/street/m3_full_scene/main.png) · [终稿](../../captures/street/final/main.png)

资产数按实际场景节点统计，模型复用实例和花团外壳计入三角面；GPU 图元数还包括影子和后处理。[资产清单](asset_manifest.json) · [30 秒静机采样](../../captures/street/final/benchmark.json)
