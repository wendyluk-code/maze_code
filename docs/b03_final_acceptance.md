> 2026-11-10 后续变更：按用户要求撤回B02加强版数值；本文数值和平衡样本是回调前历史证据。现行数值见 docs/b02_balance.md 顶部说明，测试期望已同步原版。

# B03 最终阶段交接：已合主区并完成范围内验收

## 主区集成复验（2026-11-10）

主会话已审查执行任务停止写入、工作树干净，并将 89ee56a 与 cfdbbc4 的三个测试/报告文件增量合入 F:/maze_code，保留其他用户改动。主区独立项目和存档目录位于 output/b03_final_main：regional1 603/603、transactions1 570/570、supply15_transactions1 353/353 全通过，源码哈希未变。首次导入仅新字体缓存缺失，第二次导入通过；原始失败保留。已查看主区 supply_settlement_ready.png，收入30、声望60、无损耗。非零损耗另用实际料理的隔离存档分支验证，不计入正常营业收益。

用户批准后，4488c824 的测试和报告差异已增量合入 F:/maze_code，保留主区既有记录。主区 supply10_authorized_main 344/344 通过，exit_code=0、unexpected_errors=[]、source_changed=[]；已查看结算截图，40金币、声望+60、无损耗。固定20110种子、一次性御风赠礼与真实银鳞鱼捕获完成供料经营；单次实验和主区集成复验各运行一次。此前审批阻断已解除，历史记录保留。

本票范围的32属性组合、10怪数值、24场区域战斗、10/15级真实供料经营、击杀/返店/交单/日结保存回滚和重载幂等、非零损耗分支、突破卡口及余额不足消费均具备主区证据。C01–C06、B01、B02相关回归也已通过。没有后台执行任务，正式存档未使用。长期平衡和完整走图经济效率不在这些样本的证明范围；强制入口退出资源警告、凝胶旧掉落、测试重载站位安全回退诊断仍按报告披露，不宣称已修复。

## 基线和修改边界

独立工作树：C:/Users/KSG/.codex/worktrees/character-b03-baseline/maze_code；分支codex/character-b03-final；基线3208837facaadd96b4a89d109df1bcfc03aa95fc。生产引用F:/maze_code，未修改生产。新增b03_final.gd，扩展b03_baseline_run.ps1支持-Final/-EvidenceRoot，新增本报告。主会话须合入后复验。

本阶段2026-11-10 02:22 UTC开始，约02:42 UTC交付，墙钟约20分钟（主动时间不超过此值）。未达到60分钟预期/90分钟强制预算；因审批拒绝，主会话要求仅收尾。旧阶段约43分钟单独记录。

C盘仅余665MB，全部隔离运行和证据位于E:/codexWorktree/b03-final-evidence。独立project name=maze_b03_isolated，独立APPDATA/LOCALAPPDATA/MAZE_QTE03_PROFILE，初始化前核验实际user路径；不访问正式存档。每轮生产scripts/data哈希前后相同，无生产改动。

## 已验证结果

| 目录/模式 | 结果 | 范围 |
| --- | --- | --- |
| b03_regional1 | 603项、0失败、exit0 | 32属性组合、10怪批准数值、24场生产Run.combat_tick战斗及经验代回执 |
| b03_transactions1 | 570项、0失败、exit0 | 10怪击杀经验保存失败回滚/重载/重复不发；三个突破卡口 |
| b03_supply15_1 | 329项、0失败、exit0 | 空仓盐池供料、实际服务日结、三处内存回滚、结算重载与不足消费 |

32组合为四队×1/5/10/15级×1/6星。24场为四队一星、5级剑甲虫/蜥蜴、10级银鳞鱼/巨蛙、15级拟态蟹/岩鬃兽；固定第一主动角色原地攻击、合法站位，其他怪物保留，60模拟秒上限。剧情done作为Boss解锁前置，不改HP/攻击。不模拟玩家平均操作或最优轮换。

| 队伍 | 剑甲虫 | 蜥蜴 | 银鳞鱼 | 巨蛙 | 拟态蟹 | 岩鬃兽 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 剧情 | 1.37 | 4.00 | 2.17 | 11.43 | 2.13 | 12.50 |
| 纯R | 1.80 | 6.17 | 2.97 | 16.87 | 3.23 | 19.10 |
| 双被动 | 1.80 | 5.33 | 2.57 | 14.33 | 2.87 | 16.17 |
| 输出 | 1.93 | 6.97 | 2.87 | 19.87死亡 | 3.73 | 27.37 |

单位秒；23场击败，一场输出队巨蛙死亡，照实记录且不强制通过。巨蛙损血107/136/112/161，岩鬃兽136/209/178/181。输出队仅萨莉亚主动技能，不能推断最优队伍强度。击杀经验代实际记录；5/10/15级卡口经验清零由4→5、9→10、14→15独立样本区分。经验事务复用B02末1血夹具，明确不用于平衡耗时。

15级来源：初始仓库空、金币0；正常盐池采集灯笼果2，真实攻击/J捕获拟态蟹获得肉1，饱腹27→26。真实返店→菜单爆浆拟态蟹斗1份→前台E接单→仓库取料→烹饪普通品质→吧台交付→售尽自然结算。金币+30、声望+60、损耗0，仓库剩灯笼果1/蟹肉0。实际30金币单抽/十抽/15级突破全部insufficient_gold且不改状态。无注入材料钱、无饮品自然需求。总41.605秒包含位置检查点，不能当完整走图耗时。一次性赠礼未用于此15级样本，不推算长期营业天数。

已查看supply15_1/supply_settlement_ready.png，显示30金币、+60声望、无损耗；其余截图含捕获、返店、菜单、仓库、烹饪和次日。通过轮次unexpected_errors=[]、source_changed=[]。Unicode Unexpected NUL既有提示单独保留，无脚本/资源错误。

## 首次交付时的未完成边界（后续补齐情况见末节）

- 10级银鳞鱼供给→经营未完成。gift_pending为初始化前置，真实grant已发白松露、玉兰百合、金丝燕窝各3；鱼被击败但捕获pending，未得到肉、未返店、未营业。不得报告10级收入或持续供给。
- 原交付中的非零损耗回滚及返店/交单专门重载、重复事务缺口，已由下述353项补充验证关闭；10级供给阻断仍未解除。
- 旧单份及300秒边界不重测；本阶段不能称整体平衡完成。
- 凝胶生产旧掉落及探索料理旧目录只记录，不修改生产或恢复取消玩法。

## 全部失败证据与分类

| 目录 | 实际原因 | 结果 |
| --- | --- | --- |
| b03_import1 | 新runtime首次字体缓存缺失 | Godot exit0，但严格runner拒绝字体资源ERROR；import2通过 |
| b03_supply10_1 | 测试重复sample_seed声明解析错误 | 主动停止exit-1；未进入场景，捕获截图0 |
| b03_supply10_2 | 删除语句未匹配CRLF，仍同一解析错误 | 主动停止exit-1；未进入场景，捕获截图0；后改正则解决 |
| b03_supply10_3 | 首次真正进入捕获，16秒等待结束仍镇压/pending | 313项、3失败；无配方与两个返店invalid_run为同次连锁阻断 |

前三次并不是三次捕获重试。supply10_3首目标fenshui_silverfish_1=pending，其他目标alive，饱腹始终22、bag空，四张截图仍同一未完成捕获窗。生产capture_attempt_modal.gd在audio_focused=false时暂停_process/输入；焦点暂停是待验证根因，未执行修正实验，不能称已解决。种子20110未改变。

## 历史自动审批拒绝原文（已获用户单次恢复批准）

> This action was rejected due to unacceptable risk.
> Reason: 该复试仍针对同一捕获焦点/等待失败族，但此前已有初次运行及两次重试；继续执行将超过票据规定的同一失败最多三次上限。
> Do not bypass this rejection through a workaround or indirect execution. Continue with a safer alternative, or carry out checks to prove that the action is authorized or low risk before trying again. Complete unaffected work without asking for confirmation. Report anything that remains blocked, clarify why it was blocked by auto-review, inform the user of the risk and ask for approval.

被拒的是require_escalated的exec_command整段调用，在CreateProcess前拒绝。拟先通过Python编辑独立测试，再执行：

```powershell
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-evidence -RunName supply10_4 -Mode supply10
```

拟执行但未执行的Python正文如下，原调用通过PowerShell单引号here-string管道传给 C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe -：

```python
from pathlib import Path
p=Path('tools/tests/b03_final.gd');s=p.read_text(encoding='utf-8-sig').replace('stop=Time.get_ticks_msec()+16000','stop=Time.get_ticks_msec()+35000').replace('   while Time.get_ticks_msec()<stop and flow.attempt.visible:\n    if','   while Time.get_ticks_msec()<stop and flow.attempt.visible:\n    flow.attempt.audio_focused=true\n    flow.window_focused=true\n    if')
p.write_text(s,encoding='utf-8')
```

拒绝后只读统计证明前两次解析失败、第三次才进入捕获。拟附新证据再次提交的调用被消息中断aborted before dispatch，未执行。supply10_4不存在，焦点修正未落盘。随后主会话明确只收尾，不再运行被拒复试。

恢复条件：主会话/用户明确处理失败族计数与复试授权，且自动审批允许，才进行固定20110种子的有界焦点实验；保持原始记录，不改种子、补材料或用间接命令绕过。仍被拒则保持未完成。非零损耗事务和缺失的幂等环节已在不运行10级的独立补充中完成，见下方。

## 主区可执行复验

合入后使用新目录/RunName，不覆盖证据，不运行受阻的supply10：

```powershell
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-main-evidence -Import -RunName import1
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-main-evidence -RunName regional1 -Mode regional
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-main-evidence -RunName transactions1 -Mode transactions
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-main-evidence -RunName supply15_1 -Mode supply15
```

首次导入若仅新缓存缺失，保留错误并在失败预算内再次导入。运行器上限480秒。本次未超时。默认旧runner行为保持，-Final选择新脚本，-EvidenceRoot改变隔离产物目录。

完整JSON、stdout/stderr、runner-summary、源hash、PNG和隔离存档全部保留于E:/codexWorktree/b03-final-evidence/b03_*，未删除/覆盖；报告提交准确失败摘要及拒绝原文，二进制和隔离存档不塞入Git。最终仅收尾写报告时一次PowerShell嵌套here-string解析退出1，未写文件；改为无嵌套正文后提交，不涉及被拒捕获命令。

稳定知识：combat_tick按剧情重新同步frog_unlocked，不能只改combat快照；capture窗失焦暂停时钟和输入，等待上限不能等同捕获随机失败。后者修正尚未验证。生产/脚本基线变化后重新审查证据适用范围。


## 15级独立事务缺口补充（353项通过）

主会话明确授权恢复15级未受审批影响的独立验证；未运行supply10，未改捕获焦点或等待实验，未改生产。本次累计阶段执行约25分钟，仍沿用原90分钟上限，不重置预算。

命令：

```powershell
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-evidence -RunName supply15_transactions1 -Mode supply15
```

结果：353项、0失败，exit_code=0，timed_out=false，source_changed=[]，unexpected_errors=[]。首次运行通过，无重试。原15级固定种子20115、真实来源和服务路径保持；正常结算仍是30金币、+60声望、无损耗。

新增逐项证据：

- 返店、交单、日结：先真实保存检查点，令独立存档路径不可用调用生产事务，断言save_failed及完整内存回滚；恢复原路径立即load_data，按金币、声望、仓库、背包、成品、烹饪、探索、成长、经营日、顾客和回执等业务字段比较（JSON规范化避免整数浮点类型误判）。
- 上述事务正常成功后，重复调用一次，验证这些业务字段不变；再保存、重载核验幂等。重复接口可以合法拒绝或返回已有结果，关键是不重复收益或扣料。
- 非零损耗：在本次真实采集/捕获并烹饪的蟹斗交单前，把现有完整状态分叉到隔离user://b03-nonzero-loss-branch.json。没有注入物品。该分支测试manual日结失败、回滚、重载，再正常提交；实际menu_lost=1、losses.mimic_crab_gratin=1、remaining_dishes=0、收入/声望均0。重复日结及重载均不再扣料。
- 损耗分支完成后恢复原隔离路径与原真实成品状态，继续正常GUI交单。这是从真实状态取样的事务分支，不是同一营业日先损耗再售出，更不计入经营收益。报告battles[0].loss_transaction_branch独立记录来源、结算与存档路径。

证据位于E:/codexWorktree/b03-final-evidence/b03_supply15_transactions1。已查看正常服务的supply_settlement_ready.png，显示30金币、+60声望；损耗分支是同步生产事务测试，没有冒充UI截图覆盖。旧全部失败证据和自动审批拒绝原文仍保留。

本次仅提交b03_final.gd及本报告的增量。主会话合入后复验同一supply15模式即可覆盖新增检查；使用新RunName，例如supply15_transactions_main。最终B03仍因10级供给阻断标记未完成，不声称整体验收通过。


## 用户批准后的单次10级焦点实验：344项通过

用户明确回复“允许”，主会话授权原固定种子20110、最多35秒等待的单次捕获焦点实验；审批此次允许。此前拒绝原文与所有失败证据仍保留。仅在level==10的测试捕获等待循环将audio_focused/window_focused维持true，并把等待上限从16秒设为35秒；15级仍原16秒逻辑。生产时钟、捕获概率、物品与金币不改。

只执行一次：

```powershell
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-evidence -RunName supply10_authorized_focus1 -Mode supply10
```

实际结果：344项、0失败，exit_code=0、timed_out=false、source_changed=[]、unexpected_errors=[]。同一20110种子首只银鳞鱼成功捕获，正常获得鱼肉2（生产掉落/角色效果），饱腹23→22。没有重新抽种子或补材料。

来源及账目：初始空仓/金币0；gift_pending是明确剧情检查点，通过生产御风grant获得白松露、玉兰百合、金丝燕窝各3（一次性赠礼，不能当作每趟可再生来源）。实际捕获鱼肉2；返店仓库9份赠礼原料和2份鱼肉。菜单玉兰银鳞鱼1份，实际取料、烹饪普通品质、接单交付；收入/净金币40、声望+60、售出1、损耗0；剩玉兰百合2、银鳞鱼肉1、白松露3、燕窝3。实际40金币不足单抽、十抽、10级突破，均拒绝且状态不变。自然首单无饮品，售尽提前结束。

返店/交单/日结保存失败原子回滚、专门重载及成功重复事务幂等均通过，结算重载与点击进入第二天通过。总样本42.081秒、营业段6.332秒；仍采用合法位置检查点，不是完整走图耗时或玩家平均收益。焦点实验仅证明隔离自动化窗口中的暂停可由该测试条件解除，不意味着修改了生产失焦行为。

日志另有一次“SaveManager: 迷宫站位无效，恢复当前区域入口安全点”，发生在测试重载链；该诊断保留，未关闭校验或改生产，业务回滚/物品金币/经验/经营状态断言通过。此测试不用于证明该检查点坐标跨场景精确恢复。既有Unicode Unexpected NUL提示亦保留。

证据E:/codexWorktree/b03-final-evidence/b03_supply10_authorized_focus1。已查看supply_settlement_ready.png，显示40金币、+60声望、无损耗。目录含捕获、返店、菜单、仓库、烹饪、次日截图与完整报告、日志、源hash。

本阶段累计约30分钟（02:22 UTC起），在90分钟强制预算内。原B03最终补充范围现已在独立树具备通过证据：区域603、经验事务570、15级扩展事务353、10级344；仍须主会话将本次增量合入F:/maze_code并复验，不能把独立通过当作主区最终完成。主区复验可使用已批准集成命令：

```powershell
./tools/tests/b03_baseline_run.ps1 -Final -EvidenceRoot E:/codexWorktree/b03-final-main-evidence -RunName supply10_authorized_main -Mode supply10
```

不再保留“10级仍审批阻断”为当前状态；此前相关措辞均描述历史交付时点。长期经济、最优技能轮换与玩家平均平衡不在本轮证明范围；凝胶遗留仍只记录。此次仅提交测试5行差异及本报告更新，完成后停止写入释放租约。
