# CH1-QTE-03 烹饪完整流程验收

本票据新增 `tools/tests/ch1_qte_03_input.gd` 与同名 `.tscn`，通过真实 `InputEventKey` / `InputEventMouseButton` 驱动首章：前台接单、仓库鼠标选肉盐、料理台开始/起锅、前台交付。指针由自然 `_process` 推进，未直接写入指针或发射按钮信号。脚本还检查取消、自然超时一星、重复交付、3.6 秒往返与 ±0.08/±0.19 边界。

`tools/tests/ch1_qte_03_run.ps1` 负责隔离 `APPDATA` / `LOCALAPPDATA`、保存 stdout/stderr、检查 JSON 检查数与正式存档 SHA-256 不变。它优先运行 `res://tools/tests/ch1_qte_03_input.tscn`；因此主任务集成本票测试文件后，在主工作区运行：

```powershell
& pwsh -NoProfile -File C:\Users\KSG\.codex\worktrees\6269\maze_code\tools\tests\ch1_qte_03_run.ps1 -ProjectRoot F:\maze_code
```

验收会在 `output/ch1_qte_03/<run>/` 生成 `qte03.json`、`runner-summary.json`、`qte03.stdout.log`、`qte03.stderr.log` 与餐厅背景截图。当前工作树缺少 LFS/导入后的纹理，不能用工作树截图代表最终 UI；最终证据必须来自 `F:\maze_code` 集成后的运行。

## 手动体验入口

保持正式存档不动，用 QTE02 的隔离状态夹具写入“已接单、已取料、尚未开始烹饪”后打开餐厅场景；玩家自行靠近料理台按 `E`，点击“开始烹饪”，让指针自然往返后点击“起锅”，随后到前台按 `E` 交付：

```powershell
$p = 'C:\Users\KSG\.codex\worktrees\6269\maze_code\output\ch1_qte_03_manual'
New-Item -ItemType Directory -Force $p | Out-Null
$old_appdata = $env:APPDATA; $old_localappdata = $env:LOCALAPPDATA; $old_profile = $env:MAZE_QTE02_PROFILE
try {
    $env:APPDATA = $p; $env:LOCALAPPDATA = $p; $env:MAZE_QTE02_PROFILE = $p
    & 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path F:\maze_code --script res://tools/tests/ch1_qte_02_state.gd -- --mode=write --sample=before --report="$p\seed.json"
    & 'F:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --path F:\maze_code --audio-driver Dummy --rendering-method gl_compatibility res://scenes/restaurant_map_2d.tscn
} finally {
    $env:APPDATA = $old_appdata; $env:LOCALAPPDATA = $old_localappdata; $env:MAZE_QTE02_PROFILE = $old_profile
}
```

该入口只使用隔离用户目录；关闭窗口后可直接删除 `output/ch1_qte_03_manual`，不会触碰正式 `user://save.json`。

## 当前检查点

本票测试文件和 runner 已在 `codex/ch1-qte-03` 完成；主工作区复跑需先集成 `.gd`、`.tscn` 与本票 runner。runner 将 `.tscn` 作为 Godot 场景位置参数启动，测试参数放在 `--` 之后。当前脚本覆盖真实首单三档、两种尺寸、仓库布局/滚动条、空仓库确认、地图确认与 `ready_to_depart`；末格多份、拖拽释放、取消重开和选择清空的专门视觉证据复用主工作区 `output/warehouse_hover_check/report.json`（95 checks/0 failures），生产哈希未变，不在本脚本重复注入库存。工作树运行只能做资源/解析检查，因旧工作树缺少导入纹理而未形成可用 GUI 证据。

最终主工作区回放：`output/ch1_qte_03/run_20260925_140420/qte03.json` 为 **218 checks / 0 failures**，`runner-summary.json` 标记 `engine_errors=false`、`real_save_unchanged=true`；截图位于同目录 `screenshots/`。QTE02 生命周期回归报告为 `output/ch1_qte_03/qte02_lifecycle_main/lifecycle.json`（70/0）；其临时 wrapper 的元数据清理路径保护退出码为 1，但场景进程与报告本身均为 0。引擎编辑器、默认启动和餐厅场景无头检查日志位于 `output/ch1_qte_03/engine_checks/`，均无错误输出。
