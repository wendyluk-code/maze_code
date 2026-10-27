# EXIT-FIX-01 石阵结束探索修复

## 状态与边界

已增量合入 F:/maze_code，主工作区 flow 验收99项、0失败，正式存档指纹未变；证据见 output/maze_fixes_20261017/exit_flow。以下保留独立工作树交付记录。工作树 `C:/Users/KSG/.codex/worktrees/c87f/maze_code`，分支 `codex/maze-exit-settlement-fix`，HEAD `f24c4ee5200b06cbe8cc8c0b232e0f7aa8005910`。未提交，未写主工作区。

本票以已批准快照为前置输入，仅修改 capture_run.gd、maze_entry.gd、destination_confirmation.gd，新增 data/maze/settlement_exit.gd 和本票测试、本文档；不包含快照差异，不修改地图或仓库界面。原始副本在 `output/exit_fix_01/original/`，原始及交付哈希在 `output/exit_fix_01/manifest.json`，增量补丁在 `output/exit_fix_01/exit_fix_01.patch`。

## 原因与改动

原版实际场景站石阵 `(116,724)` 按 E 后点“结束探索”显示“返回进度未保存，请重试”。相同状态调用结算返回 `not_exit`（不在出口）；仅改坐标为旧出口 `(13,699)` 即成功。原校验只接受旧出口45像素内，石阵另在43像素范围交互。原版 Esc 同样发出 cancelled（取消）信号，被场景当成结束探索。

新增石阵结算配置，将石阵显示位置、提示位置、交互半径与结算校验共同引用。旧出口45像素条件保留，石阵只接受43像素以内，不允许任意地点入库。结算继续使用原 CaptureRun.finish（结束探索）中的库存、个人饱腹、探索状态、存档与失败回滚事务。

复用现有通行确认与 Toast（短暂提示）组件。新增 open_choice（打开双动作选择）与 secondary_selected（明确选择第二动作）信号，仅石阵使用。鼠标或聚焦后的 Enter 可选择结束探索；Esc 始终关闭。普通 open_confirmation（打开确认）重置选择模式，旧入口、出口继续探索、其他调用方保留取消语义。组件登记内容由主会话合并至组件库，不修改共享文档。

## 验收与证据

运行器 `tools/tests/exit_fix_01_run.ps1` 接受 ProjectRoot（项目根目录）、OutputRoot（输出目录），默认定位自身项目；所有进程设置 APPDATA、LOCALAPPDATA 与隔离标记，实际 user://（用户数据目录）前缀验证通过，未使用玩家存档。每个进程超时240秒。

主工作区复验命令：

```powershell
pwsh -NoProfile -File F:/maze_code/tools/tests/exit_fix_01_run.ps1 -ProjectRoot F:/maze_code -Mode import
pwsh -NoProfile -File F:/maze_code/tools/tests/exit_fix_01_run.ps1 -ProjectRoot F:/maze_code -Mode flow
pwsh -NoProfile -File F:/maze_code/tools/tests/exit_fix_01_run.ps1 -ProjectRoot F:/maze_code -Mode smoke
```

实际运行相同命令但使用本独立工作树：

- `output/exit_fix_01/repro/`：原版12项复现通过，包含错误提示截图、坐标单变量与Esc误触；原版复现脚本保存在该目录。
- `output/exit_fix_01/final/`：87项0失败，完整运行器成功，正式存档前后指纹相同。
- `output/exit_fix_01/acceptance/`：扩展到99项0失败，1152×648及1280×720实际场景渲染；10张截图逐张查看。覆盖石阵距离显隐、按钮边界与不重叠、E打开、Esc关闭、下一区域仅提示、保存失败全量回滚、鼠标/Enter结束、所有可捕获物逐项入库、实际餐厅、重新读档及餐厅重进、重复结算拒绝、仅入场扣20体力、旧出口与入口取消、旧进行中存档继续及结算。
- `output/exit_fix_01/import/`：首次完整导入成功，正式指纹不变。最终 `import_checked/` 引擎退出0，无脚本/资源错误，但正式指纹保护未通过。

最新扩展场景及最终导入期间，正式目录 `saves/1792242698-074-5e80f68aef602ad5.json` 哈希发生变化。运行器按原规则报失败，未放宽检查；本进程的实际保存路径在各输出目录 profile/Godot/app_userdata/maze_code/chapter-ending-test.json。来源主会话与另一票也观察到相同文件变化，来源主会话已确证主项目编辑器PID67136及子游戏PID58592正在运行（游戏参数 --path F:/maze_code --scene res://scenes/start_screen.tscn），正式指纹门禁受外部运行游戏影响；不能声称最新整套运行器全部通过。未回退该文件、未终止其他游戏进程。主会话应在玩家未操作正式存档的时段重新验收并核验指纹。

环境错误单列：系统证书存储读取失败；编辑器无法写引擎安装目录 editor_settings-4.7.tres。均未伴随脚本解析或资源缺失。初次开发测试出现缩进解析错误和JSON数值类型直接比较误报，已修正；记录保留在 verified、verified2，最终功能报告无此错误。

主工作区流程现已复验通过。仍未覆盖：完整地图步行/捕获路线（本票用有效物资夹具直达石阵，验证所有物资结算而非重新验收捕获）；场景加载失败的注入路径。本票未改旧场景切换失败回滚逻辑。正式指纹门禁需待外部游戏停止写盘后由主会话复验。

## 可复用知识

通行弹窗的关闭与第二业务动作必须分离：Esc是关闭，结束探索是显式业务选择。正例为石阵 open_choice + secondary_selected，反例为把 cancelled 绑定结算。普通确认每次打开重置模式；更改公共组件输入处理时复验石阵Esc、两按钮与普通确认取消。

显示/交互与结算位置统一使用 settlement_exit 配置，旧出口兼容单独保留。更换石阵位置或半径时重跑距离、合法出口与非法远点断言。JSON读档数值可由整数变为浮点，状态等价比较必须比较数值，不能把类型差异当作存档丢失。
