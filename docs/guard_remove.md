# GUARD-REMOVE：移除格挡

2026-10-25。交付基于独立工作树 `C:/Users/KSG/.codex/worktrees/bf49/maze_code`，分支 `codex/guard-remove`。本说明记录隔离开发验收；主工作区 `F:/maze_code` 的合入及最终集成验收由来源主任务负责。

## 行为与兼容

右键无战斗用途。移除举锅动作、正面挡弹、格挡碰撞特效及操作说明；左键攻击、Tab/数字/空格切换、Shift加速和J捕获保留。普通史莱姆蓄力、吐弹、近战与队伍防御计算保留。

`combat_controls_hint.gd`（战斗操作提示）继续复用 `interact_button.tscn`（长底框）和 `key_button.tscn`（键帽），改为攻击、切换、加速三组，底框348×48，居中偏移±174，不改共享素材。

旧存档的 `guard_left`、`guard_reuse`、`guard_aim`、`impacts`、`blocks`（格挡时间、冷却、方向、碰撞特效、次数）不再用于伤害或显示；成功战斗事务会清理。旧 `guard_read`、`guard_pending`（格挡教学已读、待讲解）在教学同步时清理，旧已读键可保留但不再参与门禁。有效敌方弹丸与攻击状态仍须通过原有校验。

首次史莱姆仍在三次实际命中后讲解切换，随后自然蓄力吐弹，无格挡说明。旧档停在前摇时也直接继续。完整0.28秒喷射动画结束才解除最低1血保护，保存失败回滚；本票未删普通吐弹能力或改数值。

## 基线与集成边界

原提交 `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`，原工作树干净且分离头指针。建立票据分支后，只读源工作区，将运行所需当前代码、资源、文档与测试复制到本工作树，保留已跟踪删除语义。

快照提交为 `7c7745d2ae5a4c429ce80d1b16bb1be2f6182b67`。2252项文件/删除记录逐文件复制前后及整体复制后源SHA256均稳定，清单在 `output/guard_remove/snapshot/snapshot-manifest.json`。不复制源缓存、存档、输出目录或临时运行目录。原基线中已有历史产物不是本票实现增量。

只合入快照提交之后的实现差异，禁止整体合入快照。`scripts/ui_layer.gd` 保持快照原样。历史素材保留；导入产生的 `.import` 差异不交付。

## 可复跑验收

在待验收工作区根目录执行，执行器均隔离 `user://`（用户数据目录）并比较正式存档JSON指纹：

```powershell
& ./tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_skill_01.tscn -OutputRoot output/guard_remove/skills
& ./tools/tests/slime_lesson_timing_run.ps1 -Mode flow -Scene res://tools/tests/slime_spit_lesson.tscn -OutputRoot output/guard_remove/lesson_verified
& ./tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/guard_remove_capture.tscn -OutputRoot output/guard_remove/capture_final
& ./tools/tests/combat_02_run.ps1 -Mode import -OutputRoot output/guard_remove/import
& ./tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot output/guard_remove/smoke
```

技能基线193项通过，确实复现旧右键举锅与挡弹。移除后技能场景259项通过，教学场景123项通过，当前战斗入口到J捕获专项39项通过，均覆盖1152×648和1280×720真实场景及输入事件，已查看提示栏、受击、吐弹与击败截图。等价旧存档和失败保存场景用状态夹具构造，不冒充人工完整游玩。

初次全新工作树导入在字体缓存生成前报资源错误，完成导入后复跑通过。教学首次误用缺少 `--isolation-root`（隔离目录参数）的执行器，被隔离检查拒绝；换用原教学执行器后发现原失败保存模拟对象缺少后增区域接口，改为正式单例加失败路径后回滚检查通过。失败日志分别保留于 `baseline_import`、`lesson`、`lesson_correct_runner`，不计为通过。旧 `capture_attempt.tscn`（捕获验收场景）仍依赖靠近活怪即胜利和未击败直接结算的历史前置，158项中40项失败并有2条脚本错误；当前快照的 `capture_run.defeat` 早已要求生命为零，此前置不由本票改变。原失败保留在 `capture`，本票新增聚焦场景走左键真实击败、确认、J镇压、领奖、读档链路，避免扩大到旧测试整体改造。聚焦场景首轮鼠标确认未触发，改用页面原生Tab/Enter选择确认，并按现行10秒镇压流程等待，37项通过；原失败记录在 `capture_current`，功能通过记录在 `capture_keyboard`；截图复核发现夹具停止战斗帧导致HUD未隐藏，恢复正式帧处理后增加显隐断言，最终记录在 `capture_final`，捕获业务未修改。

编辑器解析与主场景启动通过，未发现项目错误。全部运行正式存档指纹一致。环境仅系统证书读取警告，编辑器另有Steam目录编辑器设置写权限警告，已单独记录。

## 可复用知识与重审条件

退役能力必须同时解除输入、伤害、显示和教学等待条件；只删右键入口会让旧前摇存档永久停住。旧字段可以忽略并在成功事务清理，但不可再作为免伤或动画开关。修改战斗事务、教学保护、存档迁移或提示组件时重跑上述场景；集成到有用户改动的工作区时仅增量合入并重新验收。
