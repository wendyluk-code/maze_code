# MAP-05 采挖、宝箱与料理闭环

独立工作树 `C:/Users/KSG/.codex/worktrees/75ee/maze_code`，分支 `codex/region-food-loop`，基线 `0ab444f2261b3a4534e05085f6d055eca5be5519`（`codex/region-map05-base-20261026`）。目标游戏工作区为 `F:/maze_code`，由来源主任务审查、增量合入及集成验收；本文不是主区完成声明。

## 玩家行为与状态

分水庭凉须草3处各2份、细孔渠藕2处各2份；盐池灯笼果2处各2份。植物进入本趟暂存袋，经原探索结算入餐厅仓库。`capture_run_v1.resource_claims`（本趟采集凭证）跨图、保存和重启保持，新趟重建；放弃本趟不入库。分水庭木材树桩3份直接沿既有木材库存与永久凭证发放。两图各3个真宝箱，每箱100金币永久一次，沿既有金币凭证，不与拟态蟹共用ID或交互入口。

`data/maze/region_resources.gd` 是固定身份、数量与坐标目录。采用已批准候选坐标，14点均经引擎8像素网格、真实移动函数从区域出生点连通检查。盐池灯笼果1的中心不可走，最近合法站位约(575.46,662.54)，距中心28像素；宝箱3中心不可走，最近合法站位约(1350.19,301.95)，距中心10像素。两者沿52像素交互半径从岸边领取，不修改底图碰撞。普通怪在资源中心42像素保护圆及身体外扩范围避让；战斗期间区域资源提示与领取被拒绝。

宝箱与采挖目录分别校验资源类型，植物ID不能调用金币领取。数量、凭证、站位与保存为同一事务；保存失败完整回滚，界面只显示已保存奖励。坏本趟凭证拒绝使用，不清空后补领。

## 配方与食用

| 配方 | 材料各1份 | 解锁 | 用途 |
| --- | --- | --- | --- |
| 凉须蛙囊汤 `frog_soup` | 风袋蛙胃囊、凉须草 | 首次成功捕获巨蛙 | 生命格，一/二/三星立即恢复团队最大生命15/25/35%，不溢出 |
| 风袋蛙鼓鼓包 `wind_frog_bread` | 风袋蛙胃囊、地穴麦粉 | 同上 | 饱腹格，按队伍顺序轮流补1点，团队合计1/2/3点，跳过满值成员 |
| 爆浆拟态蟹斗 `mimic_crab_gratin` | 拟态宝箱蟹肉、灯笼果 | 首次成功捕获拟态蟹 | 订单菜，基础金币30，无探索效果 |
| 脆炸水蝎藕夹 `scorpion_lotus_fritters` | 盲水蝎尾肉、细孔渠藕 | 首次成功捕获盲水蝎 | 订单菜，基础金币30，无探索效果 |

捕获成功与新食谱写入同一保存事务，重复结算不解锁第二次，失败或放弃不解锁。兼容只读现存、合法探索记录里指定魔物的 `captured`（成功捕获）状态；存在详细结算记录时还要求原因为成功。不会以库存、失败计数、击败或保底绑定推断成功，也不补发材料。历史记录派生的配方在下一趟开始覆盖旧探索记录前持久化；已登记配方自身是永久证据。早于本票且已完全丢失成功证据的历史无法推断，须再次成功捕获。

料理星级来自现有制作结果。原三份赠礼、便当五格布局、冰柜按份首次入柜起算七天、暂停/离线计时、再次存入不重置、装盒保存不可取回均保持。汤与史莱姆冻同占生命格。汤没有持续回血字段；鼓鼓包余量丢弃，未出战角色不分配。满生命汤及全满饱腹包单吃均拒绝且保留；全吃跳过无收益的这两种即时料理，其他份沿既有规则处理。食用仅在迷宫非战斗、非剧情阶段，失败回滚生命、个人饱腹与已食状态；已食格到探索结束清除，未食格跨趟保留。

没有新增顾客、游戏任务、麦粉/绝缘叶来源或正式档材料。测试的麦粉只来自隔离夹具。

## 素材与组件复用

内置 imagegen 生成凉须草、渠藕、灯笼果各一株；真实透明原稿、完整实际提示词与alpha裁切清单保留在 `output/map05/generated`、`prompts.md`、`asset_manifest.json`。统一透明裁切后置于256方画布，底部锚点(128,248)，场景48世界像素画布宽。纯闪光取已有 `white_stars_dots_twinkle_256.gif` 的32帧，无重绘。木材直接沿原含树桩图集，真箱沿原宝箱图集。

成品/原料图标复用 `output/food_icons_20261015/icons`，汤复用已批准 `output/region_encounters_review/v2/generated/frog_soup.png`，生产副本在 `assets/ui/region_food`。采集植物在 `assets/props/region_resources`。裁切复现脚本 `tools/tests/map05_assets.py` 需要保留的原稿，原图不覆盖。

界面复用 `chest_interact_prompt`（唯一近距E提示）、`loot_modal`（获得物品）、`feedback_toast`（短暂提示）、原料理台、冰柜和便当。便当效果描述按实际料理ID选择，原配方两参数接口仍兼容。地图只登记当前区未领真箱，继续受原揭雾规则约束，不把拟态蟹当宝箱、不新增采挖地图标记。未改 `scripts/ui_layer.gd`。

## 验收入口与证据

统一使用 `tools/tests/combat_02_run.ps1`，显式传 `-ProjectRoot` 和 `-OutputRoot`。引擎为 `F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`。运行器隔离APPDATA、LOCALAPPDATA、MAZE_QTE03_PROFILE；报告列出实际 `user://chapter-ending-test.json` 和正式档前后SHA256。

完整逐次命令及结果由 `output/map05/commands.json` 汇总各运行器summary生成；本文件末尾记录最终结果。以下是主区可直接复用的命令，输出目录可由主任务另指定：

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ProjectRoot F:/maze_code -OutputRoot F:/maze_code/output/map05_integrated/flow -ScenePath res://tools/tests/map05_flow.tscn
& tools/tests/combat_02_run.ps1 -Mode flow -ProjectRoot F:/maze_code -OutputRoot F:/maze_code/output/map05_integrated/reachability -ScenePath res://tools/tests/map05_probe.tscn
foreach ($phase in @('seed','resolve','eat','verify')) {
    $env:MAP05_PHASE = $phase
    & tools/tests/combat_02_run.ps1 -Mode flow -ProjectRoot F:/maze_code -OutputRoot "F:/maze_code/output/map05_integrated/restart_$phase" -ProfileRoot F:/maze_code/output/map05_integrated/restart_profile -ScenePath res://tools/tests/map05_restart.tscn
}
foreach ($size in @('1152','1280')) {
    $env:MAP05_CHAIN_SIZE = $size
    & tools/tests/combat_02_run.ps1 -Mode flow -ProjectRoot F:/maze_code -OutputRoot "F:/maze_code/output/map05_integrated/chain_$size" -ScenePath res://tools/tests/map05_chain.tscn
}
```

连续场景每进程一个分辨率，避免两个长捕获流程超过运行器240秒上限。入口 `map05_chain.tscn` 复用YF04真实八句对白、追击、20%停战、战后奖励、飞入与告别，然后同趟进入分水庭鱼/巨蛙、盐池蟹/蝎/岩鬃兽，真实攻击击败、鼠标确认与J键捕获、数字2选铁山和鼠标采盐，再E采挖、结算入仓、餐厅E料理台制作、E冰柜存入、鼠标装盒、再次探索鼠标全吃。

连续场景是有界集成样例：使用同一SaveManager和正式场景/事务；跨区域通过正式切区事务切换，站位由夹具移动到已验证位置，不模拟整段人类步行。为限制时长，战斗夹具提升攻击至300、按现行容量补满队伍饱腹，捕获随机值固定成功；巨蛙用实际芽芽复制得到两胃囊，不直接注入肉。故证明的是输入、状态、保存和界面链路，不证明自然随机成功率、低级队伍连续捕获的资源平衡或全程无夹具游玩。麦粉仍仅测试补一份。

四进程覆盖植物/永久木材/宝箱、付费捕获退出、成功解锁、两种真实制作星级、按份存取不重置七天、装盒未食退出、实际食用后再退出，以及已食不重复恢复。最后一阶段只读已保存生命并结束本趟，不重复执行前置。

## 历史失败与限制

首次新工作树导入缺已有字体缓存，建立缓存后导入通过。首次新夹具引用旧捕获函数名导致解析失败与运行器超时；随后夹具把个人饱腹设得超过实际等级上限，合法性拒绝引起后续串联失败。已分别改为当前 `start_capture` 与真实容量；不改捕获生产规则。

截图审查发现旧采挖闪光图集包含树桩，初稿植物叠出了树桩；已切换复用纯闪光帧，保留失败截图。首轮连续场景J按键等待短于完整捕获结算周期，奖励未结束便进入后续流程；按现行180次上限、奖励出现即停止的输入循环修正。首轮重启夹具误用冰柜 `take`，改为现行 `withdraw` 后四进程通过。旧 `bento01_flow` 被现行首次冰柜对白挡住；`map05_bento_regression` 只设已读前置，完整复用原装配/并发测试，不修改生产对白或原测试。

`restart_seed`、`restart_resolve`、`chain_01` 检测正式槽 `saves/1793002969-609-a453a8abf7dc9578.json` 在运行期间变化，原前后指纹保留；已通知来源主任务。测试实际路径均在本工作树profile，不能从指纹单独确定外部写入者。未回写正式档、未干预其他进程，未为碰稳定窗口无限重跑。后续因真实夹具修正进行的复验保留独立目录。系统证书读取、编辑器设置目录权限为单列环境告警。

最新 `chain_final_1280` 同样检测到上述正式槽指纹变化：308项功能检查零失败、引擎退出码0，但正式存档保护检查失败，因此该次运行不能标为整体验收通过。来源主任务已获通知，须在目标工作区查明写入来源并复验；未通过反复运行寻找安静窗口消除这一记录。

## 最终结果

以下目录均位于 `output/map05/`；检查数为实际报告记录，不表示覆盖所有游戏行为。

| 运行目录 | 功能检查 | 正式档前后指纹 |
| --- | --- | --- |
| final_flow | 545通过，双分辨率 | 不变 |
| reachability | 73通过 | 不变 |
| restart_fixed_seed / resolve / eat / verify | 18 / 20 / 5 / 6通过，四进程共享restart_fixed_profile | 不变 |
| chain_capture_wait | 1152分辨率294通过；早于最后资源类型断言补充 | 不变 |
| chain_final_1280 | 1280分辨率308通过 | **变化，运行器整体验收失败** |
| regression_map01 / map02_flow / map03_flow | 1741 / 459 / 2115通过 | 不变 |
| regression_map04_flow / map04_contract | 405 / 70通过 | 不变 |
| regression_map01_pity_compat | 344通过 | 不变 |
| regression_map05_bento_regression | 212通过 | 不变 |
| import_final / smoke_final | 退出码0，无项目错误 | 不变 |

最终编辑器导入仍报告系统证书读取和编辑器设置目录写入权限告警，已单列于summary，不属于项目脚本或资源错误。各summary的引擎参数、实际隔离路径、结果及重启阶段/连续场景尺寸环境变量汇总于 `commands.json`。截图见各运行目录的 `screenshots`，其中最新连续场景包括采挖、真实击败、制作、装盒和食用画面。

## 知识交接与重审条件

永久领取与每趟领取必须使用不同生命周期的凭证，二者不能只靠场景隐藏判断。资源目录身份校验还须区分发金币与发食材；正例是植物ID调用宝箱事务被拒绝，反例是共享find返回任意资源后按宝箱常量发金币。旧图集名称不能证明它只含特效，须实际查看画面后复用。改变区域目录、保护半径、地图地形、食谱解锁证据、捕获或存档结构、料理格规则及饱腹容量时，重跑相关入口并重新审阅截图。

`output/map05` 为忽略证据目录，保留原图、提示词、报告、截图和隔离档，不随生产提交合入。来源主任务须读取或复制证据，禁止把profile当玩家存档合入。独立树完成后仍须主区增量合入与集成验收，整体游戏交付在此之前**未完成**。
