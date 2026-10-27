# B2 执行交付

## 状态与边界

独立执行工作已完成，停止写入后交来源任务审查；F:/maze_code 的合入与集成验收尚未完成，由来源主会话负责。

- 来源：01a163b4-c5e2-7720-b326-a59c64b5b1b5 / local。
- source_project_id：7c3963e8-2c05-4bd9-9992-d9dc706e8cf4；按明确所选项目创建，project_binding_verified = true。
- 工作目录：C:/Users/KSG/.codex/worktrees/2264/maze_code。
- 基线：codex/bugfix-baseline-20261022 / d50be15f12f00326df408cd4c389445abf4c0c93；初始干净，独占分支 codex/bug-b2。
- 仅修改 scripts/maze/capture_run.gd，新增 tools/tests/bug_b2* 与本文件；保留 ui_layer.gd 和全部基线实现。
- 预算：主动60分钟、强停90分钟；实际约15分钟；无长命令或后台进程。

## 问题、实验与修复

基线对四种魔物的 captured（捕获）、failed（失败）、skipped（放弃）三种结果调用生产刷新入口，12项到期不刷新的断言全部失败；另外生产 combat_tick 连续推进181秒也复活，合计57项中13项失败。证据：tools/tests/bug_b2_evidence/baseline_red.json。

根因是 refresh_due 在 respawn_at 到期且视野外有安全出生点时重建怪物、布局与随机结果。将此兼容入口改为不变更状态且返回 false；击败、结算与旧档缺字段补存不再创建复活期限。字段和函数接口仍保留，旧档已有非零期限可以读取，奖励代数回执、付费及提交回滚不变。

来源任务特别明确返回原区清空剩余怪物是既有玩法，因此 change_region 未改。旧档已经因该玩法将怪物标为 skipped 时，不推断或恢复其历史捕获结果。

## 验收证据

使用已核验的 F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe。所有运行均以 runner 的子进程 APPDATA/LOCALAPPDATA 隔离，不关闭其他游戏；正式 JSON 存档前后 SHA256 指纹相同。

命令（在本票工作目录）：

```powershell
pwsh -NoProfile -File tools/tests/bug_b2_run.ps1 -Mode state
pwsh -NoProfile -File tools/tests/bug_b2_run.ps1 -Mode flow
pwsh -NoProfile -File tools/tests/bug_b2_run.ps1 -Mode import
pwsh -NoProfile -File tools/tests/bug_b2_run.ps1 -Mode smoke
```

- 状态：57项全通过，覆盖四种怪物、三种结果、181秒生产计时、存档恢复、缺字段旧档、跨区返回、新探索、击败/结算/计时/切区保存失败回滚及奖励幂等。
- 图形：75项全通过。真实 maze_entry.tscn，固定布局夹具；将史莱姆设为1HP、冷却归零，然后通过生产攻击和弹道推进击杀，进行结算与显示刷新。截图 before_kill、dead_after_deadline、return_and_reload 已人工视觉检查。
- 图形跨区和读档使用生产状态接口并在实际场景节点刷新显示；没有覆盖点击传送路标的整条输入流程。目标工作区的完整集成验收仍由主会话执行。
- import：通过，无项目解析或资源错误；smoke：通过。
- 汇总与截图：tools/tests/bug_b2_evidence/；完整原始日志与隔离存档保留在 tools/tests/bug_b2_output/（不提交）。

首次空缓存导入启动阶段报告字体导入缓存尚不存在；导入完成后重跑通过。增强图形攻击用例首次因新场景攻击冷却未归零而失败，单变量修正夹具冷却后通过；没有修改生产战斗逻辑。

环境提示单列：根证书读取失败；编辑器导入不能保存 Godot 安装目录 editor_settings-4.7.tres。未屏蔽项目错误。

## 限制与稳定知识

- 现有 combat_03_state.gd 专门断言旧的循环复活，已与新需求冲突；本票无权改它，以 B2 回归替代相关验收。旧测试未作为通过证据。
- 当前其他区域不生成独立魔物，本票不新增区域魔物系统；若新增区域，应复核其独立状态服务是否遵循本趟不复活。
- 可复用事实：怪物结算状态与 combat actor 的生命一并持久化；本趟死亡只由新探索重建，跨区仍保留既有清区规则。重新审查条件为引入新区域怪物或更改存档生命周期。
- 不推送、不合入主工作区；来源任务收到交付后核对提交，再进行本地增量合入和目标场景验收。

工作树清理说明：Godot 导入后许多 .import 文件因换行/文件状态被 git status 标记修改，但 git -c core.safecrlf=false diff --numstat 无未暂存内容差异。批量恢复曾被自动审批拒绝（通配符可能覆盖用户改动），因此保留这些文件，不纳入提交；仅暂存票据文件。没有需要用户额外授权才能交付的代码工作。主会话合入应使用本票提交，不复制这些导入文件。
