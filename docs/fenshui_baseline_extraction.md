# 分水庭最小现有成果提取记录

2026-10-29，#2必要输入准备。状态：候选基线；提取已落盘，完整验收未完成，不代表#2鱼上岸玩法完成。

## 授权、对象与计时

- 来源会话：01a185bb-80e4-7eb1-b8b0-5969c6199d95，hostId（执行主机标识）为local。
- 执行会话：01a187fe-c001-75d2-8f59-001804e04d97，项目5a79f9f2-2337-493f-b672-62a4a80a770d；来源明确放行，仅本工作树唯一写者。
- 工作树：E:/codexWorktree/76a9/代号：料理迷宫；分支codex/fenshui-fish-shore。
- 冻结来源：1f426fbb12829fac854fe612694609d9a4b80f15；创建分支前重新核对为该提交、干净分离头指针。
- 准备实际开始：2026-10-29 22:09:54.8044210 +08:00；本批硬截止22:38，整票90分钟不重置。写入批次在来源放行后才开始，本批不启动新玩法。完整实施与主验仍需使用剩余累计预算，不能按原90分钟重新计时。
- 读取来源主目录及历史文档，不修改、暂存或提交来源主目录；不推送，不移动集成分支，不修改议题。不改历史通过结论。

## 最小差异与来源

逐文件清单与原始SHA-256（内容指纹）见[fenshui_baseline_sources.json](fenshui_baseline_sources.json)。它记录来源，不把混合脏文件的完整内容当作本票成果。

1. 新增试玩规则、效果脚本及UID（Godot资源标识）；沿用既有两鱼一鳗隔离标记、锁向冲刺、一次局部放电、旧停顿态补字段及电纹计算优化。
2. combat_simulation.gd只增加分水庭脚本预加载、推进分支、试玩标记类型和演员阶段校验，共6行；capture_run.gd只增量修改snapshot（读取快照），在副本上补旧试玩停顿字段。不带入小屋区域允许列表、地形或跨图逻辑。
3. fenshui_roads.gd只提取已有岸路数组缓存和零半径检测优化；不改碰撞形状、玩家可走范围或其他地图。
4. 专用试玩入口加载正式maze_fenshui.tscn后显式挂载效果、两行说明。未修改maze_entry.gd或正式场景挂载，因此正常分水庭不会自动启用试玩。
5. 提取已有27项行为测试、场景交互、旧档恢复脚本和两个启动器；提取无桌面输入专项及共享输入助手。project.godot只增加maze_automated_test标记下的不可聚焦设置；combat_02_run.ps1只提取隔离测试标记和副屏查询，不带入其他地图测试。
6. UI组件文档只增加分水庭试玩说明，不带小屋章节。设计对齐、规格、布局审阅及HTML、领域与问题跟踪文档仅作为历史上下文。其引用的旧output和未纳入素材仍在来源，不代表这些附件随基线分发。

不纳入：小屋/园圃/青苔池新代码、底图、图片导入元数据、AGENTS整份替换、生成素材、正式存档和旧output。现有试玩没有保护膜、25%保护伤害、鱼上岸/搁浅/凝膜的新状态；这些属于后续#2，不在本批实现。

## 依赖与边界

- 新脚本/场景中的16个直接res://源码引用均存在，未发现直接源码文件缺口；这不涵盖所有传递资源导入或运行效果。
- 专用入口依赖既有ch2_entry_state → chapter_ending_input → ch1_qte_03_input继承链及正常捕获/存档事务。共享输入助手已经提取为视口内事件，不调用系统鼠标定位或鼠标模式切换。
- fenshui_trial_interaction.ps1默认SourceSave（旧体验档路径）仍指向来源output/fs01/play-final/profile下的chapter-ending-test.json；文件存在且未入库。外部分发时必须显式提供旧档样例，不能假称自包含。
- 两个分水庭启动器带测试专用不可聚焦标记，但原文件没有显式选择副屏；本批保持既有源码，不直接运行这些有窗口启动器。复跑须先确认副屏并在启动前选择副屏；不能只凭隐藏窗口断言不会占主屏。
- 本次System.Windows.Forms显示器查询只返回DISPLAY193主屏，1707×960，没有副屏；因此不启动任何有窗口游戏、编辑器或截图。无头输入通过不代表Windows原生窗口焦点通过。
- 第三次等待导入仍不能得到启动封面、枯水渠、金币等纹理缓存；编辑器另报Blender路径未配置。对应原始资源源码存在，完整导入失败原因未进一步独立定位，不推测新玩法代码导致，也不配置Blender或扩修开始界面。

## 实际验证

Godot可执行文件存在：D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe。所有测试仅运行本工作树，APPDATA、LOCALAPPDATA、MAZE_QTE03_PROFILE均为本批output内隔离目录；测试标记只对子进程设置。命令通过启动器或独立ProcessStartInfo（子进程启动信息）执行，不改用户会话环境。记录采用各命令原始日志；未单独采集每条命令的秒级起止，不补造。

证据根：output/fenshui-baseline-20261029/（本轮新产物，仅本地留证，不入库）。

| 检查与实际入口 | 实际结果 | 证据与上限 |
| --- | --- | --- |
| combat_02_run.ps1 -Mode import，参数为当前ProjectRoot、上述Godot与本批OutputRoot | 两轮均未通过；引擎退出0但启动封面资源/脚本错误，首轮还有冷缓存字体错误；Blender未配置 | import/与import-warm/的summary.json、stdout.log、stderr.log；每进程240秒 |
| Godot --headless --import --path 当前工作树 --log-file 本批import-wait/engine.log | 第三次、最后一次等待导入检查，退出0但同样资源/脚本错误；没有声称通过，不再重试 | import-wait/engine.log；240秒 |
| Godot --headless --path 当前工作树 --script res://tools/tests/fenshui_borrow_lightning.gd --log-file 本批unit/engine.log | 27项0失败，退出0；电纹两次计算43.782、42.231毫秒 | unit/engine.log；240秒 |
| Godot --headless --path 当前工作树 --quit-after 600 --scene res://tools/tests/desktop_independent_input.tscn --log-file 本批internal-input/engine.log -- --report=本批internal-input/report.json；自定义功能为maze_automated_test | 7项0失败，退出0；真实内部悬停、鼠标按下松开、键盘激活及配置检查 | internal-input/report.json、engine.log；60秒 |
| 同一无头输入场景，移除测试标记，传--normal-config=true及新的report/log路径 | 2项0失败，退出0；正常启动配置不启用不可聚焦 | normal-config/report.json、engine.log；60秒 |
| combat_02_run.ps1 -Mode smoke，当前ProjectRoot、上述Godot与本批OutputRoot | 未通过；引擎退出0但启动封面缺缓存，start_screen.gd解析失败 | smoke/summary.json、stdout.log、stderr.log；240秒 |
| 复制只读旧体验档至本批legacy/profile，Godot --headless --path 当前工作树 --scene res://tools/tests/fenshui_trial_legacy_restart.tscn --log-file 本批legacy/first.log -- --fs01-resume --fs01-check --report=本批legacy/first.json | 第一进程因地图、金币纹理缓存缺失，maze_entry.gd加载失败、capture_flow不可访问；达到60秒终止，没有生成报告，第二进程未启动 | legacy/first.log；未通过，非跨进程恢复成功 |
| git diff --check；直接引用存在性；原件保护 | 差异空白检查通过；16个直接引用无缺失；22:22:33核对49个来源文件指纹全不变 | 来源指纹清单及工具原始记录 |

各次导入和smoke运行器报告其检查的正式JSON存档指纹不变；不外推为整机自定义存档目录审计。旧体验档源文件与复制入隔离目录的副本SHA-256一致，源文件未修改。本批未启动有窗口进程，无本工作树驻留Godot进程。

## 尚未完成与来源接收要求

- 编辑器无错误导入、主场景启动尚未通过，不能把此提交认定为已验收可运行基线。
- 完整场景交互、双分辨率截图、原生不可聚焦检查、三阶段场景恢复及旧档两进程恢复均未通过或未运行；原有历史95项/31+5+4项通过记录没有移植为本次通过。
- 来源需亲验候选提交、确认纹理导入依赖的有界处理归属，并在副屏恢复后复跑场景；缺口解决前不开始#2新玩法。#2与整图均未完成。
- 提取过程未新建可跨会话复用的领域规则或设计决策；历史材料原样保留，本记录是一次性交付检查点，不生成空知识交接。
