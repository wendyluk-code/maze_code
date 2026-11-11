# 冰柜布局编辑

打开 scenes/restaurant_map_2d.tscn，在场景树展开 InteractPoints → Fridge → FreezerLayout（已开启可编辑子节点）。

- Tray：原手绘凹槽贴图。选择 Polygon2D，使用顶部多边形顶点编辑工具拖动四角来调整透视。只调整 polygon 顶点；UV 是原图取样坐标，通常无需修改。
- Slot1 / Slot2 / Slot3：三个杯位中心。移动 Marker2D 会同时移动杯子、点击区域及该杯位的提示。
- 每个杯位下的 Selection：选中框轮廓，可调整多边形顶点；编辑器的浅蓝辅助面在游戏中隐藏，只绘制靠近时的选中线。
- Thermometer：温度计左上角位置。
- Prompt：E 提示位置。

底图透视变化不会自动改变杯位，需同时对齐三个 Slot。不要移动 Fridge 本身或其 OcclusionOutline：它们控制既有交互位置和遮挡。

保存餐厅场景后重新运行即可生效。也可单独编辑 scenes/restaurant/freezer_layout.tscn 修改默认布局，但单独场景没有地图作为参照。已有实例属性覆盖优先于默认布局。

运行时仍只在首次探索教学成功完成并返店后显示；第一章及战败返回不提前解锁。未修改冰镇时长、禁取、损坏判定、订单和惩罚。

验证：目标工作区冰镇集成68项、坐标及界面14项、第一章31项通过，正式存档不变。证据分别为 output/freezer_editor_integrated_20261104、output/freezer_editor_coordinates_verified_20261104、output/freezer_editor_chapter_20261104。初次坐标验收在同帧读取旧按钮位置失败，改为等待实际下一次处理后通过，失败记录保留。系统证书读取警告与本功能无关。
重新审查条件：修改节点名称、节点层级、交互距离或槽位数量时，需要重新验证坐标绑定和交互。

## 前景缺角修正（2026-11-04）

实机单变量对比确认：第三格缺角来自 z=50 的旧地图前景覆盖 z=2 的新 Tray。prop_foreground 仅为具有 FreezerLayout/Tray 的对象绑定 freezer_foreground 材质；可见 Tray 多边形以内不再绘制旧前景，其余柜身保持原遮挡。每帧读取当前顶点、偏移和变换，保留用户的场景覆盖。当前边界支持最多64个顶点，贴图透明区域也按多边形整体避让。

目标 F:/maze_code：重叠实机场景13项、冰镇68项通过，正式存档未变。截图位于 output/freezer_overlap_after_20261104/foreground_on.png；修正前开启/关闭前景的对照位于 output/freezer_overlap_before_20261104。

第一章回归31项有2项未通过：首句对白、移动教学提示的可见性。串行复验与关闭新增材质的控制实验同样失败，暂无证据归因本次修正，尚未定位其根因；不能宣称第一章回归全通过。日志分别在 output/freezer_overlap_chapter_serial_20261104 和 output/freezer_overlap_chapter_control_20261104。系统证书读取警告单独保留。

若修改 Tray 为带透明孔洞的素材、超过64个顶点或改变前景坐标系，需要重新验收边界。

2026-11-04：Prompt 锚点现在定位统一的140×48屏幕按钮，文案为 E 冰镇；旧挖掘键帽及料理保鲜按钮已移除。杯位、选中框及前景避让不变。

2026-11-04更新：温度计改为自动贴杯右侧并按杯图非透明高度对齐，原 Thermometer 节点保留但不再控制实际位置；调整 Slot 即可让杯子与温度计一起移动。
