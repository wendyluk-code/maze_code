# B3 枯水渠右下道具附近追击修复交付

执行目录：`C:/Users/KSG/.codex/worktrees/0814/maze_code`。
分支：`codex/bug-b3`。基线：`d50be15f12f00326df408cd4c389445abf4c0c93`（`codex/bugfix-baseline-20261022`）。
来源任务：`01a163b4-c5e2-7720-b326-a59c64b5b1b5`，主机 `local`。
项目：`7c3963e8-2c05-4bd9-9992-d9dc706e8cf4`；项目绑定已由创建参数确认。
本票执行与独立工作树验收通过；最终交付仍需主会话增量合入 `F:/maze_code` 并完成集成验收。

## 问题与最小修复

真实场景 `scenes/maze_entry.tscn` 中，玩家在 `(999,1171)`（南侧挖掘点 `entry_dig_south_bend=(923,1211)` 东北约86像素）可合法站立。修复前剑甲虫从 `(983,1132)` 追击约6秒，仍在旧节点附近往返，玩家生命36不下降。截图和报告见 `tools/tests/bug_b3_evidence/before/`。

玩家道路包含 `extra_walkable_areas()` 补充多边形，战斗的 `walkable()` 却只认旧道路中心线宽度，因此直线路径与近战命中检查拒绝合法玩家站位，寻路持续退回中心线节点。

生产差异仅 `scripts/maze/combat_simulation.gd`：`walkable()` 委托已有 `Roads.is_walkable(point, radius)`。保留既有道路、补充区域、绕障图及战斗数值/规则。未修改 `entry_roads.gd`、`maze_player.gd`、`maze_entry.gd`、分水庭、盐池、用户距离显隐改动。

同一最小夹具仅替换此函数后，生命36→31，追击能靠近并造成伤害，见 `after_minimal/`。不将所有未知地图位置都宣称验证通过。

## 验收命令与结果

均在本工作树执行，复用已有 `tools/tests/combat_02_run.ps1`（隔离运行脚本），其单次超时240秒。每次均核验正式存档文件指纹未变化。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/bug_b3_scene.tscn -OutputRoot tools/tests/bug_b3_evidence/acceptance_v2
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_navigation.tscn -OutputRoot tools/tests/bug_b3_evidence/navigation
& tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot tools/tests/bug_b3_evidence/smoke
& tools/tests/combat_02_run.ps1 -Mode import -OutputRoot tools/tests/bug_b3_evidence/import_verified
```

- 图形场景99项通过：真实方向输入进出 `(999,1171)`、南侧宝箱旁 `(824,1159)`、东侧宝箱旁 `(1099,663)`；三处怪物追近攻击；南侧挖掘 E 领取木材3、南侧和东侧宝箱 E 各领取金币100、关闭奖励恢复输入；环路、内支路、栅栏支路连续通行，沟壑树林与栅栏继续阻挡。
- 原有导航回归15项通过：7条双向绕弯路线到达且每步不穿墙。
- 无头启动、编辑器导入通过，无脚本解析、资源加载和场景错误。
- 逐张查看关键截图，玩家/怪物可见，木材奖励弹窗正常；截图在 `acceptance_v2/screenshots/`，完整移动坐标和生命变化在同目录上级 `report.json`。
- 本票没有调用系统输入控制其他窗口，没有关闭用户游戏。图形验收通过 Godot 场景内输入事件与真实玩家/战斗/奖励流程运行。

## 中间失败与结论边界

第一次新工作树导入先报告缺失字体缓存，导入完成后图形场景成功；最终再次编辑器导入已无该错误。全部运行仍有系统证书读取警告；编辑器另有引擎安装目录编辑器设置写入权限错误，单独记录于摘要的环境错误字段，未过滤脚本错误。

首次扩展验收 `acceptance/` 的4项失败已保留：3项来自过期测试要求穿过当前石阵封闭出口；1项是测试怪物的迁移后出生点未同步，触发离家返航。随后仅修正测试：回归限定本票相邻道路并固定测试怪物出生点，生产代码未增加修改，99项全部通过。

独立工作树测试不能替代正式工作区集成；主会话应合入后重跑上述命令。测试采用固定怪物布局隔离随机性，未对所有随机布局穷举。截图中战斗标签近距离重叠为原有显示，不在本票修改范围。

## 可复用知识

首区的玩家移动、追击可见直线和近战命中应共用现有可走区域判定；中心线寻路图用于绕障，不应另作可站立范围来源。若今后调整道路补充多边形、引入其他地图战斗或改变脚底半径，应重新运行本票边缘站位与绕障回归。

执行结束后释放本票全部文件租约，尤其 `maze_player.gd`（本票未改，可交给 B4）。本票不合入正式工作区、不推送。
