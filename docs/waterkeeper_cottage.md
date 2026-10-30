# 守水人小屋地图接入

目标工作区：D:/workspace/代号：料理迷宫。本次仅接入室外地图，不添加铁柱、纸条剧情、采集、商店、怪物或奖励；南侧树根庭院出口不开放。

## 玩家路径

从分水庭进入青苔池，沿出生点所在土路往北走，到尽头的紫色路标选择“前往守水人小屋”。小屋右侧道路出生，沿石桥抵达门前院落。右侧来源路标返回青苔池同一土路的安全落点。两端沿用已有的“前往 / 结束探索”确认框；Esc 仅关闭确认，不结算探索。

室外道路与院落可走；房屋、菜畦、围栏、溪流、悬崖背景不可走。南路允许接近树根方向，但在出图前止步，没有通往树根庭院的传送。青苔池原有地形未扩大。

## 生产接入

- 场景：scenes/maze_waterkeeper_cottage.tscn，区域标识 waterkeeper_cottage（守水人小屋）。
- 底图：assets/maps/waterkeeper_cottage.png，1672×941；原稿和去除伪文字牌子的生成记录保留在 output/waterkeeper-map-20261028/。
- 地形及连接：data/maze/waterkeeper_cottage_roads.gd；位置保存、恢复及战斗状态允许区域同步登记。不改变存档版本，不为旧档虚构已到访记录。
- 总图：waterkeeper_cottage_projection.gd；和青苔池共享一个连接标记，以原总图的小屋旁土路、院落及南路独立核对。详细地图与总图不是同一比例，不保证逐像素等距。
- 界面复用：world_interaction_prompt.gd（世界位置按钮）、destination_confirmation.gd（区域选择）、既有短暂提示和地图组件；没有新增界面样式或玩法任务。

## 可复跑验收

在项目根目录用 PowerShell 运行 tools/tests/waterkeeper_run.ps1；-Godot 可覆盖本机引擎位置，-OutputRoot 指定独立证据目录。

1. -Mode flow（实际场景流程）：覆盖1152×648与1280×720、真实方向输入走到入口和院落、房屋/溪水/菜畦阻挡、南侧止步、鼠标/键盘确认、取消恢复输入、换区保存失败回滚、攻击期间拒绝换区、往返与重进、总图定位、非法位置恢复、不新增怪物资源及青苔池新路标结算。
2. -Mode restore（独立新进程恢复）：必须通过 -ProfileRoot 复用前一步输出下的 profile 隔离目录，验证小屋场景、院落位置、活动探索和实际结束探索返回餐厅。测试末尾只恢复隔离样例，以便预览。
3. -Mode regression（旧地图回归）：复用青苔池原专项，包含分水庭和盐池往返。
4. -Mode import（编辑器导入）与 -Mode smoke（无头启动）：检查资源和脚本，不代替实际场景验收。

每轮保留 summary.json（汇总）、report.json（行为报告）、标准输出、错误日志、截图和正式档前后指纹。首次缺少场景的预期失败保留在 output/waterkeeper-integration-20261028/red-behavior；测试前置和投影校准期间的失败记录不删除。最终证据使用同一根目录的 final-flow-v4、final-restore、final-regression、final-import、final-smoke。只有最终日志无脚本错误、报告通过并核对截图后，才作为当前版本的完成证据。

交互式验收启动前查询本机显示器，指定副屏；无副屏则停止，不回退主屏。小屋专项另记录引擎实际窗口所在屏幕与坐标。测试在隔离进程内注入方向输入，不操作用户其他窗口；为允许用户同时使用主屏，仅测试夹具维持内部焦点标志，不改变生产游戏的失焦暂停规则。

边界：隔离存档验收不代表已修改玩家正式进度；不覆盖现有未提交改动，不提交或推送代码。未覆盖未来剧情、联网存档或其他设备。

## 屋侧通路与植物摇动（2026-10-28追加）

用户确认开放屋侧、菜畦间的土路，不开放房屋室内。新增通路从院落经(620,344)、(550,335)、(500,350)、(450,363)、(400,380)到(350,392)，并连接原有葡萄架方向的小路。番茄菜畦、大叶蔬菜菜畦和柴堆有独立阻挡；溪流、房屋及南侧未开放出口维持原规则。

植物仅为装饰，不产生采集点或奖励。番茄与大叶白萝卜各自分层：根部与接地阴影固定，上部轻摇和轻微呼吸，不同植株错开节奏；番茄下部运动略滞后。进入植株65世界像素范围时触发一次衰减轻颤，持续停留不重复，离开85像素后可再次触发；玩家输入锁定期间不新触发回应。这些距离仅用于装饰反馈，不改变交互、战斗或采集距离。

原地图 waterkeeper_cottage.png 保留。waterkeeper_cottage_soil.png（去除旧植株的生产底图）只合成两块菜畦局部，区域外保留原图像素；不重画房屋、道路或桥梁。透明植物位于 assets/props/cottage_garden/，生产尺寸160×160，四周留出摇动空间。分层控制为 scripts/maze/cottage_garden.gd，局部叶片形变为 cottage_plant.gdshader。

三张改稿沿用本地网关与 seasunCodex/gpt-6-luna 请求模型，完整提示词、原始PNG、透明请求参数和生成日志保留在 output/cottage-garden-20261028/。tools/prepare_cottage_garden.gd 可从这些原始素材重新生成局部补土与缩小后的透明植株，不调用模型，也不替代视觉检查。

新增验收入口为 tools/tests/cottage_garden_run.ps1：-Mode flow 跑双分辨率实际场景，包含WASD、斜路方向输入、障碍、位置保存、根部固定、错峰轻摇、靠近一次回应与离开重入；-Mode restore 必须通过 -ProfileRoot 复用前一步的 profile 子目录，在新进程恢复菜畦间位置；-Mode regression 复验小屋原往返与地图流程；-Mode import 和 smoke 分别检查导入及启动。所有交互进程继续指定副屏。

最终证据位于 output/cottage-garden-20261028/final-flow、final-restore、final-regression、final-import、final-smoke，包含报告、截图、正式档指纹及本次源码摘要。原有失败记录保留，不用后续通过覆盖。motion_1280x720 内的48张图片来自真实场景逐帧渲染；cottage_garden_preview.py 只将其组装为审阅动图，不补造运动。
