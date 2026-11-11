# 餐厅布局编辑

## 当前显示模式（2026-10-29）

已按用户要求恢复拆分前的 `assets/maps/restaurant_map.png` 完整底图。当前不绘制独立设施及圆凳图片；旧节点仅保留碰撞、交互范围、E 提示偏移与顾客定位数据，用户手调数据不回退。原图包含右上方门、不包含新增垃圾桶图像，垃圾桶交互点仍保留。移动这些节点不再移动底图中的设施外观。主角与顾客层级保留；从原图采样柜台前景以维持顾客在柜台后、凳子前，其他设施复用原地图遮挡区域并保留左侧主角优先。该遮挡区域与碰撞范围独立。下方拆分图片编辑说明仅适用于保留的独立道具场景，不是当前主地图显示方式。

验证：`output/restaurant_layout/flat_map_02/` 场景检查 120 项通过，`flat_map_order/` 首单 16 项通过，正式存档未变。实际画面已核对；仅系统证书环境警告。原地图遮挡数据保存在 `assets/restaurant_layout/original_occlusion.json`，仅用于原图坐标，换图时须重新校准。

入口是 `scenes/restaurant_map_2d.tscn`。在 Godot 的二维编辑界面打开它，即可调整餐厅；游戏启动仍沿用开始界面。正式底图为用户批准的右上角无门版本。

## 移动现有设施

在左侧场景树展开 `InteractPoints`（交互物件），选中设施根节点，按 W 使用移动工具，或修改检查器中的 Transform / Position（变换／位置）。保存场景后运行，图片、碰撞、交互区域和按钮定位一起移动。

| 节点 | 对象 |
| --- | --- |
| Cauldron | 汤锅料理台 |
| FoodCart | 小餐车 |
| Fridge | 冰柜 |
| BarCounter | 吧台，包含三张可独立移动的圆凳 |
| Register | 收银前台，包含顾客、排队和教程镜头定位点 |
| Store | 仓库货架 |
| TrashBin | 垃圾桶 |

每个设施是 `scenes/restaurant/props/` 中的独立场景。餐厅内已开启设施的 Editable Children（可编辑子节点）；展开即可调整内部节点。画布采用组合选择，调整完整设施时选根节点，修改子节点时从场景树选择。背景 BG 已锁定，避免误拖。

三张圆凳在 `BarCounter/StoolRight`、`StoolMiddle`、`StoolLeft` 下。移动吧台会带动整组；单独移动圆凳时，其 `Seat0/1/2`（座位定位点）会一起移动。第一张座位同时用于铁山与普通顾客。当前经营容量仍为三席，增加装饰圆凳不会自动增加订单容量。

## 调整层级、图片和碰撞

2026-10-29：冰柜、小餐车、汤锅开启 `Player In Front On Left`（左侧主角优先显示）。以设施根节点的世界 X 坐标为界，主角脚底位于左侧时，仅 Art 图片的相对层级临时降低 1；中线和右侧恢复原图片层级，继续按 Y 排序。此规则也覆盖左上方向，不移动设施、碰撞或 E 提示。其他设施默认关闭。移动设施后分界随根节点移动；修改根节点或图片层级后需复验。实际场景左右、前后截图及 120 项通过报告：`output/restaurant_layout/left_front_01/`，正式存档未变；系统证书读取环境警告仍存在。

修复记录：主角必须保持 Z Index = 0 才能和普通设施按落地点排序；UIOverlay 必须保持 Visible 开启，否则其 E 按钮及经营界面整体不显示。三张吧台凳使用绝对层级 -3（Z As Relative 关闭），位于顾客 -2 下方，吧台与前台仍为 -1。保留当前手调碰撞、交互轮廓、背景边界及吧台图片覆盖。2026-10-28 复验输出 `output/restaurant_layout/layer_fix_final/`（96 项）和 `layer_fix_order_final/`（首单 16 项），均通过，正式存档未变；各设施按钮截图为 `prompt_*.png`。按钮验收同时检查所属 CanvasLayer 可见性，不能只检查按钮自身 visible。仅残留系统证书读取环境警告。

默认以根节点的 Y 坐标排序，人物走到道具后方会被遮挡，走到前方会显示在道具前面。根节点代表落地排序点；调整图片相对位置时使用 `Art`（图片节点）的 Offset（绘制偏移），保持其 Position 为零，避免影响排序。

需要固定前后顺序时，修改设施根节点的 Ordering / Z Index（绘制顺序／层级）。数值越大越靠前；非零层级也会改变它与人物的遮挡关系。通常保留 0，以落地点排序。

当前固定规则：主角与普通设施为 0，吧台和点单前台为 -1，普通顾客与铁山为 -2。两个柜台始终低于主角、高于顾客；其他设施和主角继续按落地点排序。顾客因此也位于其他 0 层设施后方。顾客层级由生成脚本设置，运行时不能只靠修改场景默认值覆盖。验证记录：`output/restaurant_layout/layer_rules_01/`，86 项通过，正式存档未变；已检查料理台前后运行截图，环境仍有系统证书读取警告。

- `Body/Collision`：实际阻挡轮廓，可在二维编辑器选中多边形节点编辑顶点。禁用 Disabled 后不再阻挡。
- `InteractionArea`：交互轮廓，不参与绘制。需要单独扩大触达范围时修改其顶点。没有这个节点时，使用碰撞轮廓作为交互范围。
- `Ui Offset`：按钮相对物件根节点的偏移。
- `WalkZone/Boundary`：餐厅整体可走外边界，隐藏绘制但可选中编辑顶点。它限制整个场地，道具碰撞则随设施移动，不再保留旧底图中的家具洞。
- `Register/CustomerCounter`、`Queue0/1`、`GuestCamera`：候客、排队和首章镜头标记，可单独调整。
- `MazeReturnSpawn`：迷宫返回位置；移动时要确保主角脚底圆完整落在可走区域内。

不要重命名现有业务设施根节点或座位定位点。它们仍被原有餐厅流程引用。

## 添加新道具

1. 在文件系统中找到 `scenes/restaurant/props/decoration.tscn`，创建继承场景并另存为自己的道具文件。
2. 选择 `Art`，将自己的透明 PNG 拖到 Texture（纹理），设置缩放和绘制偏移，使底部靠近根节点原点。
3. 若需阻挡，调整 `Body/Collision` 多边形并取消 Disabled（禁用）；不需阻挡时保留禁用。
4. 保存道具场景，将它拖入餐厅的 `Decorations`（装饰物件）节点下，调整位置、层级并保存餐厅。
5. 运行餐厅检查外观、遮挡与通行。要在餐厅实例内覆盖图片等子节点属性，先对该实例开启“可编辑子节点”，再保存。

新模板默认是装饰物，不注册为交互目标。仅打开 Interactive（可交互）不会自动添加经营功能；新料理台、库存容器等业务需要另接对应逻辑。布局保存于场景文件，已有经营存档不保存家具坐标，因此重新进入餐厅时采用最新场景布局。

## 实现与验证记录（2026-10-28）

实际目标工作区：`F:\maze_code`。基线：`1f426fbb12829fac854fe612694609d9a4b80f15`。未提交、未推送；保留 `tools/godot_portable/`，未修改受保护的 `scripts/ui_layer.gd`。

使用已有交互按钮、仓库窗、烹饪窗、教程和经营事务；本次不新增 UI 控件，不改变存档格式。`layout_prop.gd` 提供物件轮廓，`layout_walk_zone.gd` 读取场景边界与变换后的碰撞，`layout_anchors.gd` 为顾客和教程读取定位点。普通顾客与铁山采用新的排序与位置；旧图固定遮挡不再用于本餐厅。

在目标工作区实际运行：

```powershell
& tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/restaurant_layout.tscn -OutputRoot F:/maze_code/output/restaurant_layout/final_layout_02
& tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/restaurant_layout.tscn -Mode first_order -OutputRoot F:/maze_code/output/restaurant_layout/first_order_03
```

布局专项 78 项通过：包括设施接近与按钮显示、移动后原位置释放、新位置阻挡、顾客和座位标记、图片／位置／层级保存重开、新增道具在重开场景显示、迷宫返回出生、经营状态读档、实际移动输入。首单专项 16 项通过：真实 E 接单、鼠标取料及取消、料理台开始与空格起锅、结果确认、吧台交付、重复结算防护及输入恢复。两次均验证正式存档指纹未变。

运行截图和完整报告保存在上述输出目录。`depth_530.png`、`depth_850.png` 展示人物在料理台前后；`saved_layout_reopened.png` 是修改位置、层级并增加示例圆凳后的保存副本，示例不加入正式布局。

历史失败保留：前两轮发现新增实例未开启可编辑子节点导致图片覆盖未保存、JSON 数字类型导致比较误报，已分别修正保存方法和数值比较。普通顾客测试补齐两秒行走前置。旧首单测试使用失效步骤编号，改为按当前教程类型与目标推进；结果确认等待淡入可输入后再操作。迷宫返回点最初缺少完整脚底空间，已扩展该处边界并通过实际返回复验。

Windows 窗口截图工具两次返回 `SetIsBorderRequired failed: 不支持此接口 (0x80004002)`，未完成编辑器鼠标拖动的自动操作验证。保存、重开及运行检查通过 Godot 实际场景序列化与渲染完成，不能将其描述为编辑器鼠标操作已验证。引擎运行另有系统证书存储读取警告，已与脚本／资源错误区分。

最低启动检查也已执行：Godot 4.7.2 的 `--headless --path F:/maze_code --quit-after 5` 和 `--headless --editor --path F:/maze_code --quit` 均退出 0，无脚本解析或资源加载错误。编辑器日志另记录原有 `output/ch2_live_integration/candidates/` 中重复资源标识警告，以及沙箱不能写 Steam 安装目录下 `editor_settings-4.7.tres` 的设置保存错误；未扩张范围修改这些目录。日志为 `output/restaurant_layout/headless-startup.log` 和 `editor-final.stdout.log`／`editor-final.stderr.log`。

## 可复用知识与复验条件

### 四件设施投影更新（2026-10-28）

吧台、点单前台、冰柜、小餐车已改用 `assets/restaurant_layout/` 下对应的 `*_shadow.png`。投影随右上方光照向左下方延伸，四件素材同时适度降低饱和度，使用透明背景和柔和暖灰褐色；原无影素材保留。仅调整四个道具场景的 Art 纹理、缩放与绘制偏移以适配新图边界，保留餐厅实例位置、层级、碰撞及 E 提示偏移。

在 `F:\maze_code` 运行布局专项，输出为 `output/restaurant_layout/shadow_check_03/`：78 项通过、0 失败，正式存档指纹未变；已查看 `layout_overview.png` 确认四件设施及投影在实际餐厅中显示。编辑器导入退出 0；仍有系统证书读取、历史输出资源 UID 重复及安装目录编辑器设置无法保存的环境问题，无新增脚本或资源加载错误。新素材原稿及透明度分析存于 `output/restaurant_layout/shadows/`。替换其他带影图片时须按物件本体而非包含阴影的整图边界对齐，并复验实际场景。

餐厅道具的图片、碰撞、交互范围和关联标记应挂在同一根节点下，场景实例内部属性覆盖需开启可编辑子节点或另存继承场景。新增道具或调整层级、脚底原点、场地边界后，应复验前后遮挡、旧位置释放、新位置阻挡、交互范围、保存重开及返回出生；新增业务设施另验经营流程。原始生成设计稿保存在本地 `output/restaurant_layout/draft_v1/`，生产素材已进入 `assets/restaurant_layout/`，运行不依赖输出目录。
