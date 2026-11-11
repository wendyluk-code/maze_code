# C05 澄砚：归流护持

独立工作树 `C:/Users/KSG/.codex/worktrees/character-c05-chengyan/maze_code`，分支 `codex/character-c05-chengyan`，基线 `3e0d76b69bdb3156749aef2315068fb28e6f5214`（C03）。只依赖已验收 C03；未自行合入 C04、B01。主会话须审查后增量合入 `F:/maze_code`，对公共战斗文件做联合回归；本记录不是主区完成声明。

## 已确认行为

澄砚为团队被动，每趟探索首次致命伤保留1HP；无敌1秒，期间免疫伤害、受击击退和闪红，无敌结束后5秒匀速恢复触发时团队最大生命10%。2星恢复12%，3星15%，4星无敌1.5秒，5星恢复18%，6星恢复20%且无敌2秒。恢复封顶当前生命上限，途中剧情加入或星级变化不重算已锁定总量。第二次致死正常战败。

跨区、重入、读档保留次数和剩余时间；暂停不推进、离线不补时，换队不刷新。正式结束探索后的新出发初始化机会。首探战败沿原快照回退，再次出发是新趟。剧情切磋本身不致死，不消耗机会。不改变移速，不要求切换或攻击。

## 接入

`chengyan_guard.gd` 仅管理纯状态，存于 `combat.chengyan_guard`。字段为本趟已用标记、无敌剩余、回血剩余、触发时总恢复量和累计已结算量。恢复使用累计差值，避免帧率改变总量；封顶浪费的恢复不顺延。死亡停止剩余效果但保留已用标记。

`team_attack.receive_damage` 是实际承伤入口，调用原 `incoming_damage` 防御公式后结算保命，返回是否应播放原受击反馈。普通近战、史莱姆弹丸、巨蛙和岩鬃兽全部接入；同一模拟步第一次保命立即保护之后的命中。防御公式及怪物攻击值未改。现有无澄砚零伤害的受击反馈保持基线行为。

原 `capture_run` 保存事务统一保存伤害、机会、计时、恢复和位置，失败整体回滚；无敌期间也将时钟变化纳入保存条件。新探索显式初始化，重入和跨区不清除。缺少字段的旧状态允许通过原校验，首次承伤按未使用初始化；没有做正式旧档迁移或访问。

UI复用五槽 `combat_skill_bar` 和 `character_details_modal`：键帽显示“被动”，点击详情，数字键只提示并保持当前主动技能；效果期间槽名显示“护持中／回复中”，结束恢复角色名，提示说明本趟已触发。详情显示“保命与恢复生命”和“每趟首次致命伤”。不增加图片、动画或音频素材；`scripts/ui_layer.gd` 未改。

## 验收

引擎实际4.7.2，路径 `F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`；配置主入口为 `scenes/start_screen.tscn`。每个运行器使用独立项目名和 APPDATA、LOCALAPPDATA、MAZE_QTE03_PROFILE，测试验证真实用户目录，未访问正式存档。

|命令|结果|
|---|---|
|`./tools/tests/c05_chengyan_run.ps1 -RunName final`|245项通过，`output/c05_chengyan_final/report.json`|
|`./tools/tests/c03_ahong_run.ps1 -RuntimeName c05_chengyan_runtime -RunName c05_regression`|221项通过|
|`./tools/tests/c02_jiaopopo_run.ps1 -RuntimeName c05_chengyan_runtime -RunName c05_regression`|270项通过|
|`./tools/tests/c01_dingdang_run.ps1 -RuntimeName c05_chengyan_runtime -RunName c05_regression`|306项通过|
|`./tools/tests/c05_chengyan_run.ps1 -Import -RunName import_final`|退出0，无项目脚本或资源错误|
|`./tools/tests/c05_chengyan_run.ps1 -Smoke -RunName smoke_final`|引擎退出0，但严格运行器因基线资源退出占用判失败|

覆盖1–6星、多个步长、普通伤害/恰致死/超额致死、同帧多个伤害入口、免击退闪红、回血封顶和触发总量锁定、实际剧情加入与切磋、保存失败回滚及重试、读档重入跨区青苔池、暂停、换队、新趟与首探失败回退、损坏字段、真实键鼠被动详情输入恢复。截图为同目录 `c05_details.png`、`c05_guard.png`、`c05_recovered.png`，已查看详情及保命实际1280×720画面。C03/C02回归在最终只收紧澄砚状态校验前运行；C01与最终专项在收紧后运行。

首次导入缺字体缓存；第二次和最终导入通过。`r1` 测试脚本两处变量类型推断错误，确认后终止该专属进程，未跑业务断言。`r2` 241项中26失败：读档浮点用字典精确比较，以及夹具重建随机布局造成与存档不一致；`diagnosis`改近似比较并记录明确 `combat=true, layout=false`，剩25个连带失败。仅修复夹具保留原布局后 `r3` 242项全通过；生产布局校验未放宽。补剧情边界后最终245项通过。所有失败日志保留。

无头入口仍有基线2个对象、1个资源退出占用，不能称全绿。未运行全剧情、全部地图长期战斗或B票数值平衡验证；没有宣称游戏整体平衡。

## 可复用边界

已验证：连续伤害保护必须在实际承伤入口立即更新状态；事后在帧末检查HP会漏掉同帧后续攻击。用累计恢复差值且保存总量/已结算量，可保证多步长和读档后不重复回血。修改承伤入口、存档事务、时间推进、最大生命更新或技能栏模态流程后需重跑本专项。未来新增伤害类型需接入统一承伤入口，不能从当前四类覆盖推断其已受保护。

## 主区集成验收
2026-11-09 已增量合入 F:/maze_code，保留 C04 水网、B01 防御和常驻 UI 蒙层改动。target_import 通过；output/c05_chengyan_target_final 专项245项通过，正式存档双重隔离。后续C06联合回归待完成。
