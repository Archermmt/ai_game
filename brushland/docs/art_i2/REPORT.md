# I2：连续岛面与材质第一批

2026-10-29；承接I1提交5f568f9。

- 1m逻辑格/存档不变；显示采用0.5m连续高度采样，8m分块，地基保持平整，较大高差仍保留陡边。道路端点、人物脚底和编辑射线使用同一表面。
- 快照差分决定脏块及邻边，稳定块和模型保持原节点。网格数组在WorkerThreadPool生成，主线程提交；当前等待本笔worker完成，尚非可取消的完全异步发布。
- Poly Haven三项材质九通道已下载、核对官方MD5/大小并记录SHA256，见[下载锁](downloads.json)。原件位于game/art/materials；CC0来源为https://polyhaven.com/license。照片纹理通过shader低对比混合，GL法线弱化。
- 主屋/茶屋/灯塔材质试装，屋顶补UV/切线；两种原创叶片树冠与岩组先作样板。Quaternius下载入口的实际模型包未取得，未冒称已导入；原创树冠仍需后续视觉调整。
- 独立表面21项检查通过：采样、撤销/重载、稳定块ID和清空；原8步规则回归及两渲染器实际截图/编辑/摄影通过。报告在docs/reports/art_i2，截图在snapshots/art_i2。

本机Compatibility短样本帧间隔p95 14.428ms，整笔重建p95 37.521ms（I1约107ms）。固定存档、同机位；光照按渲染路径校准，因此不是只替换网格的纯光照对照。不是M1/Windows或完整压力验收。

VA04第一版与VA05首批样板可检查；G1参考级视觉仍未通过。接下来I3完成分层草、风/种子/避让、受光浅水与连续白沫，再联调光照。当前宽泛的主屋材质映射、远景树冠疏密和岩岸造型仍须精修，不标全部美术资产完成。

[全景](../../snapshots/art_i2/gl_compatibility/whole.png) · [主屋](../../snapshots/art_i2/gl_compatibility/house.png) · [岸边](../../snapshots/art_i2/gl_compatibility/shore.png)
