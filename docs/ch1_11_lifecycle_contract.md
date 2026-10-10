# CH1-11 第一章最终生命周期契约

本契约保留第一章完成事务的不变量；界面流程已由 CH1-1009-11 更新。合法 `ready_to_depart` 准备态依次经过入队弹窗、冒险者之家介绍、迷宫入口介绍；最后一句对白结束时，通过 `SaveManager.advance_chapter_1_outro("maze")` 调用完成事务，在同一份 JSON 存档中写入 `chapter_1_done=true` 与 `tutorial_done=true`，并保留首单结算、库存、声望、地图、队伍、入口及卡组快照。结束蒙层随后单独等待新按 E 确认，详见 [章节结束演出约定](chapter_endings.md)。

## 不变量

- 只有首单已结算、三种首单物品为零、准备步骤为 `ready_to_depart` 且结构完整时才能完成。
- 完成是原子事务。写盘失败回滚内存，正式存档不留下半完成标记；重复完成返回幂等成功，不重复写盘或奖励。
- 完成后的 `lifecycle_stage()` 为 `done`。出发快照仍为 `ready_to_depart`，入口不会切换场景，也不会触发迷宫或战斗。
- 已移除准备面板的“确认第一章完成”按钮。迷宫介绍对白完成后发出一次 `chapter_1_finished`，保存失败保留当前可重试检查点；完成蒙层的确认不再发放奖励或重复完章。
- 第一章玩家界面已去掉跳过按钮。内部 `skip_all()` 只取消当前教程，不伪造章节完成；场景重进和旧异步令牌均安全。
- `--replay-tutorial` 使用 `SaveManager` 独立内存副本。重播可走到 `done` 视图，但结束后正式内存、磁盘和奖励保持原样。

旧档读取继续保留未知字段并对缺失/损坏字段写入中文 `migration_diagnostics`；不会凭单独的 `tutorial_done` 或损坏准备字段补发完成奖励。只有重新满足完整准备态后才允许最终提交。

## 验收

当前真实收尾验收使用 `tools/tests/chapter_ending_input.tscn`，覆盖入队、两个入口对白及闪烁高亮、章节结束蒙层、新按 E、各检查点重载、取消、保存失败回滚与重播隔离。最新证据见 `output/maze_entrance_highlight/verified/acceptance.json`（158 项通过）。历史 `ch1_11_lifecycle_suite`、`ch1_09` 中旧手动确认及跳过 UI 假设不代表当前界面契约；不能未经更新就用来判定新版收尾。
