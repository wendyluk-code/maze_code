# TEAM-ENTRY-01-R2 迷宫入口组队

## 行为与复用

餐厅迷宫入口直接打开组队弹窗。四个横向槽位初次为空；加号打开已拥有角色列表，头像和姓名复用现有角色详情，独立勾选框加入或移除角色，最多四人且不重复。当前生产角色仍只有芽芽、铁山，没有添加角色或修改拥有名单。

基础战力读取当前等级的攻击力总和；饱腹度读取只读恢复快照的当前余额与上限。技能区按阶位逐项显示已解锁名称和完整说明，可滚动。总当前饱腹为零时在饱腹行下显示红字“当前队伍饱腹度为0，无法捕获任何食材。”，仍允许出发；空队或体力不足禁止出发。

`team_entry_modal.gd`（组队入口组件）扩展已有通行确认，复用 SproutTheme（界面主题）、20体力消耗行、取消与确认按钮；组合原生容器、列表、复选框和可滚动正文。角色详情继续使用 `character_details_modal.gd`，头像使用现有正方形肖像和24像素派系图标。Esc逐层返回详情、列表、入口；Tab限制在当前层，遮罩拦截下层点击。餐厅沿用原输入锁定与恢复，不新增独立暂停系统。

## 状态与事务

`SaveManager.TEAM_MEMORY_KEY` 对应 `maze_team_memory_v1`（上次成功队伍记忆），只保存有序角色ID数组。没有字段或字段非法时返回空队。组件内 `selected`（当前选择）是草稿，取消不写存档。

`request_maze_entry(party)`（预留入场队伍）验证拥有关系、去重、一至四人、体力和无活跃探索，保存临时 `_maze_entry_party`；重复确认返回忙碌。兼容旧调用不传参数时仍使用原拥有名单，真实餐厅始终显式传入草稿。`exploration_entry_party()`（读取本次入场队伍）供 CaptureRun.begin 使用；没有临时请求时保留历史直接入口的名单兼容。已有活跃探索先走原恢复分支，队伍不被记忆或草稿覆盖。

到达迷宫后，CaptureRun.begin（创建探索）冻结所选成员和饱腹状态，并在原 `record_maze_location`（位置保存）事务内一起写入20体力消耗、位置、完整探索与队伍记忆。成功清理临时队伍；保存失败恢复完整状态并清理请求。由真实餐厅请求触发的到达保存失败会返回餐厅，禁止旧自动重试在临时队伍清理后误用默认名单。普通活跃探索恢复仍保留原重试行为。资源加载或转场返回错误时，餐厅清理请求，不提交草稿。加载存档也清理所有待进入状态。

正例：只选铁山出发，探索成员和头像仅铁山，拥有名单仍是芽芽、铁山。反例：先覆盖拥有名单，或在点击确认时先单独保存记忆。修改保存接口、位置切换、队伍拥有规则或恢复分支后必须复跑事务及真实转场检查。

## 基线与交付边界

执行目录：`C:/Users/KSG/.codex/worktrees/e263/maze_code`，分支 `codex/team-entry-01-r2`，原快照 `ef836bea2db23ff73de684b71649f393b47aa5c9`。来源任务确认快照包含另一清理任务的中间状态后，单独恢复了主目录的 SaveManager 兼容基线，提交 `20777d25153893101d7b8f015a7bc5906aaa47e5`；其文件SHA256为 `9c92e05620d4727adf9390b9d7edd2b36a92a14e327c5ee20f1f2517252989dd`。最终集成仅应用该提交之后的本票增量，不能合并原快照或兼容基线提交。

实际 `project.godot` 的启动场景为 `scenes/start_screen.tscn`，引擎版本4.7；真实玩法验收显式加载 `restaurant_map_2d.tscn` 和 `maze_entry.tscn`。没有修改受保护的 `scripts/ui_layer.gd`，也没有修改美术、角色配置、任务系统或插件。

## 实际验证

运行器 `tools/tests/team_entry_01_run.ps1`（专项执行入口）使用独立 APPDATA / LOCALAPPDATA（应用数据目录）、240秒超时及隐藏进程，比较正式存档全部JSON指纹，不恢复或覆盖用户存档。实际输出均在执行目录的 `output/team_entry_01/`：

| 输出目录 | 结果 |
| --- | --- |
| `final_flow` | 123项通过，1152×648及1280×720实际渲染与鼠标/键盘操作，16张截图加保存失败返回截图 |
| `final_restart` | 独立进程4项通过，实际重建迷宫、记忆/原趟队伍/头像顺序一致且不再扣费 |
| `final_import` | 编辑器导入退出0，无脚本或资源错误 |
| `final_smoke` | 主入口无头启动退出0，无脚本或资源错误 |

各轮正式存档指纹一致。系统根证书读取及编辑器全局设置写权限警告分别记入 `summary.json` 的 `environment_errors`（环境错误），未将脚本或资源错误归入环境问题。

专项覆盖：首次/旧档空队、单人/双人选择、取消草稿、属性真实值、技能解锁全文和滚动、详情/列表遮罩、逐层Esc、Tab限制、实际移动恢复、零饱腹可进入且捕获拒绝、体力不足、重复确认、真实队伍与头像顺序、拥有名单不变、入场保存失败全量回滚并返回餐厅、空资源转场失败、存档重载与独立进程恢复。四人上限、第五人拒绝、去重和补位使用隔离五ID夹具执行组件实际使用的 `update_selection`（更新选择）函数；没有向正式角色数据添加虚拟角色，也不声称已运行四个生产角色的探索。

早期失败及修正证据保留：`flow_initial` 的夹具入口节点名错误；`flow_node_fix` 定位到动态列表节点路径不稳定，改为保存容器引用；`flow_rows_fix` 的夹具体力时间戳非整数、铁山等级不足以击败首怪，分别按生产数据契约修正。之后 `flow_fixture_fix` 96项、`extended_flow` 117项和最终123项通过。没有修改生产数值迎合测试。已查看两种分辨率的选人、详情、完整技能滚动、零饱腹和迷宫截图。

主会话合入 `F:/maze_code` 后执行：

```powershell
./tools/tests/team_entry_01_run.ps1 -ProjectRoot F:/maze_code -Mode import -OutputRoot F:/maze_code/output/team_entry_01/integrated_import
./tools/tests/team_entry_01_run.ps1 -ProjectRoot F:/maze_code -Mode flow -OutputRoot F:/maze_code/output/team_entry_01/integrated_flow
./tools/tests/team_entry_01_run.ps1 -ProjectRoot F:/maze_code -Mode resume -ProfileRoot F:/maze_code/output/team_entry_01/integrated_flow/profile -OutputRoot F:/maze_code/output/team_entry_01/integrated_restart
./tools/tests/team_entry_01_run.ps1 -ProjectRoot F:/maze_code -Mode smoke -OutputRoot F:/maze_code/output/team_entry_01/integrated_smoke
```

独立工作树验收不代替上述最终集成。旧13怪全量回放未运行；该场景已经采用10怪目录。导入造成的 `.import` 路径噪声保留但不提交，禁止整工作树覆盖主目录。

## 原任务审查修正

来源审查要求补齐零饱腹警告末尾中文句号，并修复扩展组件对普通通行确认的兼容。共享提示行与按钮现按模式挂回对应容器，普通模式隐藏组队和子层、重置模式、委托父类处理输入与刷新；再次打开组队恢复组队容器和门禁，重复打开保持控件顺序。没有修改普通确认基类。

修正后 `review_final_flow` 实际双分辨率145项通过（保留原123项，新增普通确认鼠标确认/取消、默认Enter取消、左右键+Enter、E松键、Esc、探索→普通→探索、重复探索布局顺序）。`review_final_restart` 独立进程4项通过；`review_final_import`、`review_final_smoke` 均退出0，无脚本或资源错误，所有正式存档指纹一致。19张截图在 `review_final_flow/screenshots`，已查看普通确认及带句号零饱腹警告。当前修正版以这些输出为准，之前输出保留为历史证据。

## 稳定知识与复查条件

拥有名单、弹窗草稿、临时入场请求、活跃探索成员和成功队伍记忆是五种不同生命周期的数据：浏览只改草稿，入场统一提交后冻结成员，恢复只读取原趟成员，失败清理请求。需要扩展角色种类或队伍编辑时重新审查名单来源、数据有效性和UI四槽限制。临时队伍清理后不能继续旧新探索自动重试，否则会以兼容名单创建一趟非用户选择的探索；失败返回流程与保存事务必须一同复验。
