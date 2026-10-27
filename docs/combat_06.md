# COMBAT-06：手动攻击、加速与攻血显示

执行基线 `df23c5206a2314e94b5f396133068cbb50df23b4`，独占分支 `codex/combat-06`，工作目录 `C:/Users/KSG/.codex/worktrees/2bb7/maze_code`。来源任务 `01a14263-a55a-71d2-9fb2-10e636d0b31c` 已确认范围。执行任务不合入 `F:/maze_code`，最终集成由来源主任务负责。

## 玩家行为与实现边界

- J 每次新按提交一次攻击；系统重复事件无效。保留0.9秒冷却、180世界像素选敌距离、原飞行与命中规则。冷却中或无有效目标时按键直接丢弃，不排队。选最近存活且不返航的魔物，不按J不会发射。移动与手动攻击可以同时进行。
- Shift 按住且实际移动时速度为原130的1.5倍。独立金条用满量1表示，可加速5秒；停止加速1秒后开始恢复，恢复8秒从空到满。静止、碰墙不扣条；不消耗饱腹或入场体力，不治疗生命。
- 耗尽后退回普通移动；松开Shift、待恢复后新按即可再次加速，不必等满条。耗尽锁只用于避免一直按住时每帧在微量恢复与耗尽之间抖动。
- 弹窗、玩家锁定、禁用物理处理、失焦期间不推进战斗、耗条或恢复。清空加速按住状态和战斗累计时间，恢复后须新按Shift。J由未处理键盘事件接入，捕获窗原有J输入优先消费，不穿透战斗；没有跨帧攻击队列。
- `combat_attack`（攻击事务）与原战斗推进一样保存失败全状态回滚。加速量 `sprint` 与停止计时 `sprint_rest` 随原战斗检查点保存（最长0.5秒），不增加每帧写盘。正常保存/读档保留两值，按键和耗尽输入锁不持久化。旧档缺字段默认满条与零等待，不改变版本或迁移旧经营规则；新档显式初始化这两个字段。

## 显示复用

复用 `capture_monster.make_health_bar` 的原生圆角进度条：米色轨道、棕边，主角绿色、魔物红色，120×7世界像素；主角下方金条120×4。ATK左对齐、HP右对齐同一行，两端对齐条形。数字使用引擎内置字体，浅米白、深棕描边。主角常显；魔物激活显隐与原避让逻辑保持，横向避让距离随宽度增至128。

新增 `combat_controls_hint.gd` 只组合现有 `SproutTheme` 奶油细框、字体和原生键名标签，底部显示“Shift 加速 · J 攻击”，键名带细框。没有生成或新增美术素材。提示随战斗暂停隐藏，其他业务弹窗显隐规则沿用原实现。

来源额外确认的唯一目录外改动为 `scripts/ch2_exploration_guide.gd` 的 `05_power` 文案：

- 修改前：你会自动向附近魔物抛出锅铲，移动不会中断攻击。头顶显示攻击和生命，及时移动躲开魔物的近战，生命耗尽会失去本趟食材。
- 修改后：按 J 向射程内最近的魔物抛出一次锅铲，按住 Shift 移动可加速。头顶显示攻击、生命和金色加速条，及时移动躲开魔物的近战，生命耗尽会失去本趟食材。

没有改变教学阶段、时序、角色数值、道路或正式存档。

## 验收与复跑

复用 `tools/tests/combat_02_run.ps1`，每次隔离 `APPDATA`、`LOCALAPPDATA`、`MAZE_QTE03_PROFILE`。该运行器同时记录正式存档前后SHA256，不停止用户游戏。引擎为 Godot 4.7.2，实际主入口为 `scenes/start_screen.tscn`。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_06_flow.tscn -OutputRoot output/combat_06/flow_release_final
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_06_health.tscn -OutputRoot output/combat_06/health_final
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_06_state.tscn -OutputRoot output/combat_06/state_final
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_navigation.tscn -OutputRoot output/combat_06/navigation_05
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_flow.tscn -OutputRoot output/combat_06/flow_05
& tools/tests/combat_02_run.ps1 -Mode import -OutputRoot output/combat_06/import_final
& tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot output/combat_06/smoke_final
```

本票将旧自动战斗流程复制为 `combat_06_flow` 并按手动规则适配；没有在生产代码中设置自动攻击测试开关。历史 `combat_02_flow` 中“自动出手”断言已不适用于新规则，不应直接作为本票验收入口。其余不依赖自动出手的05道路与场景回归原样运行。

输入场景通过 `Input.parse_input_event`（引擎真实事件分发）注入J/Shift，通过实际场景、原事务与渲染验证。速度倍率测量走实际道路；5秒耗尽、1秒等待、8秒恢复采用生产模拟精确步进验证，并结合实际输入检查耗尽退速和恢复后再加速。这不是连续人工键盘游玩录像。

状态专项还覆盖最近目标、返航目标排除、180/181射程、旧档缺字段、真实写盘重载、攻击与加速保存失败全量回滚、非法耗条数据拒绝。流程专项覆盖胜利J不穿透、捕获按J结算、胜败返回餐厅、奖励入库和失败丢袋，双分辨率1152×648、1280×720。HUD专项检查真实比例、多怪避让、红绿金条、暂停与恢复，截图位于各批次 `screenshots`。

## 可复用知识与重审条件

手动操作意图不应保存或缓存在战斗时间推进中：事件当下做门禁和事务，冷却拒绝即丢弃；持久化只保存资源与恢复时钟。正例是捕获窗消耗J但不会给关闭后的战斗补发；反例是把J设成跨弹窗等待标记。修改输入路由、锁定、存档结构或战斗步进后，重新运行本票输入、状态与HUD专项。

## 本工作树实际结果

| 验收 | 检查数 | 失败数 | 证据目录 |
| --- | ---: | ---: | --- |
| 手动输入、加速、捕获胜败与退场，双分辨率 | 147 | 0 | `output/combat_06/flow_release_final` |
| 红绿金条、数字与多怪避让，双分辨率 | 53 | 0 | `output/combat_06/health_final` |
| 旧档、持久化、选敌与保存失败 | 22 | 0 | `output/combat_06/state_final` |
| COMBAT-05道路卡点回归 | 15 | 0 | `output/combat_06/navigation_05` |
| COMBAT-05追逐、返航、镜像与重载 | 55 | 0 | `output/combat_06/flow_05` |
| 编辑器解析导入、无头入口启动 | 两项退出0 | 0项目错误 | `output/combat_06/import_final`、`smoke_final` |

以上运行器均成功，正式存档前后指纹一致。系统证书读取失败，以及编辑器无法保存Steam目录下的个人编辑器设置，为单列环境警告；没有脚本解析或资源错误。两分辨率战斗、受伤多怪截图已人工查看。最终差异审查恢复了误触的空队伍字体，攻击事务同步保存发射时玩家位置；状态专项再次通过22项。提交前补充空条松键后等待物理帧的回归，确保耗尽锁只在Shift仍按住时生效，释放后不会被空闲帧重新锁住。

交付限制：尚未在玩家目标目录 `F:/maze_code` 合入与集成，必须由来源主任务执行后才能认定游戏目标完成。无远端推送，不覆盖正式存档。历史自动攻击专项不再适用；本票没有回放所有餐厅经营与所有教程阶段。

## 主目录集成验收（2026-10-21）
执行任务已停止写入；主任务审查提交5f67ab2c7bbd8c5993d38f42b32fb3aae57aed3e，按相对df23c520的票据差异增量合入F:/maze_code。组件库文档仅追加本票说明，保留同期暖金按钮呼吸及烹饪随机区域记录。主目录 integrated_flow 147项、integrated_health 53项、integrated_state 22项、integrated_05_flow 55项、integrated_05_navigation 15项，共292项全部通过；smoke通过。所有测试正式存档指纹一致。实际查看双分辨率战斗截图、多怪受伤截图与原蜥蜴卡点镜像截图。证据位于output/combat_06/integrated_*。保留系统证书及编辑器设置权限环境警告。
