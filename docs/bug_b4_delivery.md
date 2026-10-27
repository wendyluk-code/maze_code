# B4 路标修复交付

主会话已审查从冻结基线到最终提交1834dae的完整9文件差异，增量合入 F:/maze_code；2026-10-23目标工作区双分辨率347项场景检查全部通过，正式存档指纹未变。证据位于 output/bugfix_20261023/b4_integrated。执行任务已停止写入并释放单写者租约，以下保留执行工作树的验收与失败记录。分水庭/盐池大范围运动边界仍等待用户标注，不在本票交付内。

## 基线与授权

- 来源任务：01a163b4-c5e2-7720-b326-a59c64b5b1b5，hostId=local。
- 项目：7c3963e8-2c05-4bd9-9992-d9dc706e8cf4；project_binding_verified=true（成功派发记录）。
- 工作区：C:/Users/KSG/.codex/worktrees/b4f4/maze_code；独占分支 codex/bug-b4。
- 冻结基线：codex/bugfix-baseline-20261022，d50be15f12f00326df408cd4c389445abf4c0c93。
- 续修前 HEAD 为检查点5f261fb7c1b8308196c70ccf36960c1c2d08d044，工作树干净。用户2026-10-23确认额外授权 settlement_exit.gd 的局部交互半径43→70，保留路标尺寸。
- B3依赖已由来源确认解除；不带入B2/B3/B5提交。续修预算30分钟、强停45分钟，本次约5分钟；无长命令、无超过重试上限。

## 实现

- spawn_portal.gd 继承 settlement_portal.gd，来源与前进路标共用现有紫色四帧和0.11尺寸，绿色素材保留。
- 按脚底纵坐标选择遮挡：人物在上，路标绘于人物前；人物在下，人物绘于路标前。移除父场景再次重排来源路标的操作。
- 局部阻挡半宽58、半高20世界像素，分步移动并保留沿轴滑动。旧合法站位若位于新增阻挡内，可向外退出。地形数据未修改。
- 返回路标提示与确认统一“前往”，复用 WorldInteractionPrompt（世界交互提示）和 DestinationConfirmation.open_region_choice（区域选择确认）。不全局替换其他业务“返回”。
- SettlementExit.INTERACT_RADIUS 从43改为70，提示和 CaptureRun.finish 结算仍共用 can_bank，避免仅扩提示导致结算失败。
- 保留战斗禁用、E松键确认、取消、结束探索、落点、保存、转场及输入恢复；不修改 scripts/ui_layer.gd 或其用户距离显隐改动。

## 证据与验证

问题证据：baseline 49项8失败，来源路标绿色和“返回”，实景可见人物穿进路标。原实现没有路标局部碰撞且绘制顺序固定。局部阻挡与排序修复后，检查点325项剩2失败，均为横向安全间距超出43像素业务半径；用户批准70后，保留同一断言并补实际结算，347项全部通过。

```powershell
& tools/tests/combat_02_run.ps1 -Mode flow -ScenePath res://tools/tests/bug_b4_flow.tscn -OutputRoot output/bug_b4/approved_final
& tools/tests/combat_02_run.ps1 -Mode smoke -OutputRoot output/bug_b4/approved_smoke
& tools/tests/combat_02_run.ps1 -Mode import -OutputRoot output/bug_b4/approved_import_stable
```

Godot路径已核验：F:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe。

- 真实场景1152×648、1280×720：347项，0失败，进程退出0。
- 覆盖四路标紫色素材/前往文案、可达侧实按方向靠近/离开/阻挡、旧阻挡内合法站位退出、上下遮挡、距离显隐、E/鼠标确认、Esc取消、输入锁恢复、跨区往返与落点、队伍/背包/饱腹/体力保留、战斗禁用、切区及结算保存失败完整回滚、合法站位保存读档、成功结束探索入库。
- 枯水渠业务用横向合法站位(130,714)；另从(142,714)实按A接近路标，再E打开、点击结束探索，实际回餐厅且凝胶只入库一次，两分辨率均通过。
- smoke启动与import_stable编辑器检查通过。approved_import 首次重导入发生 get_multiple_md5 的 f.is_null 缓存校验错误，日志保留；缓存生成后一次复验通过，无脚本或资源错误。
- 最终环境警告仅系统证书读取、编辑器安装目录设置写权限。全部运行 real_saves_unchanged=true；APPDATA/LOCALAPPDATA隔离，未关闭用户游戏。
- 最新证据根目录：C:/Users/KSG/.codex/worktrees/b4f4/maze_code/output/bug_b4/approved_final，含report.json、summary.json、stdout.log、stderr.log和22张双分辨率截图。已查看1152横向提示与1280横向结束探索确认截图；此前已查看两分辨率前后遮挡与确认窗。早期失败证据保留。

## 边界与交接

原地形可达标准侧面：枯水渠东侧、分水庭来源路标南侧、分水庭盐池路标南北、盐池来源路标南北；其余采样受原terrain限制，记录于stdout.log的B4_UNREACHABLE_SIDES，不将强设不可走坐标作为可达证据。大范围可走区域不属于本票，未修改。未单独运行旧存档跨进程重启案例，已覆盖旧站位实按退出及真实文件保存/读档。

主会话从冻结基线到最终提交审查完整9文件增量：原四脚本、bug_b4_flow三文件、本文、settlement_exit.gd；不要只取最后一提交而漏掉5f261fb。自动导入元数据不是交付内容。

主会话已在共享组件库增量登记：共用紫色四帧、前往/结束探索、Esc只取消、局部阻挡58×20半尺寸、脚底排序及枯水渠统一70交互/结算半径。目标工作区另通过卡位回归99项、盐池回归33项及编辑器导入/启动检查，证据分别位于 output/bugfix_20261023 的 b3_regression、b5_regression、final_import、final_smoke。全部正式存档指纹未变，最终无项目错误；证书读取和引擎安装目录编辑器设置写权限告警单独保留。

集成命令包装曾在B3实际99项全通过后误读未由PowerShell运行器设置的外层 LASTEXITCODE，导致后续命令中断；核验summary中的引擎退出码0、失败0与存档指纹后继续运行B5，没有把包装层误报当作游戏失败，也没有删除该记录。

稳定知识：路标提示范围与结算共享 SettlementExit.can_bank，不能只扩大UI；来源节点_ready之后的父场景重排会逆转同层遮挡。修改素材尺寸、角色比例、镜头倍率、地形或路标坐标后，重新跑本专项并审阅实际截图。
