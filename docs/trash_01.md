# TRASH-01 餐厅垃圾桶交付

2026-10-21，在用户明确授权的 `F:/maze_code` 直接增量实现。当前分支 `master`，基线及交付时 `HEAD`（当前提交）均为 `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`；没有创建工作树、切分支、提交或推送。

## 玩家行为

垃圾桶位于左端柜台草边，世界脚底位置 `(195,545)`。使用已确认低饱和透明原素材，显示区域裁切、不重生成图片；原地图局部草叶在桶前遮住左侧轮廓与桶脚，后方草叶保留。脚底胶囊碰撞挡住桶实体，右侧可接近，下方可通过。

最近目标为垃圾桶时显示原 `interact_button.tscn`（道具交互按钮），文字为“E 丢弃”；鼠标与 E 进入同一流程，B 不触发；确认框内 E 不直接确认丢弃，自动重复按键被拒绝。旁边冰柜更近时仍选冰柜，不为垃圾桶改变最近目标规则。

第一章正式结束且章末标题关闭后开放；之前可看见桶，操作提示“请先完成当前任务”。第一章已有的错误目标提示继续由教程发出，避免叠加两条提示。对白、过场、烹饪和其他持有输入锁的窗口阻止触发。

复用 `destination_confirmation.gd`（统一确认框）及 `feedback_toast.gd`（短暂提示），专用子类仅屏蔽 E 并加入限高物品清单。文案“丢弃以下物品？丢弃后无法找回。”，列名称与数量，按钮“取消 / 确认丢弃”，默认焦点取消。空手不弹框，只提示“没有可丢弃的食材或料理”。取消、Esc和默认 Enter 不改库存，关闭恢复原输入状态。

一次清空全部已登记料理原料及料理成品，包括全部星级余额；不触及仓库、木材、其他物品、订单、交付进度或奖励。存档事务接收玩家确认过的清单，清单改变则拒绝旧确认。保存失败完整恢复内存状态，窗口保留并提示“保存失败，物品未丢弃，请重试”；成功提示“已丢弃”，既有携物组件自动从真实库存刷新。

## 本次增量

- `scenes/restaurant_map_2d.tscn`：新增垃圾桶节点。
- `scripts/restaurant/trash_bin.gd` 及其 `.uid`：素材、碰撞、原地图草叶采样；人物在桶前后时调整绘制层级，避免吧台前景采样误盖桶盖。
- `assets/props/trash/trash_bin.png` 及 `.import`：复制已确认原素材。
- `scripts/restaurant/discard_flow.gd`、`discard_confirmation.gd` 及其 `.uid`：专用流程与统一确认框子类。
- `scripts/save_manager.gd`：新增白名单读取、完章门槛和原子丢弃事务；既有接口不变。
- `scripts/player_map.gd`、`scripts/ui_layer.gd`、`scripts/ui/restaurant_hud.gd`、`project.godot`：键鼠路由、原按钮和通用 E 输入路由。
- `tools/tests/trash_01.gd`、`.gd.uid`、`.tscn`、`trash_01_run.ps1`：隔离验收入口。
- 本文和 `docs/ui_component_library.md`：交付与组件使用登记。

动工前全部 Git 状态记录在 `output/trash_01/baseline/git-status.txt`。本票涉及的既有文件逐个保留原始快照在同目录，以文件路径双下划线命名；交付差异与这些快照比较，不能把相对 Git 提交的所有差异当作本票改动。受保护的距离显隐、携料图标、现有料理判定及其他既有更改均保留。

## 已运行验收

引擎实际为 `F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`，报告版本 Godot 4.7.2。项目真实主入口为 `scenes/start_screen.tscn`，餐厅目标为 `scenes/restaurant_map_2d.tscn`。

```powershell
& tools/tests/trash_01_run.ps1 -Mode flow -OutputRoot F:/maze_code/output/trash_01/accepted
& tools/tests/trash_01_run.ps1 -Mode prepare -OutputRoot F:/maze_code/output/trash_01/final_prepare -ProfileRoot F:/maze_code/output/trash_01/final_persistence_profile
& tools/tests/trash_01_run.ps1 -Mode resume -OutputRoot F:/maze_code/output/trash_01/final_resume -ProfileRoot F:/maze_code/output/trash_01/final_persistence_profile
& tools/tests/trash_01_run.ps1 -Mode smoke -OutputRoot F:/maze_code/output/trash_01/smoke
& tools/tests/trash_01_run.ps1 -Mode import -OutputRoot F:/maze_code/output/trash_01/final_import
```

`flow`（真实场景流程）双分辨率 1152×648、1280×720共119项通过；另在 `prepare`（事务准备）补验了真实待交付订单及事务层章前限制，共25项通过。`resume`（独立进程恢复）4项通过。最终完整流程已包含上述补充断言。启动与编辑器检查通过，全部报告均核对正式存档指纹不变。

流程通过实际 `InputEventKey` / `InputEventMouseButton`（键盘/鼠标事件）驱动正式餐厅场景；测试初始存档和物品由隔离夹具设置。覆盖距离、相邻目标选择、B/E/鼠标/重复事件、取消/确认/Esc/默认回车、空手、多种多份原料与成品、全目录长清单、第一章真实移动教学限制、物理碰撞与通道、真实对白/仓库/烹饪窗口拦截、输入恢复、真实文件写入失败完整回滚与重试、料理星级清理及独立进程读档。回归实际前台接单→仓库鼠标取料→汤锅开始/结束→结果关闭→吧台上菜。

截图在 `output/trash_01/accepted/screenshots`：`bin_near_*`（桶与原按钮）、`confirm_*`（确认）、`save_failed_*`（保存失败）、`discarded_*`（成功）、`all_food_scroll_*`（长清单）、`regression_cooked_*`（烹饪）、`regression_served_*`（上菜）、`chapter_locked_1280x720.png`（真实章前限制）。已检查双分辨率位置、草叶覆盖、确认布局和桶盖不受吧台采样遮挡。

早期失败记录保留：`flow1` 的夹具站位选中了更近冰柜，改为真实可达桶右侧后通过；`extended` 使用旧教程固定序号的两项断言失败，改为识别正式前台移动步骤后通过，没有改教程数据以迁就测试。视觉检查另修复了双提示和桶盖被前景采样遮挡。

## 限制与知识交接

环境警告：系统证书库读取失败；编辑器检查另有引擎安装目录下编辑器设置无法保存。它们与本票脚本、资源和场景运行错误分开记录，最终没有项目错误。未验证实际操作系统断电/进程在重命名瞬间被强杀；持久化沿用原同目录临时文件替换实现，已验证真实写入失败与正常跨进程恢复。本票未增加迷宫丢弃、补料、奖励或取消订单能力。

可复用知识：携物图标读取料理原料目录与料理目录的真实库存，丢弃必须同时处理成品星级余额；否则会留下隐性可交付记录。正例是统一保存成功后图标自动消失，反例是仅隐藏图标或仅清材料。场景底图前景采样可能覆盖新增独立道具，必须在角色位于其他道具后方时检查，而非只看桶旁截图。修改物品目录、星级存档、章节结束契约、前景采样或锁定路由后，应重跑本入口及双分辨率截图；失败按原事务/路由修正，不绕过保存或距离选择。

来源任务接收本地交付后仍需审查本次增量和验收证据。本票已在目标目录实现，不需要再次复制或整文件合并。

2026-10-21 按用户确认改为通用 E 交互，删除专用 B 映射，确认框仍需显式确认。keys 专项双分辨率59项通过，正式存档不变，截图与报告 output/trash_01/e_keys_review。此次完整 flow 在顾客订单初始化失败，伴随后续接单和教程失败（output/trash_01/e_key_verify），未将旧全流程宣称为本次通过；本次未修改订单生成逻辑。keys 覆盖原按钮E、B无效、确认取消、长按、保存失败、碰撞、空手、章前门槛与输入锁。
