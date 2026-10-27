# COMBAT-07：鼠标单击攻击与短条战斗提示

执行基线为 `54ff9d6db46de3d2d3c95b1afbc3cbf85320276d`（`codex/combat-07-baseline`），独占分支 `codex/combat-07`，工作目录 `C:/Users/KSG/.codex/worktrees/3088/maze_code`。来源任务 `01a14263-a55a-71d2-9fb2-10e636d0b31c` 已确认票据，无依赖。项目归属依据来源明确绑定 maze_code 且创建成功，`project_binding_verified=true`（项目归属已核验）。初始 HEAD 与基线一致且工作树干净。预算60分钟、90分钟强制停止，无超过20分钟命令；执行任务不合入 `F:/maze_code`。

## 玩家行为

- 战斗只接受 GUI（图形界面）未消费的鼠标左键按下事件，每单击一次尝试发射一次。长按不连发，冷却、失焦或锁定期间的事件不缓存，J不再战斗攻击；捕获窗原J保持不变。冷却0.9秒、射程180世界像素、弹道预判与伤害数值不变。
- `combat_simulation.select_target`（选择当前目标）同时供显示和发射使用，选择射程内最近存活、有生命且非返航的魔物；距离相等保留原目录顺序。返航、死亡、离开射程即切换目标，无目标隐藏所有魔物攻血，主角常显。
- 血条60×6世界像素，加速条60×4。ATK与HP使用9号字体分两行左对齐，条形位于文字下方。主角整组位于本地坐标(-30,-113)，魔物按实际身体高度居中正上方；取消横向避让，围攻不会把标签甩到远处。保留主角绿、魔物红、加速金、米色轨道及棕边。
- 底部320×48长底框来自 `scenes/ui/interact_button.tscn`，两个键帽来自 `scenes/ui/key_button.tscn`，准确显示“Shift 加速”和“单击 攻击”。仅本实例将键帽加宽为76并拉伸底图覆盖文字，餐厅共享资源文件不变。
- 地图、背包、头像、关闭按钮及提示框由原GUI输入消费机制阻止穿透。金币和体力原为忽略鼠标的装饰计数，实测会穿透，现仅迷宫实例改为拦截鼠标。第二章只替换攻击教学文案，捕获J文案、教学时序和06加速参数不变。

## 验收入口

所有运行沿用 `tools/tests/combat_02_run.ps1`，隔离 APPDATA、LOCALAPPDATA 与 MAZE_QTE03_PROFILE，记录正式存档前后SHA256，不关闭用户游戏。实际引擎 Godot 4.7.2，正式入口 `scenes/start_screen.tscn`。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_07_flow.tscn -OutputRoot output/combat_07/flow_final
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_07_hud_ui.tscn -OutputRoot output/combat_07/hud_ui_stable
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_06_state.tscn -OutputRoot output/combat_07/state_06
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_navigation.tscn -OutputRoot output/combat_07/navigation_05
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_flow.tscn -OutputRoot output/combat_07/flow_05
& tools/tests/combat_02_run.ps1 -Mode import -OutputRoot output/combat_07/import_final
& tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot output/combat_07/smoke_final
```

07主流程由06入口复制并只将战斗输入改为鼠标；捕获J保持原测试。鼠标通过 `Viewport.push_input`（视口事件分发）、Shift通过引擎输入分发，真实场景、GUI处理、事务和渲染均参与；不是人工游玩录像。状态及05回归未修改。

HUD专项只控制隔离样例位置和生命，正式组件仍读真实运行状态，不向生产代码注入模拟数字。验证两分辨率1152×648、1280×720，包含多目标切换、移动居中、字体尺寸比例颜色、键帽，以及任务入口、金币体力、小地图、地图按钮、背包、两位队友头像、各关闭按钮、空位、锁定与恢复。

## 问题证据及边界

`hud_ui_counters_red` 两分辨率共4项失败，均是金币和体力点击穿透；原因是这两个计数组件忽略鼠标，事件进入战斗未处理输入阶段。仅调整迷宫实例的鼠标过滤后，`hud_ui_stable` 147项通过。这不改变餐厅的输入策略。

早期 `hud_ui` / `hud_ui_fixed` 为测试问题：事务提交替换运行状态后仍持有旧字典，以及目标判断未包含原弹道速度预判；按生产事务重新取状态、比较实际预测位置后通过。`hud_ui_accepted` 出现测试手动调用 `_process(0)` 时带入上一帧战斗累计时间的非确定性；专项在手动刷新显示前清零累计时间，使无推进的布局样例稳定。生产运行时钟未修改。早期失败日志保留，未冒充通过。

## 可复用知识

战斗鼠标攻击应放在未处理事件阶段，让按钮、遮罩先消费；显示性HUD若忽略鼠标，也必须明确决定能否穿透。目标选择只保留一个生产函数，渲染与事务都调用它，不能各自复制筛选条件。正确例是返航后立即不显示且不会被发射选中；错误例是HUD沿用“激活即显示”，发射却排除返航。修改输入阶段、目标筛选、实例鼠标过滤或组件布局时重跑本票主流程、HUD及状态回归。

执行交付仅证明独立工作树，玩家目标目录的增量合入与集成验收仍由来源主任务完成。未回放全部餐厅经营或完整剧情。没有修改08受击反馈、09首段史莱姆、道路、数值、订单、饱腹或正式素材。

## 独立工作树最终结果

| 验收 | 检查 | 失败 | 证据目录 |
| --- | ---: | ---: | --- |
| 鼠标输入、加速、捕获J、胜败返回与读档回滚 | 149 | 0 | `output/combat_07/flow_final` |
| 双分辨率短条、目标切换及UI输入 | 147 | 0 | `output/combat_07/hud_ui_stable` |
| 06状态与保存失败回滚 | 22 | 0 | `output/combat_07/state_06` |
| 05道路卡点 | 15 | 0 | `output/combat_07/navigation_05` |
| 05追逐、返航、镜像及重载 | 55 | 0 | `output/combat_07/flow_05` |
| 编辑器解析导入与无头启动 | 两项退出0 | 0项目错误 | `output/combat_07/import_final`、`smoke_final` |

总计388项检查通过，以上各批正式存档指纹一致。已查看1152×648和1280×720实际短条底框截图、目标切换截图；位置、字体、原颜色和键帽显示符合已确认布局。保留系统证书读取失败及Steam编辑器设置目录写入权限警告，没有脚本或资源错误。导入产生的本工作树资源元数据已恢复基线，不进入票据提交。

推荐审查图：`output/combat_07/hud_ui_stable/screenshots/short_bars_real_scene_1152x648.png`、`short_bars_real_scene_1280x720.png`。证据未写入玩家目标目录；最终集成状态由来源任务另行记录。

## 主目录集成记录
2026-10-21：db6903ff相对54ff9d6基线的票据差异已增量合入F:/maze_code，保留用户修改。主目录integrated_flow149项、integrated_hud_ui147项、integrated_state22项均通过，正式存档指纹一致；已查看实机短条与统一键帽截图。证据output/combat_07/integrated_*。
