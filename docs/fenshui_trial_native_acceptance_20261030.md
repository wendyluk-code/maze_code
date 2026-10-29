# 分水庭撤除临时观测后的原生对照

## 范围与输入

本批只撤除先前添加的三个临时计时观测，使用原正式场景`tools/tests/fenshui_trial_interaction.tscn`执行一次完整95项流程。不改玩法、渲染器、随机控制、截图顺序、帧采样、250毫秒门槛或共享副屏规则；不运行最小或完整观测子类，不设置FS01_TIMING_DIAG，不预热或自动重试。

三个文件均通过apply_patch逐项撤除，不使用整文件Git回退。撤除前差异保存在`output/fenshui-uninstrumented-20261030/observations-before-cleanup.patch`，有观测版本快照及记录继续保留在前次诊断目录。撤除后与最初记录原件逐字节相同：

- `scripts/save_manager.gd` SHA256：`9F81DB8C0002F90399432360256A5CA33094E898E0010B56B3FCB2B6FD055E9A`。
- `scripts/maze/capture_flow.gd` SHA256：`668FFB7A7E6AE020CB20B1F6A033CC0B20BFD2E15A4053F9165017043AA3DAC3`。
- `scripts/ui/components/capture_attempt_modal.gd` SHA256：`48FABF9D43ECDBFEF8AB1C2CEA3625020273609C6CDF3262FCAE3913D3F8D6EF`。

HEAD中的Git对象使用LF换行，记录原件与工作区使用CRLF，原始字节摘要因此不等于Git对象摘要；Git换行转换后的三个文件对象摘要均等于HEAD，游戏源码差异为零。最初直接禁用转换的摘要检查未通过后，明确核实了这一差别，没有改写文件换行来制造通过。

测试时游戏源码基线为`a53ea40af44853eea714b3a28f43a787bd09ef6d`，工作树`E:/codexWorktree/76a9/代号：料理迷宫`，分支`codex/fenshui-fish-shore`。新增独立运行器只封装已有一次性启动方式，并提供ProjectRoot（项目目录）与OutputRoot（新输出目录）参数；不修改原正式测试入口。共享运行器还会启动两次旧档进程，故本批不直接调用它，以守住仅一次原生进程的授权边界。

## 复跑方法与保护

在待验项目目录执行，下例输出目录必须尚不存在：

```powershell
& ./tools/tests/fenshui_trial_interaction_primary.ps1 -ProjectRoot (Get-Location).Path -OutputRoot (Join-Path (Get-Location) "output/fenshui-uninstrumented-20261030/actual") -SourceSave "D:/workspace/代号：料理迷宫/output/fs01/play-final/profile/Godot/app_userdata/maze_code/chapter-ending-test.json" -AllowPrimaryScreenForThisExperiment
```

来源可在实际目标目录复验并传入新的OutputRoot；上例不是授权自动重跑。默认不允许主屏，调用时必须显式传入本次持续授权对应的开关。启动前以maze_automated_test启用no_focus（启动不聚焦），原95项入口检查unfocusable=true、has_focus=false（窗口不可聚焦且未获得焦点）。只发送Godot内部输入。CreateNoWindow只隐藏控制台，不被当作游戏窗口不聚焦的证据。

运行器隔离APPDATA、LOCALAPPDATA、MAZE_QTE03_PROFILE，移除可能继承的FS01_TIMING_DIAG，使用Forward+及Dummy音频，不验证出声。单进程120秒超时只终止自身进程树。保存实际参数、PID、带时区起止、退出码、窗口保护原检查、渲染日志及帧样本统计；源档前后摘要不一致时失败并保留现场，不回写源档。

## 结果解释边界

旧报告5400个交互样本，总时长约95071毫秒、均值约17.606毫秒；前次有观测完整流程1020个交互样本，总时长约91286毫秒、均值约89.496毫秒。两次总交互时长接近且95条检查同序，不是仅覆盖五分之一流程，也不能称性能等价。统计变化的原因尚未定位。

本次对照不构成性能修复，不推断旧975.606／466.167毫秒长帧的根因；此前三轮来源验收失败及全部原始证据保留。来源主目录集成、来源最终验收与Issue #2新玩法不在本批执行范围内。

## 本次实际结果

无观测当前版本本次达标，旧偶发长帧原因未知。

- 2026-10-30 00:51:42.4834730至00:53:27.9487574 +08，唯一原生进程PID71696，退出0，未超120秒，无引擎或脚本错误。00:54:07复核该进程已不存在。
- 原95项全部通过；95条检查标签及顺序与旧报告完全相同。双分辨率战斗、技能、成功／失败／取消／鳗鱼捕获和旧档恢复全部保留；生成原顺序11张截图。
- 原frame_ms数组1019个样本，总91194.768毫秒，均值89.494375毫秒，最大197.516毫秒，250毫秒及以上样本0个。没有额外连续观测，也没有通过暂停更多统计或清除样本获得结果。
- Windows原生窗口保护原检查通过，表示当次检查时unfocusable=true、has_focus=false；启动前no_focus配置已核验。本批沿用原入口的检查，不声称新增了逐帧原生焦点观测。Forward+／Vulkan，NVIDIA GeForce RTX 5060，音频Dummy。
- 源体验档前后SHA256同为`A3CC5EBCF08AE7740849513CDB57BC3BBC19AAE84EF08807296047170CF0D1B5`；隔离正式存档，无源档回写。
- 本次均值与前次有观测89.496毫秒接近，未恢复旧报告17.606毫秒的采样均值。这是两次实测对照，不能证明观测没有任何性能影响，也不能外推旧偶发原因。

原始证据：`output/fenshui-uninstrumented-20261030/actual/report.json`、`summary.json`、`engine.log`及11张截图。summary包含完整实际命令、引擎、环境设置、PID、起止、源档摘要和帧统计。

本批没有重新完成人工视觉验收、来源最终验收或主目录集成；未动态验证运行器的超时及失败分支。基线之外仅新增独立运行器和本报告，本地提交不包含profile、.import或output。此前计时观测差异已撤除，不存在新的性能修复提交。

本批00:49:36开始，最多10分钟且绝对截止01:00 +08；此前来源保守累计98分钟，额度120分钟。结束时按实际本批时长继续累计，保留来源约12分钟以上核验额度；新增池570分钟不重复分配。无超过20分钟长命令，无自动重试或额外原生预检。
