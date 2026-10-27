# COMBAT-08：受击击退与身体闪白

执行基线 `db6903ff9bebf1d9793e465b2792d105a50e05ba`（`codex/combat-07`），独占分支 `codex/combat-08`，执行目录 `C:/Users/KSG/.codex/worktrees/8c92/maze_code`。来源任务 `01a14263-a55a-71d2-9fb2-10e636d0b31c` 已确认票据；依赖 COMBAT-07 已完成。项目归属依据来源明确绑定 maze_code 且创建成功，`project_binding_verified=true`（项目归属已核验）。初始 HEAD 与基线一致且干净，分支创建经共享 Git 元数据权限审批后成功。预算60分钟、90分钟强制停止，无超过20分钟命令；本执行任务不写入或合入 `F:/maze_code`。

## 行为与实现

真实近战扣血后，主角沿远离该魔物的位置方向，以150世界像素/秒击退0.12秒，合计18像素；真实锅铲弹道扣血后，魔物沿远离该枚锅铲发射位置的方向，以100世界像素/秒击退0.12秒，合计12像素。来源与受击位置完全重合时采用向下方向。连续命中重新计算方向和剩余时间，每次扣血均独立结算，不增加无敌时间。魔物击退期间暂停追逐位移，但保留原冷却与前摇推进。

击退沿直线每0.5像素探测原道路脚底规则，遇到路边、栅栏、地图边界立即截断；不使用原手动移动的沿墙滑动。原地图道路与素材未改变。玩家自身移动继续走原输入和道路规则，战斗以当前玩家位置加本次击退，事务成功后同步显示位置；探索存档位置采用同次战斗结算位置。失败恢复最近成功子步，避免回到更早的画面位置。

`hit_remaining`（剩余击退秒数）、`hit_velocity`（击退速度）和 `flash_remaining`（剩余白闪秒数）保存在原战斗状态内，与伤害及位置同一事务提交，不修改 SaveManager（存档管理器）接口。旧档缺省为无反馈；重载只继续剩余时间，不重启反馈。非法时间、非有限坐标、超过允许上限的速度被拒绝。返航、致死及新生命清除反馈；离开场景释放局部材质。暂停、输入锁、物理处理关闭及失焦沿用原统一战斗暂停条件。

常规战斗仍使用0.05秒步长，存在击退或白闪时细分至0.01秒，使0.12秒受击时长不会被常规20Hz步长拉长到0.15秒；撞墙提前截断击退后，白闪仍按0.1秒结束。屏幕展示仍受实际帧率限制。每帧最多追赶0.2秒，保留卡顿时限制积攒时间的策略。身体通过独立 `hit_flash.gdshader`（局部着色器）显示白色0.1秒，保留纹理透明度；材质只挂主角和魔物身体节点，原血条、数字、阴影、07短条布局和操作提示均保留。

## 复跑入口

沿用 `tools/tests/combat_02_run.ps1`，实际引擎 Godot 4.7.2，配置入口 `scenes/start_screen.tscn`。每次运行隔离 APPDATA、LOCALAPPDATA、MAZE_QTE03_PROFILE，并比较正式存档前后 SHA256；只终止本次测试创建且超时的进程。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_08_feedback.tscn -OutputRoot output/combat_08/feedback_gate_fixed
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_08_mouse_regression.tscn -OutputRoot output/combat_08/regression_07_precision
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_07_hud_ui.tscn -OutputRoot output/combat_08/hud_07
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_06_state.tscn -OutputRoot output/combat_08/state_06
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_navigation.tscn -OutputRoot output/combat_08/navigation_05
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_05_flow.tscn -OutputRoot output/combat_08/flow_05
& tools/tests/combat_02_run.ps1 -Mode import -OutputRoot output/combat_08/import_final
& tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot output/combat_08/smoke_final
```

08专项使用真实迷宫、鼠标事件、战斗事务和弹道命中；只控制隔离样例初始位置、前摇与生命，不直接设置反馈字段来冒充命中。报告 `sequences`（位置序列）包含0、0.05、0.1、0.12秒对应位置及白闪时间；双分辨率截图包含 `hero_white`、`hero_after`、`monster_white`、`monster_after`。鼠标回归完整继承07真实输入、胜败返回、捕获J及状态流程。未回放全部餐厅经营和完整剧情。

## 早期失败与证据边界

`feedback_first` 157项中6项失败：恢复实时战斗会刷新跳过的怪物，而后续夹具重新创建了旧固定布局的战斗，和当前运行布局不一致，正式校验正确拒绝。夹具改为通过 `Run.monsters_for` 读取当前布局后，`feedback_layout_fixed` 157项全部通过；没有修改生产布局规则迎合测试。

原07入口在 `regression_07` 中149项有2项读档比较失败。08位置值经JSON默认十进制序列化后末位差约 `2.5011e-12`，超过旧递归比较的 `1e-12` 阈值。08鼠标回归仅对非整数采用 `1e-9` 容差，整数精确、字典字段和数组长度仍严格比较；差值逐项保存到 `json_precision.jsonl`。同流程 `regression_07_precision` 149项通过。此精度比世界坐标 Vector2 的实际单精度分辨率小得多，不掩盖可观察位移，不修改生产存档逻辑。

编辑器导入自动改变的既有 `.import` 资源元数据保留在工作树，不作通配符恢复，不进入票据提交。系统证书读取失败及 Steam 编辑器设置目录写权限警告属于环境限制，单独记录；最终结果以对应 summary.json 为准。

新增栅栏计时用例在 `feedback_accepted` 暴露了夹具不足：北侧出生的史莱姆被放到栅栏后触发返航门禁，实际没有造成伤害。最终夹具同步该用例出生位置，并明确断言生命由36变33；结束恢复原样例。跳过的无关怪物设定未来刷新时间，避免计时专项意外扩展为刷新测试；重建战斗保持当前布局原始数字，反馈专项复用上面的JSON精度比较。此修正后的 `feedback_gate_fixed` 全部通过，原失败目录保留。

## 独立工作树最终结果

| 验收 | 检查数 | 失败 | 证据目录 |
| --- | ---: | ---: | --- |
| 双分辨率真实受击、连续伤害、墙边、暂停、读档及生命周期 | 227 | 0 | `output/combat_08/feedback_gate_fixed` |
| 07真实鼠标、胜败返回、捕获J及读档 | 149 | 0 | `output/combat_08/regression_07_precision` |
| 07短条及UI输入 | 147 | 0 | `output/combat_08/hud_07` |
| 06状态及保存失败 | 22 | 0 | `output/combat_08/state_06` |
| 05道路卡点 | 15 | 0 | `output/combat_08/navigation_05` |
| 05追逐返航与重载 | 55 | 0 | `output/combat_08/flow_05` |
| 编辑器导入与无头启动 | 两项退出0 | 0项目错误 | `output/combat_08/import_final`、`smoke_final` |

合计615项检查通过，各批正式存档指纹一致。最终双分辨率受击及恢复截图已复查，报告中的主角位移为18像素、魔物12像素，0.1秒白闪结束、0.12秒击退结束。末次生产修正仅补充“击退被墙截断但白闪尚未结束”时继续细分计时，已由最终专项覆盖。回归截图及报告均位于独立工作树，未写入玩家目标目录。

## 可复用知识与重审条件

受击表现涉及位置时必须与伤害共同提交，再从成功状态同步玩家显示；不能由显示层另开独立补间并与输入和存档争写坐标。正例是失败后伤害、剩余时钟、弹道和位置一起还原；反例是保存失败但白闪或位移仍播放。改变战斗步长、输入暂停、道路脚底、身体材质、事务提交或序列化时，应重新运行本票专项与07/06/05相关回归。保存往返测试须区分整数状态和浮点位置的合法末位误差，同时记录实际差值。

执行交付仅证明独立工作树；玩家目标目录的增量合入及集成验收由来源主任务完成。

## 审查修正：身体常态与透明度逐像素保持

主任务审查指出初稿片元函数再次执行 `texture(TEXTURE, UV) * COLOR`，可能重复乘纹理。`combat_08_pixels.tscn` 将真实主角和史莱姆身体的同一帧纹理放入512×512透明视口，分别渲染无材质、关闭闪白、开启闪白；每种身体均测原色和节点半透明调制，不推进动画。`pixels_before` 证明问题存在：原色主角31,998像素、魔物50,479像素的常态RGBA发生变化，最大通道差约0.2549；白闪alpha分别有12,167和36,840像素改变。先前肉眼截图不足以证明常态外观及alpha完全保持，此段证据取代该项原判断。

最小修正只删除重复纹理采样，直接保留 Godot CanvasItem（二维绘制节点）片元已有的 `COLOR`，开启白闪时仅将RGB设为白色。`pixels_fixed` 21项通过：四组常态对比变化像素全部为0、最大RGBA差为0；四组白闪alpha变化像素全部为0。透明视口读回为预乘alpha颜色，白闪可见像素按RGB等于alpha校验；首次用RGB等于1的四项断言不适用于该读回格式，已纠正，并未放宽常态或alpha比较。正式存档前后指纹一致，仅系统证书环境警告。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_08_pixels.tscn -OutputRoot output/combat_08/pixels_fixed
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/combat_08_feedback.tscn -OutputRoot output/combat_08/feedback_shader_fixed
```

像素证据包含主角与史莱姆的原图、关闭闪白与白闪共12张512×512图片，均在 `pixels_fixed/screenshots`。同一受击专项在 `feedback_shader_fixed` 重新验证227项、0失败，实际场景新截图替代修正前偏暗的截图；编辑器导入 `import_shader_fixed` 退出0且无项目错误，正式存档指纹均一致。修正不改变战斗、计时或输入，不扩展其它回归范围。以后新增CanvasItem片元着色时，应先对照无材质做关闭特效的像素比较，避免重复乘纹理及alpha。

## 主目录集成记录
2026-10-21：最终702294ac相对db6903ff的票据差异已增量合入F:/maze_code。主目录integrated_feedback227项、integrated_pixels21项、integrated_mouse149项均通过，正式存档指纹一致；已查看双角色白闪实际截图。正常材质逐像素保持由integrated_pixels验证，非早期肉眼结论。证据output/combat_08/integrated_*。

## 主角长帧闪白修复（2026-10-21）

问题复现：combat_flash_frame.tscn在真实场景近战扣血时调用生产_process(0.2)，原实现同帧补算将0.1秒flash_remaining耗尽，渲染前shader已关闭。output/flash_frame_before记录13项中两项失败。修正capture_flow.gd，仅在成功提交且主角存活的扣血步触发0.1秒显示计时，按渲染帧推进，暂停冻结；与模拟剩余时间取大值驱动原身体材质，伤害和击退模拟保持不变。死亡清理显示计时。

output/flash_frame_fixed：13项通过，正式存档未变，实际白闪截图已查看。原受击专项output/flash_frame_regression及复验flash_frame_regression_final均227项功能通过；补充截图批次flash_frame_final的13项亦通过。但这三批正式存档指纹门禁失败，同一正式存档发生变化，系统同时存在Godot进程57868、67136、72788，未结束用户进程；读取命令行因权限拒绝，不能确定写入来源。因此修复已接入F:/maze_code，功能已验证，整体验收未完成，不可宣称存档隔离总门禁通过。需要停止其他游戏运行/写盘后再验收；保留全部失败证据。仅另有系统证书环境告警。

用户退出游戏后最终复验：F:/maze_code的output/flash_exit_verified_combat_flash_frame为13项通过，flash_exit_verified_combat_08_feedback为227项通过，flash_exit_verified_smoke启动退出0；三批正式存档指纹均保持一致，无项目错误，仅系统证书环境告警。已查看本次实际受击闪白截图。此前存档变化记录保留，本次最终验收通过，长帧主角闪白修复完成。
