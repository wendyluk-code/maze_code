# COMBAT-05：石化蜥蜴道路卡点与朝向

本票基线为 `22aa84f437501ae84a28e429b6a1f5ebab3a7a8e`，独占分支为 `codex/combat-05`，执行目录为 `C:/Users/KSG/.codex/worktrees/7cf8/maze_code`。执行任务只交付差异；玩家目标目录 `F:/maze_code` 的合入与集成验收由来源主任务负责。

## 问题证据与最小实验

用户截图路段对应北侧长廊。只读现有存档时，石化蜥蜴位置为 `(790,326)`、模式为 `return`（返航）、速度为零、生命为 60；玩家位置约 `(888.7483,287.625)`。没有修改或复制正式存档用于测试。

基线 `next_waypoint`（下一个路径航点）把临时起点接入道路节点后直接返回 `path[1]`。当起点恰好等于道路节点坐标，路径的下一点也可能等于当前位置。怪物每步移动距离为零，随后再次求得相同路径。

`output/combat_05/red_exact/report.json` 保存基线红灯：从 `(790,326)` 返回 `(270,720)` 连续 20 步停在原地；从 `(552,455)` 返回同一目标也停滞。7 条路径中的两条失败，另外五条通过。仅将航点选择改为跳过与当前位置重合的点，同一测试全部通过，证据为 `output/combat_05/navigation_final/report.json`（15 项、0 失败）。

最初“最近路段无条件接入导致穿障碍”只是调查假设；本次复现证明的是零长度首段。本票没有修改道路、脱战距离、追逐范围或战斗数值。

## 实现

- `scripts/maze/combat_simulation.gd`：沿已计算的路径选择第一个与当前位置不重合的航点。空路径仍返回当前位置。
- `scripts/maze/capture_monster.gd`：石化蜥蜴设置 `flip_h`（水平镜像），头朝右；四帧阴影接地点同时水平翻转。其他怪物保持原方向。
- `tools/tests/combat_05_navigation.*`：截图卡点返航、截图路段双向移动、左侧道路绕弯往返，检查每一步可走且不穿墙。
- `tools/tests/combat_05_flow.*`：加载真实迷宫场景，用 `Run.combat_tick`（战斗事务推进）执行返航、双向追逐、多怪和写盘重载，保存真实渲染截图。

## 实际验收

使用现有 `tools/tests/combat_02_run.ps1` 运行器。每次子进程均设置独立 `APPDATA`、`LOCALAPPDATA` 与 `MAZE_QTE03_PROFILE`，不停止用户游戏。实际引擎为 Godot `4.7.2.stable.steam.ed1daf0bf`，入口配置是 `scenes/start_screen.tscn`，不是旧文档缓存中的餐厅直接入口。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_navigation.tscn -OutputRoot output/combat_05/navigation_final
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_flow.tscn -OutputRoot output/combat_05/flow_final
& tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot output/combat_05/smoke_final
& tools/tests/combat_02_run.ps1 -Mode import -OutputRoot output/combat_05/import_final
```

| 项目 | 实际结果 | 证据 |
| --- | --- | --- |
| 道路回归 | 引擎退出 0；15 项、0 失败 | `navigation_final/report.json` |
| 真实场景 | 引擎退出 0；55 项、0 失败 | `flow_final/report.json` |
| 无头主入口启动 | 引擎和运行器退出 0，无项目错误，正式存档哈希未变 | `smoke_final/summary.json` |
| 编辑器解析与导入 | 引擎退出 0，无项目解析/资源错误 | `import_final/summary.json` |

上表路径均位于 `output/combat_05/`。道路、场景、编辑器三次的运行器最终均判失败，原因是正式存档的前后哈希发生变化，不能把它们称为运行器整体通过。隔离测试明确报告 `user_dir` 位于各自的 `output/combat_05/<批次>/profile/Godot/app_userdata/maze_code`；场景写盘路径也在该隔离目录。来源主任务确认当时未运行游戏，用户可能仍在运行正式游戏，因此哈希变化保留为并发环境限制，不把它归因为测试写盘，也不宣称正式存档未变。

引擎另报系统证书读取失败；编辑器还报 Steam 安装目录中的 `editor_settings-4.7.tres` 无法写入。这些是环境错误，独立列在运行器报告中，不与项目解析错误混合。

场景证据包括：

- `flow_final/screenshots/截图路段向右追逐_before.png` 与 `截图路段向右追逐_after.png`：同一长廊从远处接近到攻击前摇，蜥蜴头朝右。
- `flow_final/screenshots/截图路段向左追逐_before.png` 与 `截图路段向左追逐_after.png`：反向追逐。
- `flow_final/screenshots/多怪追逐_after.png`：蜥蜴、史莱姆、剑甲虫同时推进。
- `flow_final/report.json` 的返航轨迹：第一步离开 `(790,326)`，经 `(704.805,383.737)`、`(542.534,478.139)`、`(370.876,681.673)` 回家；最终回到 `(270,720)`、空闲、生命恢复为 84。

追逐夹具为隔离验证双向运动，将蜥蜴出生点放在该段道路附近；返航夹具使用生产出生点 `(270,720)` 和真实卡点。生产的距离上限不变，不能据双向夹具推断蜥蜴将无限追逐到北门。此测试通过真实事务与真实渲染验证运动，不是键盘沿路连续诱导的人工游玩录像。

首次新增场景测试因两处局部变量缺少显式类型出现解析错误，已修正；对应日志保留在 `flow/`。随后重载检查因沿用 `1e-12` 容差，把 JSON 双精度十进制尾数舍入视作失败；保存前后诊断在 `flow_reload_diagnostic/`，本票比较容差改为 `1e-6` 后 55 项通过。未修改游戏的序列化实现。

## 交接边界与可复用结论

本票已验证：临时图节点与已有路点重合时，不应把零长度第一条边当作下帧运动目标。该结论适用于当前 AStar2D（二维 A 星路径图）接入方式；更换导航图、改变接入策略或调整移动容差时应重新运行本票道路回归。

导入生成的 `.import` 文件只有换行状态变化，没有 Git 规范化内容差异。批量恢复操作被自动审批拒绝后未执行；最终在断言没有内容差异后只登记相同内容到索引，未改写资源文件，交付不包含任何 `.import` 差异。

剩余事项：来源主任务审查后增量合入目标目录，运行对应集成验收；需要在没有并发正式存档写入的条件下取得完整运行器成功结果。执行任务不合入、不推送、不改变下一票的 J 攻击、加速或 HUD 范围。

## 主目录集成验收（2026-10-21）
来源提交 df23c5206a2314e94b5f396133068cbb50df23b4 已仅按票据差异增量合入 F:/maze_code。integrated_flow 55项、integrated_navigation 15项全部通过，两个运行器均退出0、正式存档哈希不变，无项目错误；保留环境系统证书告警。实际查看向右追逐截图，蜥蜴镜像与卡点经过正常。证据 output/combat_05/integrated_flow 与 integrated_navigation。
