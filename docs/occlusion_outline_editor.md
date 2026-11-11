# 遮挡判定轮廓编辑

打开 scenes/restaurant_map_2d.tscn，在 2D 视图展开 InteractPoints，选择设施下的 OcclusionOutline。顶部切换多边形编辑工具，拖动顶点并 Ctrl+S 保存，重新运行游戏生效。橙红色半透明轮廓只在编辑器显示，不增加物理碰撞。

支持汤锅、小餐车、冰柜、吧台、前台、仓库。垃圾桶和入口原来禁用遮挡，因此未凭空添加轮廓。现有六个轮廓原样迁移，未修正吧台右侧原有重叠问题，用户可自行拖动校准。

存在 OcclusionOutline 时，游戏优先读取其 Polygon（多边形）以及节点变换；根节点的旧 Occlusion Polygon 数组只供没有该子节点的旧场景兼容。不要同时修改两份数据。避免交叉边，至少保留三个顶点。Foreground Polygon 仍控制实际重绘区域，碰撞仍由原掩码控制，这两者没有改动。

2026-10-30 在 F:/maze_code 验证：output/occlusion_outline/first，28项通过，验证原轮廓、运行隐藏、坐标读取及保存重开，正式存档未变。已检查运行截图无辅助色块；未自动操作编辑器鼠标拖拽，使用 Godot 原生 Polygon2D 编辑能力。系统证书读取环境警告仍存在。
