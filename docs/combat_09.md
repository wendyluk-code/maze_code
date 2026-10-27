# COMBAT-09：每趟迷宫首遇史莱姆

执行基线为 `702294ac5586a4b13c9061a8a84f903500edd396`（`codex/combat-08`），独占分支 `codex/combat-09`，工作目录 `C:/Users/KSG/.codex/worktrees/e25c/maze_code`。来源任务 `01a14263-a55a-71d2-9fb2-10e636d0b31c` 已确认票据，依赖 COMBAT-08 已完成。项目归属依据来源明确选择 maze_code 并创建成功，`project_binding_verified=true`（项目归属已核验）。初始 HEAD 等于基线且工作树干净，创建分支所需共享 Git 元数据写权限已获工具批准。预算60分钟、90分钟强制停止，无超过20分钟的命令。本执行任务不合入 `F:/maze_code`，不推送。

## 行为与边界

每次真正新入场，从本次史莱姆配额中取一只作为 `slime_1`，固定在真实首路中心点 `(860,295)`；距出生点 `(1073,195)` 约235像素，超过150触发半径和180攻击选中范围，出生时不会贴脸激活。该点位于石门长廊，先于首个环路岔口，玩家沿路前进即可看到并遭遇。其余怪物仍使用原随机源抽取配额与道路候选点，总数10，组合仍为史莱姆/砖壳蜗牛/剑甲虫/石化蜥蜴的 `2/3/4/1`、`2/4/3/1`、`3/3/3/1`。石化蜥蜴固定 `(270,720)`，全部怪物保留80像素出生间距。

其它初始怪物不得落入入口道路起端 `(1117,126)` 至首只史莱姆点的224像素包络：对该段每条折线求最近点距离，必须大于224。224由当前最大触发半径200加道路半宽24组成，也覆盖180攻击选中范围。包络包含入口后退方向、左右可走区域与拐角圆帽。因此即使剑甲虫触发范围大于史莱姆，也不能在这段先激活或被选中。专项校验将战斗实际触发范围及选中范围与该边界比较，今后数值或道路变更会暴露失效。

生产改动仅在 `data/maze/capture_catalog.gd` 的新布局生成器。旧 `Catalog.all()` 固定布局保留，现有进行中探索、旧档缺布局补存、捕获保底资格、奖励和经验事务均不变。`Run.begin()` 仅在没有进行中探索时调用生成器；重复入场不补怪、不重抽、不重新授奖。

首段排除只应用于新布局，`spawn_points()` 全道路候选集和 `safe_spawn()` 原规则保持不变。首遇之后冷却仍为60/90/90/180秒，满足距主角260以外、视口外、道路合法和间距要求时，可重新随机出生在首段，不永久封锁该区域。首只史莱姆冷却刷新也不固定回 `(860,295)`。

## 证据链与测试边界

旧生成器只检查入口距离260及怪物间距，没有保证首遇顺序。修改前300种子专项全部不满足本票完整契约，其中种子4、5、6在实际模拟推进中，中心及左右路径均先激活剑甲虫。修改生成器后，同一专项通过；检查配额、固定首领、道路、间距、相同种子的确定性、不同种子的差异，以及首路可走采样点和实际模拟的首激活/首选中目标。

09流程专项通过真实餐厅交互点 E、探索准备确认和正式转场进入迷宫，不预置生产布局。迷宫首段使用实际移动输入，记录首个激活集合和第一个显示属性的怪物。首怪以生产满血、攻击、伤害和捕获随机值，接受真实鼠标攻击和 J 捕获操作。为验证冷却边界仅调整运行时钟；返回测试将角色放至合法结算点，再调用场景原返回入口，不声称回放了完整迷宫路线。07/08回归保留原固定布局夹具，未改写旧测试或生产固定布局来迎合新规则。

09状态专项覆盖新入场保存失败全量回滚、重复入场、旧进行中固定布局和残血、旧档双缺布局补存、旧趟结束后才启用新规则，以及真实弹道致死后的经验回执和失败回滚。

测试开发中保留的失败证据：

- `layout_before`：测试脚本局部变量类型无法推断，修正显式 `Vector2` 类型后才执行基线复现；不是生产失败。
- `layout_final`：追加触发半径边界保护断言后，其局部布尔变量类型需要显式声明；修正为 `bool` 后使用 `layout_guard_fixed` 复验，原301项通过记录仍保留。
- `layout_red`：旧生成器的300个契约失败，保留各种子的首次激活记录。
- `flow_first`：餐厅首次来客对白尚未关闭，E未打开入口准备；测试改为用真实E完成已有前置。
- `flow_arrival`：等待即将释放的迷宫对象协程导致测试无法继续，改为调用原返回入口并有界等待餐厅场景出现；只终止该次验收自己创建的进程。
- `flow_transition`：两项刷新断言失败，证据中背包值分别为整数1及读档后的浮点1.0，刷新代数为1、位置已随机变化、物品数未增加。测试改用已有递归保存比较，整数字值仍精确相等，不修改生产逻辑。

## 复跑

沿用 `tools/tests/combat_02_run.ps1`：每次隔离 APPDATA、LOCALAPPDATA、MAZE_QTE03_PROFILE，比较正式存档前后SHA256，命令超时只结束自己启动的进程。实际引擎 Godot 4.7.2，项目配置入口为 `scenes/start_screen.tscn`。输出在本工作树 `output/combat_09/`；截图是实际场景1152×648和1280×720。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_09_layout.tscn -OutputRoot output/combat_09/layout_guard_fixed
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_09_state.tscn -OutputRoot output/combat_09/state_first
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_09_flow.tscn -OutputRoot output/combat_09/flow_accepted
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_08_feedback.tscn -OutputRoot output/combat_09/regression_08
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_08_mouse_regression.tscn -OutputRoot output/combat_09/regression_07_mouse
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_07_hud_ui.tscn -OutputRoot output/combat_09/regression_07_hud
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_03_state.tscn -OutputRoot output/combat_09/regression_03_state
& tools/tests/combat_02_run.ps1 -Mode import -OutputRoot output/combat_09/import_final
& tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot output/combat_09/smoke_final
```

## 独立工作树验收结果

| 验收 | 检查数 | 失败 | 证据目录 |
| --- | ---: | ---: | --- |
| 300种子、三条路径、触发范围与配额边界 | 302 | 0 | `layout_guard_fixed` |
| 旧布局保留、入场与经验保存失败回滚 | 22 | 0 | `state_first` |
| 双分辨率餐厅入场、捕获、刷新、两种返回再入场 | 85 | 0 | `flow_accepted` |
| 08击退、白闪、墙边、暂停与恢复 | 227 | 0 | `regression_08` |
| 07真实鼠标、捕获J、胜败返回与读档 | 149 | 0 | `regression_07_mouse` |
| 07属性短条和界面输入 | 147 | 0 | `regression_07_hud` |
| 03各类冷却刷新、生命周期与旧档迁移 | 69 | 0 | `regression_03_state` |
| 编辑器导入、无头启动 | 两项退出0 | 0项目错误 | `import_final`、`smoke_final` |

合计1001项检查通过，300个种子生成300种不同布局并覆盖三种配额组合。六次真实入场（每个分辨率首次、正常返回后、放弃返回后）首个激活集合与显示目标均只有 `slime_1`，实测触发时玩家约在 `(990.16,228.90)`。已复看双分辨率实际入场/首遇截图，出生时史莱姆可见但未激活；首遇时属性短条指向史莱姆。截图在 `flow_accepted/screenshots/`，文件包括 `first_entry_1152x648.png`、`first_first_slime_1280x720.png` 以及两种返回后的首遇图。

所有执行批次正式存档指纹一致。系统证书读取和 Steam 编辑器设置目录写入警告已单列，没有项目脚本或资源错误。编辑器改变的462个既有 `.import` 元数据文件留在工作树，不恢复、不提交；本票提交仅含一个生产脚本、09专项及本文档。普通 `git diff --check` 将仓库原有CRLF行尾判为尾空白，按 `core.whitespace=cr-at-eol` 核查本票差异通过，未全文件转换行尾。

未回放全部餐厅经营、完整剧情或从首段徒步到出口；结算测试使用合法出口站位。未执行主目录集成，该步骤由来源任务负责。

## 可复用知识与重审条件

保证第一遭遇必须约束怪物触发圆与玩家可走区域的关系，不能只比较怪物距入口的距离。适用范围是本迷宫入口到首次遭遇的单通道；不变量是首怪配额内、其它触发范围不能进入受保护通道。正例是包络包含道路全宽与拐角；反例是把甲虫出生点放得略远却忽略它更大的触发半径。若修改入口道路、出生点、魔物触发半径或选中射程，应重新校验几何边界、300种子与双分辨率真实入口流程，并按新实际范围调整包络。此约束不能扩展成永久禁止首段冷却刷新。

玩家目标目录的增量合入与最终集成验收由来源主任务完成；独立工作树证据不替代该步骤。

## 主目录集成验收

2026-10-21：来源主任务在执行任务停止写入、释放租约后审查0c2e4f4b相对702294ac的11文件增量，通过git apply --check后合入F:/maze_code，保留主目录原有未提交改动。主目录依次运行combat_09_layout（302）、combat_09_state（22）、combat_09_flow（85）、combat_08_mouse_regression（149）、combat_07_hud_ui（147）、combat_08_feedback（227），合计932项、0失败。命令沿用本文运行器，输出目录为output/combat_09/integrated_<场景名>。编辑器导入integrated_import与无头启动integrated_smoke均退出0，无项目脚本或资源错误，全部正式存档指纹前后一致。

已查看主目录1280×720首遇史莱姆及1152×648围攻HUD截图，确认首遇目标、角色上方短条、仅当前怪显示属性及底部单长框双键帽。07、08此前的主目录集成证据继续有效，其中身体材质正常态逐像素一致由output/combat_08/integrated_pixels的21项检查证明。系统证书及Steam编辑器设置目录权限告警单独保留，不计为项目错误。验收范围不包含全部经营剧情，也不声称回放从入口徒步到出口。

## 出口外侧禁止出生（2026-10-21）

用户截图显示魔物出生在出口石阵左侧。代码证据：spawn_points遍历完整可走道路，包括(116,724)至地图左边缘，初始生成及refresh_due共用该候选列表，但safe_spawn原先仅检查道路、玩家距离、视口及魔物间距，没有出口边界。

2026-10-21的首次修正要求候选点x大于石阵坐标116；该旧边界已被下方2026-10-22规则取代。

2026-10-22按用户确认，将禁止出生区域扩大为蜥蜴1左侧通往出口的整段道路。`capture_catalog.LAST_MONSTER_POSITION`（末只怪物位置）统一为 `(270,720)`，初始候选点及 `safe_spawn`（刷新安全检查）共用 `x >= 270` 的边界；边界本身保留，蜥蜴可在固定位置刷新。当前地图所有其他道路均位于其右侧，因此该判定不会排除其他区域。总数10只、三种配额、首怪位置、80像素间距均保留；不迁移已保存布局，不限制追逐移动。改变出口道路走向或蜥蜴固定位置后必须重新审查此坐标边界。

主工作区本轮验收：`output/lizard_boundary_final` 的147项检查通过，包含300个随机种子、300次实际冷却刷新和出口场景截图；`output/lizard_boundary_layout` 的302项回归通过，覆盖配额、距离、入口首遇与相同种子可复现性。原候选点中5个后侧点被排除，完整刷新候选由138减为133，初始可选随机点由102减为100。更新点位图在 `output/spawn_maps_lizard_boundary`。正式存档指纹保持一致；旧规则红灯证据在 `output/lizard_boundary_red`，不计为通过。

主目录验收：exit_spawn_boundary专项149项（300种子外侧点检查、共用候选集合、直接刷新守卫、真实场景截图），combat_09_layout302项（300种子配额/间距/首遇），combat_03_state69项（真实冷却刷新与事务），合计520项功能通过，所有通过批次正式存档指纹不变。证据output/exit_spawn_visual_final、exit_spawn_combat_09_layout、exit_spawn_combat_03_state；已查看出口实机场景，石阵左侧无魔物。仅系统证书环境告警。初次专项因_check第三参数需Dictionary而发生脚本解析失败，运行器超时结束该次自建进程，修正测试参数后通过；原日志output/exit_spawn_before保留。首张截图未等待镜头跟随，后使用现有snap_to_target校准观察位置，未修改生产镜头。

此边界只约束出生点，不限制追逐中的魔物移动；出口石阵或道路朝向变化时需重新检查边界规则及上述验收。
