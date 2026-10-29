# 分水庭最小现有成果提取记录

2026-10-29，#2必要输入准备。状态：候选基线；隔离Blender配置、三纹理加载和来源启动检查已通过；旧档环境适配后两次独立无头进程均10项0失败，源档未变，原生焦点明确未验证。完整场景与视觉验收仍未完成，不代表#2鱼上岸玩法完成。下文保留失败历史，最新结果见末节。

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

## 首轮未完成项与来源接收要求（历史记录）

- 编辑器无错误导入、主场景启动尚未通过，不能把此提交认定为已验收可运行基线。
- 完整场景交互、双分辨率截图、原生不可聚焦检查、三阶段场景恢复及旧档两进程恢复均未通过或未运行；原有历史95项/31+5+4项通过记录没有移植为本次通过。
- 来源需亲验候选提交、确认纹理导入依赖的有界处理归属，并在副屏恢复后复跑场景；缺口解决前不开始#2新玩法。#2与整图均未完成。
- 提取过程未新建可跨会话复用的领域规则或设计决策；历史材料原样保留，本记录是一次性交付检查点，不生成空知识交接。

## 后续：隔离配置Blender与旧档无头恢复（2026-10-29）

### 原因证据和用户选择

首轮并非缺少三张PNG源图：封面、枯水渠地图、金币的原图与主目录指纹相同，导入描述规范化换行后相同。已有日志完成扫描后即出现Blender配置错误；隔离编辑器的Blender路径为空。对照本机引擎提交ed1daf0bf的官方实现，editor_scene_importer_blend.cpp第551～552行在无头配置查询时返回true；editor_file_system.cpp第1049～1054行在支持检查返回true后提前返回，未调用整批reimport_files。此链路支持“Blender前置配置阻断整批导入”的定位，不把先后报错当作唯一依据。

用户明确选择配置Blender，不采用禁用导入。来源已实测Blender 5.2.1 LTS；本任务重新核对同版本引擎源码第54～64行：字段以文件路径检查并直接执行--version，因此填写可执行文件，不填写目录。

只用apply_patch在本工作树新建output/blender-config-20261029/profile/Godot/editor_settings-4.7.tres，设置filesystem/import/blender/blender_path为C:/Program Files/Blender Foundation/Blender 5.2/blender.exe；没有覆盖enabled、没有禁用导入、不写全局或主目录设置、不复制任何旧.godot缓存。该机器特定配置不入库。APPDATA、LOCALAPPDATA、MAZE_QTE03_PROFILE均隔离到这个新profile。

### 配置后的真实结果与已发生的截止偏差

- 单次命令：Godot --headless --import --path 当前工作树 --log-file output/blender-config-20261029/import.log。23:04:15.453+08启动，PID29828，约23:05:07退出0，批量reimport确实执行并显示655步完成；扫描该日志未见ERROR、SCRIPT ERROR或Traceback。没有再次重跑整库导入。
- output/blender-config-20261029/load_textures.gd通过ResourceLoader.load实际加载封面、maze_entry地图、HUD金币；三者均为Texture2D且宽高大于0，最终3项通过、失败0，load-final.log对应进程退出0。首次加载脚本因ok变量类型推断错误而解析失败，load.log原件保留；只给该临时脚本补显式bool后复核加载，不隐去此失败、不把它当资源加载失败。
- 来源独立执行combat_02_run.ps1 -Mode smoke -ProjectRoot 当前工作树 -Godot D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe -OutputRoot output/fenshui-source-review/smoke，summary.json显示退出0、errors与environment_errors为空、检查到的正式存档指纹不变。本任务已读取该报告，但没有把来源运行冒称为自己的重跑。
- 上批实际开始23:03:27.739+08，最后加载结束23:06:04.397+08，主动墙钟约2分37秒；虽然未超过3分钟，越过23:06绝对截止约4秒。来源已记录，继续保留，不以本批通过抹去偏差。

这些结果仅证明这次隔离配置解除了导入前置阻断并使三张纹理可加载，以及来源启动检查通过；不证明新机器自动配置、全仓资源格式或完整游戏验收。没有运行图形窗口或系统输入。

### 本批格式整理和旧档验证

本批从23:09:51.662+08开始，最多8分钟、绝对截止23:18+08；来源登记整票已用保守33分钟，总90分钟余57分钟，本批继续累计，不重置。没有新玩法放行。
截至23:14:35.070+08的收尾核对，主动墙钟约4分43秒，未超过本批预算；本批只有本报告产生语义改动，613项格式证明中不等项为0，没有本工作树驻留Godot进程。

1. 先对613个已跟踪.import逐个计算Git规范化内容指纹，并与基线对象逐个比较；全部相同后才恢复原CRLF。指纹证据output/fenshui-recovery-20261029/import-eol-proof.json保留每个路径与两端指纹，脚本restore_import_eol.ps1保留判定与格式整理过程。未用reset/checkout、未删除缓存或日志；完成后git status确认工作树干净，图片元数据没有进入语义改动。
2. 只读源档仍为主目录output/fs01/play-final/profile/Godot/app_userdata/maze_code/chapter-ending-test.json；明确复制到本批新output/fenshui-recovery-20261029/profile。新profile隔离APPDATA/LOCALAPPDATA/MAZE_QTE03_PROFILE，仅对子进程设置maze_automated_test功能标记。
3. 实际启动：Godot --headless --path 当前工作树 --scene res://tools/tests/fenshui_trial_legacy_restart.tscn --log-file output/fenshui-recovery-20261029/first.log -- --fs01-resume --fs01-check --report=output/fenshui-recovery-20261029/first.json。每进程上限60秒，CreateNoWindow；本批run_legacy.ps1和summary.json记录完整参数、PID、带时区起止、退出与源档保护。
4. 第一进程PID72372于23:12:01.098+08启动，23:12:07.526+08结束，未超时，退出1；9项中8项通过、1项失败。通过的是隔离档加载、真实分水庭就绪、旧停顿字段补齐、战斗继续、鱼不重复受电、奖励和费用不重复、兼容字段保存等；唯一失败为既有脚本第4行“旧档重启测试不获取桌面焦点”的窗口属性组合断言。报告未记录组合中两个原始属性各自的值，不猜是哪一个导致失败，也不据此声称系统焦点真的被获取。
5. 按本批失败即停约束，第二进程未启动，没有原样重试、没有删断言求通过，也没有修改现有测试标准。第一次保存成功只说明隔离副本已保存，不能代替第二进程重新加载的验收。
6. 源档前后SHA-256均为A3CC5EBCF08AE7740849513CDB57BC3BBC19AAE84EF08807296047170CF0D1B5；不回写源档，不冒称审计整机存档。

### 当前剩余边界

旧档两进程验证整体仍未完成；本次不将9项1失败改成通过。下一次若调整无头环境接入，应先区分“无头数据恢复/内部输入”与“原生窗口焦点”验收，按来源放行保留原生检查，而非删掉要求。现有desktop_independent_input专项也只在非headless显示服务下检查原生窗口属性；是否采用对应的环境分离方式须由来源确认，本轮未实施。

仍缺副屏，未运行原生窗口焦点、双分辨率截图、完整95项交互或三阶段场景恢复。无头真实场景就绪不等于渲染验收。来源仍需亲验本次交付；#2新玩法与整图均未完成。

## 旧档测试环境适配返修（最新）

来源第2轮完整基线验收仍未通过，集中重评为无头入口误用原生窗口条件，不是战斗实现失败。本批只修改旧档测试、其专用复跑脚本和本报告，不改游戏逻辑、主目录、集成引用。按已确认边界验证旧档加载、推进、保存后再次恢复和环境证据。

按TDD（测试先行）先只增加观测、保留原断言，使用新隔离副本复现红灯。output/fenshui-legacy-adapter-20261029/red/记录PID70812于23:19:10.818～23:19:16.839+08运行，9项1失败。原始值为display_backend="headless"（无头后端）、startup_no_focus=true（启动不可聚焦配置）、unfocusable=false、has_focus=true；native_focus_verified=false（原生焦点未验证）。这次不猜哪项失败，也不把无头属性直接解释为系统焦点变化。

随后参照desktop_independent_input：无头分支检查真实隔离目录及启动no_focus配置；原生分支仍分别断言unfocusable和not has_focus，没有删除或降低原生要求。每份报告保留原始值，本批所有运行均为headless，原生焦点标志均为false。

旧档报告新增restored_state（加载后快照）与saved_state（保存后快照），记录玩家与三只魔物生命、奖励袋、饱食、战斗累计时间、攻击阶段和剩余计时。专用启动器tools/tests/fenshui_trial_legacy_restart.ps1仅复制一次源档到新隔离profile，两次进程串行共享该副本，第二次不重置；验证首次输出与第二次输入存档指纹相同，并比较两份状态。每进程60秒，失败或超时即停、无自动重试；输出目录已存在时拒绝覆盖证据。

实际绿灯证据位于output/fenshui-legacy-adapter-20261029/green/：

- 第一进程PID91132，23:20:09.156～23:20:15.382+08，10项0失败，退出0，无引擎错误。
- 第二进程PID37880，23:20:15.403～23:20:21.519+08，10项0失败，退出0，无引擎错误。
- summary.json中second_loaded_first_save=true（第二进程读取首次保存）、state_restored_equal=true（生命/奖励/计时快照相同）、source_unchanged=true（源档未变）、native_focus_verified=false。进程间衔接存档SHA-256均为138578C21963164DEFB6C32027054FD45A706FDC59A7430A75F60E942580444B。
- 源档前后指纹仍为A3CC5EBCF08AE7740849513CDB57BC3BBC19AAE84EF08807296047170CF0D1B5。正常配置专项在新的normal-config目录另验2项0失败、退出0、startup_no_focus=false，保留report.json和engine.log。

实际使用以下命令，将OutputRoot指定为本轮green目录；复跑必须换新目录，下面自动生成新位置：

~~~powershell
& ./tools/tests/fenshui_trial_legacy_restart.ps1 -SourceSave 'D:/workspace/代号：料理迷宫/output/fs01/play-final/profile/Godot/app_userdata/maze_code/chapter-ending-test.json' -OutputRoot (Join-Path $PWD ('output/fenshui-legacy-recheck/' + (Get-Date -Format 'yyyyMMdd_HHmmss'))) -Godot 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe'
~~~

命令需在仓库根运行，源档与Godot路径须在该机器存在。启动器记录完整参数、带时区起止、PID、退出、超时和源档保护。原有失败日志保留，未把无头画面当作渲染证据。

本批23:17:20.177+08开始，最多8分钟、硬截止23:25+08，继承整票保守40分钟已用及90分钟总额，不重置。本批不导入、不启动图形窗口或系统输入。两次无头恢复通过不等于原生焦点、连续渲染、双分辨率、95项交互或三阶段恢复通过；副屏条件与来源最终验收仍缺，#2新玩法未开始。
截至23:23:27.731+08收尾检查，主动墙钟约6分08秒，未超过本批预算；原生要求仍留在测试原生分支，本轮没有新增领域规则或游戏能力。
