# COMBAT-03 随机布局与安全刷新交付

主目录集成记录（2026-10-20）：已将相对b5df27e的03及修复累计增量（最终71a76d1）合入F:/maze_code，保留用户改动及docs/combat_02.md原有集成记录。主目录output/combat_03/integrated_*记录layout301、state69、flow127、跨进程seed10/restore6、02流程111/血条45/边界57/四类魔物25项通过（共751项），导入及启动通过，正式存档指纹不变。已查看主目录两种分辨率第二生命J捕获和奖励截图。项目脚本与资源错误为0；证书、便携编辑器全局设置写权限告警单列。经验结算和角色页面由后续COMBAT-04处理。

本修复在独立工作树 `C:/Users/KSG/.codex/worktrees/fa12/maze_code`、分支 `codex/combat-03-fix` 执行。基线为 `6d57c38ea77a016bfb1593f126420affb48bd48a`；03累计差异基线为 `b5df27e83cd0b35d5d5fa0e4efd72a93eb3eec7b`。来源主会话负责将累计增量合入 `F:/maze_code` 并复验；本记录不表示主目录已完成。

开始于2026-10-20 16:27（北京时间），预期主动执行60分钟，强制截止17:57，同一失败最多首次加两次有证据重试。没有超过20分钟的命令，单次验收进程上限240秒。启动时工作树干净、HEAD与基线一致，独占分支已核验。所选项目为 `7c3963e8-2c05-4bd9-9992-d9dc706e8cf4`，项目归属依据来源创建参数确认。

实际项目入口为 `scenes/start_screen.tscn`，配置要求Godot 4.7；本机实际执行Godot 4.7.2。未修改正式素材、UI样式、02战斗数值、饱腹规则、餐厅订单剧情、插件或主目录用户改动。

## 问题证据与修复

旧场景在 `output/combat_03_fix/baseline` 稳定复现15项中1项失败。其存档显示目标刷新截止为60.35秒，测试却把时钟设为60.1秒，并只推进0.1秒；旧安全点循环比较的是已有 `safe_point`，不是候选点。旧测试直接把HP置零后放弃捕获，不能证明自动击杀或实际捕获。

运行时还有独立遗漏：仅距旧出生点260就刷新，无镜头检查；普通怪不换出生点；未完整重置AI、保底和弹道生命有效性；全局洗牌不受传入种子控制，手写随机点包含道路外位置。此次修复：

- 每趟等概率选择配额 `(2,3,4,1)/(2,4,3,1)/(3,3,3,1)`，顺序为史莱姆、蜗牛、甲虫、蜥蜴。普通点从实际道路分段采样，使用同一局部随机源洗牌；入口安全距离260，怪物出生点间距至少80。蜥蜴固定 `(270,720)`。
- 死亡进入待捕获时建立运行时间截止，分别60/90/90/180秒。实际视口经画布逆变换得到世界范围，再外扩80像素覆盖身体；镜头内、距主角小于260、占用或道路外均拒绝。没有视口或安全点则延后且不消耗随机源。普通刷新离旧出生点至少80；首领使用固定点。
- 保持10个固定身份槽位，只增加 `refresh_count`（生命代数）。新生命重建HP、前摇、冷却、脱战计时、速度、捕获四随机、付费记录及本生命保底。每次更新布局同时更新战斗出生点，返航回本次出生点满血。本趟首次保底、芽芽次数、付款游标和已有袋中奖励保留。
- 弹道保存发射时各目标的生命代数，不能命中新生的同ID怪物。刷新当帧强制提交，保存失败回滚布局、随机源、生命、弹道、时钟及位置；恢复保存后重试得到同一随机结果。
- 新战斗档缺布局时补现状：优先既有战斗布局，否则保留02固定布局。已有HP、随机、袋、pending（待捕获身份）和已付款不变。02没有死亡时钟的已结算怪物从迁移时补完整冷却，不猜测离线时长；旧战力档返回不支持，不删除存档。
- 删除缺actor（战斗实体）时隐藏节点的掩盖逻辑，改为验证完整状态。02夹具明确构造固定布局；只测单种伤害时显式延后其他槽位刷新。

## 可复跑命令

必须使用PowerShell 7；Windows PowerShell不支持此运行器使用的进程参数接口。03运行器支持 `-ProjectRoot`，默认使用脚本所在项目。所有模式，包括布局检查，均复用02隔离运行器，设置APPDATA/LOCALAPPDATA并核对正式JSON存档指纹。不要使用 `--user-data-dir`。

```powershell
$ps = 'C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'
& $ps -File ./tools/tests/combat_03_run.ps1 -Mode layout
& $ps -File ./tools/tests/combat_03_run.ps1 -Mode state
& $ps -File ./tools/tests/combat_03_run.ps1 -Mode flow
& $ps -File ./tools/tests/combat_03_run.ps1 -Mode restart_seed -OutputRoot output/combat_03/restart_seed -ProfileRoot output/combat_03/restart_profile
& $ps -File ./tools/tests/combat_03_run.ps1 -Mode restart_restore -OutputRoot output/combat_03/restart_restore -ProfileRoot output/combat_03/restart_profile
& $ps -File ./tools/tests/combat_02_run.ps1 -Mode flow
& $ps -File ./tools/tests/combat_02_run.ps1 -Mode health
& $ps -File ./tools/tests/combat_02_run.ps1 -Mode edges
& $ps -File ./tools/tests/combat_02_run.ps1 -Mode monsters
& $ps -File ./tools/tests/combat_03_run.ps1 -Mode import
& $ps -File ./tools/tests/combat_03_run.ps1 -Mode smoke
```

种子准备与恢复必须顺序启动两个独立进程，共用同一个隔离ProfileRoot（用户目录）。各输出目录的 `summary.json` 记录实际引擎、PID、参数、退出码、环境错误和指纹结果；`report.json` 记录逐项断言。stdout和summary仅在进程退出后落盘，等待时间不是挂起证据。

## 实际验收证据

以下目录均位于本工作树 `output/combat_03_fix/`，不能用独立工作树结果替代主目录集成复验。

| 目录 | 结果 | 覆盖 |
| --- | --- | --- |
| accepted_layout | 301项，0失败 | 300种子，三配额分别99/104/97次；每次10只、道路合法、260安全区、80间距、固定首领、同种子复现 |
| accepted_state | 69项，0失败 | 四类冷却前后、安全点延后、随机不消耗、每类连续四代刷新、旧弹道隔离、十槽位、旧新战斗档补布局、损坏字段与旧战力档拒绝 |
| accepted_flow | 127项，0失败 | 1152×648和1280×720真实迷宫，满14HP目标至少五次自动弹道命中、当前详情页、实际J操作、扣费奖励、安全刷新、再次满血击杀捕获、返航满血、保存失败原子回滚、已付费迁移 |
| restart_seed / restart_restore | 10 / 6项，0失败 | 跨进程布局、HP、随机源、31.25秒运行时钟、待捕获、袋与已付费恢复；离线不增加迷宫时间、不二次付费 |
| accepted_02_flow | 111项，0失败 | 02胜败、真实移动输入、背包/角色页暂停、捕获、奖励、退出回餐厅、保存失败、弹道和伤害 |
| regression_health | 45项，0失败 | 双分辨率血条、真实尺寸、满/半/低/零HP、多怪、返航与暂停 |
| regression_edges | 57项，0失败 | 双分辨率地图/首次教学暂停、镜头输入恢复、死亡保存失败重试和等级冻结 |
| accepted_02_monsters_fixed | 25项，0失败 | 四种魔物真实前摇、单次伤害、生命与接触不逐帧扣血 |
| accepted_import / accepted_smoke | 退出0，无项目错误 | 编辑器导入、主入口无头启动 |

场景夹具明确将其他九只设为延迟刷新，只隔离目标战斗；目标两次都是满14HP，以原攻击3和真实锅铲击杀。冷却用受控时钟接近截止，随后通过正式推进事务；第二生命仅固定捕获随机抽样以消除概率波动，J操作和奖励事务照常执行。状态专项的残血、死亡、旧档和弹道样例是受控夹具，不冒称真实击杀；完整真实击杀由场景专项提供。

已实际查看最终两分辨率的J操作、第二生命捕获详情和奖励截图，界面无裁切或新增样式变化。截图位于 `accepted_flow/screenshots`，共18张，包括 `first_j_operation_1152x648.png`、`second_j_operation_1280x720.png`、`second_reward_1152x648.png`。详情页捕获率沿用原1.2秒数字入场动画，早期截图可能尚在数字递增阶段。

历史失败完整保留：布局脚本首轮类型推断错误、flow_1的Vector2类型推断错误（触发240秒超时）；flow_2的6项失败是迁移夹具仍处于skipped（已跳过），修正其状态后通过；accepted_02_monsters的6项失败是其他跳过怪物的零冷却触发刷新，破坏固定布局，显式延后后通过。03包装运行器首次空ProfileRoot在跨进程参数传递中错位，已改为PowerShell7内直接调用隔离脚本。没有删除失败断言或修改运行时迁就这些夹具。

全部完成运行的summary均记录正式JSON存档前后指纹相同。指纹清单位于各目录 `real_saves_before.json` / `real_saves_after.json`。系统证书读取告警，以及便携引擎编辑器设置写入权限告警单列在environment_errors（环境错误）中；不包含脚本解析、场景或资源错误。未改正式存档。

## 集成与稳定知识

本票补丁相对 `6d57c38`；主目录集成使用03累计补丁，相对 `b5df27e`。禁止带入更早的 `a0c5b40` 依赖快照，也不要覆盖主目录额外的 `docs/combat_02.md` 集成记录。导入自动产生的.import变动不进入补丁。

可复用的不变量：身份槽位不等于一次生命；返航、捕获付款/奖励和弹道都必须对齐同一生命代数，而本趟保底与付款游标跨生命保留。正例是保存失败恢复相同随机源后重试；反例是仅恢复HP却留下旧attempt（付费操作标记），或从全局随机源重新抽刷新位置。修改出生点选择、镜头变换、保存协议或生命周期字段后，应复跑layout/state/flow及跨进程恢复；若出现不同结果，先核对实际视口、候选道路、deadline（刷新截止）与当前运行时钟，再做单变量修正。

本次没有手动巡回所有道路或验证所有餐厅剧情；这些不在本票范围。来源主会话仍须在玩家实际目标目录合入和复验，完成该步骤后才可宣布游戏代码整体交付完成。

导入元数据清理说明：自动审批拒绝按通配符还原.import，理由为范围过宽。随后逐项差异检查得到0个内容差异，属于行尾/索引状态变化；未执行丢弃文件内容的清理，原样保留在工作树且不加入提交。该项不阻塞代码补丁交付。
