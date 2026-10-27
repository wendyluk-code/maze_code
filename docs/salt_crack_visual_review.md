# 盐晶第一版裂纹接入验收

目标工作区：F:/maze_code。基线分支 codex/freezer-01，HEAD f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910。工作区存在大量此前未提交改动，本次直接增量修改，不提交、不覆盖其他功能。

用户确认素材为 exec-d618c067-96e1-4dd0-a98d-86c8d354374c.png（第一张纯裂纹）。保留原透明通道，裁切三阶段至 assets/effects/salt_cracks；原地图晶石及碰撞保持原样。两簇主晶石表面使用同一组三阶段裂纹，无耗尽灰层。新裂纹中心向外0.4秒渐变，成功命中矿震0.18秒，与岩鬃兽震屏独立。成功采盐复用凉须草获得物品窗，收下恢复输入；保存失败不发视觉反馈。

本次涉及：
- scripts/maze/salt_crystal_visual.gd、salt_crack_reveal.gdshader：贴图、图层、阶段动画。
- scripts/maze/maze_camera.gd：独立矿震。
- scripts/maze/maze_entry.gd：已提交岩盐展示与原采集关闭流程。
- scripts/maze/capture_flow.gd：弹窗锁定后停止本帧战斗补算。
- tools/tests/salt_crack_visual.gd / .tscn：真实键盘鼠标采矿双分辨率验收。
- tools/tests/map04_flow.gd：旧综合流程增加收下岩盐步骤。
- docs/ui_component_library.md：复用约定及旧文案更新。

实测命令：
tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/salt_crack_visual.tscn -OutputRoot output/salt_crack_review
结果133项通过，无脚本/资源错误，正式存档指纹未变。覆盖两块三阶段、实际鼠标土攻击、中心展开、震动归零、奖励窗、关闭输入恢复、耗尽、非土反馈、读档不重播、保存失败事务回滚及怪物震屏兼容。截图为1280×720和1152×648的实际游戏场景。为稳定采矿验收，测试降低攻击力并控制敌人状态，不代表完整自然战斗回放。

Godot --headless --editor --path F:/maze_code --quit 与 --headless --path F:/maze_code --quit-after 5 均退出0，日志 output/salt_crack_checks；使用隔离APPDATA/LOCALAPPDATA。

补充综合回归：
tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/map04_flow.tscn -OutputRoot output/salt_crack_map04
845项中841通过，4项失败，均为两分辨率下岩鬃兽“甩头单次8攻击经防御结算”“甩头不重复伤害”。该失败未修复，未证明与此前基线是否一致，不宣称全量回归通过。正式存档指纹未变。其余采晶保存/重载/跨日/去重/回滚项目通过，完整明细见该目录 acceptance.json。

早期验收发现：新增代码缩进混用导致解析失败，已修复；固定推进0.2秒会受战斗细分步长影响而在实际命中前断言，改为有限步进至命中；将怪物移到非法位置的试验被存档校验拒绝，已弃用，保留失败日志。最终证据以上述 salt_crack_review 为准。

可复用知识：反馈只接收成功保存事务；背景晶石贴图放在底图后、玩家前；采集模态打开时停止战斗补算；相机独立效果不得被每帧怪物震屏归零调用清除。修改事务提交、图层顺序、相机或采集锁时重新检查。

## 2026-10-27 岩鬃兽旧断言后续处理

用户授权继续处理此前4项失败。根因：MAP-04测试仍设置旧甩头 windup=0.7，期待0.7秒扣血；现行设计与实现已改为1.1秒锁向咆哮（参见 boss_combat_repair.md），旧冲撞断言也不能证明现行行为。

本次仅更新 tools/tests/map04_flow.gd 中过时的战斗断言，没有更改伤害数值或生产战斗逻辑。覆盖前摇不伤害、释放按攻击8经防御结算、持续阶段不重复扣血、锁向、侧面躲避、原地释放、休息1.5秒及不产盐；明确断言方向样例确实执行。

目标工作区 F:/maze_code，HEAD仍为 f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910，保留所有既有用户改动。
- tools/tests/ui_modal_unify_run.ps1 -Scene res://tools/tests/map04_flow.tscn -OutputRoot output/rockmane_assertions_current：877项通过，0失败。
- BOSS_REPAIR_SCOPE=salt；tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/boss_combat_repair.tscn -OutputRoot output/rockmane_assertions_live：77项通过，0失败，实际盐池双分辨率咆哮、震屏、读档、伤害反馈及绕障验收。已目检1280×720咆哮截图。
- 两次运行无项目错误、无环境告警，正式存档指纹未变。git diff --check通过。

此前4项失败已处理；保留旧失败报告作为历史证据。此结论限于本次盐池范围，不覆盖文档中另行记录的巨蛙混合水怪追击问题。后续变更岩鬃兽攻击阶段时，应同步更新旧综合测试的行为预期，不以兼容存档的阶段名 rush 推断仍有冲撞。
