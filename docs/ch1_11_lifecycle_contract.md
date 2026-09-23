# CH1-11 第一章最终生命周期契约

本票据把合法的 `ready_to_depart`（准备出发）准备态提交为 `done`（第一章完成）。最终确认只通过 `SaveManager.complete_chapter_1()` 进入；它在同一份 JSON 存档中写入 `chapter_1_done=true` 与兼容字段 `tutorial_done=true`，并保留首单结算、库存、声望、地图、队伍、入口及卡组快照。

## 不变量

- 只有首单已结算、三种首单物品为零、准备步骤为 `ready_to_depart` 且结构完整时才能完成。
- 完成是原子事务。写盘失败回滚内存，正式存档不留下半完成标记；重复完成返回幂等成功，不重复写盘或奖励。
- 完成后的 `lifecycle_stage()` 为 `done`。出发快照仍为 `ready_to_depart`，入口不会切换场景，也不会触发迷宫或战斗。
- 教程最终步骤只建立稳定的 `ready_to_depart`；准备面板的“确认第一章完成”按钮调用同一原子接口。成功后发出 `chapter_1_finished`，保存失败保留可重试的准备态。
- `skip_all()` 只取消当前教程，不伪造章节完成；重复跳过、场景重进和旧异步令牌均安全。
- `--replay-tutorial` 使用 `SaveManager` 独立内存副本。重播可走到 `done` 视图，但结束后正式内存、磁盘和奖励保持原样。

旧档读取继续保留未知字段并对缺失/损坏字段写入中文 `migration_diagnostics`；不会凭单独的 `tutorial_done` 或损坏准备字段补发完成奖励。只有重新满足完整准备态后才允许最终提交。

## 验收

运行 `tools/tests/ch1_11_lifecycle_suite.tscn` 覆盖合法完成、重进恢复、重复调用、保存失败回滚和重播隔离；再运行 `ch1_09_run_isolated.ps1`、编辑器无头解析检查与主入口冒烟。真实场景验收还需确认完成后仍停留餐厅，入口只保留状态展示，不自动进入迷宫。
